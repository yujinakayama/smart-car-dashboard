//
//  PlaybackModeButton.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/02.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

@IBDesignable class PlaybackModeButton: UIButton {
    override var isSelected: Bool {
        didSet {
            reflectSelection()
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
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    func commonInit() {
        layer.cornerRadius = 8

        setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 18), forImageIn: .normal)

        reflectSelection()
    }

    func reflectSelection() {
        if isSelected {
            imageView?.tintColor = .white
            backgroundColor = tintColor
        } else {
            imageView?.tintColor = tintColor
            backgroundColor = .secondarySystemBackground
        }
    }
}

@IBDesignable class RepeatModeButton: PlaybackModeButton {
    static let modes: [MPMusicRepeatMode] = [.none, .all, .one]

    var value = RepeatModeButton.modes.first! {
        didSet {
            updateAppearance()
        }
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        updateAppearance()
    }

    override func commonInit() {
        super.commonInit()
        addTarget(self, action: #selector(didTouchUpInside), for: .touchUpInside)
    }

    @objc func didTouchUpInside() {
        value = nextValue
        sendActions(for: .valueChanged)
    }

    var nextValue: MPMusicRepeatMode {
        let currentIndex = Self.modes.firstIndex(of: value) ?? Self.modes.startIndex
        let nextIndex = currentIndex >= (Self.modes.endIndex - 1) ? Self.modes.startIndex : currentIndex + 1
        return Self.modes[nextIndex]
    }

    func updateAppearance() {
        switch value {
        case .all:
            setImage(UIImage(systemName: "repeat"), for: .normal)
            isSelected = true
        case .one:
            setImage(UIImage(systemName: "repeat.1"), for: .normal)
            isSelected = true
        default:
            setImage(UIImage(systemName: "repeat"), for: .normal)
            isSelected = false
        }
    }
}

@IBDesignable class ShuffleModeButton: PlaybackModeButton {
    static let modes: [MPMusicShuffleMode] = [.off, .songs]

    var value = ShuffleModeButton.modes.first! {
        didSet {
            updateAppearance()
        }
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        updateAppearance()
    }

    override func commonInit() {
        super.commonInit()
        setImage(UIImage(systemName: "shuffle"), for: .normal)
        addTarget(self, action: #selector(didTouchUpInside), for: .touchUpInside)
    }

    @objc func didTouchUpInside() {
        value = nextValue
        sendActions(for: .valueChanged)
    }

    var nextValue: MPMusicShuffleMode {
        switch value {
        case .songs:
            return .off
        default:
            return .songs
        }
    }

    func updateAppearance() {
        isSelected = value == .songs
    }
}
