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
import BetterSegmentedControl

class RearviewViewController: UIViewController, ConnectionDelegate, H264ByteStreamParserDelegate {
    lazy var displayView: AVSampleBufferDisplayView = {
        let displayView = AVSampleBufferDisplayView()

        view.addSubview(displayView)

        displayView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            displayView.leftAnchor.constraint(equalTo: view.leftAnchor),
            displayView.rightAnchor.constraint(equalTo: view.rightAnchor),
            displayView.topAnchor.constraint(equalTo: view.topAnchor),
            displayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        return displayView
    }()

    lazy var activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView(style: .large)
        activityIndicatorView.color = .white

        view.addSubview(activityIndicatorView)

        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        return activityIndicatorView
    }()

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

    let cameraOptionsAdjuster = CameraOptionsAdjuster()

    lazy var sensitivityModeSegmentedControl: HUDSegmentedControl = {
        let segmentTitles = ["Auto", "Day", "Night", "Low Light", "Ultra Low Light"]
        assert(segmentTitles.count == CameraOptionsAdjuster.SensitivityMode.allCases.count)

        let segmentedControl = HUDSegmentedControl(titles: segmentTitles)
        segmentedControl.isHidden = true
        segmentedControl.selectedSegmentIndex = Defaults.shared.cameraSensitivityMode?.rawValue ?? 0
        segmentedControl.addTarget(self, action: #selector(sensitivityModeSegmentedControlDidChangeValue), for: .valueChanged)

        view.addSubview(segmentedControl)

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            NSLayoutConstraint(item: segmentedControl, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.7, constant: 0),
            segmentedControl.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9),
            segmentedControl.heightAnchor.constraint(equalTo: segmentedControl.widthAnchor, multiplier: 0.3 / CGFloat(segmentTitles.count)),
        ]

        let constraint = segmentedControl.widthAnchor.constraint(equalToConstant: CGFloat(segmentTitles.count * 180))
        constraint.priority = .defaultHigh
        constraints.append(constraint)

        NSLayoutConstraint.activate(constraints)

        return segmentedControl
    }()

    var sensitivityModeSegmentedControlHidingTimer: Timer?

    lazy var gestureRecognizer: UIGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(gestureRecognizerDidRecognizeTap))
        gestureRecognizer.numberOfTapsRequired = 1
        return gestureRecognizer
    }()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        _ = displayView
        _ = activityIndicatorView
        _ = sensitivityModeSegmentedControl

        displayLayer.videoGravity = .resizeAspect

        displayView.addGestureRecognizer(gestureRecognizer)

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
            do {
                try connectToRaspberryPi(host: raspberryPiAddress)
            } catch {
                showAlertAboutInvalidRaspberryPiAddress()
            }
        } else {
            showAlertAboutInvalidRaspberryPiAddress()
        }
    }

    @objc func stop() {
        connection?.disconnect()
    }

    func retry(terminationReason: Connection.TerminationReason) {
        if terminationReason == .closedByServer {
            Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(start), userInfo: nil, repeats: false)
        } else {
            activityIndicatorView.startAnimating()
            Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(start), userInfo: nil, repeats: false)
        }
    }

    func flushImage() {
        DispatchQueue.main.async {
            self.displayLayer.flushAndRemoveImage()
        }
    }

    func connectToRaspberryPi(host: String) throws {
        let connection = try Connection(host: host, port: 5001)
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
                self.retry(terminationReason: reason)
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

    @IBAction func gestureRecognizerDidRecognizeTap() {
        if sensitivityModeSegmentedControl.isHidden {
            self.sensitivityModeSegmentedControl.alpha = 0
            sensitivityModeSegmentedControl.isHidden = false

            UIView.animate(withDuration: 0.25) {
                self.sensitivityModeSegmentedControl.alpha = 1
            }
        }

        resetSensitivityModeSegmentedControlVisibilityLifetime()
    }

    @IBAction func sensitivityModeSegmentedControlDidChangeValue() {
        guard let sensitivityMode = CameraOptionsAdjuster.SensitivityMode(rawValue: sensitivityModeSegmentedControl.selectedSegmentIndex) else { return }
        cameraOptionsAdjuster.sensitivityMode = sensitivityMode
        resetSensitivityModeSegmentedControlVisibilityLifetime()
    }

    private func resetSensitivityModeSegmentedControlVisibilityLifetime() {
        sensitivityModeSegmentedControlHidingTimer?.invalidate()

        sensitivityModeSegmentedControlHidingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { (timer) in
            UIView.animate(withDuration: 1) {
                self.sensitivityModeSegmentedControl.alpha = 0
            } completion: { (finished) in
                self.sensitivityModeSegmentedControl.isHidden = true
            }
        }
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

    func showAlertAboutInvalidRaspberryPiAddress() {
        let alertController = UIAlertController(
            title: nil,
            message: "You need to specity your Raspberry Pi address in the Settings app.",
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: "OK", style: .default))

        present(alertController, animated: true)
    }
}
