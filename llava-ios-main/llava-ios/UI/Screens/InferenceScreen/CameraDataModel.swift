/*
 See the License.txt file for this sample’s licensing information.
 */

import AVFoundation
import SwiftUI
import os.log

final class CameraDataModel: ObservableObject {
    let camera = Camera()
    var lastFrameTime: CFTimeInterval = 0
    let savingInterval = 0.5
    @Published var viewfinderImage: Image?
    @Published var thumbnailImage: Image?
    var currentImageData: Data?
    
    var isPhotosLoaded = false
    
    init() {
        Task {
            await handleCameraPreviews()
        }
        
        Task {
            await handleCameraPhotos()
        }
    }
    
    func handleCameraPreviews() async {
        let imageStream = camera.previewStream
            .map { $0 }
        let unpackedImageStream = camera.previewStream
            .compactMap { self.unpackPhoto(from: $0) }
        for await image in imageStream {
            let newImage = unpackPhoto(from: image)
            //print("NewPreview")
            let currentTime = CACurrentMediaTime()
            if currentTime - lastFrameTime >= savingInterval {
                Task { @MainActor in
                    viewfinderImage = image.image
                }
                lastFrameTime = currentTime
                savePhoto(imageData: newImage!.imageData)
                //print("Output")
                
            }
            // Perform action every 0.5 seconds
        }
        
        for await photoData in unpackedImageStream {
            Task { @MainActor in
                thumbnailImage = photoData.thumbnailImage
            }
            let currentTime = CACurrentMediaTime()
            if currentTime - lastFrameTime >= savingInterval {
                lastFrameTime = currentTime
                savePhoto(imageData: photoData.imageData)
                print("Output")
                
            }
            
        }
        
    }
    
    func handleCameraPhotos() async {
        /*let unpackedPhotoStream = camera.photoStream
         .compactMap { self.unpackPhoto($0) }
         
         for await photoData in unpackedPhotoStream {
         Task { @MainActor in
         thumbnailImage = photoData.thumbnailImage
         }
         savePhoto(imageData: photoData.imageData)
         }*/
    }
    private func unpackPhoto(from ciImage: CIImage) -> PhotoData? {
        // Resize CIImage to 512x512
        guard let resizedImageData = resizeCIImageTo512x512(ciImage) else { return nil }
        
        // Generate thumbnail image (128x128) from the CIImage
        let thumbnailSize = CGSize(width: 256, height: 256)
        guard let thumbnailImage = generateThumbnail(from: ciImage, size: thumbnailSize) else { return nil }
        
        // Extract photo dimensions
        let photoExtent = ciImage.extent
        let imageSize = (width: Int(photoExtent.width), height: Int(photoExtent.height))
        let thumbnailDimensions = (width: Int(thumbnailSize.width), height: Int(thumbnailSize.height))
        
        return PhotoData(
            thumbnailImage: thumbnailImage,
            thumbnailSize: thumbnailDimensions,
            imageData: resizedImageData,
            imageSize: (256, 256)
        )
    }
    
    // Helper function to resize CIImage to 512x512
    private func resizeCIImageTo512x512(_ ciImage: CIImage) -> Data? {
        let targetSize = CGSize(width: 256, height: 256)
        
        let resizedCIImage = ciImage.transformed(by: CGAffineTransform(scaleX: targetSize.width / ciImage.extent.width,
                                                                       y: targetSize.height / ciImage.extent.height))
        
        // Convert resized CIImage to UIImage and then to JPEG Data
        let context = CIContext()
        guard let cgImage = context.createCGImage(resizedCIImage, from: resizedCIImage.extent) else { return nil }
        let resizedUIImage = UIImage(cgImage: cgImage)
        return resizedUIImage.jpegData(compressionQuality: 1.0)
    }
    
    func savePhoto(imageData: Data) {
        Task {
            self.currentImageData = imageData
            logger.debug("Saved Image")
        }
    }
    
    private func generateThumbnail(from ciImage: CIImage, size: CGSize) -> Image? {
        let context = CIContext()
        
        // Scale the CIImage to thumbnail size
        let scaleTransform = CGAffineTransform(scaleX: size.width / ciImage.extent.width,
                                               y: size.height / ciImage.extent.height)
        let thumbnailCIImage = ciImage.transformed(by: scaleTransform)
        
        // Convert CIImage to CGImage
        guard let cgThumbnail = context.createCGImage(thumbnailCIImage, from: thumbnailCIImage.extent) else { return nil }
        
        // Create and return the thumbnail Image
        return Image(decorative: cgThumbnail, scale: 1, orientation: .up)
    }
    
}

fileprivate struct PhotoData {
    var thumbnailImage: Image
    var thumbnailSize: (width: Int, height: Int)
    var imageData: Data
    var imageSize: (width: Int, height: Int)
}

fileprivate extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

fileprivate extension Image.Orientation {
    
    init(_ cgImageOrientation: CGImagePropertyOrientation) {
        switch cgImageOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}

fileprivate let logger = Logger(subsystem: "world.prashanth.llava-ios", category: "DataModel")
