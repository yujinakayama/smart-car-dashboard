//
//  Genre.swift
//  AppleMusic
//

import Foundation

public typealias Genre = Resource<GenreAttributes, VoidRelationship>

public struct GenreAttributes: Codable {
    public let name: String
}
