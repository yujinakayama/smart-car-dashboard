//
//  MusicItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/16.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore
import MediaPlayer

class MusicItem: SharedItemProtocol {
    var firebaseDocument: DocumentReference?

    let artworkURLTemplate: String?
    let creator: String?
    let id: String?
    let name: String?
    let playParameters: MPMusicPlayerPlayParameters?
    let url: URL
    let creationDate: Date?

    func open() {
        if let playParameters = playParameters {
            play(playParameters: playParameters)
        } else {
            openInMusicApp()
        }
    }

    func artworkURL(size: CGSize) -> URL? {
        return artworkURL(width: Int(ceil(size.width)), height: Int(ceil(size.height)))
    }

    func artworkURL(width: Int, height: Int) -> URL? {
        guard let urlTemplate = artworkURLTemplate else { return nil }

        let urlString = urlTemplate
            .replacingOccurrences(of: "{w}", with: String(width))
            .replacingOccurrences(of: "{h}", with: String(height))

        return URL(string: urlString)
    }

    private func play(playParameters: MPMusicPlayerPlayParameters) {
        let player = MPMusicPlayerController.systemMusicPlayer
        let queueDescriptor = MPMusicPlayerPlayParametersQueueDescriptor(playParametersQueue: [playParameters])
        player.prepend(queueDescriptor)
        player.skipToNextItem()
        player.play()
    }

    private func openInMusicApp() {
        UIApplication.shared.open(url, options: [:])
    }
}
