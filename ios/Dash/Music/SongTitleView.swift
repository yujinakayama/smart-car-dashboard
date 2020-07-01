//
//  SongTitleView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

@IBDesignable class SongTitleView: UIStackView {
    let songLabel: UILabel = {
        let songLabel = UILabel()
        songLabel.textColor = UIColor.label
        songLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        return songLabel
    }()

    let artistLabel: UILabel = {
        let artistLabel = UILabel()
        artistLabel.textColor = artistLabel.tintColor
        artistLabel.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        return artistLabel
    }()

    var musicPlayer: MPMusicPlayerController! {
        didSet {
            addNotificationObserver()
            updateLabels()
        }
    }

    required init(coder: NSCoder) {
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
        axis = .vertical
        alignment = .fill
        distribution = .fillEqually

        addArrangedSubview(songLabel)
        addArrangedSubview(artistLabel)
    }

    func addNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlayerControllerNowPlayingItemDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
    }

    func updateLabels() {
        songLabel.text = musicPlayer.nowPlayingItem?.title
        artistLabel.text = musicPlayer.nowPlayingItem?.artist
    }

    @objc func musicPlayerControllerNowPlayingItemDidChange() {
        updateLabels()
    }
}
