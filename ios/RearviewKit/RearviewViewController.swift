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

public protocol RearviewViewControllerDelegate: NSObjectProtocol {
    func rearviewViewController(didChangeCameraSensitivityMode cameraSensitivityMode: CameraSensitivityMode)
}

public class RearviewViewController: UIViewController, ConnectionDelegate, H264ByteStreamParserDelegate {
    public weak var delegate: RearviewViewControllerDelegate?

    public let configuration: RearviewConfiguration

    public var cameraSensitivityMode: CameraSensitivityMode {
        didSet {
            sensitivityModeSegmentedControl.selectedSegmentIndex = cameraSensitivityMode.rawValue

            if isStarted {
                cameraOptionsAdjuster.apply(cameraSensitivityMode)
            }
        }
    }

    public var contentMode: ContentMode = .scaleAspectFit {
        didSet {
            applyContentMode()
        }
    }

    lazy var displayView = AVSampleBufferDisplayView()

    lazy var activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView(style: .large)
        activityIndicatorView.color = .white
        return activityIndicatorView
    }()

    var displayLayer: AVSampleBufferDisplayLayer {
        return displayView.displayLayer
    }

    var isStarted: Bool = false

    var connection: Connection?

    var expiredFrameFlushingTimer: Timer?
    let frameExpirationPeriodInMilliseconds = 200
    var lastFrameTime: __uint64_t?

    var retryTimer: Timer?

    lazy var h264ByteStreamParser: H264ByteStreamParser = {
        let h264ByteStreamParser = H264ByteStreamParser()
        h264ByteStreamParser.delegate = self
        return h264ByteStreamParser
    }()

    var hasReceivedInitialFrame = false

    let cameraOptionsAdjuster: CameraOptionsAdjuster

    lazy var sensitivityModeSegmentedControl: HUDSegmentedControl = {
        let segmentTitles = ["Auto", "Day", "Night", "Low Light", "Ultra Low Light"]
        assert(segmentTitles.count == CameraSensitivityMode.allCases.count)

        let segmentedControl = HUDSegmentedControl(titles: segmentTitles)
        segmentedControl.isHidden = true
        segmentedControl.selectedSegmentIndex = cameraSensitivityMode.rawValue
        segmentedControl.addTarget(self, action: #selector(sensitivityModeSegmentedControlDidChangeValue), for: .valueChanged)
        return segmentedControl
    }()

    public var sensitivityModeControlPosition: SensitivityModeControlPosition = .bottom {
        didSet {
            updateSensitivityModeSegmentedControlCenterYConstraint()
        }
    }

    var sensitivityModeSegmentedControlCenterYConstraint: NSLayoutConstraint?

    var sensitivityModeSegmentedControlHidingTimer: Timer?

    public lazy var tapGestureRecognizer: UIGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(gestureRecognizerDidRecognizeTap))
        gestureRecognizer.numberOfTapsRequired = 1
        return gestureRecognizer
    }()

    lazy var displayViewTopConstraint = displayView.topAnchor.constraint(equalTo: view.topAnchor)
    lazy var displayViewBottomConstraint = displayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    lazy var displayViewAspectRatioConstraint = displayView.widthAnchor.constraint(equalTo: displayView.heightAnchor, multiplier: 4 / 3)

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    public override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    public init(configuration: RearviewConfiguration, cameraSensitivityMode: CameraSensitivityMode = .auto) {
        self.configuration = configuration
        self.cameraOptionsAdjuster = CameraOptionsAdjuster(configuration: configuration)
        self.cameraSensitivityMode = cameraSensitivityMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        stop()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        view.addSubview(displayView)
        view.addSubview(activityIndicatorView)
        view.addSubview(sensitivityModeSegmentedControl)

        view.addGestureRecognizer(tapGestureRecognizer)

        installLayoutConstraints()

        applyContentMode()
    }

    func installLayoutConstraints() {
        for subview in view.subviews {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            displayView.leftAnchor.constraint(equalTo: view.leftAnchor),
            displayView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])

        NSLayoutConstraint.activate([
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        sensitivityModeSegmentedControlCenterYConstraint = NSLayoutConstraint(item: sensitivityModeSegmentedControl, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: sensitivityModeControlPosition.rawValue * 2, constant: 0)

        NSLayoutConstraint.activate([
            sensitivityModeSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sensitivityModeSegmentedControl.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9),
            {
                let constraint = sensitivityModeSegmentedControl.widthAnchor.constraint(equalToConstant: CGFloat(sensitivityModeSegmentedControl.titles!.count * 180))
                constraint.priority = .defaultHigh
                return constraint
            }(),
            sensitivityModeSegmentedControl.heightAnchor.constraint(equalTo: sensitivityModeSegmentedControl.widthAnchor, multiplier: 0.3 / CGFloat(sensitivityModeSegmentedControl.titles!.count)),

        ])

        updateSensitivityModeSegmentedControlCenterYConstraint()
    }

    func updateSensitivityModeSegmentedControlCenterYConstraint() {
        sensitivityModeSegmentedControlCenterYConstraint?.isActive = false

        sensitivityModeSegmentedControlCenterYConstraint = NSLayoutConstraint(
            item: sensitivityModeSegmentedControl,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .centerY,
            multiplier: sensitivityModeControlPosition.rawValue * 2,
            constant: 0
        )

        sensitivityModeSegmentedControlCenterYConstraint?.isActive = true

        sensitivityModeSegmentedControl.superview?.setNeedsLayout()
    }

    @objc public func start() {
        if isStarted { return }
        isStarted = true
        cameraOptionsAdjuster.apply(cameraSensitivityMode)
        connect()
    }

    @objc public func stop() {
        isStarted = false
        retryTimer?.invalidate()
        connection?.disconnect()
        activityIndicatorView.stopAnimating()
    }

    func retry(terminationReason: Connection.TerminationReason) {
        if terminationReason == .closedByServer {
            retryTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(connect), userInfo: nil, repeats: false)
        } else {
            startAnimatingActivityIndicator()
            retryTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(connect), userInfo: nil, repeats: false)
        }
    }

    func startAnimatingActivityIndicator() {
        if activityIndicatorView.isAnimating {
            return
        }

        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.35
        activityIndicatorView.layer.add(animation, forKey: nil)

        activityIndicatorView.startAnimating()
    }

    func flushImage() {
        DispatchQueue.main.async {
            self.displayLayer.flushAndRemoveImage()
        }
    }

    @objc func connect() {
        guard connection == nil else {
            logger.warning("Skipping because a connection already exists")
            return
        }

        let host = NWEndpoint.Host.ipv4(configuration.raspberryPiAddress.ipv4Address)
        let connection = Connection(host: host, port: 5001)
        connection.delegate = self
        connection.connect()
        self.connection = connection
    }

    func connectionDidEstablish(_ connection: Connection) {
        logger.info()

        if cameraOptionsAdjuster.lastRequestError != nil {
            // The sinatra server takes longer to launch than raspivid.
            cameraOptionsAdjuster.apply(cameraSensitivityMode, maxRetryCount: 10)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.hasReceivedInitialFrame = false

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

            self.connection = nil

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
        guard let sensitivityMode = CameraSensitivityMode(rawValue: sensitivityModeSegmentedControl.selectedSegmentIndex) else { return }
        cameraSensitivityMode = sensitivityMode
        resetSensitivityModeSegmentedControlVisibilityLifetime()
        delegate?.rearviewViewController(didChangeCameraSensitivityMode: sensitivityMode)
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

    func applyContentMode() {
        // First reset this constaint to avoid conflicts
        displayViewAspectRatioConstraint.isActive = false

        switch contentMode {
        case .scaleAspectFit:
            displayLayer.videoGravity = .resizeAspect
            displayViewTopConstraint.isActive = true
            displayViewBottomConstraint.isActive = true
            displayViewAspectRatioConstraint.isActive = false
        case .scaleAspectFill:
            displayLayer.videoGravity = .resizeAspectFill
            displayViewTopConstraint.isActive = true
            displayViewBottomConstraint.isActive = true
            displayViewAspectRatioConstraint.isActive = false
        case .top:
            displayLayer.videoGravity = .resizeAspectFill
            displayViewTopConstraint.isActive = true
            displayViewBottomConstraint.isActive = false
            displayViewAspectRatioConstraint.isActive = true
        case .bottom:
            displayLayer.videoGravity = .resizeAspectFill
            displayViewTopConstraint.isActive = false
            displayViewBottomConstraint.isActive = true
            displayViewAspectRatioConstraint.isActive = true
        }
    }
}

extension RearviewViewController {
    public enum ContentMode {
        case scaleAspectFit
        case scaleAspectFill
        case top
        case bottom
    }

    public enum SensitivityModeControlPosition: CGFloat {
        case top    = 0.15
        case center = 0.50
        case bottom = 0.85
    }
}
