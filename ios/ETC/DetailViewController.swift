//
//  DetailViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit

class DetailViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!

    var usage: ETCUsage? {
        didSet {
            configureView()
        }
    }

    var entranceMapItem: MKMapItem?
    var exitMapItem: MKMapItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self

        configureView()
    }

    func configureView() {
        guard usage?.entranceTollbooth != nil && usage?.exitTollbooth != nil else { return }

        fetchEntranceAndExitLocation { [weak self] (entrance, exit) in
            guard let self = self, entrance != nil && exit != nil else { return }
            self.showRoute(source: entrance!, destination: exit!)
        }
    }

    private func fetchEntranceAndExitLocation(completionHandler: @escaping (MKMapItem?, MKMapItem?) -> Void) {
        guard let entrance = usage?.entranceTollbooth, let exit = usage?.exitTollbooth else {
            completionHandler(nil, nil)
            return
        }

        let group = DispatchGroup()

        group.enter()
        mapItem(for: entrance) { [weak self] (mapItem) in
            self?.entranceMapItem = mapItem
            group.leave()
        }

        group.enter()
        mapItem(for: exit) { [weak self] (mapItem) in
            self?.exitMapItem = mapItem
            group.leave()
        }

        group.notify(queue: .main, work: DispatchWorkItem() { [weak self] in
            guard let self = self else { return }
            completionHandler(self.entranceMapItem, self.exitMapItem)
        })
    }

    private func showRoute(source: MKMapItem, destination: MKMapItem) {
        routeBetween(source: entranceMapItem!, destination: exitMapItem!) { [weak self] (route) in
            guard let self = self else { return }

            [source, destination].forEach { (mapItem) in
                let annotation = MKPointAnnotation()
                annotation.title = mapItem.name
                annotation.coordinate = mapItem.placemark.coordinate
                self.mapView.addAnnotation(annotation)
            }

            guard route != nil else { return }

            self.mapView.addOverlay(route!.polyline)
            self.mapView.setVisibleMapRect(route!.polyline.boundingMapRect, edgePadding: self.routeRectPadding, animated: false)
        }
    }

    private func mapItem(for tollbooth: Tollbooth, completionHandler: @escaping (MKMapItem?) -> Void) {
        // TODO: This tends to pick wrong location
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(tollbooth.name)IC"

        MKLocalSearch(request: request).start { (response, error) in
            completionHandler(response?.mapItems.first)
        }
    }

    private func routeBetween(source: MKMapItem, destination: MKMapItem, completionHandler: @escaping (MKRoute?) -> Void) {
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile

        MKDirections(request: request).calculate { (response, error) in
            completionHandler(response?.routes.first)
        }
    }

    private var routeRectPadding: UIEdgeInsets {
        let horizontalPadding = mapView.bounds.width * 0.15
        let verticalPadding = mapView.bounds.height * 0.15

        return UIEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.lineWidth = 10
        renderer.strokeColor = UIColor(red: 73/255, green: 163/255, blue: 249/255, alpha: 1)
        return renderer
    }
}

