//
//  CloudinaryService.swift
//  RideBookingApp
//
//  Phase 5 - Cloudinary Integration for Image Uploads
//
//  Uploads images via Cloudinary's unsigned upload preset and returns
//  the resulting secure_url. Only the URL is ever written to Firestore;
//  Cloudinary itself stores the binary image.
//
//  UPDATED - reads cloudName/uploadPreset from Constants.Cloudinary
//  (Utilities/Constants.swift, filled in during Phase 0) instead of a
//  second hardcoded copy, so there's one source of truth.
//

import Foundation
import UIKit

enum CloudinaryUploadState: Equatable {
    case idle
    case uploading(progress: Double)
    case success(url: String)
    case failure(message: String)
}

enum CloudinaryError: LocalizedError {
    case invalidImage
    case badServerResponse
    case missingSecureURL
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not prepare the image for upload."
        case .badServerResponse: return "Cloudinary returned an unexpected response."
        case .missingSecureURL: return "Upload succeeded but no URL was returned."
        case .network(let error): return error.localizedDescription
        }
    }
}

/// Wraps Cloudinary's unsigned upload endpoint.
final class CloudinaryService {

    static let shared = CloudinaryService()

    private var uploadURL: URL {
        URL(string: Constants.Cloudinary.uploadURL)!
    }

    private init() {}

    /// Uploads a UIImage and returns the Cloudinary secure_url.
    /// - Parameters:
    ///   - image: source image (e.g. from PhotosPicker)
    ///   - folder: optional Cloudinary folder, e.g. "profile_photos", "vehicle_photos", "licenses"
    ///   - compressionQuality: JPEG compression, 0.0-1.0
    ///   - onProgress: optional progress callback (0.0-1.0), useful for @Published state in a ViewModel
    func uploadImage(
        _ image: UIImage,
        folder: String,
        compressionQuality: CGFloat = 0.6,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> String {

        // Resize to keep uploads fast/cheap on the free tier
        let resized = image.resized(maxDimension: 1280)

        guard let imageData = resized.jpegData(compressionQuality: compressionQuality) else {
            throw CloudinaryError.invalidImage
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendFormField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendFormField(name: "upload_preset", value: Constants.Cloudinary.uploadPreset)
        if !folder.isEmpty {
            appendFormField(name: "folder", value: folder)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        onProgress?(0.1)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            onProgress?(0.9)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw CloudinaryError.badServerResponse
            }

            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let secureURL = json["secure_url"] as? String
            else {
                throw CloudinaryError.missingSecureURL
            }

            onProgress?(1.0)
            return secureURL

        } catch let error as CloudinaryError {
            throw error
        } catch {
            throw CloudinaryError.network(error)
        }
    }
}

// MARK: - Image resizing helper

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return self }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
