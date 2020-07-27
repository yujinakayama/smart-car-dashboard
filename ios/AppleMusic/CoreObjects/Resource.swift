//
//  Resource.swift
//  HMV
//

import Foundation

public struct Resource<AttributesType: Codable, RelationshipsType: Codable>: Codable, Identifiable {
    public let id: String
    public let type: MediaType
    public let href: String
    public let attributes: AttributesType?
    public let relationships: RelationshipsType?
    // let meta: Meta
}
