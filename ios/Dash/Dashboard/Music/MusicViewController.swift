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
    enum LayoutMode {
        case vertical
        case square
        case landscape
    }

    @IBOutlet weak var artworkView: ArtworkView!
    @IBOutlet weak var songTitleView: SongTitleView!
    @IBOutlet weak var playbackProgressView: PlaybackProgressView!
    @IBOutlet weak var playbackControlView: PlaybackControlView!
    @IBOutlet weak var volumeView: VolumeView!
    @IBOutlet weak var shuffleModeButton: ShuffleModeButton!
    @IBOutlet weak var repeatModeButton: RepeatModeButton!

    var musicPlayer: MPMusicPlayerController {
        return MPMusicPlayerController.systemMusicPlayer
    }

    lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let gestureRecognizer = UIPanGestureRecognizer()
        view.addGestureRecognizer(gestureRecognizer)
        return gestureRecognizer
    }()

    var currentLayoutMode: LayoutMode?

    var desiredLayoutMode: LayoutMode {
        if traitCollection.horizontalSizeClass == .compact {
            return .vertical
        } else {
            let size = view.bounds.size

            if (size.width / size.height) > 2 {
                return .landscape
            } else {
                return .square
            }
        }
    }

    @IBOutlet var artworkViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var artworkViewAndSongTitleViewTopAlignmentConstraint: NSLayoutConstraint!
    @IBOutlet var songTitleViewAndPlaybackProgressViewLeadingAlignmentConstraint: NSLayoutConstraint!
    @IBOutlet var songTitleViewAndPlaybackProgressViewVerticalConstraint: NSLayoutConstraint!
    @IBOutlet var artworkViewAndVolumeViewBottomAlignmentConstraint: NSLayoutConstraint!

    var constraintsForLandscapeLayoutMode: [NSLayoutConstraint] {
        return [
            artworkViewBottomConstraint,
            artworkViewAndSongTitleViewTopAlignmentConstraint,
            songTitleViewAndPlaybackProgressViewLeadingAlignmentConstraint,
            songTitleViewAndPlaybackProgressViewVerticalConstraint,
            artworkViewAndVolumeViewBottomAlignmentConstraint
        ]
    }

    lazy var artworkViewBottomLargeSpacingConstraint = view.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 260)
    lazy var artworkViewAndSongTitleViewCenterYAlignmentConstraint = songTitleView.centerYAnchor.constraint(equalTo: artworkView.centerYAnchor)
    lazy var artworkViewAndPlaybackProgressViewLeadingAlignmentConstraint = playbackProgressView.leadingAnchor.constraint(equalTo: artworkView.leadingAnchor)
    lazy var artworkViewAndPlaybackProgressViewVerticalConstraint = playbackProgressView.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 24)
    lazy var volumeViewBottomConstraint = view.bottomAnchor.constraint(equalTo: volumeView.bottomAnchor, constant: 24)

    var constraintsForSquareLayoutMode: [NSLayoutConstraint] {
        return [
            artworkViewBottomLargeSpacingConstraint,
            artworkViewAndSongTitleViewCenterYAlignmentConstraint,
            artworkViewAndPlaybackProgressViewLeadingAlignmentConstraint,
            artworkViewAndPlaybackProgressViewVerticalConstraint,
            volumeViewBottomConstraint
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        playbackControlView.delegate = self

        artworkView.visualEffectScopeView = view

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
            selector: #selector(musicPlayerControllerNowPlayingItemDidChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        shuffleModeButton.addTarget(self, action: #selector(shuffleModeSwitchValueDidChange), for: .valueChanged)
        repeatModeButton.addTarget(self, action: #selector(repeatModeSwitchValueDidChange), for: .valueChanged)

        updatePlaybackModeButtons()

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(artworkViewDidRecognizeDoubleTap))
        gestureRecognizer.numberOfTapsRequired = 2
        artworkView.addGestureRecognizer(gestureRecognizer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        switchLayoutModeIfNeeded()
    }

    func switchLayoutModeIfNeeded() {
        let desiredLayoutMode = self.desiredLayoutMode

        if currentLayoutMode == desiredLayoutMode { return }

        switch desiredLayoutMode {
        case .vertical:
            NSLayoutConstraint.deactivate(constraintsForSquareLayoutMode)
            NSLayoutConstraint.deactivate(constraintsForLandscapeLayoutMode)
        case .square:
            NSLayoutConstraint.deactivate(constraintsForLandscapeLayoutMode)
            NSLayoutConstraint.activate(constraintsForSquareLayoutMode)
        case .landscape:
            NSLayoutConstraint.deactivate(constraintsForSquareLayoutMode)
            NSLayoutConstraint.activate(constraintsForLandscapeLayoutMode)
        }

        currentLayoutMode = desiredLayoutMode
    }

    func updatePlaybackModeButtons() {
        shuffleModeButton.value = musicPlayer.shuffleMode
        repeatModeButton.value = musicPlayer.repeatMode
    }

    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
    }

    func playbackControlView(_ playbackControlView: PlaybackControlView, didPerformOperation operation: PlaybackControlView.Operation) {
        switch operation {
        case .skipToBeginning:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.playbackProgressView.scheduleUpdatesIfNeeded()
            }
        default:
            break
        }
    }

    @objc func musicPlayerControllerNowPlayingItemDidChange() {
        updatePlaybackModeButtons()
    }

    @objc func applicationWillEnterForeground() {
        updatePlaybackModeButtons()
    }

    @IBAction func shuffleModeSwitchValueDidChange() {
        musicPlayer.shuffleMode = shuffleModeButton.value
    }

    @IBAction func repeatModeSwitchValueDidChange() {
        musicPlayer.repeatMode = repeatModeButton.value
    }

    @objc func artworkViewDidRecognizeDoubleTap() {
        addNowPlayingItemToFavoritesPlaylist()
    }

    func addNowPlayingItemToFavoritesPlaylist() {
        guard let nowPlayingItem = musicPlayer.nowPlayingItem else { return }

        guard let favoritesPlaylist = favoritesPlaylist else {
            let alertController = UIAlertController(
                title: "“Favorites” playlist not found",
                message: "You need to create a playlist named “Favorites” in the Music app first.",
                preferredStyle: .alert
            )

            alertController.addAction(UIAlertAction(title: "OK", style: .default))

            present(alertController, animated: true)

            return
        }

        if favoritesPlaylist.items.contains(nowPlayingItem) { return }

        favoritesPlaylist.add([nowPlayingItem]) { (error) in
            logger.error(error)
        }

        let animation = HeartAnimation(view: artworkView)
        animation.start()
    }

    var favoritesPlaylist: MPMediaPlaylist? {
        let favoritesPlaylist = MPMediaQuery.playlists().collections?.first(where: { (collection) in
            guard let playlist = collection as? MPMediaPlaylist else { return false }
            return playlist.name == "Favorites"
        })

        return favoritesPlaylist as? MPMediaPlaylist
    }
}
