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

    var currentBrand: ETCCardBrand {
        get {
            let int = Int16(pageControl.currentPage)
            return ETCCardBrand(rawValue: int)!
        }

        set {
            let page = Int(newValue.rawValue)
            pageControl.currentPage = page
            scrollToPage(page, animated: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        pageScrollView.delegate = self

        nameTextField.text = card.name

        // Not sure why but setting the scroll view's content offset immediately in viewDidLoad() doesn't work
        DispatchQueue.main.async {
            self.currentBrand = self.card.brand
        }
    }

    @IBAction func cancelButtonDidTap(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func doneButtonDidTap(_ sender: Any) {
        card.brand = currentBrand
        card.name = nameTextField.text
        try! card.managedObjectContext?.save()

        dismiss(animated: true)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(pageScrollView.contentOffset.x / pageScrollView.bounds.width)
    }

    @IBAction func cardPageControlValueDidChange() {
        scrollToPage(pageControl.currentPage, animated: true)
    }

    func scrollToPage(_ page: Int, animated: Bool) {
        let contentOffsetX = pageScrollView.bounds.width * CGFloat(page)
        pageScrollView.setContentOffset(CGPoint(x: contentOffsetX, y: 0), animated: animated)
    }
}
