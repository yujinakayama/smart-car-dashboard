//
//  UIButtonExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2021/05/05.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

extension UIButton {
    func setBackgroundColor(_ color: UIColor?, for state: UIControl.State) {
        let image = makeImage(from: color)
        setBackgroundImage(image, for: state)
    }
}

fileprivate func makeImage(from color: UIColor?) -> UIImage? {
    guard let color = color else { return nil }

    let rect = CGRect(x: 0, y: 0, width: 1, height: 1)

    UIGraphicsBeginImageContext(rect.size)
    let context = UIGraphicsGetCurrentContext()!
    context.setFillColor(color.cgColor)
    context.fill(rect)
    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()

    return image
}
