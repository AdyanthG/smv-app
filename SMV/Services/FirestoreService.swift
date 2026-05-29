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

    func saveScanResult(userId: String, result: ScanResult) async -> String? {
        let data: [String: Any] = [
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
            "timestamp": FieldValue.serverTimestamp(),
        ]

        do {
            let docRef = try await db.collection("scans").addDocument(data: data)

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
                "isProfilePublic": true, // Default to public
            ]

            // Only set firstScore on the very first scan
            if currentScanCount == 0 {
                updateData["firstScore"] = result.overallScore
            }

            try await userRef.setData(updateData, merge: true)

            return docRef.documentID
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Update a scan document with image download URLs after storage upload
    func updateScanImageURLs(scanDocId: String, urls: [String: String]) async {
        do {
            try await db.collection("scans").document(scanDocId).setData(urls, merge: true)
        } catch {
            errorMessage = error.localizedDescription
        }
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
            let data = doc.data()
            var results: [(String, String)] = []

            let angleKeys = [
                ("Front", "frontImageURL"),
                ("Left", "leftImageURL"),
                ("Right", "rightImageURL"),
                ("Up", "upTiltImageURL"),
                ("Down", "downTiltImageURL"),
            ]

            for (label, key) in angleKeys {
                if let url = data[key] as? String {
                    results.append((label, url))
                }
            }

            return results
        } catch {
            return []
        }
    }

    // MARK: - Posts

    func savePost(
        authorId: String,
        authorName: String,
        authorHandle: String,
        caption: String,
        hashtags: [String],
        scanResultId: String? = nil,
        authorScore: Double? = nil
    ) async -> String? {
        let data: [String: Any] = [
            "authorId": authorId,
            "authorName": authorName,
            "authorHandle": authorHandle,
            "caption": caption,
            "hashtags": hashtags,
            "scanResultId": scanResultId as Any,
            "authorScore": authorScore as Any,
            "likeCount": 0,
            "commentCount": 0,
            "isPublic": true,
            "createdAt": FieldValue.serverTimestamp(),
        ]

        do {
            let docRef = try await db.collection("posts").addDocument(data: data)
            return docRef.documentID
        } catch {
            errorMessage = error.localizedDescription
            return nil
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

    func fetchLeaderboard(
        category: String = "Global",
        timeframe: String = "All Time",
        limit: Int = 50
    ) async -> [[String: Any]] {
        do {
            // Determine the sort field from category
            let sortField: String
            if let cat = LeaderboardCategory(rawValue: category) {
                sortField = cat.firestoreField
            } else {
                sortField = "bestScore"
            }

            // Always fetch by score — avoids Firestore composite index requirements
            let query: Query = db.collection("users")
                .order(by: sortField, descending: true)
                .limit(to: limit * 3) // Over-fetch to account for timeframe filtering

            let snapshot = try await query.getDocuments()

            // Compute EST-based cutoff dates for timeframe filtering
            var estCalendar = Calendar.current
            estCalendar.timeZone = estTimeZone
            let now = Date()

            let cutoffDate: Date? = {
                switch timeframe {
                case "Today":
                    return estCalendar.startOfDay(for: now)
                case "This Week":
                    return estCalendar.date(byAdding: .day, value: -7, to: estCalendar.startOfDay(for: now))
                default:
                    return nil // All Time — no cutoff
                }
            }()

            // Filter and sort in-memory
            let isMostImproved = category == "Most Improved"
            let results = snapshot.documents.compactMap { doc -> [String: Any]? in
                var data = doc.data()
                data["id"] = doc.documentID

                // Filter out private profiles
                if data["isProfilePublic"] as? Bool == false { return nil }

                // Must have a score > 0 in the sort field
                let score = data[sortField] as? Double ?? 0
                if score <= 0 { return nil }

                // For Most Improved, require at least 2 scans
                if isMostImproved {
                    let scanCount = data["scanCount"] as? Int ?? 0
                    if scanCount < 2 { return nil }
                }

                // Apply timeframe filter (in-memory using EST)
                if let cutoff = cutoffDate {
                    guard let lastScanTimestamp = data["lastScanAt"] as? Timestamp else { return nil }
                    if lastScanTimestamp.dateValue() < cutoff { return nil }
                }

                return data
            }.sorted { a, b in
                let aScore = a[sortField] as? Double ?? 0
                let bScore = b[sortField] as? Double ?? 0
                return aScore > bScore
            }

            // Apply final limit and assign ranks
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
