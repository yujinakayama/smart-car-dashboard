//
//  LocationInformationWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/06/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreLocation

class LocationInformationWidgetViewController: UIViewController, RoadTrackerDelegate {
    @IBOutlet weak var roadView: UIView!
    @IBOutlet weak var roadNameLabel: UILabel!
    @IBOutlet weak var canonicalRoadNameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var lowLocationAccuracyLabel: UILabel!

    let roadTracker = RoadTracker()

    var currentPlace: OpenCage.Place?

    weak var debugger: RoadTrackerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        roadTracker.delegate = self

        setLowLocationAccuracyLabelText()

        view.addInteraction(UIContextMenuInteraction(delegate: self))
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

            roadTracker.startTracking()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        roadTracker.stopTracking()
        currentPlace = nil
        super.viewDidDisappear(animated)
    }

    func roadTracker(_ roadTracker: RoadTracker, didUpdateCurrentLocation location: CLLocation) {
        DispatchQueue.main.async {
            self.lowLocationAccuracyLabel.isHidden = roadTracker.considersLocationAccurate(location)
            self.debugger?.roadTracker(roadTracker, didUpdateCurrentLocation: location)
        }
    }

    func roadTracker(_ roadTracker: RoadTracker, didUpdateCurrentPlace place: OpenCage.Place, for location: CLLocation, with reason: RoadTracker.UpdateReason) {
        var shouldAnimate = false

        if let previousPlace = currentPlace {
            shouldAnimate = RoadName(place: previousPlace) != RoadName(place: place)
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

            self.updateLabels(for: place, animated: shouldAnimate)


            self.debugger?.roadTracker(roadTracker, didUpdateCurrentPlace: place, for: location, with: reason)
        }

        currentPlace = place
    }

    func updateLabels(for place: OpenCage.Place, animated: Bool) {
        if animated {
            withAnimation {
                self.updateLabels(for: place)
            }
        } else {
            updateLabels(for: place)
        }
    }

    func updateLabels(for place: OpenCage.Place) {
        updateRoadNameLabels(for: place)
        updateAddressLabel(for: place)
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

    func updateRoadNameLabels(for place: OpenCage.Place) {
        let roadName = RoadName(place: place)

        if let popularName = roadName.popularName {
            roadNameLabel.text = popularName
            canonicalRoadNameLabel.text = roadName.canonicalRoadName
        } else if let canonicalRoadName = roadName.canonicalRoadName {
            roadNameLabel.text = canonicalRoadName
            canonicalRoadNameLabel.text = nil
        } else if let unnumberedRouteName = roadName.unnumberedRouteName {
            roadNameLabel.text = unnumberedRouteName
            canonicalRoadNameLabel.text = nil
        } else {
            roadNameLabel.text = nil
            canonicalRoadNameLabel.text = nil
        }
    }

    func updateAddressLabel(for place: OpenCage.Place) {
        addressLabel.text = currentPlace?.address.components.joined(separator: " ")
    }

    func hideLabelsWithNoContent() {
        roadNameLabel.isHidden = roadNameLabel.text == nil
        canonicalRoadNameLabel.isHidden = canonicalRoadNameLabel.text == nil
        addressLabel.isHidden = addressLabel.text == nil
    }
}

extension LocationInformationWidgetViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let actionProvider: UIContextMenuActionProvider = { (suggestedActions) in
            let action = UIAction(title: "Debug", image: UIImage(systemName: "ladybug")) { (action) in
                let debugViewContoller = LocationInformationDebugViewController()
                self.debugger = debugViewContoller

                let navigationController = UINavigationController(rootViewController: debugViewContoller)
                navigationController.modalPresentationStyle = .overCurrentContext
                self.present(navigationController, animated: true)
            }

            return UIMenu(title: "", children: [action])
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
    }
}
