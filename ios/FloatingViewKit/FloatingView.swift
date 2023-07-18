//
//  FloatingView.swift
//  FloatingViewKit
//
//  Created by Yuji Nakayama on 2023/07/20.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

class FloatingView: UIView {
    init(contentView: UIView) {
        super.init(frame: .zero)
        
        addSubview(contentView)
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
