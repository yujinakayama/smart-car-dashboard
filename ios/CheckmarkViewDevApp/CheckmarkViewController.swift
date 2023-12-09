//
//  ViewController.swift
//  CheckmarkViewDevApp
//
//  Created by Yuji Nakayama on 2023/12/03.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import CheckmarkView

class CheckmarkViewController: UIViewController {
    @IBOutlet weak var checkmarkView: CheckmarkView!

    override func viewDidLoad() {
        super.viewDidLoad()

//        checkmarkView.showsDebugGuides = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.checkmarkView.startAnimating()
        }
    }
}

