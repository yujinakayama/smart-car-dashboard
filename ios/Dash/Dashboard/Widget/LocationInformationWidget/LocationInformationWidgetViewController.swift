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
    enum LocationMode: Int {
        case address
        case landmarkRelativeLocation
    }

    @IBOutlet weak var roadView: UIView!
    @IBOutlet weak var roadNameLabel: UILabel!
    @IBOutlet weak var canonicalRoadNameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var relativeLocationView: UIView!
    @IBOutlet weak var relativeLocationLabel: UILabel!
    @IBOutlet weak var relativeLocationAngleImageView: UIImageView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var lowLocationAccuracyLabel: UILabel!

    var isVisible = false

    var locationMode: LocationMode {
        get {
            return Defaults.shared.locationInformationWidgetMode
        }
        
        set {
            Defaults.shared.locationInformationWidgetMode = newValue
        }
    }
    
    lazy var tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewDidRecognizeTap))
    
    var roadTracker: RoadTracker {
        return RoadTracker.shared
    }

    var lastRoad: Road?

    var landmarkTracker: LandmarkTracker {
        return LandmarkTracker.shared
    }
    
    var policyOfMostInterestingLandmarkDetection: LandmarkTracker.Policy {
        return Defaults.shared.policyOfMostInterestingLandmarkDetection
    }

    lazy var distanceFormatter = NatualDistanceFormatter()
    
    var showsLocationAccuracyWarning = true

    // horizontalAccuracy returns fixed value 65.0 in reinforced concrete buildings, which is unstable
    static let unreliableLocationAccuracy: CLLocationAccuracy = 65

    lazy var distanceTextAttributes = AttributeContainer([
        .font: UIFont.monospacedDigitSystemFont(ofSize: relativeLocationLabel.font.pointSize, weight: .regular)
    ])

    var activeLocationView: UIView {
        switch locationMode {
        case .address:
            return addressLabel
        case .landmarkRelativeLocation:
            return relativeLocationView
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        resetViews()

        NotificationCenter.default.addObserver(self, selector: #selector(roadTrackerDidUpdateCurrentLocation), name: .RoadTrackerDidUpdateCurrentLocation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(roadTrackerDidUpdateCurrentRoad), name: .RoadTrackerDidUpdateCurrentRoad, object: nil)

        view.addGestureRecognizer(tapGestureRecognizer)
        
        setLowLocationAccuracyLabelText()
    }

    func scaleLabelFontSizes(scale: CGFloat) {
        let labels: [UILabel] = [roadNameLabel, canonicalRoadNameLabel, addressLabel, relativeLocationLabel, lowLocationAccuracyLabel]

        for label in labels {
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

    @objc func viewDidRecognizeTap() {
        guard lastRoad != nil else { return }

        Task {
            await toggleLocationView()
        }
    }
    
    func toggleLocationView() async {
        switch locationMode {
        case .address:
            locationMode = .landmarkRelativeLocation

            addressLabel.text = nil
            addressLabel.isHidden = true
            // Show relativeLocationView right now to avoid ugly layout shake
            relativeLocationView.isHidden = false
            relativeLocationLabel.text = " "
            
            if let currentLocation = roadTracker.currentLocation,
               let relativeLocation = await landmarkTracker.relativeLocationToMostInterestingLandmark(around: currentLocation, with: policyOfMostInterestingLandmarkDetection)
            {
                updateRelativeLocationView(for: relativeLocation)
            }
        case .landmarkRelativeLocation:
            locationMode = .address

            relativeLocationView.isHidden = true
            relativeLocationLabel.text = " "
            relativeLocationAngleImageView.transform = .identity
            relativeLocationAngleImageView.isHidden = true

            if let currentRoad = roadTracker.currentRoad {
                updateAddressLabel(for: currentRoad)
            }
        }
    }
    
    @objc func roadTrackerDidUpdateCurrentLocation(notification: Notification) {
        guard isVisible else { return }

        logger.debug()

        guard let location = notification.userInfo?[RoadTracker.NotificationKeys.location] as? CLLocation else {
            return
        }

        updateLowLocationAccuracyLabel(location: location)

        if locationMode == .landmarkRelativeLocation {
            Task {
                if let relativeLocation = await landmarkTracker.relativeLocationToMostInterestingLandmark(around: location, with: policyOfMostInterestingLandmarkDetection) {
                    updateRelativeLocationView(for: relativeLocation)
                }
            }
        }
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
            withRoadChangeAnimation {
                self.updateViews(for: road)
            }
        } else {
            updateViews(for: road)
        }
    }

    func updateViews(for road: Road) {
        updateRoadNameLabels(for: road)
        
        if locationMode == .address {
            updateAddressLabel(for: road)
        }
    }

    func withRoadChangeAnimation(_ changes: @escaping () -> Void) {
        let initialShow = roadNameLabel.isHidden
        let activeLocationView = self.activeLocationView

        if initialShow {
            activeLocationView.layer.opacity = 0
            activeLocationView.isHidden = false
        }

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.roadView.layer.setAffineTransform(.init(scaleX: 1.2, y: 1.2))
            self.roadView.layer.opacity = 0
        } completion: { (finished) in
            guard finished else { return }

            self.roadView.layer.setAffineTransform(.init(scaleX: 0.85, y: 0.85))

            changes()

            UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseOut) {
                self.roadView.layer.setAffineTransform(.identity)
                self.roadView.layer.opacity = 1
            }

            if initialShow {
                UIView.animate(withDuration: 1, delay: 0.4, options: .curveEaseInOut) {
                    activeLocationView.layer.opacity = 1
                }
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

        roadNameLabel.isHidden = roadNameLabel.text == nil
        canonicalRoadNameLabel.isHidden = canonicalRoadNameLabel.text == nil
    }

    func updateAddressLabel(for road: Road) {
        addressLabel.text = road.address.components.joined(separator: " ")
        addressLabel.isHidden = addressLabel.text == nil
    }
    
    func updateRelativeLocationView(for relativeLocation: LandmarkRelativeLocation) {
        guard let landmarkName = relativeLocation.landmark.name else { return }

        let distance = distanceFormatter.string(from: relativeLocation.distance)
        var attributedString = AttributedString("\(landmarkName) まで ")
        attributedString.append(AttributedString(distance, attributes: distanceTextAttributes))
        relativeLocationLabel.attributedText = NSAttributedString(attributedString)

        if relativeLocationAngleImageView.isHidden {
            self.relativeLocationAngleImageView.transform = CGAffineTransform(rotationAngle: relativeLocation.angle.toRadians())
            relativeLocationAngleImageView.isHidden = false
        } else {
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
                self.relativeLocationAngleImageView.transform = CGAffineTransform(rotationAngle: relativeLocation.angle.toRadians())
            }
        }

        // If road name is not yet shown, wait for it
        if !roadNameLabel.isHidden {
            relativeLocationView.isHidden = false
        }
    }

    func resetViews() {
        roadNameLabel.text = nil
        roadNameLabel.isHidden = true
        
        canonicalRoadNameLabel.text = nil
        canonicalRoadNameLabel.isHidden = true

        addressLabel.text = nil
        addressLabel.isHidden = true

        // Set whitespace to keep its height since the text may have not been set even after roadNameLabel.text is set
        relativeLocationLabel.text = " "
        relativeLocationAngleImageView.transform = .identity
        relativeLocationAngleImageView.isHidden = true
        relativeLocationView.isHidden = true

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

class NatualDistanceFormatter {
    lazy var meterFormatter = createFormatter(fractionDigits: 0)
    lazy var kilometerFormatter = createFormatter(fractionDigits: 1)

    private func createFormatter(fractionDigits: Int) -> MeasurementFormatter {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = [.naturalScale, .providedUnit]
        formatter.unitStyle = .medium
        formatter.numberFormatter.minimumFractionDigits = fractionDigits
        formatter.numberFormatter.maximumFractionDigits = fractionDigits
        return formatter
    }
    
    func string(from distance: CLLocationDistance) -> String {
        let measurement = Measurement(value: roundDistance(distance), unit: UnitLength.meters)

        if measurement.value >= 1000 {
            return kilometerFormatter.string(from: measurement)
        } else {
            return meterFormatter.string(from: measurement)
        }
    }

    private func roundDistance(_ distance: CLLocationDistance) -> CLLocationDistance {
        if distance >= 1000 {
            return ceil(distance / 100) * 100
        } else if distance >= 100 {
            return ceil(distance / 50) * 50
        } else {
            return ceil(distance / 10) * 10
        }
    }
}
