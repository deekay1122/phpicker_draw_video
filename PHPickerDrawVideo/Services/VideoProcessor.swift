//
//  VideoProcessor.swift
//  PHPickerDrawVideo
//
//  Created by 江尻大作 on 2022/01/13.
//

import UIKit
import Vision
import AVFoundation

protocol VideoProcessorDelegate: AnyObject {
    func displayFrame(_ frame: CVPixelBuffer?, withAffineTransform transform: CGAffineTransform)
    func drawBodyPoints(landmarks: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint])
}

class VideoProcessor {
    
    let queue = DispatchQueue(label: "VisionProcessingQueue")
    
    
    
    var videoAsset: AVAsset? {
        didSet {
            readAndDisplayFirstFrame()
        }
    }
    
    var cancelRequested = false
    
    weak var delegate: VideoProcessorDelegate?
    
    static var shared: VideoProcessor {
        let instance = VideoProcessor()
        return instance
    }
    
    private init() {}
    
    func readAndDisplayFirstFrame() { // use this in case you want to display first frame
        guard let videoAsset = videoAsset else { return }
        
        guard let videoReader = VideoReader(videoAsset: videoAsset) else { return }
        guard let firstFrame = videoReader.nextFrame() else { return }
        
        // printing video attributes to understand affine transformations for video orientations.
        print("image size: \(videoReader.imageSize)")
        
        print("affine transform a: \(videoReader.videoTrack.preferredTransform.a)")
        print("affine transform b: \(videoReader.videoTrack.preferredTransform.b)")
        print("affine transform c: \(videoReader.videoTrack.preferredTransform.c)")
        print("affine transform d: \(videoReader.videoTrack.preferredTransform.d)")
        print("affine transform tx: \(videoReader.videoTrack.preferredTransform.tx)")
        print("affine transform ty: \(videoReader.videoTrack.preferredTransform.ty)")
        
        print("affine transform inverted a: \(videoReader.affineTransform.a)")
        print("affine transform inverted b: \(videoReader.affineTransform.b)")
        print("affine transform inverted c: \(videoReader.affineTransform.c)")
        print("affine transform inverted d: \(videoReader.affineTransform.d)")
        print("affine transform inverted tx: \(videoReader.affineTransform.tx)")
        print("affine transform inverted ty: \(videoReader.affineTransform.ty)")
        
        DispatchQueue.global().async {
            self.delegate?.displayFrame(firstFrame, withAffineTransform: videoReader.affineTransform)
        }
        
    }
    
    func performTracking() {
        guard let videoAsset = videoAsset else { return }
        
        guard let videoReader = VideoReader(videoAsset: videoAsset) else { return }
        
        guard videoReader.nextFrame() != nil else { return }
        
        cancelRequested = false
        
        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
        
        while true {
            guard cancelRequested == false, let frame = videoReader.nextFrame() else {
                break
            }
            
            let requestHandler = VNImageRequestHandler(
                cvPixelBuffer: frame,
                orientation: videoReader.orientation,
                options: [:])
            
            queue.async {
                do {
                    try requestHandler.perform([bodyPoseRequest])
                    guard let results = bodyPoseRequest.results else { return }
                    try results.forEach { observation in
                        let bodyLandmarks = try observation.recognizedPoints(.all)
                            .filter { point in
                                point.value.confidence > 0.5
                            }
                        
                        self.delegate?.drawBodyPoints(landmarks: bodyLandmarks)
                    }
                } catch {
                    
                }
            }
            
            // Draw results
            delegate?.displayFrame(frame, withAffineTransform: videoReader.affineTransform)
            usleep(useconds_t(videoReader.frameRateInUSeconds)) // sleep in micro seconds accuracy
        }
        //        delegate?.didFinifshTracking()
    }
    
    func cancelTracking() {
        cancelRequested = true
    }
}

