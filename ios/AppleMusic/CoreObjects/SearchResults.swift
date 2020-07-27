//
//  SearchResults.swift
//  AppleMusic
//

import Foundation

public struct SearchResults: Codable {
    enum CodingKeys: String, CodingKey {
        case albums
        case artists
        case musicVideos = "music-videos"
        case playlists
        case songs
    }

    public let albums: ResponseRoot<Album>?
    public let artists: ResponseRoot<Artist>?
    public let musicVideos: ResponseRoot<MusicVideo>?
    public let playlists: ResponseRoot<Playlist>?
    public let songs: ResponseRoot<Track>?
}

// MARK: - SearchHints

public struct SearchHints: Codable {
    public let terms: [String]
}
