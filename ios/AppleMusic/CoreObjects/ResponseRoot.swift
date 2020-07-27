//
//  ResponseRoot.swift
//  HMV
//

import Foundation

public struct ResponseRoot<T: Codable>: Codable {
    public let data: [T]?
    public let results: T?
    public let errors: [AppleMusicAPIError]?
    // let meta: Meta?
    public let next: String?
    public let href: String?
}
