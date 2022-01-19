//
//  PlaybackProgressView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

@IBDesignable class PlaybackProgressView: UIView {
    let slider: Slider = {
        let slider = Slider()
        slider.addTarget(self, action: #selector(sliderValueDidChange), for: .valueChanged)
        slider.isContinuous = true
        slider.minimumTrackTintColor = UIColor(named: "Music Player Progress Slider Minimum Track Tint Color")
        slider.maximumTrackTintColor = UIColor(named: "Music Player Progress Slider Maximum Track Tint Color")
        return slider
    }()

    let elapsedTimeLabel: UILabel = {
        let elapsedTimeLabel = UILabel()
        elapsedTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        elapsedTimeLabel.textAlignment = .left
        elapsedTimeLabel.textColor = UIColor(named: "Music Player Progress Slider Minimum Track Tint Color")
        return elapsedTimeLabel
    }()

    let remainingTimeLabel: UILabel = {
        let remainingTimeLabel = UILabel()
        remainingTimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        remainingTimeLabel.textAlignment = .right
        remainingTimeLabel.textColor = UIColor(named: "Music Player Progress Slider Minimum Track Tint Color")
        return remainingTimeLabel
    }()

    var musicPlayer: MPMusicPlayerController! {
        didSet {
            playerState = PrecisePlayerState(musicPlayer: musicPlayer)
            addNotificationObserver()
            musicPlayerControllerNowPlayingItemDidChange()
        }
    }

    var playerState: PrecisePlayerState!

    var updateTimer: Timer?
    var sliderAnimator: UIViewPropertyAnimator?

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
        addSubview(slider)
        addSubview(elapsedTimeLabel)
        addSubview(remainingTimeLabel)

        setSliderThumbImage()
        installLayoutConstraints()
    }

    func setSliderThumbImage() {
        if let playerState = playerState, playerState.isPlayingLiveItem || playerState.isProbablyPlayingRadio {
            slider.setThumbImage(UIImage(), for: .normal)
        } else {
            slider.setThumbImage(thumbImage, for: .normal)
        }
    }

    func installLayoutConstraints() {
        for subview in subviews {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }

        var constraints: [NSLayoutConstraint] = []

        constraints.append(contentsOf: [
            slider.topAnchor.constraint(equalTo: topAnchor),
            slider.leftAnchor.constraint(equalTo: leftAnchor),
            rightAnchor.constraint(equalTo: slider.rightAnchor),
            slider.heightAnchor.constraint(equalToConstant: 30)
        ])

        constraints.append(contentsOf: [
            elapsedTimeLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: -8),
            elapsedTimeLabel.leftAnchor.constraint(equalTo: leftAnchor),
        ])

        constraints.append(contentsOf: [
            remainingTimeLabel.topAnchor.constraint(equalTo: elapsedTimeLabel.topAnchor),
            rightAnchor.constraint(equalTo: remainingTimeLabel.rightAnchor),
        ])

        NSLayoutConstraint.activate(constraints)
    }

    func addNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlayerControllerNowPlayingItemDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(musicPlayerControllerPlaybackStateDidChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillEnterForeground),
            name: UIScene.willEnterForegroundNotification,
            object: nil
        )
    }

    func scheduleUpdatesIfNeeded(initialUpdate: Bool = true) {
        unscheduleUpdates()

        if initialUpdate {
            update()
        }

        if !playerState.isMovingForwardPlaybackTime {
            return
        }

        playerState.waitForPlaybackToActuallyStart { [weak self] in
            guard let self = self else { return }

            self.update()

            self.updateTimer = Timer.scheduledTimer(
                timeInterval: self.playbackTimeUpdateInterval,
                target: self,
                selector: #selector(self.update),
                userInfo: nil,
                repeats: true
            )
        }
    }

    func unscheduleUpdates() {
        playerState.stopWaitingForPlaybackToActuallyStart()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    @objc func update() {
        updateSlider()
        updateTimeLabels()
    }

    func updateSlider() {
        sliderAnimator?.stopAnimation(true)
        sliderAnimator = nil

        slider.value = Float(displayedPlaybackTime)

        if !playerState.isMovingForwardPlaybackTime || playerState.currentPlaybackRate == 0 || slider.isTracking {
            return
        }

        sliderAnimator = UIViewPropertyAnimator(duration: playbackTimeUpdateInterval, curve: .linear) { [weak self] in
            guard let self = self else { return }
            let delta: Float = self.musicPlayer.currentPlaybackRate > 0 ? 1 : -1
            self.slider.setValue(self.slider.value + delta, animated: true)
        }

        sliderAnimator?.startAnimation()
    }

    func updateTimeLabels() {
        if let nowPlayingItem = musicPlayer.nowPlayingItem {
            if playerState.isPlayingLiveItem {
                elapsedTimeLabel.text = nil
                remainingTimeLabel.text = nil
            } else {
                elapsedTimeLabel.text = formatTimeInterval(displayedPlaybackTime)
                let remainingTime = ceil(floor(nowPlayingItem.playbackDuration) - displayedPlaybackTime)
                remainingTimeLabel.text = "−" + formatTimeInterval(remainingTime)
            }
        } else {
            elapsedTimeLabel.text = "--:--"
            remainingTimeLabel.text = "--:--"
        }
    }

    func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }

    @objc func musicPlayerControllerNowPlayingItemDidChange() {
        setSliderThumbImage()
        slider.maximumValue = Float(musicPlayer.nowPlayingItem?.playbackDuration ?? 0)
        remainingTimeLabel.isHidden = playerState.isProbablyPlayingRadio
        scheduleUpdatesIfNeeded()
    }

    @objc func musicPlayerControllerPlaybackStateDidChange() {
        scheduleUpdatesIfNeeded()
    }

    @objc func sceneWillEnterForeground() {
        // When the scene entered background, UIKit removes all animations
        // even if it's an infinite animation.
        // So we restart the animation here if it should be when the app came back to foreground.
        scheduleUpdatesIfNeeded()
    }

    @IBAction func sliderValueDidChange() {
        let isDragFinishing = !slider.isTracking

        if isDragFinishing {
            playerState.currentPlaybackTime = TimeInterval(slider.value)
            // We specify initialUpdate: false here because getter of musicPlayer.currentPlaybackTime
            // returns the old value and calling update() here causes some flicker of the slider position
            scheduleUpdatesIfNeeded(initialUpdate: false)
        } else {
            unscheduleUpdates()
            update()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setSliderThumbImage()
        }
    }

    var playbackTimeUpdateInterval: TimeInterval {
        return TimeInterval(1.0 / musicPlayer.currentPlaybackRate)
    }

    var displayedPlaybackTime: TimeInterval {
        if slider.isTracking {
            return TimeInterval(slider.value)
        } else {
            return playerState.currentPlaybackTime
        }
    }

    var thumbImage: UIImage {
        let color = UIColor(named: "Music Player Progress Slider Minimum Track Tint Color") ?? UIColor.gray
        let radius: CGFloat = 3
        let padding: CGFloat = 1

        let imageSize = CGSize(width: (radius + padding) * 2, height: (radius + padding) * 2)

        let imageBounds = CGRect(
            origin: CGPoint(x: imageSize.width / 2, y: 0),
            size: imageSize
        )

        let renderer = UIGraphicsImageRenderer(bounds: imageBounds)

        return renderer.image { (rendererContext) in
            let thumbFrame = imageBounds.insetBy(dx: padding, dy: padding).offsetBy(dx: 0, dy: 0.5)
            color.setFill()
            rendererContext.cgContext.fillEllipse(in: thumbFrame)
        }
    }
}

extension PlaybackProgressView {
    class Slider: UISlider {
        let trackHeight: CGFloat = 3

        override func trackRect(forBounds bounds: CGRect) -> CGRect {
            var trackRect = super.trackRect(forBounds: bounds)
            trackRect.size.height = trackHeight
            return trackRect
        }

        override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
            let thumbRect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
            return thumbRect.inset(by: UIEdgeInsets(top: -15, left: -15, bottom: -15, right: -15))
        }

        // With this, users can just tap (or drag) any point to change the current playback position,
        // without starting touching the current thumb position.
        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            // We need to invoke continueTracking(_:with:)
            // to update value with a single tap without dragging.
            // Invoking continueTracking(_:with:) asynchronously
            // to run it _after_ returning true from beginTracking(_:with:)
            // so that isTracking property will became true.
            DispatchQueue.main.async {
                super.continueTracking(touch, with: event)
            }

            return true
        }
    }
}

extension PlaybackProgressView {
    class PrecisePlayerState {
        let musicPlayer: MPMusicPlayerController

        lazy var precisePlaybackObserver = PrecisePlaybackObserver(playerState: self)

        var lastNowPlayingItemChangeTime: Date?

        init(musicPlayer: MPMusicPlayerController) {
            self.musicPlayer = musicPlayer

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(musicPlayerControllerNowPlayingItemDidChange),
                name: .MPMusicPlayerControllerNowPlayingItemDidChange,
                object: musicPlayer
            )
        }

        @objc func musicPlayerControllerNowPlayingItemDidChange() {
            lastNowPlayingItemChangeTime = Date()
        }

        var currentPlaybackTime: TimeInterval {
            get {
                // On iOS 14 musicPlayer.currentPlaybackTime tends to return
                // musicPlayer.nowPlayingItem.playbackDuration (i.e. end of the song)
                // when musicPlayer.nowPlayingItem is just changed.
                if musicPlayer.currentPlaybackTime == musicPlayer.nowPlayingItem?.playbackDuration {
                    return 0
                } else if let lastNowPlayingItemChangeTime = lastNowPlayingItemChangeTime, Date().timeIntervalSince(lastNowPlayingItemChangeTime) < 0.15 {
                    return 0
                } else {
                    return musicPlayer.currentPlaybackTime
                }
            }

            set {
                musicPlayer.currentPlaybackTime = newValue
            }
        }

        var currentPlaybackRate: Float {
            return musicPlayer.currentPlaybackRate
        }

        var isMovingForwardPlaybackTime: Bool {
            switch self.musicPlayer.playbackState {
            case .interrupted, .paused, .stopped:
                return false
            default:
                return !isWaitingForPlaybackToActuallyStart && !isPlayingLiveItem
            }
        }

        var isPlayingLiveItem: Bool {
            return musicPlayer.currentPlaybackTime.isNaN
        }

        var isProbablyPlayingRadio: Bool {
            guard let nowPlayingItem = musicPlayer.nowPlayingItem else { return false }
            return nowPlayingItem.playbackDuration == 0
        }

        func waitForPlaybackToActuallyStart(precision: TimeInterval = 0.01, expirationDuration: TimeInterval = 1, handler: @escaping () -> Void) {
            precisePlaybackObserver.waitForPlaybackToActuallyStart(precision: precision, expirationDuration: expirationDuration, handler: handler)
        }

        func stopWaitingForPlaybackToActuallyStart() {
            precisePlaybackObserver.stopWaiting()
        }

        var isWaitingForPlaybackToActuallyStart: Bool {
            return precisePlaybackObserver.isWaiting
        }
    }

    class PrecisePlaybackObserver {
        let playerState: PrecisePlayerState
        var timer: Timer?

        init(playerState: PrecisePlayerState) {
            self.playerState = playerState
        }

        func waitForPlaybackToActuallyStart(precision: TimeInterval, expirationDuration: TimeInterval, handler: @escaping () -> Void) {
            stopWaiting()

            let observationStartDate = Date()
            let initialPlaybackTime = playerState.currentPlaybackTime

            timer = Timer.scheduledTimer(withTimeInterval: precision, repeats: true) { [weak self] (timer) in
                guard let self = self else { return }

                if Date().timeIntervalSince(observationStartDate) >= expirationDuration {
                    self.stopWaiting()
                    return
                }

                if self.playerState.currentPlaybackRate == 0 {
                    return
                }

                if self.playerState.currentPlaybackTime != initialPlaybackTime  {
                    handler()
                    self.stopWaiting()
                }
            }
        }

        func stopWaiting() {
            timer?.invalidate()
            timer = nil
        }

        var isWaiting: Bool {
            return timer != nil
        }
    }
}
