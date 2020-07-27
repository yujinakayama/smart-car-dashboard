//
//  Include.swift
//  HMV
//

import Foundation

/// Relationships to include with a lookup request.
public enum Include: String {
    case albums
    case artists
    case genres
    case tracks
}
