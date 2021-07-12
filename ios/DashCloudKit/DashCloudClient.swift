//
//  DashCloudClient.swift
//  DashCloudKit
//
//  Created by Yuji Nakayama on 2021/06/10.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import CoreLocation

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

        let payload: [String: Any] = [
            "vehicleID": vehicleID,
            "attachments": attachments
        ]

        post(url: url, payload: payload) { (result) in
            switch result {
            case .success(_):
                completionHandler(nil)
            case .failure(let error):
                completionHandler(error)
            }
        }
    }

    public func geocodeGoogleMapsLocation(_ url: URL, completionHandler: @escaping (Result<Location, Error>) -> Void) {
        let item = Item(url: url)

        item.encode { (result) in
            switch result {
            case .success(let attachments):
                self.geocodeGoogleMapsLocation(attachments, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    private func geocodeGoogleMapsLocation(_ attachments: [String: Any], completionHandler: @escaping (Result<Location, Error>) -> Void) {
        let url = URL(string: "geocode", relativeTo: baseURL)!

        let payload: [String: Any] = [
            "attachments": attachments
        ]

        post(url: url, payload: payload) { (result) in
            switch result {
            case .success(let data):
                var location: Location!

                do {
                    location = try JSONDecoder().decode(Location.self, from: data)
                } catch {
                    completionHandler(.failure(error))
                    return
                }

                completionHandler(.success(location))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    private func post(url: URL, payload: [String: Any], completionHandler: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completionHandler(.failure(error))
        }

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completionHandler(.failure(error))
                    return
                }

                if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                    completionHandler(.failure(DashCloudClientError.serverError))
                    return
                }

                completionHandler(.success(data ?? Data()))
            }
        }

        task.resume()
    }
}

enum DashCloudClientError: Error {
    case serverError
}
