//
//  GoogleServieInfo.swift
//  ShareExtension
//
//  Created by Yuji Nakayama on 2020/01/30.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

class GoogleServiceInfo {
    let path: String

    var projectID: String {
        return dictionary["PROJECT_ID"] as! String
    }

    private lazy var dictionary: [String: Any] = {
        let data = FileManager.default.contents(atPath: path)!
        var format = PropertyListSerialization.PropertyListFormat.xml
        return try! PropertyListSerialization.propertyList(from: data, options: [], format: &format) as! [String: Any]
    }()

    init(path: String) {
        self.path = path
    }
}
