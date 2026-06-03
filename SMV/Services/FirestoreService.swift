//
//  FirestoreService.swift
//  SMV
//
//  Cloud Firestore service for user profiles, scan results,
//  posts, and leaderboard data.
//

import Foundation
import FirebaseFirestore

@Observable
final class FirestoreService {

    private var db: Firestore { Firestore.firestore() }

    var errorMessage: String?

    // MARK: - User Profiles

    func saveUserProfile(
        userId: String,
        displayName: String,
        handle: String = "",
        bio: String = "",
        gender: String = "Male",
        avatarURL: String? = nil,
        latestScore: Double? = nil
    ) async {
        var data: [String: Any] = [
            "displayName": displayName,
            "handle": handle,
            "handleLower": handle.trimmingCharacters(in: .whitespaces).lowercased(),
            "bio": bio,
            "gender": gender,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let score = latestScore {
            data["latestScore"] = score
        }
        if let avatar = avatarURL {
            data["avatarURL"] = avatar
        }

        do {
            try await db.collection("users").document(userId).setData(data, merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Whether a handle is free (case-insensitive), ignoring the current user.
    /// Empty handles are always "available" (treated as unset).
    func isHandleAvailable(_ handle: String, excludingUserId: String) async -> Bool {
        let normalized = handle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !normalized.isEmpty else { return true }
        do {
            let snapshot = try await db.collection("users")
                .whereField("handleLower", isEqualTo: normalized)
                .limit(to: 1)
                .getDocuments()
            // Available if nobody else holds it.
            return snapshot.documents.allSatisfy { $0.documentID == excludingUserId }
        } catch {
            // On error, don't block the user — fail open.
            return true
        }
    }

    func fetchUserProfile(userId: String) async -> [String: Any]? {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return doc.data()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Scan Results

    /// Save a scan. The Firestore document ID is the local `result.id`, so a scan
    /// resolves identically whether referenced locally or remotely (posts,
    /// profiles, leaderboard). `imageURLs` (frontImageURL, etc.) are written into
    /// the same document when provided. Returns the scan document ID, or nil only
    /// if the scan-document write fails (the user-aggregate update is best-effort
    /// and never discards a successfully-written scan).
    @discardableResult
    func saveScanResult(userId: String, result: ScanResult, imageURLs: [String: String] = [:]) async -> String? {
        let scanId = result.id
        var data: [String: Any] = [
            "userId": userId,
            "overallScore": result.overallScore,
            "eyeAreaScore": result.eyeAreaScore,
            "jawScore": result.jawScore,
            "symmetryScore": result.symmetryScore,
            "harmonyScore": result.harmonyScore,
            "proportionsScore": result.proportionsScore,
            "skinClarityScore": result.skinClarityScore,
            "fwhr": result.fwhr,
            "canthalTiltDegrees": result.canthalTiltDegrees,
            "gonialAngleDegrees": result.gonialAngleDegrees,
            "facialThirdsDeviation": result.facialThirdsDeviation,
            "ipdRatio": result.ipdRatio,
            "eyeAspectRatio": result.eyeAspectRatio,
            "noseWidthRatio": result.noseWidthRatio,
            "lipRatio": result.lipRatio,
            "philtrumRatio": result.philtrumRatio,
            "rawSymmetry": result.rawSymmetry,
            "failos": result.failos,
            "failoPenalty": result.failoPenalty,
            "isMultiAngleScan": result.isMultiAngleScan,
            "timestamp": FieldValue.serverTimestamp(),
        ]
        for (field, url) in imageURLs { data[field] = url }

        // 1) Write the scan document (deterministic ID). This is the critical write.
        do {
            try await db.collection("scans").document(scanId).setData(data, merge: true)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }

        // 2) Update the user aggregate (leaderboard stats). Best-effort: a failure
        //    here must not discard the scan we just saved.
        do {
            // Update user's latest score and stats
            let userRef = db.collection("users").document(userId)
            let userDoc = try await userRef.getDocument()
            let userData = userDoc.data() ?? [:]
            let currentBest = userData["bestScore"] as? Double ?? 0
            let currentScanCount = userData["scanCount"] as? Int ?? 0

            // Per-category current bests
            let currentBestEyeArea = userData["bestEyeAreaScore"] as? Double ?? 0
            let currentBestJaw = userData["bestJawScore"] as? Double ?? 0
            let currentBestSymmetry = userData["bestSymmetryScore"] as? Double ?? 0
            let currentBestHarmony = userData["bestHarmonyScore"] as? Double ?? 0
            let currentBestProportions = userData["bestProportionsScore"] as? Double ?? 0
            let currentBestSkinClarity = userData["bestSkinClarityScore"] as? Double ?? 0

            // First score tracking (for Most Improved)
            let firstScore = userData["firstScore"] as? Double ?? result.overallScore

            // Improvement rate: (latest - first) / sqrt(scanCount + 1)
            // sqrt prevents gaming by doing many bad scans then one good one
            let improvement = max(0, result.overallScore - firstScore)
            let improvementRate = improvement / sqrt(Double(currentScanCount + 1))

            // Streak calculation
            let streak = computeStreak(lastScanTimestamp: userData["lastScanAt"], currentStreak: userData["streak"] as? Int ?? 0)

            var updateData: [String: Any] = [
                "latestScore": result.overallScore,
                "bestScore": max(currentBest, result.overallScore),
                // Per-category latest scores
                "latestEyeAreaScore": result.eyeAreaScore,
                "latestJawScore": result.jawScore,
                "latestSymmetryScore": result.symmetryScore,
                "latestHarmonyScore": result.harmonyScore,
                "latestProportionsScore": result.proportionsScore,
                "latestSkinClarityScore": result.skinClarityScore,
                // Per-category best scores (used for leaderboard ranking)
                "bestEyeAreaScore": max(currentBestEyeArea, result.eyeAreaScore),
                "bestJawScore": max(currentBestJaw, result.jawScore),
                "bestSymmetryScore": max(currentBestSymmetry, result.symmetryScore),
                "bestHarmonyScore": max(currentBestHarmony, result.harmonyScore),
                "bestProportionsScore": max(currentBestProportions, result.proportionsScore),
                "bestSkinClarityScore": max(currentBestSkinClarity, result.skinClarityScore),
                "improvementRate": improvementRate,
                "scanCount": FieldValue.increment(Int64(1)),
                "lastScanAt": FieldValue.serverTimestamp(),
                "streak": streak,
            ]

            // Only set firstScore on the very first scan
            if currentScanCount == 0 {
                updateData["firstScore"] = result.overallScore
            }

            try await userRef.setData(updateData, merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }

        return scanId
    }

    /// Fetch all angle image URLs for a user's latest scan (for gallery view)
    func fetchScanGalleryURLs(userId: String) async -> [(angle: String, url: String)] {
        do {
            let snapshot = try await db.collection("scans")
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else { return [] }
            return angleURLs(from: doc.data())
        } catch {
            return []
        }
    }

    /// Ordered angle keys shared by gallery fetches: (label, scan-doc field)
    private static let angleURLKeys: [(label: String, field: String)] = [
        ("Front", "frontImageURL"),
        ("Left", "leftImageURL"),
        ("Right", "rightImageURL"),
        ("Up", "upTiltImageURL"),
        ("Down", "downTiltImageURL"),
    ]

    /// Extract angle image URLs from a scan document's data
    private func angleURLs(from data: [String: Any]) -> [(angle: String, url: String)] {
        FirestoreService.angleURLKeys.compactMap { label, field in
            guard let url = data[field] as? String else { return nil }
            return (label, url)
        }
    }

    /// Fetch a single scan document by its Firestore document ID
    func fetchScan(scanId: String) async -> [String: Any]? {
        do {
            let doc = try await db.collection("scans").document(scanId).getDocument()
            guard var data = doc.data() else { return nil }
            data["id"] = doc.documentID
            return data
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Fetch all of a user's scans (sorted newest-first in memory to avoid a
    /// composite index requirement). Each dict includes the document `id`.
    func fetchUserScans(userId: String, limit: Int = 30) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection("scans")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()

            let scans = snapshot.documents.map { doc -> [String: Any] in
                var data = doc.data()
                data["id"] = doc.documentID
                return data
            }.sorted { a, b in
                let aTime = (a["timestamp"] as? Timestamp)?.dateValue() ?? .distantPast
                let bTime = (b["timestamp"] as? Timestamp)?.dateValue() ?? .distantPast
                return aTime > bTime
            }

            return Array(scans.prefix(limit))
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    /// Fetch the angle gallery for the scan that achieved a user's best score in
    /// the given scan field (e.g. "overallScore", "eyeAreaScore"). Returns the
    /// chosen scan's document id plus its angle image URLs.
    func fetchScanGallery(userId: String, scoreField: String) async -> (scanId: String?, images: [(angle: String, url: String)]) {
        let scans = await fetchUserScans(userId: userId)
        guard let best = scans.max(by: { a, b in
            (a[scoreField] as? Double ?? 0) < (b[scoreField] as? Double ?? 0)
        }) else { return (nil, []) }
        return (best["id"] as? String, angleURLs(from: best))
    }

    /// Fetch the angle gallery for one specific scan document
    func fetchScanGalleryForScan(scanId: String) async -> [(angle: String, url: String)] {
        guard let data = await fetchScan(scanId: scanId) else { return [] }
        return angleURLs(from: data)
    }

    // MARK: - Posts

    func savePost(
        authorId: String,
        authorName: String,
        authorHandle: String,
        caption: String,
        hashtags: [String],
        scanResultId: String? = nil,
        authorScore: Double? = nil,
        authorAvatarURL: String? = nil,
        imageURL: String? = nil,
        scoreChange: Double? = nil,
        isPublic: Bool = true
    ) async -> String? {
        var data: [String: Any] = [
            "authorId": authorId,
            "authorName": authorName,
            "authorHandle": authorHandle,
            "caption": caption,
            "hashtags": hashtags,
            "scanResultId": scanResultId as Any,
            "authorScore": authorScore as Any,
            "likeCount": 0,
            "commentCount": 0,
            "isPublic": isPublic,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let authorAvatarURL { data["authorAvatarURL"] = authorAvatarURL }
        if let imageURL { data["imageURL"] = imageURL }
        if let scoreChange { data["scoreChange"] = scoreChange }

        do {
            let docRef = try await db.collection("posts").addDocument(data: data)
            return docRef.documentID
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Fetch a single post document by ID (for opening posts not cached locally)
    func fetchPost(postId: String) async -> [String: Any]? {
        do {
            let doc = try await db.collection("posts").document(postId).getDocument()
            guard var data = doc.data() else { return nil }
            data["id"] = doc.documentID
            return data
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Fetch comments for a post, oldest-first (sorted in memory)
    func fetchComments(postId: String) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection("posts").document(postId)
                .collection("comments").getDocuments()
            return snapshot.documents.map { doc -> [String: Any] in
                var data = doc.data()
                data["id"] = doc.documentID
                return data
            }.sorted { a, b in
                let aTime = (a["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
                let bTime = (b["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
                return aTime < bTime
            }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    /// Whether the given user has liked a post
    func isPostLiked(postId: String, userId: String) async -> Bool {
        do {
            let doc = try await db.collection("posts").document(postId)
                .collection("likes").document(userId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }

    func fetchFeedPosts(limit: Int = 20) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection("posts")
                .whereField("isPublic", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.map { doc in
                var data = doc.data()
                data["id"] = doc.documentID
                return data
            }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func toggleLike(postId: String, userId: String) async {
        let likeRef = db.collection("posts").document(postId)
            .collection("likes").document(userId)

        do {
            let doc = try await likeRef.getDocument()
            if doc.exists {
                try await likeRef.delete()
                try await db.collection("posts").document(postId).updateData([
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
            } else {
                try await likeRef.setData(["timestamp": FieldValue.serverTimestamp()])
                try await db.collection("posts").document(postId).updateData([
                    "likeCount": FieldValue.increment(Int64(1))
                ])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Moderation (Report / Block)

    /// File a report against a post for review (App Store UGC requirement).
    func reportPost(postId: String, authorId: String, reporterId: String, reason: String) async {
        do {
            try await db.collection("reports").addDocument(data: [
                "postId": postId,
                "authorId": authorId,
                "reporterId": reporterId,
                "reason": reason,
                "status": "pending",
                "createdAt": FieldValue.serverTimestamp(),
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Block a user. Their content is hidden from the blocker's feed.
    func blockUser(userId: String, blockedId: String) async {
        do {
            try await db.collection("users").document(userId)
                .collection("blocked").document(blockedId)
                .setData(["timestamp": FieldValue.serverTimestamp()])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unblockUser(userId: String, blockedId: String) async {
        try? await db.collection("users").document(userId)
            .collection("blocked").document(blockedId).delete()
    }

    /// IDs the user has blocked (to filter feeds/leaderboards/profiles).
    func fetchBlockedIds(userId: String) async -> Set<String> {
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("blocked").getDocuments()
            return Set(snapshot.documents.map { $0.documentID })
        } catch {
            return []
        }
    }

    // MARK: - Saves (Bookmarks)

    /// Whether the given user has saved/bookmarked a post
    func isPostSaved(postId: String, userId: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(userId)
                .collection("saved").document(postId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }

    /// Toggle a post's saved state for a user. Stored under users/{uid}/saved/{postId}.
    func toggleSave(postId: String, userId: String) async {
        let savedRef = db.collection("users").document(userId)
            .collection("saved").document(postId)
        do {
            let doc = try await savedRef.getDocument()
            if doc.exists {
                try await savedRef.delete()
            } else {
                try await savedRef.setData([
                    "postId": postId,
                    "timestamp": FieldValue.serverTimestamp(),
                ])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Comments

    func saveComment(
        postId: String,
        authorId: String,
        authorName: String,
        body: String
    ) async {
        let data: [String: Any] = [
            "postId": postId,
            "authorId": authorId,
            "authorName": authorName,
            "body": body,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        do {
            try await db.collection("posts").document(postId)
                .collection("comments").addDocument(data: data)
            // Increment comment count on post
            try await db.collection("posts").document(postId).updateData([
                "commentCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Leaderboard

    /// EST timezone used for leaderboard timeframe boundaries
    private var estTimeZone: TimeZone {
        TimeZone(identifier: "America/New_York") ?? TimeZone(secondsFromGMT: -5 * 3600)!
    }

    /// Read a Firestore numeric value as Double whether it's stored as a Double
    /// or an Int (e.g. counters like voteWins use integer increments).
    static func numericValue(_ any: Any?) -> Double {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        return 0
    }

    /// EST-based cutoff for a timeframe. Returns nil for "All Time".
    private func cutoffDate(for timeframe: String) -> Date? {
        var estCalendar = Calendar.current
        estCalendar.timeZone = estTimeZone
        let now = Date()
        switch timeframe {
        case "Today":
            return estCalendar.startOfDay(for: now)
        case "This Week":
            return estCalendar.date(byAdding: .day, value: -7, to: estCalendar.startOfDay(for: now))
        default:
            return nil
        }
    }

    func fetchLeaderboard(
        category: String = "Global",
        timeframe: String = "All Time",
        limit: Int = 50
    ) async -> [[String: Any]] {
        let cat = LeaderboardCategory(rawValue: category) ?? .global

        // Timeframe-scoped leaderboards (Today / This Week) must rank by the best
        // *scan within that window*, not the user's all-time aggregate. Most
        // Improved and Most Voted are inherently cumulative, so they always use
        // the aggregate path.
        if let cutoff = cutoffDate(for: timeframe), cat != .mostImproved, cat != .mostVoted {
            return await fetchTimeframeLeaderboard(scanField: cat.scanField, cutoff: cutoff, limit: limit)
        }

        // All Time (and Most Improved): rank by the user aggregate field.
        let sortField = cat.firestoreField
        do {
            let snapshot = try await db.collection("users")
                .order(by: sortField, descending: true)
                .limit(to: limit * 3)
                .getDocuments()

            let isMostImproved = cat == .mostImproved
            let results = snapshot.documents.compactMap { doc -> [String: Any]? in
                var data = doc.data()
                data["id"] = doc.documentID

                if data["isProfilePublic"] as? Bool == false { return nil }

                // Coerce the ranking value to Double (some fields, e.g. voteWins,
                // are stored as integers).
                let score = Self.numericValue(data[sortField])
                if score <= 0 { return nil }

                if isMostImproved {
                    let scanCount = data["scanCount"] as? Int ?? 0
                    if scanCount < 2 { return nil }
                }

                // Unified score key used by the leaderboard view.
                data["leaderboardScore"] = score
                return data
            }.sorted { a, b in
                Self.numericValue(a[sortField]) > Self.numericValue(b[sortField])
            }

            return Array(results.prefix(limit)).enumerated().map { index, item in
                var data = item
                data["rank"] = index + 1
                return data
            }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    /// Rank users by their best scan in the given field since `cutoff`. Each
    /// entry carries the exact scan id that earned the score so the gallery/avatar
    /// can open *that* scan (not the all-time best).
    private func fetchTimeframeLeaderboard(scanField: String, cutoff: Date, limit: Int) async -> [[String: Any]] {
        do {
            // Single-field range filter → uses the default index, no composite index.
            let snapshot = try await db.collection("scans")
                .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: cutoff))
                .getDocuments()

            // Best scan per user within the window.
            struct Best { var score: Double; var scanId: String; var count: Int }
            var bestByUser: [String: Best] = [:]
            for doc in snapshot.documents {
                let data = doc.data()
                guard let uid = data["userId"] as? String else { continue }
                let score = data[scanField] as? Double ?? 0
                if score <= 0 { continue }
                if var existing = bestByUser[uid] {
                    existing.count += 1
                    if score > existing.score {
                        existing.score = score
                        existing.scanId = doc.documentID
                    }
                    bestByUser[uid] = existing
                } else {
                    bestByUser[uid] = Best(score: score, scanId: doc.documentID, count: 1)
                }
            }

            // Highest scorers first; join with profiles for display + privacy.
            let ranked = bestByUser.sorted { $0.value.score > $1.value.score }.prefix(limit)
            var results: [[String: Any]] = []
            for (uid, best) in ranked {
                guard let profile = await fetchUserProfile(userId: uid) else { continue }
                if profile["isProfilePublic"] as? Bool == false { continue }
                guard let name = profile["displayName"] as? String else { continue }
                results.append([
                    "id": uid,
                    "displayName": name,
                    "avatarURL": profile["avatarURL"] as Any,
                    "scanCount": best.count,
                    "leaderboardScore": best.score,
                    "scanId": best.scanId,
                    "rank": results.count + 1,
                ])
            }
            return results
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    // MARK: - User Stats

    func fetchUserStats(userId: String) async -> (scanCount: Int, bestScore: Double, streak: Int) {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let data = doc.data() ?? [:]
            return (
                scanCount: data["scanCount"] as? Int ?? 0,
                bestScore: data["bestScore"] as? Double ?? 0,
                streak: data["streak"] as? Int ?? 0
            )
        } catch {
            return (0, 0, 0)
        }
    }

    // MARK: - Referral System

    /// Get or generate a unique referral code for a user
    func getReferralCode(userId: String) async -> String {
        let userRef = db.collection("users").document(userId)
        do {
            let doc = try await userRef.getDocument()
            if let code = doc.data()?["referralCode"] as? String {
                return code
            }
            // Generate a short code: first 6 chars of userId
            let code = "SMV-" + String(userId.prefix(6)).uppercased()
            try await userRef.setData(["referralCode": code, "referralCount": 0], merge: true)
            return code
        } catch {
            return "SMV-ERROR"
        }
    }

    /// Redeem a referral code (called when new user signs up with a code)
    func redeemReferral(code: String, newUserId: String) async -> Bool {
        do {
            // Find the user who owns this code
            let snapshot = try await db.collection("users")
                .whereField("referralCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()

            guard let referrerDoc = snapshot.documents.first else { return false }
            let referrerId = referrerDoc.documentID

            // Don't let users refer themselves
            guard referrerId != newUserId else { return false }

            // Increment referral count
            try await db.collection("users").document(referrerId).updateData([
                "referralCount": FieldValue.increment(Int64(1))
            ])

            // Record who referred this user
            try await db.collection("users").document(newUserId).setData([
                "referredBy": referrerId,
                "referredByCode": code,
            ], merge: true)

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Get referral count for a user
    func getReferralCount(userId: String) async -> Int {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return doc.data()?["referralCount"] as? Int ?? 0
        } catch {
            return 0
        }
    }

    // MARK: - Follow System

    func followUser(userId: String, targetId: String) async {
        let batch = db.batch()

        // Add to follower's "following" subcollection
        let followingRef = db.collection("users").document(userId)
            .collection("following").document(targetId)
        batch.setData(["timestamp": FieldValue.serverTimestamp()], forDocument: followingRef)

        // Add to target's "followers" subcollection
        let followersRef = db.collection("users").document(targetId)
            .collection("followers").document(userId)
        batch.setData(["timestamp": FieldValue.serverTimestamp()], forDocument: followersRef)

        // Increment counts using updateData (only touches specified fields)
        let userRef = db.collection("users").document(userId)
        batch.updateData(["followingCount": FieldValue.increment(Int64(1))], forDocument: userRef)

        let targetRef = db.collection("users").document(targetId)
        batch.updateData(["followerCount": FieldValue.increment(Int64(1))], forDocument: targetRef)

        do {
            try await batch.commit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unfollowUser(userId: String, targetId: String) async {
        let batch = db.batch()

        let followingRef = db.collection("users").document(userId)
            .collection("following").document(targetId)
        batch.deleteDocument(followingRef)

        let followersRef = db.collection("users").document(targetId)
            .collection("followers").document(userId)
        batch.deleteDocument(followersRef)

        let userRef = db.collection("users").document(userId)
        batch.updateData(["followingCount": FieldValue.increment(Int64(-1))], forDocument: userRef)

        let targetRef = db.collection("users").document(targetId)
        batch.updateData(["followerCount": FieldValue.increment(Int64(-1))], forDocument: targetRef)

        do {
            try await batch.commit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isFollowing(userId: String, targetId: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(userId)
                .collection("following").document(targetId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }

    /// Fetch the set of user IDs that the given user follows (for the Following feed)
    func fetchFollowingIds(userId: String) async -> [String] {
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("following").getDocuments()
            return snapshot.documents.map { $0.documentID }
        } catch {
            return []
        }
    }

    func getFollowCounts(userId: String) async -> (followers: Int, following: Int) {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            let data = doc.data() ?? [:]
            let followers = data["followerCount"] as? Int ?? 0
            let following = data["followingCount"] as? Int ?? 0
            return (followers, following)
        } catch {
            return (0, 0)
        }
    }

    // MARK: - FCM Token

    func saveFCMToken(userId: String, token: String) async {
        do {
            try await db.collection("users").document(userId).setData([
                "fcmToken": token,
                "tokenUpdatedAt": FieldValue.serverTimestamp(),
            ], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Voting System

    /// Fetch a pair of users with similar scores for comparison voting
    func fetchVotePair(excludeUserId: String) async -> ([String: Any]?, [String: Any]?) {
        do {
            // Fetch users who have scanned, ordered by score
            let snapshot = try await db.collection("users")
                .whereField("scanCount", isGreaterThan: 0)
                .order(by: "scanCount")
                .order(by: "latestScore", descending: true)
                .limit(to: 100)
                .getDocuments()

            var candidates = snapshot.documents
                .filter { $0.documentID != excludeUserId }
                .map { doc -> [String: Any] in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return data
                }
                .filter { ($0["latestScore"] as? Double ?? 0) > 0 }

            guard candidates.count >= 2 else { return (nil, nil) }

            // Shuffle then pick a pair with scores within ±1.0
            candidates.shuffle()
            let first = candidates[0]
            let firstScore = first["latestScore"] as? Double ?? 5.0

            // Find a match within ±1.0 score range
            if let matchIdx = candidates.dropFirst().firstIndex(where: { candidate in
                let score = candidate["latestScore"] as? Double ?? 5.0
                return abs(score - firstScore) <= 1.0
            }) {
                return (first, candidates[matchIdx])
            }

            // Fallback: just pick two random
            return (candidates[0], candidates[1])
        } catch {
            errorMessage = error.localizedDescription
            return (nil, nil)
        }
    }

    /// Record a vote: increment winner's voteWins, loser's voteLosses
    func recordVote(winnerId: String, loserId: String, voterId: String) async {
        let batch = db.batch()

        let winnerRef = db.collection("users").document(winnerId)
        batch.setData(["voteWins": FieldValue.increment(Int64(1))], forDocument: winnerRef, merge: true)

        let loserRef = db.collection("users").document(loserId)
        batch.setData(["voteLosses": FieldValue.increment(Int64(1))], forDocument: loserRef, merge: true)

        // Record the individual vote for audit/anti-abuse
        let voteRef = db.collection("votes").document()
        batch.setData([
            "voterId": voterId,
            "winnerId": winnerId,
            "loserId": loserId,
            "timestamp": FieldValue.serverTimestamp(),
        ], forDocument: voteRef)

        do {
            try await batch.commit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetch a user's scan images (front/left/right URLs) for voting cards
    func fetchLatestScanImages(userId: String) async -> [String: String] {
        do {
            let snapshot = try await db.collection("scans")
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else { return [:] }
            let data = doc.data()
            var urls: [String: String] = [:]
            if let url = data["frontImageURL"] as? String { urls["front"] = url }
            if let url = data["leftImageURL"] as? String { urls["left"] = url }
            if let url = data["rightImageURL"] as? String { urls["right"] = url }
            if let url = data["upTiltImageURL"] as? String { urls["up"] = url }
            if let url = data["downTiltImageURL"] as? String { urls["down"] = url }
            return urls
        } catch {
            return [:]
        }
    }

    // MARK: - Account Deletion

    /// Best-effort deletion of all of a user's cloud data. Must be called while
    /// the user is still authenticated (rules require the owner). Subcollections
    /// written by *other* users (e.g. this user's `followers`) are intentionally
    /// not enumerated here — a Cloud Function is the robust path for full fan-out
    /// cleanup, but this removes the bulk of the account's PII.
    func deleteAllUserData(userId: String) async {
        // 1) Scans
        if let scans = try? await db.collection("scans")
            .whereField("userId", isEqualTo: userId).getDocuments() {
            for doc in scans.documents { try? await doc.reference.delete() }
        }

        // 2) Posts (and their like/comment subcollections are removed with the doc
        //    on the client's view; server-side orphans need a Function to sweep)
        if let posts = try? await db.collection("posts")
            .whereField("authorId", isEqualTo: userId).getDocuments() {
            for doc in posts.documents { try? await doc.reference.delete() }
        }

        // 3) Owned subcollections under the user document
        for sub in ["following", "saved"] {
            if let docs = try? await db.collection("users").document(userId)
                .collection(sub).getDocuments() {
                for doc in docs.documents { try? await doc.reference.delete() }
            }
        }

        // 4) The user profile document itself
        try? await db.collection("users").document(userId).delete()
    }

    // MARK: - Profile Visibility

    func setProfilePublic(userId: String, isPublic: Bool) async {
        do {
            try await db.collection("users").document(userId).setData([
                "isProfilePublic": isPublic,
            ], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Persist the push-notification opt-in so Cloud Functions honor it.
    func setNotificationsEnabled(userId: String, enabled: Bool) async {
        do {
            try await db.collection("users").document(userId).setData([
                "notificationsEnabled": enabled,
            ], merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Streak

    func fetchUserStreak(userId: String) async -> Int {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return doc.data()?["streak"] as? Int ?? 0
        } catch {
            return 0
        }
    }

    /// Compute streak: if last scan was within 24-48h (different calendar day), increment.
    /// If same calendar day, keep current. If >48h gap, reset to 1.
    private func computeStreak(lastScanTimestamp: Any?, currentStreak: Int) -> Int {
        guard let timestamp = lastScanTimestamp as? Timestamp else {
            return 1 // First scan ever
        }

        let lastScanDate = timestamp.dateValue()
        let calendar = Calendar.current
        let now = Date()

        // Same calendar day → streak stays the same
        if calendar.isDate(lastScanDate, inSameDayAs: now) {
            return max(1, currentStreak)
        }

        // Yesterday → increment streak
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(lastScanDate, inSameDayAs: yesterday) {
            return currentStreak + 1
        }

        // >1 day gap → reset to 1
        return 1
    }
}
