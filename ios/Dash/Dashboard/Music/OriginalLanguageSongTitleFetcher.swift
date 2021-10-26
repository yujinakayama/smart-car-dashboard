//
//  OriginalSongTitleFetcher.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import MusicKit

class OriginalLanguageSongTitleFetcher {
    enum LanguageTag: String {
        case ja = "ja"
        case enUS = "en-US"
    }

    static let cache = Cache(name: "OriginalLanguageSongTitleFetcher", ageLimit: 60 * 60 * 24 * 30 * 12) // 12 months

    func hasCachedOriginalLanguageSong(id: String) -> Bool {
        return OriginalLanguageSongTitleFetcher.cache.containsObject(forKey: id)
    }

    func cachedOriginalLanguageSong(id: String) -> OriginalLanguageSong? {
        return OriginalLanguageSongTitleFetcher.cache.object(forKey: id) as? OriginalLanguageSong
    }

    func fetchOriginalLanguageSong(id: String) async throws -> OriginalLanguageSong? {
        return try await fetchOriginalLanguageSong(id: id, requestLanguage: .enUS)
    }

    private func fetchOriginalLanguageSong(id: String, requestLanguage: LanguageTag) async throws -> OriginalLanguageSong? {
        guard let song = try await fetchSong(id: id, in: requestLanguage) else { return nil }

        if let originalLanguage = originalLanguage(of: song), originalLanguage != requestLanguage {
            return try await fetchOriginalLanguageSong(id: id, requestLanguage: originalLanguage)
        } else {
            let song = OriginalLanguageSong(title: song.title, artist: song.artistName, isrc: song.isrc)
            cache(song: song, for: id)
            return song
        }
    }

    private func fetchSong(id: String, in language: LanguageTag) async throws -> Song? {
        let storefront = try await MusicDataRequest.currentCountryCode
        var urlComponents = URLComponents(string: "https://api.music.apple.com/v1/catalog/\(storefront)/songs/\(id)")!
        urlComponents.queryItems = [URLQueryItem(name: "l", value: language.rawValue)]

        let request = MusicDataRequest(urlRequest: URLRequest(url: urlComponents.url!))
        let response = try await request.response()

        let songResponse = try JSONDecoder().decode(SongResponse.self, from: response.data)
        return songResponse.data.first
    }

    private func cache(song: OriginalLanguageSong?, for id: String) {
        OriginalLanguageSongTitleFetcher.cache.setObjectAsync(song, forKey: id)
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

extension OriginalLanguageSongTitleFetcher {
    struct SongResponse: Decodable {
        let data: [Song]
    }
}

class OriginalLanguageSong: NSObject, NSCoding {
    enum CodingKey: String {
        case title
        case artist
        case isrc
    }

    let title: String
    let artist: String
    let isrc: String?

    init(title: String, artist: String, isrc: String?) {
        self.title = title
        self.artist = artist
        self.isrc = isrc
    }

    required init?(coder: NSCoder) {
        guard let title = coder.decodeObject(forKey: CodingKey.title.rawValue) as? String else { return nil }
        self.title = title

        guard let artist = coder.decodeObject(forKey: CodingKey.artist.rawValue) as? String else { return nil }
        self.artist = artist

        guard let isrc = coder.decodeObject(forKey: CodingKey.isrc.rawValue) as? String else { return nil }
        self.isrc = isrc
    }

    func encode(with coder: NSCoder) {
        coder.encode(title, forKey: CodingKey.title.rawValue)
        coder.encode(artist, forKey: CodingKey.artist.rawValue)
        coder.encode(isrc, forKey: CodingKey.isrc.rawValue)
    }
}
