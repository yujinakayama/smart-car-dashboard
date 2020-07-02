//
//  PlaybackControlView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/06/29.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

@IBDesignable class PlaybackControlView: UIStackView {
    enum Operation {
        case play
        case pause
        case skipToNextItem
        case skipToBeginning
        case skipToPreviousItem
    }

    weak var delegate: PlaybackControlViewDelegate?

    var musicPlayer: MPMusicPlayerController! {
        didSet {
            addNotificationObserver()
            updatePlayPauseButton()
        }
    }

    let backwardButton: UIButton = {
        let button = UIButton(type: .custom)

        button.addTarget(self, action: #selector(backwardButtonDidTap), for: .touchUpInside)

        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 32),
            forImageIn: .normal
        )

        button.setImage(UIImage(systemName: "backward.fill"), for: .normal)

        return button
    }()

    let playPauseButton: UIButton = {
        let button = UIButton(type: .custom)

        button.addTarget(self, action: #selector(playPauseButtonDidTap), for: .touchUpInside)

        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 48),
            forImageIn: .normal
        )

        button.setImage(UIImage(systemName: "play.fill"), for: .normal)

        return button
    }()

    let forwardButton: UIButton = {
        let button = UIButton(type: .custom)

        button.addTarget(self, action: #selector(forwardButtonDidTap), for: .touchUpInside)

        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 32),
            forImageIn: .normal
        )

        button.setImage(UIImage(systemName: "forward.fill"), for: .normal)

        return button
    }()

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    override func prepareForInterfaceBuilder() {
        setUp()
    }

    func setUp() {
        axis = .horizontal
        alignment = .fill
        distribution = .fillEqually

        addArrangedSubview(backwardButton)
        addArrangedSubview(playPauseButton)
        addArrangedSubview(forwardButton)
    }

    func addNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlayerControllerPlaybackStateDidChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
    }

    @objc func playPauseButtonDidTap() {
        if musicPlayer.playbackState == .playing {
            musicPlayer.pause()
            delegate?.playbackControlView(self, didPerformOperation: .pause)
        } else {
            musicPlayer.play()
            delegate?.playbackControlView(self, didPerformOperation: .play)
        }
    }

    @objc func backwardButtonDidTap() {
        if musicPlayer.currentPlaybackTime < 4 {
            musicPlayer.skipToPreviousItem()
            musicPlayer.skipToBeginning()
            delegate?.playbackControlView(self, didPerformOperation: .skipToPreviousItem)
        } else {
            musicPlayer.skipToBeginning()
            delegate?.playbackControlView(self, didPerformOperation: .skipToBeginning)
        }
    }

    @objc func forwardButtonDidTap() {
        musicPlayer.skipToNextItem()
        musicPlayer.skipToBeginning()
        delegate?.playbackControlView(self, didPerformOperation: .skipToNextItem)
    }

    @objc func musicPlayerControllerPlaybackStateDidChange() {
        updatePlayPauseButton()
    }

    func updatePlayPauseButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.musicPlayer.playbackState == .playing {
                self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            } else {
                self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            }
        }
    }
}

protocol PlaybackControlViewDelegate: NSObjectProtocol {
    func playbackControlView(_ playbackControlView: PlaybackControlView, didPerformOperation operation: PlaybackControlView.Operation)
}
