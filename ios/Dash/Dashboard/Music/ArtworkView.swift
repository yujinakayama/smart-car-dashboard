//
//  ArtworkView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

@IBDesignable class ArtworkView: UIView {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .secondarySystemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true
        return imageView
    }()

    let shadowView: UIView = {
        let shadowView = UIView()
        shadowView.backgroundColor = .black
        shadowView.layer.masksToBounds = false
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = .zero
        return shadowView
    }()

    let visualEffectView = UIVisualEffectView()

    let blurredImageView: UIImageView = {
        let blurredImageView = UIImageView()
        blurredImageView.layer.masksToBounds = true
        return blurredImageView
    }()

    var musicPlayer: MPMusicPlayerController! {
        didSet {
            addNotificationObserver()
            updateArtworkImage()
        }
    }

    var cornerRadius: CGFloat = 8 {
        didSet {
            updateCornerRadius()
        }
    }

    weak var visualEffectScopeView: UIView? {
        didSet {
            updateVisualEffectViewConstraints()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    override func prepareForInterfaceBuilder() {
        commonInit()
    }

    func commonInit() {
        imageView.layer.borderWidth = 1.0 / screen.scale

        addSubview(blurredImageView)
        addSubview(visualEffectView)
        addSubview(shadowView)
        addSubview(imageView)

        updateCornerRadius()
        updateColorAppearance()
        installLayoutConstraints()
    }

    func updateCornerRadius() {
        for view in [imageView, shadowView, blurredImageView] {
            view.layer.cornerRadius = cornerRadius
        }
    }

    func updateColorAppearance() {
        imageView.layer.borderColor = UIColor.label.withAlphaComponent(0.125).cgColor

        if traitCollection.userInterfaceStyle == .dark {
            shadowView.layer.shadowOpacity = 0.6
            visualEffectView.effect = UIBlurEffect(style: .dark)
            blurredImageView.alpha = 0.8
        } else {
            shadowView.layer.shadowOpacity = 0.3
            visualEffectView.effect = UIBlurEffect(style: .light)
            blurredImageView.alpha = 0.6
        }
    }

    var blurredImageViewTopAnchorConstraint: NSLayoutConstraint!

    func installLayoutConstraints() {
        for subview in subviews {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }

        var constraints: [NSLayoutConstraint] = []

        constraints.append(contentsOf: [
            imageView.topAnchor.constraint(equalTo: topAnchor),
            bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            imageView.leftAnchor.constraint(equalTo: leftAnchor),
            rightAnchor.constraint(equalTo: imageView.rightAnchor),
        ])

        constraints.append(contentsOf: [
            shadowView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            bottomAnchor.constraint(equalTo: shadowView.bottomAnchor, constant: 1),
            shadowView.leftAnchor.constraint(equalTo: leftAnchor, constant: 1),
            rightAnchor.constraint(equalTo: shadowView.rightAnchor, constant: 1),
        ])

        blurredImageViewTopAnchorConstraint = blurredImageView.topAnchor.constraint(equalTo: topAnchor)

        constraints.append(contentsOf: [
            blurredImageViewTopAnchorConstraint,
            blurredImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            blurredImageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.87),
            blurredImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.87),
        ])

        NSLayoutConstraint.activate(constraints)
    }

    func updateVisualEffectViewConstraints() {
        NSLayoutConstraint.deactivate(visualEffectView.constraints)

        guard let scopeView = visualEffectScopeView else { return }

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: scopeView.topAnchor),
            scopeView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            visualEffectView.leftAnchor.constraint(equalTo: scopeView.leftAnchor),
            scopeView.rightAnchor.constraint(equalTo: visualEffectView.rightAnchor),
        ])
    }

    override func layoutSubviews() {
        shadowView.layer.shadowRadius = bounds.height * 0.065
        blurredImageViewTopAnchorConstraint.constant = bounds.height * 0.2

        super.layoutSubviews()
    }

    func addNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlayerControllerNowPlayingItemDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
    }

    func updateArtworkImage() {
        let image = musicPlayer.nowPlayingItem?.artwork?.image(at: preferredImageSize)
        imageView.image = image
        blurredImageView.image = image
    }

    var preferredImageSize: CGSize {
        return screen.bounds.size
    }

    @objc func musicPlayerControllerNowPlayingItemDidChange() {
        updateArtworkImage()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColorAppearance()
        }
    }

    var screen: UIScreen {
        return window?.windowScene?.screen ?? UIScreen.main
    }
}
