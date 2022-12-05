//
//  SystemAudioVolume.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/01/13.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import MediaPlayer
import AVFAudio

class SystemAudioVolume {
    weak var delegate: SystemAudioVolumeDelegate?

    private let volumeView = MPVolumeView()

    private let audioSession = AVAudioSession.sharedInstance()

    private var observation: NSKeyValueObservation?

    init() {
        volumeView.frame = .init(x: -100, y: -100, width: 0, height: 0)
        volumeView.isHidden = true
        volumeView.isUserInteractionEnabled = false
        volumeView.setVolumeThumbImage(UIImage(), for: .normal)
        volumeView.setMinimumVolumeSliderImage(UIImage(), for: .normal)
        volumeView.setMaximumVolumeSliderImage(UIImage(), for: .normal)
    }

    deinit {
        volumeView.removeFromSuperview()
        stopObserving()
    }

    func startObserving() {
        do {
            try audioSession.setCategory(.ambient)
            // We need to re-activate after switching back from background
            // since audio session is automatically deactivated when app entered background.
            try audioSession.setActive(true)
        } catch {
            logger.error(error)
        }

        notifyIfChangedByOthers()

        if observation == nil {
            observation = audioSession.observe(\.outputVolume, changeHandler: { [unowned self] (audioSession, change) in
                self.notifyIfChangedByOthers()
            })
        }
    }

    func stopObserving() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error(error)
        }

        observation?.invalidate()
        observation = nil
    }

    private(set) var value: Float {
        get {
            // On iOS 16, audioSession.outputVolume returns rounded value with 0.05 step (e.g. 0.75, 0.8, 0.85).
            // However we cannot use privateVolumeSlider.value here since it reflect actual value with large latency.
            return audioSession.outputVolume
        }

        set {
            privateVolumeSlider.value = newValue
            isSettingValueNow = true
        }
    }

    private var isSettingValueNow = false

    private lazy var privateVolumeSlider = volumeView.subviews.first { $0 is UISlider} as! UISlider

    func setValue(_ value: Float, withIndicator showIndicator: Bool = false) {
        setVolumeViewVisibility(!showIndicator)

        self.value = value

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setVolumeViewVisibility(false)
        }
    }

    private func notifyIfChangedByOthers() {
        if isSettingValueNow {
            isSettingValueNow = false
            return
        }

        delegate?.systemAudioVolumeDidDetectChangeByOthers(self)
    }

    private func setVolumeViewVisibility(_ visible: Bool) {
        if visible, volumeView.superview == nil {
            window?.addSubview(volumeView)
        }

        volumeView.isHidden = !visible
    }

    private var window: UIWindow? {
        return UIApplication.shared.foregroundWindowScene?.keyWindow
    }
}

protocol SystemAudioVolumeDelegate: NSObjectProtocol {
    func systemAudioVolumeDidDetectChangeByOthers(_ systemAudioVolume: SystemAudioVolume)
}
