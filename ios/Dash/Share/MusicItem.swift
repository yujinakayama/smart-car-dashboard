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
        guard let storeID = storeID else { return }

        let player = MPMusicPlayerController.systemMusicPlayer
        player.setQueue(with: MPMusicPlayerStoreQueueDescriptor(storeIDs: [storeID]))
        player.play()
    }

    var storeID: String? {
        return url.pathComponents.last
    }
}
