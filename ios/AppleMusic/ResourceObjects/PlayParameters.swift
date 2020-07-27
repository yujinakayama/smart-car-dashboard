//
//  PlayParameters.swift
//  AppleMusic
//

import Foundation

/// An object that represents play parameters for resources.
public struct PlayParameters: Codable {
    /// The ID of the content to use for playback
    public let id: String

    /// The kind of the content to use for playback
    public let kind: String
}
