//
//  ViewController.swift
//  PHPickerDrawVideo
//
//  Created by 江尻大作 on 2022/01/13.
//

import UIKit
import PhotosUI
import Vision

class ViewController: UIViewController {
    
    var videoProcessor = VideoProcessor.shared // singleton
    
    lazy var overlayView: UIView = {
        let overlayView = UIView()
//        overlayView.backgroundColor = .red
//        overlayView.layer.opacity = 0.1
        return overlayView
    }()
    
    lazy var bodyPointPath: UIBezierPath = {
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 5, height: 5))
        return path
    }()
    
    var targetURL: URL? {
        didSet {
            guard let url = targetURL else { return }
            videoProcessor.videoAsset = AVAsset(url: url)
        }
    }
    
    lazy var imageView: CustomImageView = {
        let imageView = CustomImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    lazy var trackButton: UIButton = {
        let button = UIButton()
        let buttonColor = UIColor.link
        let uiImage = createUIImageFromUIColor(color: buttonColor) // UIColorからUIImageを作成
        button.setBackgroundImage(uiImage, for: .normal)
        button.setTitle("Track", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(trackButtonTapped), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGray6
        
        videoProcessor.delegate = self
        
        configureNavigationBar()
        constrainTrackButton()
        constrainImageView()
        constrainOverlayView()
    }
    
    
    @objc func addTapped() {
        videoProcessor.cancelRequested = true
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current // this is required for presenting video, otherwise very slow.
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc func trackButtonTapped() {
        DispatchQueue.global().async {
            self.videoProcessor.performTracking()
        }
    }
    
    private func constrainOverlayView() {
        view.addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.topAnchor.constraint(equalTo: imageView.topAnchor).isActive = true
        overlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor).isActive = true
        overlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor).isActive = true
        overlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor).isActive = true
    }
    
    private func constrainTrackButton() {
        view.addSubview(trackButton)
        trackButton.translatesAutoresizingMaskIntoConstraints = false
        trackButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        trackButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        trackButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        trackButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    private func constrainImageView() {
        view.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: trackButton.topAnchor, constant: -10).isActive = true
    }
    
    private func configureNavigationBar () {
        guard let navigationBar = navigationController?.navigationBar else { return }
        navigationBar.prefersLargeTitles = true
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addTapped))
        navigationItem.rightBarButtonItems = [
            addButton
        ]
    }
    
    private func createUIImageFromUIColor(color: UIColor) -> UIImage? {
        let size = CGSize(width: 50, height: 50)
        var colorImage: UIImage?
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            colorImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
        return colorImage
    }
    
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider,
              let typeIdentifier = provider.registeredTypeIdentifiers.first else { return }
        if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] (url, error) in
                guard let self = self else { return }
                if let error = error { print("error: \(error)")}
                guard let videoURL = url else { return }
                let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                guard let targetURL = documentDirectory?.appendingPathComponent(videoURL.lastPathComponent) else { return }
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: videoURL, to: targetURL)
                    self.targetURL = targetURL
                } catch {
                    print(error)
                }
            }
        }
    }
}

extension ViewController: VideoProcessorDelegate {
        func displayFrame(_ frame: CVPixelBuffer?, withAffineTransform transform: CGAffineTransform) {
            DispatchQueue.main.async { // updating the UI needs to happen on the main thread
                if let frame = frame {
                    
                    let ciImage = CIImage(cvPixelBuffer: frame).transformed(by: transform)
                    let ciContext = CIContext(options: nil)
                    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
                    let uiImage = UIImage(cgImage: cgImage)
                    self.imageView.image = uiImage
                }
            }
        }
    
    func drawBodyPoints(landmarks: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) {
        DispatchQueue.main.async {
            self.overlayView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            let rect = CGRect(origin: .zero, size: self.imageView.imageSizeAfterAspectFit)
            self.overlayView.layer.bounds = rect
            landmarks.map { (key, value) in
                let caShapeLayer = CAShapeLayer()
                caShapeLayer.path = self.bodyPointPath.cgPath
                caShapeLayer.fillColor = UIColor.blue.cgColor
                caShapeLayer.bounds = self.bodyPointPath.bounds
                let point = CGPoint(x: value.location.x, y: 1 - value.location.y)
                var convertedPoint = VNImagePointForNormalizedPoint(point, Int(self.imageView.imageSizeAfterAspectFit.width), Int(self.imageView.imageSizeAfterAspectFit.height))
                caShapeLayer.position = convertedPoint
                self.overlayView.layer.addSublayer(caShapeLayer)
            }
        }
    }
}


