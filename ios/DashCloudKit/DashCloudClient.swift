//
//  DashCloudClient.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2021/06/10.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation

public class DashCloudClient {
    lazy var baseURL = URL(string: "https://\(host)")!

    lazy var host: String = {
        let bundle = Bundle(for: GoogleServiceInfo.self)
        let googleServiceInfo = GoogleServiceInfo(path: bundle.path(forResource: "GoogleService-Info", ofType: "plist")!)
        return "asia-northeast1-\(googleServiceInfo.projectID).cloudfunctions.net"
    }()

    public init() {
    }

    public func share(_ item: Item, with vehicleID: String, completionHandler: @escaping (Error?) -> Void) {
        item.encode { (result) in
            switch result {
            case .success(let attachments):
                self.share(attachments, with: vehicleID, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(error)
            }
        }
    }

    private func share(_ attachments: [String: Any], with vehicleID: String, completionHandler: @escaping (Error?) -> Void) {
        let url = URL(string: "share", relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "vehicleID": vehicleID,
            "attachments": attachments
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completionHandler(error)
        }

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completionHandler(error)
                    return
                }

                if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                    completionHandler(DashCloudClientError.serverError)
                    return
                }

                completionHandler(nil)
            }
        }

        task.resume()
    }
}

enum DashCloudClientError: Error {
    case serverError
}
