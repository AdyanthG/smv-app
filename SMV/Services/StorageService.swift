//
//  StorageService.swift
//  SMV
//
//  Firebase Storage service for uploading and retrieving
//  scan result images and profile photos.
//

import Foundation
import FirebaseStorage
import UIKit

@Observable
final class StorageService {

    private var storage: Storage { Storage.storage() }

    var errorMessage: String?

    // MARK: - Scan Images

    /// Upload a scan result image, returns the download URL
    func uploadScanImage(userId: String, scanId: String, imageData: Data) async -> String? {
        let ref = storage.reference()
            .child("scans/\(userId)/\(scanId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            let _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Upload a named angle image for a scan, returns the download URL
    func uploadScanAngleImage(userId: String, scanId: String, angle: String, imageData: Data) async -> String? {
        let ref = storage.reference()
            .child("scans/\(userId)/\(scanId)_\(angle).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            let _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Profile Photos

    /// Upload a profile photo, returns the download URL
    func uploadProfilePhoto(userId: String, imageData: Data) async -> String? {
        let ref = storage.reference()
            .child("profiles/\(userId)/avatar.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            let _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Download

    /// Download image data from a storage URL
    func downloadImage(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }

        // If it's a Firebase Storage URL, use the SDK
        if urlString.contains("firebasestorage") {
            let ref = storage.reference(forURL: urlString)
            do {
                let data = try await ref.data(maxSize: 10 * 1024 * 1024) // 10MB max
                return data
            } catch {
                errorMessage = error.localizedDescription
                return nil
            }
        }

        // Otherwise use URLSession
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }

    // MARK: - Delete

    func deleteScanImage(userId: String, scanId: String) async {
        let ref = storage.reference()
            .child("scans/\(userId)/\(scanId).jpg")
        try? await ref.delete()
    }
}
