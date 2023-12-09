//
//  ViewController.swift
//  CheckmarkViewDevApp
//
//  Created by Yuji Nakayama on 2023/12/03.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import CheckmarkView
import AVKit

class CombinationViewController: UIViewController {
    @IBOutlet weak var progressCheckmarkView: ProgressCheckmarkView!
    @IBOutlet weak var videoPlayerView: VideoPlayerView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let videoURL = Bundle.main.url(forResource: "ApplePay", withExtension: "mov")!
        videoPlayerView.player = AVPlayer(url: videoURL)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func toggleAnimation() {
        switch progressCheckmarkView.state {
        case .inactive:
            videoPlayerView.play()
//            videoPlayerView.player?.rate = 0.1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.progressCheckmarkView.state = .inProgress
            }
        case .inProgress:
            progressCheckmarkView.state = .done
        case .done:
            progressCheckmarkView.state = .inactive
        }
    }
}

