//
//  MPMediaItemExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/10/27.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import MediaPlayer

extension MPMediaItem {
    var validPlaybackStoreID: String? {
        if playbackStoreID.isEmpty || playbackStoreID == "0" {
            return nil
        } else {
            return playbackStoreID
        }
    }
}
