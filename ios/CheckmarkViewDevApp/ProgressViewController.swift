//
//  ViewController.swift
//  CheckmarkViewDevApp
//
//  Created by Yuji Nakayama on 2023/12/03.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import CheckmarkView

class ProgressViewController: UIViewController {
    @IBOutlet weak var progressView: ProgressView!
    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.layer.setAffineTransform(.init(rotationAngle: 0.05))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        progressView.startAnimating()
    }
}

