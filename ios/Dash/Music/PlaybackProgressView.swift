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
            addNotificationObserver()
            musicPlayerControllerNowPlayingItemDidChange()
        }
    }

    lazy var precisePlaybackObserver = PrecisePlaybackObserver(musicPlayer: musicPlayer)
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
        if isPlayingLiveItem {
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
            slider.heightAnchor.constraint(equalToConstant: 10)
        ])

        constraints.append(contentsOf: [
            elapsedTimeLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
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
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    func scheduleUpdatesIfNeeded(initialUpdate: Bool = true) {
        unscheduleUpdates()

        if initialUpdate {
            update()
        }

        if !willPlaybackTimeChange {
            return
        }

        precisePlaybackObserver.waitForPlaybackToActuallyStart { [weak self] in
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
        precisePlaybackObserver.stopWaiting()
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

        if !willPlaybackTimeChange || musicPlayer.currentPlaybackRate == 0 || slider.isTracking {
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
            if isPlayingLiveItem {
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
        scheduleUpdatesIfNeeded()
    }

    @objc func musicPlayerControllerPlaybackStateDidChange() {
        scheduleUpdatesIfNeeded()
    }

    @objc func applicationWillEnterForeground() {
        // When an app entered background, UIKit removes all animations
        // even if it's an infinite animation.
        // So we restart the animation here if it should be when the app came back to foreground.
        scheduleUpdatesIfNeeded()
    }

    @IBAction func sliderValueDidChange() {
        let isDragFinishing = !slider.isTracking

        if isDragFinishing {
            musicPlayer.currentPlaybackTime = TimeInterval(slider.value)
            // We spcify initialUpdate: false here because getter of musicPlayer.currentPlaybackTime
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

    var willPlaybackTimeChange: Bool {
        switch self.musicPlayer.playbackState {
        case .interrupted, .paused, .stopped:
            return false
        default:
            return !isPlayingLiveItem
        }
    }

    var playbackTimeUpdateInterval: TimeInterval {
        return TimeInterval(1.0 / musicPlayer.currentPlaybackRate)
    }

    var isPlayingLiveItem: Bool {
        guard let musicPlayer = musicPlayer else { return false }
        return musicPlayer.currentPlaybackTime.isNaN
    }

    var displayedPlaybackTime: TimeInterval {
        if slider.isTracking {
            return TimeInterval(slider.value)
        } else {
            return musicPlayer.currentPlaybackTime
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
    }
}

extension PlaybackProgressView {
    class PrecisePlaybackObserver {
        let musicPlayer: MPMusicPlayerController
        var timer: Timer?

        init(musicPlayer: MPMusicPlayerController) {
            self.musicPlayer = musicPlayer
        }

        func waitForPlaybackToActuallyStart(precision: TimeInterval = 0.01, expirationDuration: TimeInterval = 1, handler: @escaping () -> Void) {
            stopWaiting()

            let observationStartDate = Date()
            let initialPlaybackTime = musicPlayer.currentPlaybackTime

            timer = Timer.scheduledTimer(withTimeInterval: precision, repeats: true) { [weak self] (timer) in
                guard let self = self else { return }

                if Date().timeIntervalSince(observationStartDate) >= expirationDuration {
                    self.stopWaiting()
                    return
                }

                if self.musicPlayer.currentPlaybackRate == 0 {
                    return
                }

                if self.musicPlayer.currentPlaybackTime != initialPlaybackTime  {
                    handler()
                    self.stopWaiting()
                }
            }
        }

        func stopWaiting() {
            timer?.invalidate()
            timer = nil
        }
    }
}
