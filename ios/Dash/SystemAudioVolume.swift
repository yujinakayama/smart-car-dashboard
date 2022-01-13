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

        lastSeenValue = audioSession.outputVolume
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
            observation = audioSession.observe(\.outputVolume, changeHandler: { [weak self] (audioSession, change) in
                self?.notifyIfChangedByOthers()
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
            return audioSession.outputVolume
        }

        set {
            privateVolumeSlider.value = newValue
            lastSeenValue = newValue
        }
    }

    private var lastSeenValue: Float

    private lazy var privateVolumeSlider = volumeView.subviews.first { $0 is UISlider} as! UISlider

    func setValue(_ value: Float, withIndicator showIndicator: Bool = false) {
        setVolumeViewVisibility(!showIndicator)

        self.value = value

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.setVolumeViewVisibility(false)
        }
    }

    private func notifyIfChangedByOthers() {
        if value != lastSeenValue {
            lastSeenValue = value
            delegate?.systemAudioVolumeDidDetectChangeByOthers(self)
        }
    }

    private func setVolumeViewVisibility(_ visible: Bool) {
        if visible, volumeView.superview == nil {
            window?.addSubview(volumeView)
        }

        volumeView.isHidden = !visible
    }

    private var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes

        let foregroudScene = scenes.first { (scene) in
            scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
        } as? UIWindowScene

        return foregroudScene?.keyWindow
    }
}

protocol SystemAudioVolumeDelegate: NSObjectProtocol {
    func systemAudioVolumeDidDetectChangeByOthers(_ systemAudioVolume: SystemAudioVolume)
}
