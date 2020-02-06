//
//  ETCCardEditViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCCardEditViewController: UIViewController, UIScrollViewDelegate {
    var card: ETCCardManagedObject!

    @IBOutlet weak var pageScrollView: UIScrollView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var nameTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        pageScrollView.delegate = self

        nameTextField.text = card.name
    }

    @IBAction func cancelButtonDidTap(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func doneButtonDidTap(_ sender: Any) {
        // TODO
        dismiss(animated: true)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(pageScrollView.contentOffset.x / pageScrollView.bounds.width)
    }

    @IBAction func cardPageControlValueDidChange() {
        let contentOffsetX = pageScrollView.bounds.width * CGFloat(pageControl.currentPage)
        pageScrollView.setContentOffset(CGPoint(x: contentOffsetX, y: 0), animated: true)
    }
}
