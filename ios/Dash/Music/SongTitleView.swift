//
//  SongTitleView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer
import MarqueeLabel
import AppleMusic

fileprivate func makeMarqueeLabel() -> MarqueeLabel {
    let label = MarqueeLabel()
    label.fadeLength = 24
    label.holdScrolling = true
    label.speed = .rate(30)
    label.trailingBuffer = 32

    // If we mimic the Music app completely we should do:
    //
    //   label.leadingBuffer = 24
    //   label.frame.origin.x - 24 // Or equivalent constraint
    //
    // However we don't have the (...) button on the right currently,
    // the symmetric fades are more natural.

    return label
}

@IBDesignable class SongTitleView: UIStackView {
    let songLabel: MarqueeLabel = {
        let songLabel = makeMarqueeLabel()
        songLabel.textColor = UIColor.label
        songLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        return songLabel
    }()

    let artistLabel: MarqueeLabel = {
        let artistLabel = makeMarqueeLabel()
        artistLabel.textColor = artistLabel.tintColor
        artistLabel.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        return artistLabel
    }()

    var labels: [MarqueeLabel] {
        return [songLabel, artistLabel]
    }

    var animationTimer: Timer?

    var musicPlayer: MPMusicPlayerController! {
        didSet {
            addNotificationObserver()
            tryUpdatingLabelsWithOriginalLanguageTitle()
        }
    }

    lazy var originalLanguageSongTitleFetcher: OriginalLanguageSongTitleFetcher = {
        let path = Bundle.main.path(forResource: "apple_music_developer_token", ofType: "txt")!
        let developerToken = try! String(contentsOfFile: path)
        return OriginalLanguageSongTitleFetcher(storefront: .japan, developerToken: developerToken)
    }()

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
        songLabel.text = "Lorem ipsum dolor sit amet"
        artistLabel.text = "John Appleseed"
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

    func tryUpdatingLabelsWithOriginalLanguageTitle() {
        guard let songID = musicPlayer.nowPlayingItem?.playbackStoreID else {
            updateLabels(title: nil, artist: nil)
            return
        }

        if originalLanguageSongTitleFetcher.hasCachedOriginalLanguageSong(id: songID) {
            if let originalLanguageSong = originalLanguageSongTitleFetcher.cachedOriginalLanguageSong(id: songID) {
                updateLabels(title: originalLanguageSong.title, artist: originalLanguageSong.artist)
            } else {
                let mediaItem = self.musicPlayer.nowPlayingItem
                updateLabels(title: mediaItem?.title, artist: mediaItem?.artist)
            }
            return
        }

        let mediaItem = self.musicPlayer.nowPlayingItem
        updateLabels(title: mediaItem?.title, artist: mediaItem?.artist)

        originalLanguageSongTitleFetcher.fetchOriginalLanguageSong(id: songID) { [weak self] (result) in
            guard let self = self else { return }

            switch result {
            case .success(let originalLanguageSong):
                DispatchQueue.main.async { [weak self] in
                    self?.updateLabels(title: originalLanguageSong.title, artist: originalLanguageSong.artist, animated: true)
                }
            case .failure(let error):
                logger.error(error)
            }
        }
    }

    func updateLabels(title: String?, artist: String?, animated: Bool = false) {
        if animated {
            let duration = 0.5

            UIView.transition(with: songLabel, duration: duration, options: .transitionCrossDissolve, animations: { [weak self] in
                self?.songLabel.text = title
            })

            UIView.transition(with: artistLabel, duration: duration, options: .transitionCrossDissolve, animations: { [weak self] in
                self?.artistLabel.text = artist
            })
        } else {
            songLabel.text = title
            artistLabel.text = artist
        }

        setUpAnimationIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setUpAnimationIfNeeded()
    }

    func setUpAnimationIfNeeded() {
        animationTimer?.invalidate()
        animationTimer = nil

        labels.forEach { $0.shutdownLabel() }

        if labels.allSatisfy({ !$0.labelShouldScroll() }) {
            return
        }

        let longerAnimationDuration: TimeInterval = TimeInterval(labels.map { $0.animationDuration }.max()!)
        let holdDuration: TimeInterval = 3
        let repeatingTimerInterval = longerAnimationDuration + holdDuration

        animationTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] (initialTimer) in
            guard let self = self else { return }

            self.labels.forEach { $0.triggerScrollStart() }

            self.animationTimer = Timer.scheduledTimer(withTimeInterval: repeatingTimerInterval, repeats: true, block: { [weak self] (repeatingTimer) in
                self?.labels.forEach { $0.triggerScrollStart() }
            })
        }
    }

    @objc func musicPlayerControllerNowPlayingItemDidChange() {
        tryUpdatingLabelsWithOriginalLanguageTitle()
    }
}
