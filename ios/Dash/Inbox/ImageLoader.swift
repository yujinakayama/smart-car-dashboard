//
//  ImageLoader.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/07/15.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import CacheKit

enum ImageLoaderError: Error {
    case nonImageData
}

actor ImageLoader {
    typealias LoadingTask = (task: Task<UIImage, Error>, url: URL)

    // 200MB, 90 days
    static let cache = Cache(name: "ImageLoader", byteLimit: 100 * 1024 * 1024, ageLimit: 60 * 60 * 24 * 90)

    private var currentLoadingTask: LoadingTask?
    
    func loadImage(from url: URL) async throws -> UIImage {
        if let currentLoadingTask = currentLoadingTask {
            if currentLoadingTask.url == url {
                let image = try await currentLoadingTask.task.value
                self.currentLoadingTask = nil
                return image
            } else {
                currentLoadingTask.task.cancel()
                self.currentLoadingTask = nil
            }
        }

        let cacheKey = Cache.digestString(of: url.absoluteString)

        if let image = await Self.cache.object(forKey: cacheKey) as? UIImage {
            return image
        }

        let task = Task {
            let (imageData, _) = try await URLSession.shared.data(from: url)

            try Task.checkCancellation()

            guard let image = UIImage(data: imageData) else {
                throw ImageLoaderError.nonImageData
            }

            await Self.cache.setObject(image, forKey: cacheKey)

            return image
        }

        currentLoadingTask = (task, url)

        let image = try await task.value
        currentLoadingTask = nil
        return image
    }
}
