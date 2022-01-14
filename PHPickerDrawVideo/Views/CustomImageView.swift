//
//  CustomImageView.swift
//  PHPickerDrawVideo
//
//  Created by 江尻大作 on 2022/01/13.
//

import Foundation

import UIKit

class CustomImageView: UIImageView {
    lazy var afterAspectFitWidth: CGFloat = {
        return imageSizeAfterAspectFit.width
    }()
    
    lazy var afterAspectFitHeight: CGFloat = {
        return imageSizeAfterAspectFit.height
    }()
}

extension CustomImageView {
    
    
    var imageSizeAfterAspectFit: CGSize {
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        guard let image = image else { return frame.size }
        
        if image.size.height >= image.size.width { // if portrait
            newHeight = frame.size.height // set height to the frame height
            newWidth = (image.size.width / image.size.height) * newHeight // set width based on image's w/h ratio
            
            if CGFloat(newWidth) > (frame.size.width) {
                newWidth = frame.size.width
                newHeight = (image.size.height / image.size.width) * newWidth
            }
        } else { // if landscape
            newWidth = frame.size.width
            newHeight = (image.size.height / image.size.width) * newWidth
            
            if newHeight > frame.size.height {
                newHeight = frame.size.height
                newWidth = (image.size.width / image.size.height) * newHeight
            }
        }
        return .init(width: newWidth, height: newHeight)
    }
}
