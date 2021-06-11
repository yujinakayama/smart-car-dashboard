//
//  ActionViewController.swift
//  ParkingSearchActionExtension
//
//  Created by Yuji Nakayama on 2021/05/18.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit
import DashCloudKit

class ActionViewController: UIViewController {
    var extensionItem: NSExtensionItem {
        let extensionItems = self.extensionContext!.inputItems as! [NSExtensionItem]
        return extensionItems.first!
    }

    lazy var mapItemFetcher = MapItemFetcher(extensionItem: extensionItem)

    override func viewDidLoad() {
        super.viewDidLoad()

        mapItemFetcher.fetchMapItem { (result) in
            switch result {
            case .success(let mapItem):
                self.openInDash(mapItem: mapItem)
            case .failure(let error):
                self.extensionContext!.cancelRequest(withError: error)
            }
        }
    }

    func openInDash(mapItem: MKMapItem) {
        let urlItem = ParkingSearchURLItem(mapItem: mapItem)
        open(urlItem.url)
        self.extensionContext!.completeRequest(returningItems: nil)
    }

    func open(_ url: URL) {
        guard let application = sharedApplication else { return }
        application.perform(sel_registerName("openURL:"), with: url)
    }

    // We cannot use UIApplication.shared.open(_:options:completionHandler:) in app extensions
    // https://stackoverflow.com/a/44499289/784241
    var sharedApplication: UIApplication? {
        var responder: UIResponder? = self

        while responder != nil {
           if let application = responder as? UIApplication {
               return application
           }

            responder = responder?.next
       }

        return nil
    }
}
