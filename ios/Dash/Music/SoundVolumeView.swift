//
//  SoundVolumeView.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/06/29.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import MediaPlayer

@IBDesignable class VolumeView: UIStackView {
//    var musicPlayer: MPMusicPlayerController! {
//        didSet {
//            addNotificationObserver()
//            updateSlider()
//        }
//    }
//
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    override func prepareForInterfaceBuilder() {
        setUp()
    }

    func setUp() {
        axis = .horizontal
        alignment = .center
        distribution = .fill

        let volumeView = MPVolumeView(frame: bounds)
        addArrangedSubview(volumeView)
    }
}
