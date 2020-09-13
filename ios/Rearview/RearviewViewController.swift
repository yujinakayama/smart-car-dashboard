//
//  RearviewViewController.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/09/09.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import Network
import AVFoundation

class RearviewViewController: UIViewController, H264ByteStreamParserDelegate {
    var connection: NWConnection?

    lazy var h264ByteStreamParser: H264ByteStreamParser = {
        let h264ByteStreamParser = H264ByteStreamParser()
        h264ByteStreamParser.delegate = self
        return h264ByteStreamParser
    }()

    lazy var displayLayer: AVSampleBufferDisplayLayer = {
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.frame = view.layer.bounds
        displayLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(displayLayer)
        return displayLayer
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(start), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stop), name: UIApplication.didEnterBackgroundNotification, object: nil)

        start()
    }

    @objc func start() {
        // Run the following command on the Raspberry Pi with camera:
        // while :
        // do
        // raspivid --verbose --flush -t 0 --hflip -fps 40 --exposure nightpreview --metering backlit --awb auto --flicker auto --metering average --drc high --profile high -w 1440 -h 1080 --sharpness 100 --imxfx denoise --listen -o tcp://0.0.0.0:5001 --ev 10 --saturation 10
        // done
        connectToRaspberryPi(host: "192.168.1.119")
    }

    @objc func stop() {
        connection?.cancel()
        connection = nil
        displayLayer.flushAndRemoveImage()
    }

    func connectToRaspberryPi(host: String) {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 5001, using: .tcp)

        connection.stateUpdateHandler = { [unowned self] (state) in
            logger.info(state)

            switch state {
            case .ready:
                self.readReceivedData(from: connection)
            case .cancelled, .failed, .waiting:
                self.displayLayer.flushAndRemoveImage()
            default:
                break
            }
        }

        connection.start(queue: DispatchQueue(label: "NWConnection"))

        self.connection = connection
    }

    func readReceivedData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 500, maximumLength: 100000) { [unowned self] (data, context, completed, error) in
            if let data = data {
                self.h264ByteStreamParser.parse(data)
            }

            self.readReceivedData(from: connection)
        }
    }

    func parser(_ parser: H264ByteStreamParser, didBuildSampleBuffer sampleBuffer: CMSampleBuffer) {
        logger.debug()
        displayLayer.enqueue(sampleBuffer)
    }
}
