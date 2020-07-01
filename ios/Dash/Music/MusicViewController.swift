//
//  MusicViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/06/29.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

class MusicViewController: UIViewController {
    @IBOutlet weak var artworkView: ArtworkView!
    @IBOutlet weak var playbackControlView: PlaybackControlView!
    @IBOutlet weak var volumeView: MPVolumeView!

    var musicPlayer: MPMusicPlayerController {
        return MPMusicPlayerController.systemMusicPlayer
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        MPMediaLibrary.requestAuthorization { [weak self] (authorizationStatus) in
            guard authorizationStatus == .authorized else { return }

            DispatchQueue.main.async {
                self?.setUp()
            }
        }
    }

    func setUp() {
        artworkView.musicPlayer = musicPlayer
        playbackControlView.musicPlayer = musicPlayer

        musicPlayer.beginGeneratingPlaybackNotifications()
    }

    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
    }
}
