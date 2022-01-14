//
//  VideoReader.swift
//  PHPickerDrawVideo
//
//  Created by 江尻大作 on 2022/01/13.
//

import AVFoundation

class VideoReader {
    
    static private let millisecondsInSecond: Float32 = 1000.0
    
    var frameRateInMilliseconds: Float32 {
        return videoTrack.nominalFrameRate
    }
    
    var frameRateInUSeconds: Float32 {
        return frameRateInMilliseconds * VideoReader.millisecondsInSecond
    }
    
    var imageSize: CGSize {
        return videoTrack.naturalSize
    }
    
    // The track’s transform preference to apply to its visual content during presentation or processing. Then inverting it. Why inverting it? If the preferredTransform is an identity matrix, the inverse will also be an identify matrix. If else, the inverted will include some sort of transformation information such as rotation.
    var affineTransform: CGAffineTransform {
        return videoTrack.preferredTransform.inverted()
    }
    
    var orientation: CGImagePropertyOrientation {
        
        let angleInDegrees = atan2(self.affineTransform.b, self.affineTransform.a) * CGFloat(180) / CGFloat.pi
        var orientation: UInt32 = 1
        switch angleInDegrees {
            case 0:
                orientation = 1
            case 180:
                orientation = 3
            case -180:
                orientation = 3
            case 90:
                orientation = 8
            case -90:
                orientation = 6
            default:
                orientation = 1
        }
        
        return CGImagePropertyOrientation(rawValue: orientation)!
    }
    
    private var videoAsset: AVAsset!
    var videoTrack: AVAssetTrack!
    private var assetReader: AVAssetReader! // an object that reads media data from an asset
    
    // AVAssetReaderTrackOutput is a concrete subclass of AVAssetReaderOutput that defines an interface for reading media data from a single AVAssetTrack of an AVAssetReader's AVAsset.
    private var videoAssetReaderOutput: AVAssetReaderTrackOutput!
    
    init?(videoAsset: AVAsset) { // failable initializer
        self.videoAsset = videoAsset
        let array = self.videoAsset.tracks(withMediaType: AVMediaType.video)
        self.videoTrack = array[0] // getting the first video track in the array
        
        guard self.restartReading() else {
            return nil
        }
    }
    
    func restartReading() -> Bool {
        do {
            self.assetReader = try AVAssetReader(asset: videoAsset)
        } catch {
            print("Failed to create AVAssetReader object: \(error)")
            return false
        }
        
        self.videoAssetReaderOutput = AVAssetReaderTrackOutput(track: self.videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]) // In iOS, use kCVPixelFormatType_420YpCbCr8BiPlanarFullRange for JPEG output.
        
        guard self.videoAssetReaderOutput != nil else {
            return false
        }
        
        self.videoAssetReaderOutput.alwaysCopiesSampleData = true // if you don't require modifying sample data in-place, set the value to false to prevent the output from making unnecessary copies.
        
        guard self.assetReader.canAdd(videoAssetReaderOutput) else { // determines whether you can add the output to the asset reader
            return false
        }
        
        // Prepares the receiver for obtaining sample buffers from the asset. This method validates the entire collection of settings for outputs for tracks, for audio mixdown, and for video composition and initiates reading of all outputs. status signals the terminal state of the asset reader, and if a failure occurs, error describes the failure. Returns true if the reader is able to start reading, otherwise false.
        self.assetReader.add(videoAssetReaderOutput)
        
        return self.assetReader.startReading()
    }
    
    func nextFrame() -> CVPixelBuffer? { // CVPixelBuffer derives from CVImageBuffer
                                         // Copies the next sample buffer from the output. Returns the output sampleBuffer: CMSampleBuffer, or nil if you’ve read all samples or an error occurs.
        guard let sampleBuffer = self.videoAssetReaderOutput.copyNextSampleBuffer() else {
            return nil
        }
        
        // Returns a sample buffer's CVImageBuffer of media data.
        // typealias CVImageBuffer = CVBuffer
        // An image buffer is an abstract type representing Core Video buffers that hold images. In Core Video, pixel buffers, OpenGL buffers, and OpenGL textures all derive from the image buffer type.
        return CMSampleBufferGetImageBuffer(sampleBuffer)
    }
}
