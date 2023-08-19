//
//  DoorLock.swift
//  NotificationServiceExtension
//
//  Created by Yuji Nakayama on 2023/08/19.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import Foundation

class DoorLock {
    // esp32-wifi-accessory
    // https://github.com/espressif/esp-homekit-sdk/blob/3e6955a/components/homekit/esp_hap_core/src/esp_hap_mdns.c#L71
    let host = "MyHost.local"
    let port = 8888
    let timeoutInterval: TimeInterval = 10

    func lock() async throws {
        let url = URL(string: "http://\(host):\(port)/doors/lock")!

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeoutInterval
        )
        request.httpMethod = "POST"
        request.allowsCellularAccess = false

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if !(200..<300).contains(httpResponse.statusCode) {
                throw DoorLockError.unsuccessfulHTTPResponseStatus(code: httpResponse.statusCode)
            }
        } else {
            throw DoorLockError.unknown
        }
    }
}

enum DoorLockError: Error {
    case unknown
    case unsuccessfulHTTPResponseStatus(code: Int)
}
