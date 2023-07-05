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

    var isVisible = false

    var roadTracker: RoadTracker {
        return RoadTracker.shared
    }

    var lastRoad: Road?

    let geocoder = CLGeocoder()

    var showsLocationAccuracyWarning = true

    // horizontalAccuracy returns fixed value 65.0 in reinforced concrete buildings, which is unstable
    static let unreliableLocationAccuracy: CLLocationAccuracy = 65

    override func viewDidLoad() {
        super.viewDidLoad()

        resetViews()

        NotificationCenter.default.addObserver(self, selector: #selector(roadTrackerDidUpdateCurrentLocation), name: .RoadTrackerDidUpdateCurrentLocation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(roadTrackerDidUpdateCurrentRoad), name: .RoadTrackerDidUpdateCurrentRoad, object: nil)

        setLowLocationAccuracyLabelText()
    }

    func scaleLabelFontSizes(scale: CGFloat) {
        for label in [roadNameLabel, canonicalRoadNameLabel, addressLabel, lowLocationAccuracyLabel] as! [UILabel] {
            let font = label.font!
            label.font = font.withSize(font.pointSize * scale)
        }
    }

    func setLowLocationAccuracyLabelText() {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(systemName: "mappin.slash")?.withTintColor(lowLocationAccuracyLabel.textColor, renderingMode: .alwaysTemplate)

        let attributedText = NSMutableAttributedString(attachment: imageAttachment)
        attributedText.append(NSAttributedString(string: " \(String(localized: "Low Location Accuracy"))"))

        lowLocationAccuracyLabel.attributedText = attributedText
    }

    // viewWillAppear is also called when coming back to the page without completely switch to another page
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        isVisible = true

        if let road = roadTracker.currentRoad, let location = roadTracker.currentLocation {
            update(for: road)
            updateLowLocationAccuracyLabel(location: location)
        } else {
            activityIndicatorView.startAnimating()
        }

        roadTracker.registerObserver(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        roadTracker.unregisterObserver(self)
        lastRoad = nil
        resetViews()
    }

    deinit {
        roadTracker.unregisterObserver(self)
    }

    @objc func roadTrackerDidUpdateCurrentLocation(notification: Notification) {
        guard isVisible else { return }

        logger.debug()

        guard let location = notification.userInfo?[RoadTracker.NotificationKeys.location] as? CLLocation else {
            return
        }

        updateLowLocationAccuracyLabel(location: location)
    }

    @objc func roadTrackerDidUpdateCurrentRoad(notification: Notification) {
        guard isVisible else { return }

        logger.debug()

        guard let road = notification.userInfo?[RoadTracker.NotificationKeys.road] as? Road else {
            return
        }

        update(for: road)
    }

    func update(for road: Road) {
        var shouldAnimate = false
        if let lastRoad = lastRoad {
            shouldAnimate = road != lastRoad
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

        lastRoad = road
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
            self.roadView.layer.setAffineTransform(.init(scaleX: 1.2, y: 1.2))
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
        addressLabel.text = road.address.components.joined(separator: " ")
    }

    func hideLabelsWithNoContent() {
        roadNameLabel.isHidden = roadNameLabel.text == nil
        canonicalRoadNameLabel.isHidden = canonicalRoadNameLabel.text == nil
        addressLabel.isHidden = addressLabel.text == nil
    }

    func resetViews() {
        roadNameLabel.text = nil
        canonicalRoadNameLabel.text = nil
        addressLabel.text = nil
        hideLabelsWithNoContent()
        lowLocationAccuracyLabel.isHidden = true
        activityIndicatorView.stopAnimating()
    }

    func updateLowLocationAccuracyLabel(location: CLLocation) {
        guard showsLocationAccuracyWarning else { return }

        DispatchQueue.main.async {
            self.lowLocationAccuracyLabel.isHidden = self.considersLocationAccurate(location)
        }
    }

    func considersLocationAccurate(_ location: CLLocation) -> Bool {
        return location.horizontalAccuracy < Self.unreliableLocationAccuracy
    }
}
