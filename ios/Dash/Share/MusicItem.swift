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

    let title: String?
    let url: URL
    let creationDate: Date?

    func open() {
        guard let itemID = itemID else { return }

        let player = MPMusicPlayerController.systemMusicPlayer
        player.setQueue(with: MPMusicPlayerStoreQueueDescriptor(storeIDs: [itemID]))
        player.play()
    }

    var itemID: String? {
        return songID ?? collectionID
    }

    var songID: String? {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItem = urlComponents?.queryItems?.first { $0.name == "i" }
        return queryItem?.value
    }

    var collectionID: String? {
        return url.pathComponents.last
    }
}
