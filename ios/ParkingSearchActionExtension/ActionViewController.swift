//
//  ActionViewController.swift
//  ParkingSearchActionExtension
//
//  Created by Yuji Nakayama on 2021/05/18.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MobileCoreServices
import MapKit
import ParkingSearchKit

class ActionViewController: ParkingSearchViewController {
    var extensionItem: NSExtensionItem {
        let extensionItems = self.extensionContext!.inputItems as! [NSExtensionItem]
        return extensionItems.first!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

        loadMapItem { (result) in
            switch result {
            case .success(let mapItem):
                self.destination = mapItem
            case .failure(let error):
                self.extensionContext!.cancelRequest(withError: error)
            }
        }
    }

    func loadMapItem(completion: @escaping (Result<MKMapItem, Error>) -> Void) {
        guard let attachments = extensionItem.attachments else { return }

        for attachment in attachments {
            guard let typeIdentifier = attachment.registeredTypeIdentifiers.first,
                  typeIdentifier == "com.apple.mapkit.map-item"
            else { continue }

            _ = attachment.loadObject(ofClass: MKMapItem.self) { (mapItem, error) in
                DispatchQueue.main.async {
                    if let mapItem = mapItem as? MKMapItem {
                        completion(.success(mapItem))
                    }

                    if let error = error {
                        completion(.failure(error))
                    }
                }
            }

            break
        }
    }

    @IBAction func done() {
        extensionContext!.completeRequest(returningItems: nil)
    }
}
