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
    public static let defaultURLSessionConfiguration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        return configuration
    }()

    lazy var baseURL = URL(string: "https://\(host)")!

    lazy var host: String = {
        let bundle = Bundle(for: GoogleServiceInfo.self)
        let googleServiceInfo = GoogleServiceInfo(path: bundle.path(forResource: "GoogleService-Info", ofType: "plist")!)
        return "asia-northeast1-\(googleServiceInfo.projectID).cloudfunctions.net"
    }()

    public let urlSessionConfiguration: URLSessionConfiguration

    lazy var urlSession = URLSession(configuration: urlSessionConfiguration)

    public init(urlSessionConfiguration: URLSessionConfiguration = DashCloudClient.defaultURLSessionConfiguration) {
        self.urlSessionConfiguration = urlSessionConfiguration
    }

    public func add(_ item: Item, toInboxOf vehicleID: String, notification: Bool = true, completionHandler: @escaping (Error?) -> Void) {
        item.encode { (result) in
            switch result {
            case .success(let attachments):
                self.add(attachments, toInboxOf: vehicleID, notification: notification, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(error)
            }
        }
    }

    private func add(_ attachments: [String: Any], toInboxOf vehicleID: String, notification: Bool, completionHandler: @escaping (Error?) -> Void) {
        let url = URL(string: "addItemToInbox", relativeTo: baseURL)!

        let payload: [String: Any] = [
            "vehicleID": vehicleID,
            "attachments": attachments,
            "notification": notification
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
        let encoder = Item.Encoder()
        encoder.add(url)
        let item = Item(encoder: encoder)

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
                do {
                    let location = try JSONDecoder().decode(Location.self, from: data)
                    completionHandler(.success(location))
                } catch {
                    completionHandler(.failure(error))
                }
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

        let task = urlSession.dataTask(with: request) { (data, response, error) in
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
