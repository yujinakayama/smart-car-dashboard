//
//  ETCUsageTableViewCell.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/04.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCUsageTableViewCell: UITableViewCell {
    @IBOutlet weak var feeView: UIView!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var tollboothLabel: UILabel!

    var usage: ETCUsage? {
        didSet {
            if let fee = usage?.fee {
                feeLabel.attributedText = kern("¥\(fee)", space: 1.5, range: 0...0)
            } else {
                feeLabel.text = nil
            }

            if let date = usage?.date {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                dateLabel.text = dateFormatter.string(from: date)
            } else {
                dateLabel.text = nil
            }

            if let entrance = usage?.entranceTollbooth, let exit = usage?.exitTollbooth {
                if entrance == exit {
                    tollboothLabel.text = entrance.name
                } else {
                    tollboothLabel.text = "\(entrance.name) - \(exit.name)"
                }
            } else {
                tollboothLabel.text = nil
            }
        }
    }

    // https://stackoverflow.com/questions/6745919/uitableviewcell-subview-disappears-when-cell-is-selected
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let color = feeView.backgroundColor
        super.setHighlighted(highlighted, animated: animated)
        feeView.backgroundColor = color
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        let color = feeView.backgroundColor
        super.setSelected(selected, animated: animated)
        feeView.backgroundColor = color
    }

    func kern(_ string: String, space: Float, range: ClosedRange<Int>) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string)
        attributedString.addAttributes([NSAttributedString.Key.kern: space], range: NSRange(range))
        return attributedString
    }
}
