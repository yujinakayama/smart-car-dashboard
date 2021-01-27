//
//  ETCCardEditViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCCardEditViewController: UITableViewController {
    var card: ETCCardManagedObject!

    @IBOutlet weak var pageScrollView: UIScrollView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var nameTextField: UITextField!
    let mainCardSwitch = UISwitch()

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

        mainCardSwitch.isOn = (card.uuid == Defaults.shared.mainETCCardUUID)

        // Not sure why but setting the scroll view's content offset immediately in viewDidLoad() doesn't work
        DispatchQueue.main.async {
            self.currentBrand = self.card.brand
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        if cell.reuseIdentifier == "MainCardSwitchCell" && cell.accessoryView == nil {
            cell.accessoryView = mainCardSwitch
        }

        return cell
    }

    @IBAction func cancelButtonDidTap(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func doneButtonDidTap(_ sender: Any) {
        card.brand = currentBrand
        card.name = nameTextField.text
        try! card.managedObjectContext?.save()

        if mainCardSwitch.isOn {
            Defaults.shared.mainETCCardUUID = card.uuid
        }

        dismiss(animated: true)
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            pageControl.currentPage = Int(pageScrollView.contentOffset.x / pageScrollView.bounds.width)
        } else {
            super.scrollViewDidEndDecelerating(scrollView)
        }
    }

    @IBAction func cardPageControlValueDidChange() {
        scrollToPage(pageControl.currentPage, animated: true)
    }

    func scrollToPage(_ page: Int, animated: Bool) {
        let contentOffsetX = pageScrollView.bounds.width * CGFloat(page)
        pageScrollView.setContentOffset(CGPoint(x: contentOffsetX, y: 0), animated: animated)
    }
}
