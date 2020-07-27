//
//  MediaType.swift
//  AppleMusic
//

import Foundation

public enum MediaType: String, Codable {
    case albums
    case songs
    case artists
    case playlists
    case musicVideos = "music-videos"
    case curators
    case appleCurators = "apple-curators"
}
