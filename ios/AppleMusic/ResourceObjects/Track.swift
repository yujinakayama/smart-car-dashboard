//
//  Track.swift
//  HMV
//

import Foundation

public typealias Track = Resource<TrackAttributes, TrackRelationships>

public struct TrackAttributes: Codable {
    public let artistName: String
    public let artwork: Artwork
    public let composerName: String?
    public let contentRating: ContentRating?
    public let discNumber: Int?
    public let durationInMillis: Int?
    public let genreNames: [String]
    public let movementCount: Int? // Classical music only
    public let movementName: String? // Classical music only
    public let movementNumber: Int? // Classical music only
    public let name: String
    public let playParams: PlayParameters?
    public let releaseDate: String
    public let trackNumber: Int
    public let url: URL
    public let workName: String? // Classical music only
    
    public var duration: String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional

        if let duration = formatter.string(from: TimeInterval(durationInMillis!/1000)) {
            return duration
        } else {
            return nil
        }
    }
}

public struct TrackRelationships: Codable {
    public let albums: Relationship<Album>
    public let artists: Relationship<Artist>
    public let genres: Relationship<Genre>?
}
