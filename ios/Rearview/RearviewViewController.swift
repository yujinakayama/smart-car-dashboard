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

class RearviewViewController: UIViewController, ConnectionDelegate, H264ByteStreamParserDelegate {
    @IBOutlet var displayView: AVSampleBufferDisplayView!
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!

    var displayLayer: AVSampleBufferDisplayLayer {
        return displayView.displayLayer
    }

    var connection: Connection?

    var expiredFrameFlushingTimer: Timer?
    let frameExpirationPeriodInMilliseconds = 200
    var lastFrameTime: __uint64_t?

    lazy var h264ByteStreamParser: H264ByteStreamParser = {
        let h264ByteStreamParser = H264ByteStreamParser()
        h264ByteStreamParser.delegate = self
        return h264ByteStreamParser
    }()

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        displayLayer.videoGravity = .resizeAspect

        NotificationCenter.default.addObserver(self, selector: #selector(start), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stop), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc func start() {
        // Run the following command on the Raspberry Pi with camera:
        // while :
        // do
        // raspivid --verbose --flush -t 0 --hflip -fps 40 --exposure nightpreview --metering backlit --awb auto --flicker auto --metering average --drc high --profile high -w 1440 -h 1080 --sharpness 100 --imxfx denoise --listen -o tcp://0.0.0.0:5001 --ev 10 --saturation 10
        // done
        if let raspberryPiAddress = Defaults.shared.raspberryPiAddress {
            connectToRaspberryPi(host: raspberryPiAddress)
        } else {
            let alertController = UIAlertController(
                title: nil,
                message: "You need to specity your Raspberry Pi address in the Settings app.",
                preferredStyle: .alert
            )

            alertController.addAction(UIAlertAction(title: "OK", style: .default))

            present(alertController, animated: true)

            return
        }
    }

    @objc func stop() {
        connection?.disconnect()

        expiredFrameFlushingTimer?.invalidate()
        lastFrameTime = nil

        flushImage()
    }

    func retry() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicatorView.startAnimating()
        }

        stop()
        start()
    }

    func flushImage() {
        DispatchQueue.main.async {
            self.displayLayer.flushAndRemoveImage()
        }
    }

    func connectToRaspberryPi(host: String) {
        let connection = Connection(host: host, port: 5001)
        connection.delegate = self
        connection.connect()
        self.connection = connection
    }

    func connectionDidEstablish(_ connection: Connection) {
        logger.info()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.activityIndicatorView.stopAnimating()

            self.expiredFrameFlushingTimer = Timer.scheduledTimer(
                timeInterval: 1.0 / 30,
                target: self,
                selector: #selector(self.flushExpiredFrame),
                userInfo: nil,
                repeats: true
            )
        }
    }

    func connectionDidTimeOut(_ connection: Connection) {
        logger.error()

        DispatchQueue.main.async { [weak self] in
            self?.retry()
        }
    }

    func connection(_ connection: Connection, didUpdateState state: NWConnection.State) {
        logger.info(state)

        switch state {
        case .cancelled, .failed, .waiting:
            flushImage()
        default:
            break
        }
    }

    func connection(_ connection: Connection, didReceiveData data: Data) {
        h264ByteStreamParser.parse(data)
    }

    func parser(_ parser: H264ByteStreamParser, didBuildSampleBuffer sampleBuffer: CMSampleBuffer) {
        logger.debug()

        lastFrameTime = currentTime

        DispatchQueue.main.async { [weak self] in
            self?.displayLayer.enqueue(sampleBuffer)
        }
    }

    // For safety, avoid keeping displaying old frame when the connection is unstable
    // since it may mislead the driver to determine the frame is showing the current environment.
    @objc func flushExpiredFrame() {
        guard let lastFrameTime = self.lastFrameTime else { return }

        let elapsedTimeSinceLastFrameInMilliseconds = (currentTime - lastFrameTime) / 1_000_000

        if elapsedTimeSinceLastFrameInMilliseconds >= frameExpirationPeriodInMilliseconds {
            flushImage()
        }
    }

    var currentTime: __uint64_t {
        return clock_gettime_nsec_np(CLOCK_MONOTONIC)
    }
}
