import SwiftUI
import UIKit // For UIImage manipulation

enum ImageProcessError: Error {
    case loadFailed
    case resizeFailed
    case compressionFailed
    case tooLargeAfterProcessing
}

struct ImageHelper {
    static func processImage(data: Data,
                             maxSizeInBytes: Int = 2 * 1024 * 1024, // 2MB
                             targetMaxDimension: CGFloat = 1024, // e.g., 1024x1024
                             compressionQuality: CGFloat = 0.75) async throws -> Data {

        guard var uiImage = UIImage(data: data) else {
            print("Error: Could not create UIImage from data.")
            throw ImageProcessError.loadFailed
        }

        // If already small enough, return original data (or re-compressed if preferred)
        if data.count <= maxSizeInBytes {
            // Optionally re-compress even if small to ensure consistent format/quality
            if let recompressedData = uiImage.jpegData(compressionQuality: compressionQuality), recompressedData.count <= maxSizeInBytes {
                 print("Image already within size limit. Using re-compressed data: \(recompressedData.count) bytes")
                 return recompressedData
            } else if let pngData = uiImage.pngData(), pngData.count <= maxSizeInBytes && uiImage.jpegData(compressionQuality: 1.0) == nil {
                 // If it's a PNG and small enough, and doesn't have a good JPEG representation
                 print("Image already within size limit. Using original PNG data: \(pngData.count) bytes")
                 return pngData
            }
            // If re-compression made it larger, and original was fine, stick to original if possible,
            // but usually jpegData is preferred for size.
            // For simplicity, let's proceed to resize/recompress if initial jpeg is too large.
        }
        
        print("Original image data size: \(data.count) bytes. Needs processing.")

        // Resize if dimensions are too large
        if uiImage.size.width > targetMaxDimension || uiImage.size.height > targetMaxDimension {
            let aspectRatio = uiImage.size.width / uiImage.size.height
            var newSize: CGSize
            if aspectRatio > 1 { // Landscape or square
                newSize = CGSize(width: targetMaxDimension, height: targetMaxDimension / aspectRatio)
            } else { // Portrait
                newSize = CGSize(width: targetMaxDimension * aspectRatio, height: targetMaxDimension)
            }

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0) // false for opaque to preserve transparency if PNG
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
            guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                UIGraphicsEndImageContext()
                print("Error: Could not resize image.")
                throw ImageProcessError.resizeFailed
            }
            UIGraphicsEndImageContext()
            uiImage = resizedImage // Use the resized image for compression
            print("Image resized to: \(uiImage.size.width)x\(uiImage.size.height)")
        }

        // Compress
        guard let compressedData = uiImage.jpegData(compressionQuality: compressionQuality) else {
            print("Error: Could not compress image to JPEG.")
            throw ImageProcessError.compressionFailed
        }
        print("Compressed image data size: \(compressedData.count) bytes with quality \(compressionQuality)")

        if compressedData.count > maxSizeInBytes {
            print("Error: Image still too large after compression (\(compressedData.count) bytes).")
            // You could try even lower quality here, or throw an error
            throw ImageProcessError.tooLargeAfterProcessing
        }

        return compressedData
    }
}
//  ImageHelper.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/26/25.
//

import Foundation
