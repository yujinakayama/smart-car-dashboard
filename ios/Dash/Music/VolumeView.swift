//
//  SoundVolumeView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/06/29.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

class VolumeView: UIStackView {
    lazy var minimumImageView: UIImageView = {
        let image = UIImage(systemName: "speaker.fill", withConfiguration: symbolConfiguration)
        return UIImageView(image: image)
    }()

    let volumeView = MPVolumeView()

    lazy var maximumImageView: UIImageView = {
        let image = UIImage(systemName: "speaker.3.fill", withConfiguration: symbolConfiguration)
        return UIImageView(image: image)
    }()

    var symbolConfiguration: UIImage.SymbolConfiguration {
        return UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    func setUp() {
        axis = .horizontal
        alignment = .center
        distribution = .fill
        spacing = 6

        tintColor = UIColor(named: "Music Player Slider Minimum Track Tint Color")!

        let minimumImage = UIImage(systemName: "speaker.fill", withConfiguration: symbolConfiguration)
        addArrangedSubview(UIImageView(image: minimumImage))

        // Using KVC to avoid annoying deprecation message
        volumeView.setValue(false, forKey: #keyPath(MPVolumeView.showsRouteButton))
        volumeView.heightAnchor.constraint(equalToConstant: 19).isActive = true
        setVolumeViewImages()
        addArrangedSubview(volumeView)

        let maximumImage = UIImage(systemName: "speaker.3.fill", withConfiguration: symbolConfiguration)
        addArrangedSubview(UIImageView(image: maximumImage))
    }

    func setVolumeViewImages() {
        volumeView.setVolumeThumbImage(volumeThumbImage, for: .normal)
        volumeView.setMinimumVolumeSliderImage(minimumVolumeSliderImage, for: .normal)
        volumeView.setMaximumVolumeSliderImage(maximumVolumeSliderImage, for: .normal)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setVolumeViewImages()
        }
    }

    var volumeThumbImage: UIImage {
        let thumbColor = UIColor.white
        let thumbRadius: CGFloat = 10

        let borderColor = UIColor(white: 0, alpha: 0.08)
        let borderWidth: CGFloat = 0.5

        let innerShadowColor = UIColor(white: 0, alpha: 0.08)
        let innerShadowOffset = CGSize(width: 0, height: 2)
        let innerShadowRadius: CGFloat = 1.5

        let outerShadowColor = UIColor(white: 0, alpha: 0.22)
        let outerShadowOffset = CGSize(width: 0, height: 6)
        let outerShadowRadius: CGFloat = 10

        let imageSize = CGSize(
            width: (thumbRadius + outerShadowOffset.width + outerShadowRadius) * 2,
            height: (thumbRadius + outerShadowOffset.height + outerShadowRadius) * 2
        )

        let imageBounds = CGRect(
            origin: CGPoint(x: imageSize.width / 2, y: 0),
            size: imageSize
        )

        let renderer = UIGraphicsImageRenderer(bounds: imageBounds)

        return renderer.image { (rendererContext) in
            let context = rendererContext.cgContext

            let thumbFrame = CGRect(
                x: imageBounds.midX - thumbRadius,
                y: imageBounds.midY - thumbRadius,
                width: thumbRadius * 2,
                height: thumbRadius * 2
            )

            context.saveGState()

            thumbColor.setFill()
            context.setShadow(offset: outerShadowOffset, blur: outerShadowRadius, color: outerShadowColor.cgColor)
            context.fillEllipse(in: thumbFrame)

            context.setShadow(offset: innerShadowOffset, blur: innerShadowRadius, color: innerShadowColor.cgColor)
            context.fillEllipse(in: thumbFrame)

            context.restoreGState()

            borderColor.setStroke()
            context.setLineWidth(borderWidth)
            context.strokeEllipse(in: thumbFrame)
        }
    }

    var minimumVolumeSliderImage: UIImage {
        let color = UIColor(named: "Music Player Slider Minimum Track Tint Color")!

        let leftPadding: CGFloat = 5
        let height: CGFloat = 3
        let cornerRadius: CGFloat = height / 2
        let leftCapInset = leftPadding + ceil(cornerRadius)
        let resizablePortionWidth: CGFloat = 1

        let imageSize = CGSize(
            width: leftCapInset + resizablePortionWidth,
            height: height
        )

        let imageBounds = CGRect(
            origin: CGPoint.zero,
            size: imageSize
        )

        let renderer = UIGraphicsImageRenderer(bounds: imageBounds)

        let image = renderer.image { (rendererContext) in
            color.setFill()

            let path = UIBezierPath(
                roundedRect: CGRect(x: leftPadding, y: 0, width: imageSize.width - leftPadding, height: imageSize.height),
                byRoundingCorners: [.topLeft, .bottomLeft],
                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
            )

            path.fill()
        }

        let capInsets = UIEdgeInsets(top: 0, left: leftCapInset, bottom: 0, right: 0)
        return image.resizableImage(withCapInsets: capInsets)
    }

    var maximumVolumeSliderImage: UIImage {
        let color = UIColor(named: "Music Player Slider Maximum Track Tint Color")!

        let rightPadding: CGFloat = 5
        let height: CGFloat = 3
        let cornerRadius: CGFloat = height / 2
        let rightCapInset = ceil(cornerRadius) + rightPadding
        let resizablePortionWidth: CGFloat = 1

        let imageSize = CGSize(
            width: resizablePortionWidth + rightCapInset,
            height: height
        )

        let imageBounds = CGRect(
            origin: CGPoint.zero,
            size: imageSize
        )

        let renderer = UIGraphicsImageRenderer(bounds: imageBounds)

        let image = renderer.image { (rendererContext) in
            color.setFill()

            let path = UIBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: imageSize.width - rightPadding, height: imageSize.height),
                byRoundingCorners: [.topRight, .bottomRight],
                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
            )

            path.fill()
        }

        let capInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: rightCapInset)
        return image.resizableImage(withCapInsets: capInsets)
    }
}
