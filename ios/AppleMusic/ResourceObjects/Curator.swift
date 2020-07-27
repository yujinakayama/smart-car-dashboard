//
//  Curator.swift
//  AppleMusic
//

import Foundation

public typealias Curator = Resource<CuratorAttributes, CuratorRelationships>

public struct CuratorAttributes: Codable {
    public let artwork: Artwork
    public let editorialNotes: EditorialNotes?
    public let name: String
    public let url: URL
}

public struct CuratorRelationships: Codable {
    public let playlists: Relationship<Playlist>
}
