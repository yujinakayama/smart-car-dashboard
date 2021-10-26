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
            previousItemID = musicPlayer.nowPlayingItem?.persistentID
            addNotificationObserver()
            tryUpdatingLabelsWithOriginalLanguageTitle()
        }
    }

    var previousItemID: MPMediaEntityPersistentID?

    var songDataRequestTask: Task<Void, Never>?

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
        songDataRequestTask?.cancel()

        guard let nowPlayingItem = musicPlayer.nowPlayingItem else {
            updateLabels(title: nil, artist: nil)
            return
        }

        guard let songID = nowPlayingItem.validPlaybackStoreID else {
            updateLabels(title: nowPlayingItem.title, artist: nowPlayingItem.artist)
            return
        }

        if SongDataRequest.hasCachedSong(id: songID) {
            if let song = SongDataRequest.cachedSong(id: songID) {
                updateLabels(title: song.title, artist: song.artistName)
            } else {
                updateLabels(title: nowPlayingItem.title, artist: nowPlayingItem.artist)
            }
            return
        }

        updateLabels(title: nowPlayingItem.title, artist: nowPlayingItem.artist)

        songDataRequestTask = Task {
            do {
                if let song = try await SongDataRequest(id: songID).perform() {
                    updateLabels(title: song.title, artist: song.artistName, animated: true)
                }
            } catch {
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
        // For some reason this function may be called twice for a single change...
        if musicPlayer.nowPlayingItem?.persistentID != previousItemID {
            tryUpdatingLabelsWithOriginalLanguageTitle()
        }

        previousItemID = musicPlayer.nowPlayingItem?.persistentID
    }
}
