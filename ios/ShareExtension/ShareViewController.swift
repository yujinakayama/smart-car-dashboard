//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MapKit
import SVProgressHUD

enum ShareError: Error {
    case serverError
    case unknown
}

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        SVProgressHUD.setViewForExtension(view)
        SVProgressHUD.setMinimumSize(CGSize(width: 120, height: 120))
        SVProgressHUD.setHapticsEnabled(true)

        share()
    }

    func share() {
        SVProgressHUD.show(withStatus: "Sending")

        let items = extensionContext!.inputItems as! [NSExtensionItem]
        let item = items.first!

        var inputItem: InputItem!

        do {
            inputItem = try InputItem(item: item)
        } catch {
            cancelRequest(withError: error)
            return
        }

        inputItem.encode { (dictionary) in
            self.send(dictionary) { (error) in
                if let error = error {
                    self.cancelRequest(withError: error)
                } else {
                    self.completeRequest()
                }
            }
        }
    }

    func completeRequest() {
        SVProgressHUD.showSuccess(withStatus: "Sent")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.extensionContext!.completeRequest(returningItems: nil)
        }
    }

    func cancelRequest(withError error: Error) {
        SVProgressHUD.showError(withStatus: "Failed")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.extensionContext!.cancelRequest(withError: error)
        }
    }

    func send(_ document: [String: Any], completionHandler: @escaping (Error?) -> Void) {
        let googleServiceInfo = GoogleServiceInfo(path: Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")!)
        let endPointURLString = "https://asia-northeast1-\(googleServiceInfo.projectID).cloudfunctions.net/share"

        var request = URLRequest(url: URL(string: endPointURLString)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: document)
        } catch {
            completionHandler(error)
        }

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(error)
                return
            }

            if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                completionHandler(ShareError.serverError)
                return
            }

            completionHandler(nil)
        }

        task.resume()
    }
}
