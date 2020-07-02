//
//  MusicViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/06/29.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

class MusicViewController: UIViewController, PlaybackControlViewDelegate {
    @IBOutlet weak var artworkView: ArtworkView!
    @IBOutlet weak var songTitleView: SongTitleView!
    @IBOutlet weak var playbackProgressView: PlaybackProgressView!
    @IBOutlet weak var playbackControlView: PlaybackControlView!
    @IBOutlet weak var volumeView: MPVolumeView!

    var musicPlayer: MPMusicPlayerController {
        return MPMusicPlayerController.systemMusicPlayer
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        playbackControlView.delegate = self

        MPMediaLibrary.requestAuthorization { [weak self] (authorizationStatus) in
            guard authorizationStatus == .authorized else { return }

            DispatchQueue.main.async {
                self?.setUp()
            }
        }
    }

    func setUp() {
        artworkView.musicPlayer = musicPlayer
        songTitleView.musicPlayer = musicPlayer
        playbackProgressView.musicPlayer = musicPlayer
        playbackControlView.musicPlayer = musicPlayer

        musicPlayer.beginGeneratingPlaybackNotifications()
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
}
