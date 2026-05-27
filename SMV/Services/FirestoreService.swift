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
            let currentBest = userDoc.data()?["bestScore"] as? Double ?? 0

            try await userRef.setData([
                "latestScore": result.overallScore,
                "bestScore": max(currentBest, result.overallScore),
                "scanCount": FieldValue.increment(Int64(1)),
                "lastScanAt": FieldValue.serverTimestamp(),
            ], merge: true)

            return docRef.documentID
        } catch {
            errorMessage = error.localizedDescription
            return nil
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

    func fetchLeaderboard(
        category: String = "global",
        timeframe: String = "allTime",
        limit: Int = 50
    ) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "latestScore", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.enumerated().map { index, doc in
                var data = doc.data()
                data["id"] = doc.documentID
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

        // Increment counts
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

    // MARK: - Forum Threads

    func createThread(
        id: String,
        categoryId: String,
        authorId: String,
        authorName: String,
        authorHandle: String,
        authorScore: Double?,
        title: String,
        body: String
    ) async {
        var data: [String: Any] = [
            "categoryId": categoryId,
            "authorId": authorId,
            "authorName": authorName,
            "authorHandle": authorHandle,
            "title": title,
            "body": body,
            "replyCount": 0,
            "viewCount": 0,
            "likeCount": 0,
            "isPinned": false,
            "createdAt": FieldValue.serverTimestamp(),
            "lastActivityAt": FieldValue.serverTimestamp(),
        ]
        if let score = authorScore {
            data["authorScore"] = score
        }

        do {
            try await db.collection("threads").document(id).setData(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchThreads(categoryId: String) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection("threads")
                .whereField("categoryId", isEqualTo: categoryId)
                .order(by: "lastActivityAt", descending: true)
                .limit(to: 50)
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

    // MARK: - Forum Replies

    func createReply(
        id: String,
        threadId: String,
        authorId: String,
        authorName: String,
        authorHandle: String,
        authorScore: Double?,
        body: String
    ) async {
        var data: [String: Any] = [
            "threadId": threadId,
            "authorId": authorId,
            "authorName": authorName,
            "authorHandle": authorHandle,
            "body": body,
            "likeCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        if let score = authorScore {
            data["authorScore"] = score
        }

        do {
            try await db.collection("replies").document(id).setData(data)
            // Increment reply count on thread
            try await db.collection("threads").document(threadId).updateData([
                "replyCount": FieldValue.increment(Int64(1)),
                "lastActivityAt": FieldValue.serverTimestamp(),
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchReplies(threadId: String) async -> [[String: Any]] {
        do {
            let snapshot = try await db.collection("replies")
                .whereField("threadId", isEqualTo: threadId)
                .order(by: "createdAt", descending: false)
                .limit(to: 100)
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

    // MARK: - Forum Likes

    func likeThread(threadId: String, increment: Bool) async {
        do {
            try await db.collection("threads").document(threadId).updateData([
                "likeCount": FieldValue.increment(Int64(increment ? 1 : -1)),
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func likeReply(replyId: String, increment: Bool) async {
        do {
            try await db.collection("replies").document(replyId).updateData([
                "likeCount": FieldValue.increment(Int64(increment ? 1 : -1)),
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
