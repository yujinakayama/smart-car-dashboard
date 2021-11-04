//
//  OriginalSongTitleFetcher.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MusicKit

class SongDataRequest {
    enum LanguageTag: String {
        case ja = "ja"
        case enUS = "en-US"
    }

    private static let cache = Cache(name: "SongDataRequest", ageLimit: 60 * 60 * 24 * 30 * 12) // 12 months

    static func hasCachedSong(id: String) -> Bool {
        return SongDataRequest.cache.containsObject(forKey: id)
    }

    static func cachedSong(id: String) -> Song? {
        guard let data = SongDataRequest.cache.object(forKey: id) as? Data else { return nil }
        return try? JSONDecoder().decode(Song.self, from: data)
    }

    let id: String

    init(id: String) {
        self.id = id
    }

    func perform() async throws -> Song? {
        let initialRequestLanguage = LanguageTag.enUS

        var song: Song?

        do {
            song = try await fetchSong(in: initialRequestLanguage)
        } catch let error as MusicDataRequest.Error where error.status == 404 {
            try cache(song: nil, for: id)
            return nil
        }

        guard let song = song else { return nil }

        var songInOriginalLanguage: Song!

        if let originalLanguage = originalLanguage(of: song), originalLanguage != initialRequestLanguage {
            songInOriginalLanguage = try await fetchSong(in: originalLanguage)
        } else {
            songInOriginalLanguage = song
        }

        try cache(song: songInOriginalLanguage, for: id)

        return songInOriginalLanguage
    }

    private func fetchSong(in language: LanguageTag) async throws -> Song? {
        let storefront = try await MusicDataRequest.currentCountryCode
        var urlComponents = URLComponents(string: "https://api.music.apple.com/v1/catalog/\(storefront)/songs/\(id)")!
        urlComponents.queryItems = [
            URLQueryItem(name: "l", value: language.rawValue),
            URLQueryItem(name: "extend", value: "artistUrl")
        ]

        let request = MusicDataRequest(urlRequest: URLRequest(url: urlComponents.url!))
        let response = try await request.response()

        let songResponse = try JSONDecoder().decode(SongResponse.self, from: response.data)
        return songResponse.data.first
    }

    private func cache(song: Song?, for id: String) throws {
        let data = try JSONEncoder().encode(song)
        SongDataRequest.cache.setObjectAsync(data as NSData, forKey: id)
    }

    private func originalLanguage(of song: Song) -> LanguageTag? {
        guard let isrc = song.isrc else { return nil }

        let countryCode = isrc.prefix(2)

        switch countryCode {
        case "JP":
            return .ja
        default:
            return .enUS
        }
    }
}

extension SongDataRequest {
    struct SongResponse: Decodable {
        let data: [Song]
    }
}
