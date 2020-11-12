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

    var hasReceivedInitialFrame = false

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        displayLayer.videoGravity = .resizeAspect

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            self?.hideBlankScreen()
            self?.start()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            self?.stop()
            self?.showBlankScreen()
        }
    }

    @objc func start() {
        hasReceivedInitialFrame = false

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

    func connection(_ connection: Connection, didTerminateWithReason reason: Connection.TerminationReason) {
        logger.info(reason)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.expiredFrameFlushingTimer?.invalidate()
            self.lastFrameTime = nil

            self.flushImage()

            if reason != .closedByClient {
                self.retry()
            }
        }
    }

    func connection(_ connection: Connection, didReceiveData data: Data) {
        h264ByteStreamParser.parse(data)
    }

    func parser(_ parser: H264ByteStreamParser, didBuildSampleBuffer sampleBuffer: CMSampleBuffer) {
        logger.verbose()

        lastFrameTime = currentTime

        if !hasReceivedInitialFrame {
            DispatchQueue.main.async { [weak self] in
                self?.fadeIn()
            }

            hasReceivedInitialFrame = true
        }

        DispatchQueue.main.async { [weak self] in
            self?.displayLayer.enqueue(sampleBuffer)
        }
    }

    func fadeIn() {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.25
        displayLayer.add(animation, forKey: nil)
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

    // https://developer.apple.com/library/archive/qa/qa1838/_index.html
    func showBlankScreen() {
        let blankViewController = UIViewController()
        blankViewController.modalPresentationStyle = .fullScreen
        blankViewController.view.backgroundColor = .black
        present(blankViewController, animated: false)
    }

    func hideBlankScreen() {
        dismiss(animated: false)
    }
}
