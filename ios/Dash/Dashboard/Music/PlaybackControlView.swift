//
//  PlaybackControlView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/06/29.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

@IBDesignable class PlaybackControlView: UIView {
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
            updateBackwardAndForwardButtons()
        }
    }

    let backwardButton: UIButton = {
        let button = UIButton(type: .custom)

        button.addTarget(self, action: #selector(backwardButtonDidTap), for: .touchUpInside)

        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 25),
            forImageIn: .normal
        )

        button.setImage(UIImage(systemName: "backward.fill"), for: .normal)

        return button
    }()

    let playPauseButton: UIButton = {
        let button = UIButton(type: .custom)

        button.addTarget(self, action: #selector(playPauseButtonDidTap), for: .touchUpInside)

        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 40),
            forImageIn: .normal
        )

        button.setImage(UIImage(systemName: "play.fill"), for: .normal)

        return button
    }()

    let forwardButton: UIButton = {
        let button = UIButton(type: .custom)

        button.addTarget(self, action: #selector(forwardButtonDidTap), for: .touchUpInside)

        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 25),
            forImageIn: .normal
        )

        button.setImage(UIImage(systemName: "forward.fill"), for: .normal)

        return button
    }()

    required init?(coder: NSCoder) {
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
        addSubview(backwardButton)
        addSubview(playPauseButton)
        addSubview(forwardButton)

        installLayoutConstraints()
    }

    func installLayoutConstraints() {
        for subview in subviews {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }

        var constraints: [NSLayoutConstraint] = []

        constraints.append(contentsOf: [
            playPauseButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        constraints.append(contentsOf: [
            playPauseButton.leftAnchor.constraint(equalTo: backwardButton.rightAnchor, constant: 60),
            backwardButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        constraints.append(contentsOf: [
            forwardButton.leftAnchor.constraint(equalTo: playPauseButton.rightAnchor, constant: 60),
            forwardButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        NSLayoutConstraint.activate(constraints)
    }

    func addNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlayerControllerPlaybackStateDidChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlayerControllerNowPlayingItemDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
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

    @objc func musicPlayerControllerNowPlayingItemDidChange() {
        updateBackwardAndForwardButtons()
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

    func updateBackwardAndForwardButtons() {
        backwardButton.isHidden = isPlayingLiveItem
        forwardButton.isHidden = isPlayingLiveItem
    }

    var isPlayingLiveItem: Bool {
        guard let musicPlayer = musicPlayer else { return false }
        return musicPlayer.currentPlaybackTime.isNaN
    }
}

protocol PlaybackControlViewDelegate: NSObjectProtocol {
    func playbackControlView(_ playbackControlView: PlaybackControlView, didPerformOperation operation: PlaybackControlView.Operation)
}
