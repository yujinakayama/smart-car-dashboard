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
        } else {
            musicPlayer.play()
        }
    }

    @objc func backwardButtonDidTap() {
        if musicPlayer.currentPlaybackTime < 4 {
            musicPlayer.skipToPreviousItem()
        } else {
            musicPlayer.skipToBeginning()
        }
    }

    @objc func forwardButtonDidTap() {
        musicPlayer.skipToNextItem()
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
