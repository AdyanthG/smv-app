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
}
