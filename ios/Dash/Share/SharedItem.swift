//
//  SharedItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import DictionaryCoding

protocol SharedItemProtocol {
    func open()
}

enum SharedItemError: Error {
    case invalidDictionaryStructure
    case unknownType
}

struct SharedItem {
    enum ItemType: String {
        case location
        case webpage
    }

    static func makeItem(dictionary: [String: Any]) throws -> SharedItemProtocol {
        guard let typeString = dictionary["type"] as? String else {
            throw SharedItemError.invalidDictionaryStructure
        }

        let decoder = DictionaryDecoder()

        switch ItemType(rawValue: typeString) {
        case .location:
            return try decoder.decode(Location.self, from: dictionary)
        case .webpage:
            return try decoder.decode(Webpage.self, from: dictionary)
        default:
            throw SharedItemError.unknownType
        }
    }
}
