//
//  Assistant.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import AVFAudio
import MediaPlayer

class Assistant {
    let audioOutputManager = AudioOutputManager()

    var locationOpener: LocationOpener?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillEnterForeground), name: UIScene.willEnterForegroundNotification, object: nil)
    }

    @objc func sceneDidEnterBackground() {
        Defaults.shared.lastBackgroundEntranceTime = Date()
    }

    @objc func sceneWillEnterForeground() {
        if Defaults.shared.automaticallyOpensUnopenedLocationWhenAppIsOpened {
            locationOpener = LocationOpener(newItemThresholdTime: Defaults.shared.lastBackgroundEntranceTime)

            Task {
                await locationOpener?.run()
            }
        } else {
            locationOpener = nil
        }
    }
}

extension Assistant {
    class LocationOpener {
        let newItemThresholdTime: Date
        let maxDatabaseUpdateWaitTimeInterval: TimeInterval = 2
        private var location: Location?

        init(newItemThresholdTime: Date) {
            self.newItemThresholdTime = newItemThresholdTime
        }

        func run() async {
            logger.info()

            guard let location = await getLocationToOpen() else { return }

            location.markAsOpened(true)
            location.openDirectionsInMaps()

            if !location.categories.contains(where: { $0.isKindOfParking }),
               Defaults.shared.automaticallySearchParkingsWhenLocationIsAutomaticallyOpened
            {
                await SharedItemTableViewController.pushMapsViewControllerForParkingSearchInCurrentScene(location: location)
            }

            self.location = location
        }

        func getLocationToOpen() async -> Location? {
            guard let database = Firebase.shared.sharedItemDatabase else { return nil }

            let query = database.items(type: .location, hasBeenOpened: false, createdAfter: newItemThresholdTime)

            guard let unopenedLocations = try? await query.get() as? [Location] else { return nil }

            if unopenedLocations.count == 1, let location = unopenedLocations.first {
                return location
            } else {
                return nil
            }
        }
    }
}

extension Assistant {
    class AudioOutputManager {
        var isConnectedToCarBluetoothAudio: Bool {
            return isConnectedToBluetoothAudio && Vehicle.default.isConnected
        }

        var isConnectedToBluetoothAudio: Bool {
            let route = AVAudioSession.sharedInstance().currentRoute
            return route.outputs.first?.portType == .bluetoothA2DP
        }

        init() {
            NotificationCenter.default.addObserver(self, selector: #selector(audioSessionDidChangeRoute), name: AVAudioSession.routeChangeNotification, object: nil)
        }

        @objc func audioSessionDidChangeRoute() {
            logger.info("isConnectedToCarBluetoothAudio: \(isConnectedToCarBluetoothAudio)")

            if isConnectedToCarBluetoothAudio {
                startPlayingMusicIfNeeded()
            }
        }

        @objc func startPlayingMusicIfNeeded() {
            if musicPlayer.playbackState == .playing {
                return
            }

            if !isPlayingLiveItem && !isProbablyPlayingRadio {
                musicPlayer.skipToBeginning()
            }

            musicPlayer.play()
        }

        var musicPlayer: MPMusicPlayerController {
            return MPMusicPlayerController.systemMusicPlayer
        }

        var isPlayingLiveItem: Bool {
            return musicPlayer.currentPlaybackTime.isNaN
        }

        var isProbablyPlayingRadio: Bool {
            guard let nowPlayingItem = musicPlayer.nowPlayingItem else { return false }
            return nowPlayingItem.mediaType.rawValue == 0 || nowPlayingItem.playbackDuration == 0
        }
    }
}
