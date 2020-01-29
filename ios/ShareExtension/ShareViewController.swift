//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseCore
import FirebaseFirestore

enum ShareError: Error {
    case noURLAttachmentIsAvailable
    case unknown
}

class ShareViewController: UIViewController {
    let urlTypeIdentifier = "public.url"

    override func viewDidLoad() {
        super.viewDidLoad()

        FirebaseApp.configure()

        share()
    }

    func share() {
        guard let items = extensionContext!.inputItems as? [NSExtensionItem], let item = items.first else {
            extensionContext!.cancelRequest(withError: ShareError.noURLAttachmentIsAvailable)
            return
        }

        loadURL(from: item) { (result) in
            switch result {
            case .success(let url):
                self.createItemOnFirestore(url: url) { [weak self] (error) in
                    guard let extensionContext = self?.extensionContext else { return }

                    if let error = error {
                        extensionContext.cancelRequest(withError: error)
                    } else {
                        extensionContext.completeRequest(returningItems: nil)
                    }
                }
            case .failure(let error):
                self.extensionContext!.cancelRequest(withError: error)
            }
        }
    }

    func loadURL(from item: NSExtensionItem, completionHandler: @escaping (Result<URL, Error>) -> Void) {
        let urlAttachment = item.attachments?.first { (attachment) in attachment.hasItemConformingToTypeIdentifier(urlTypeIdentifier) }

        guard let attachment = urlAttachment else {
            completionHandler(.failure(ShareError.noURLAttachmentIsAvailable))
            return
        }

        _ = attachment.loadObject(ofClass: URL.self) { (url, error) in
            if let error = error {
                completionHandler(.failure(error))
            }

            completionHandler(.success(url!))
        }
    }

    func createItemOnFirestore(url: URL, completionHandler: @escaping (Error?) -> Void) {
        let document = [
            "url": url.absoluteString
        ]

        Firestore.firestore().collection("items").addDocument(data: document, completion: completionHandler)
    }
}
