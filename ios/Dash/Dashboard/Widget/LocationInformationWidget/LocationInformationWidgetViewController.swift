//
//  LocationInformationWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreLocation
import MapboxCoreNavigation

class LocationInformationWidgetViewController: UIViewController {
    @IBOutlet weak var roadView: UIView!
    @IBOutlet weak var roadNameLabel: UILabel!
    @IBOutlet weak var canonicalRoadNameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var lowLocationAccuracyLabel: UILabel!

    var roadTracker: RoadTracker {
        return RoadTracker.shared
    }

    var currentRoad: Road?

    let geocoder = CLGeocoder()

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(roadTrackerDidUpdateCurrentLocation), name: .RoadTrackerDidUpdateCurrentLocation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(roadTrackerDidUpdateCurrentRoad), name: .RoadTrackerDidUpdateCurrentRoad, object: nil)

        setLowLocationAccuracyLabelText()
    }

    func setLowLocationAccuracyLabelText() {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "mappin.slash")?.withTintColor(lowLocationAccuracyLabel.textColor, renderingMode: .alwaysTemplate)

        let attributedText = NSMutableAttributedString(attachment: imageAttachment)
        attributedText.append(NSAttributedString(string: " \(String(localized: "Low Location Accuracy"))"))

        lowLocationAccuracyLabel.attributedText = attributedText
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !roadTracker.isTracking {
            roadNameLabel.text = nil
            canonicalRoadNameLabel.text = nil
            addressLabel.text = nil
            hideLabelsWithNoContent()

            lowLocationAccuracyLabel.isHidden = true

            activityIndicatorView.startAnimating()
        }

        roadTracker.registerObserver(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        roadTracker.unregisterObserver(self)
        currentRoad = nil
        super.viewDidDisappear(animated)
    }

    deinit {
        roadTracker.unregisterObserver(self)
    }

    @objc func roadTrackerDidUpdateCurrentLocation(notification: Notification) {
        logger.debug()

        guard let location = notification.userInfo?[RoadTracker.NotificationKeys.location] as? CLLocation else {
            return
        }

        DispatchQueue.main.async {
            self.lowLocationAccuracyLabel.isHidden = self.roadTracker.considersLocationAccurate(location)
        }
    }

    @objc func roadTrackerDidUpdateCurrentRoad(notification: Notification) {
        logger.debug()

        guard let road = notification.userInfo?[RoadTracker.NotificationKeys.road] as? Road else {
            return
        }

        var shouldAnimate = false
        if let previousRoad = currentRoad {
            shouldAnimate = road != previousRoad
        } else {
            shouldAnimate = true
        }

        DispatchQueue.main.async {
            if self.activityIndicatorView.isAnimating {
                UIView.animate(withDuration: 0.2) {
                    self.activityIndicatorView.alpha = 0
                } completion: { (finished) in
                    self.activityIndicatorView.stopAnimating()
                    self.activityIndicatorView.alpha = 1
                }
            }

            self.updateLabels(for: road, animated: shouldAnimate)
        }

        currentRoad = road
    }

    func updateLabels(for road: Road, animated: Bool) {
        if animated {
            withAnimation {
                self.updateLabels(for: road)
            }
        } else {
            updateLabels(for: road)
        }
    }

    func updateLabels(for road: Road) {
        updateRoadNameLabels(for: road)
        updateAddressLabel(for: road)
        hideLabelsWithNoContent()
    }

    func withAnimation(_ changes: @escaping () -> Void) {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.roadView.layer.setAffineTransform(.init(scaleX: 1.4, y: 1.4))
            self.roadView.layer.opacity = 0
            self.addressLabel.layer.opacity = 0
        } completion: { (finished) in
            guard finished else { return }

            self.roadView.layer.setAffineTransform(.init(scaleX: 0.85, y: 0.85))

            changes()

            UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseOut) {
                self.roadView.layer.setAffineTransform(.identity)
                self.roadView.layer.opacity = 1
            }

            UIView.animate(withDuration: 1, delay: 0.4, options: .curveEaseInOut) {
                self.addressLabel.layer.opacity = 1
            }
        }
    }

    func updateRoadNameLabels(for road: Road) {
        if let popularName = road.popularName {
            roadNameLabel.text = popularName
            canonicalRoadNameLabel.text = road.canonicalRoadName
        } else if let canonicalRoadName = road.canonicalRoadName {
            roadNameLabel.text = canonicalRoadName
            canonicalRoadNameLabel.text = nil
        } else if let unnumberedRouteName = road.unnumberedRouteName {
            roadNameLabel.text = unnumberedRouteName
            canonicalRoadNameLabel.text = nil
        } else {
            roadNameLabel.text = nil
            canonicalRoadNameLabel.text = nil
        }
    }

    func updateAddressLabel(for road: Road) {
        addressLabel.text = road.address.joined(separator: " ")
    }

    func hideLabelsWithNoContent() {
        roadNameLabel.isHidden = roadNameLabel.text == nil
        canonicalRoadNameLabel.isHidden = canonicalRoadNameLabel.text == nil
        addressLabel.isHidden = addressLabel.text == nil
    }
}
