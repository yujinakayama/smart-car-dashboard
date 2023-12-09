//
//  VideoPlayerView.swift
//  CheckmarkViewDevApp
//
//  Created by Yuji Nakayama on 2023/12/08.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import AVKit

class VideoPlayerView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    public var player: AVPlayer? {
        get {
            return playerLayer.player
        }

        set {
            playerLayer.player = newValue
        }
    }

    func play() {
        guard let player = playerLayer.player else { return }
        player.play()
    }
}
