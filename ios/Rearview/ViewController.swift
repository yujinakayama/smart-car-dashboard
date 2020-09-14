//
//  ViewController.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/09/09.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import Network
import AVFoundation

class RearviewViewController: UIViewController, H264ByteStreamParserDelegate {
    var connection: NWConnection!

    lazy var h264ByteStreamParser: H264ByteStreamParser = {
        let h264ByteStreamParser = H264ByteStreamParser()
        h264ByteStreamParser.delegate = self
        return h264ByteStreamParser
    }()

    lazy var displayLayer: AVSampleBufferDisplayLayer = {
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.frame = view.layer.bounds
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(displayLayer)
        return displayLayer
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        connectToRaspberryPi(host: "192.168.1.124")
    }

    func connectToRaspberryPi(host: String) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: 5001, using: .tcp)

        connection.stateUpdateHandler = { [unowned self] (state) in
            print(state)

            if state == .ready {
                self.readReceivedData()
            }
        }

        connection.start(queue: DispatchQueue(label: "network"))
    }

    func readReceivedData() {
        connection.receive(minimumIncompleteLength: 1000, maximumLength: 10000) { [unowned self] (data, context, completed, error) in
            if let data = data {
                self.h264ByteStreamParser.parse(data)
            }

            self.readReceivedData()
        }
    }

    func parser(_ parser: H264ByteStreamParser, didBuildSampleBuffer sampleBuffer: CMSampleBuffer) {
        print(#function)
        displayLayer.enqueue(sampleBuffer)
    }
}
