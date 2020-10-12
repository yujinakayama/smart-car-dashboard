//
//  HeartAnimation.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/09/12.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class HeartAnimation: NSObject, CAAnimationDelegate {
    enum Phase {
        case ready
        case appearing
        case disappearing
        case finished
    }

    let view: UIView

    var phase = Phase.ready

    init(view: UIView) {
        self.view = view
        super.init()
    }

    func start() {
        view.layer.addSublayer(imageLayer)
        imageLayer.add(appearanceAnimation, forKey: nil)
        phase = .appearing
    }

    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        switch phase {
        case .appearing:
            imageLayer.add(disappearanceAnimation, forKey: nil)
            phase = .disappearing
        case .disappearing:
            imageLayer.removeFromSuperlayer()
            phase = .finished
        default:
            break
        }
    }

    var imageLayer: CALayer {
        return imageView.layer
    }

    lazy var imageView: UIImageView = {
        let image = UIImage(systemName: "heart.fill")!
        let imageView = UIImageView(image: image)
        imageView.tintColor = UIColor(hue: 0, saturation: 0.6, brightness: 1, alpha: 1)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = view.bounds.insetBy(dx: view.bounds.width * 0.15, dy: view.bounds.height * 0.15)
        return imageView
    }()

    lazy var appearanceAnimation: CAAnimation = {
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.delegate = self
        animation.duration = 2.5
        animation.fromValue = 0
        animation.toValue = 1
        animation.stiffness = 200
        return animation
    }()

    lazy var disappearanceAnimation: CAAnimation = {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.delegate = self
        animation.duration = 0.3
        animation.fromValue = 1
        animation.toValue = 0
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        return animation
    }()
}
