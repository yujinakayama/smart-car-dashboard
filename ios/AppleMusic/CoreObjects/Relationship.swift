//
//  Relationship.swift
//  HMV
//

import Foundation

public struct Relationship<T: Codable>: Codable {
    public let data: [T]?
    public let href: String
    public let next: String?
    // let meta: Meta
}

public struct VoidRelationship: Codable { }
