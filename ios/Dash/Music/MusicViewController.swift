//
//  MusicViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/06/29.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer
import AVKit
import StoreKit

class MusicViewController: UIViewController, PlaybackControlViewDelegate {
    @IBOutlet weak var artworkView: ArtworkView!
    @IBOutlet weak var songTitleView: SongTitleView!
    @IBOutlet weak var playbackProgressView: PlaybackProgressView!
    @IBOutlet weak var playbackControlView: PlaybackControlView!
    @IBOutlet weak var volumeView: VolumeView!
    @IBOutlet weak var shuffleModeSwitch: PlaybackModeSwitch!
    @IBOutlet weak var repeatModeSwitch: PlaybackModeSwitch!

    var musicPlayer: MPMusicPlayerController {
        return MPMusicPlayerController.systemMusicPlayer
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        playbackControlView.delegate = self

        MPMediaLibrary.requestAuthorization { [weak self] (mediaPlayerAuthorizationStatus) in
            logger.info(mediaPlayerAuthorizationStatus)

            guard mediaPlayerAuthorizationStatus == .authorized else { return }

            SKCloudServiceController.requestAuthorization { [weak self] (cloudServiceAuthorizationStatus) in
                logger.info(cloudServiceAuthorizationStatus)

                guard cloudServiceAuthorizationStatus == .authorized else { return }

                DispatchQueue.main.async {
                    self?.setUp()
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        songTitleView.setUpAnimationIfNeeded()
    }

    func setUp() {
        artworkView.musicPlayer = musicPlayer
        songTitleView.musicPlayer = musicPlayer
        playbackProgressView.musicPlayer = musicPlayer
        playbackControlView.musicPlayer = musicPlayer

        musicPlayer.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        shuffleModeSwitch.addTarget(self, action: #selector(shuffleModeSwitchValueDidChange), for: .valueChanged)
        repeatModeSwitch.addTarget(self, action: #selector(repeatModeSwitchValueDidChange), for: .valueChanged)

        updatePlaybackModeSwitches()
    }

    func updatePlaybackModeSwitches() {
        shuffleModeSwitch.isOn = (musicPlayer.shuffleMode != .off)
        repeatModeSwitch.isOn = (musicPlayer.repeatMode != .none)
    }

    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
    }

    func playbackControlView(_ playbackControlView: PlaybackControlView, didPerformOperation operation: PlaybackControlView.Operation) {
        switch operation {
        case .skipToBeginning:
            playbackProgressView.scheduleUpdatesIfNeeded()
        default:
            break
        }
    }

    @objc func applicationWillEnterForeground() {
        updatePlaybackModeSwitches()
    }

    @IBAction func shuffleModeSwitchValueDidChange() {
        musicPlayer.shuffleMode = shuffleModeSwitch.isOn ? .songs : .off
    }

    @IBAction func repeatModeSwitchValueDidChange() {
        musicPlayer.repeatMode = repeatModeSwitch.isOn ? .all : .none
    }
}
