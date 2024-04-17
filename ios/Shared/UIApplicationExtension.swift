//
//  UIApplicationExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2022/01/14.
//  Copyright © 2022 Yuji Nakayama. All rights reserved.
//

import Foundation
import UIKit

extension UIApplication {
    @MainActor
    var foregroundWindowScene: UIWindowScene? {
        return UIApplication.shared.connectedScenes.first { (scene) in
            (scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive) && scene is UIWindowScene
        } as? UIWindowScene
    }
}
