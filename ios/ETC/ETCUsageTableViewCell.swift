//
//  ETCUsageTableViewCell.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/04.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCUsageTableViewCell: UITableViewCell {
    static var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    @IBOutlet weak var yenLabel: UILabel!
    @IBOutlet weak var feeView: UIView!
    @IBOutlet weak var feeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var roadLabel: UILabel!
    @IBOutlet weak var tollboothLabel: UILabel!
    @IBOutlet weak var dashLabel: UILabel!
    @IBOutlet weak var exitRoadView: UIView!
    @IBOutlet weak var exitRoadLabel: UILabel!
    @IBOutlet weak var exitTollboothLabel: UILabel!

    var usage: ETCUsage? {
        didSet {
            updateViews()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        var font: UIFont

        if let avenirNext = UIFont(name: "AvenirNext-Bold", size: 17) {
            let fontMetrics = UIFontMetrics(forTextStyle: .headline)
            font = fontMetrics.scaledFont(for: avenirNext)
        } else {
            font = UIFont.preferredFont(forTextStyle: .headline)
        }

        [yenLabel, feeLabel].forEach { (label) in
            label!.font = font
            label!.adjustsFontForContentSizeCategory = true
        }
    }

    private func updateViews() {
        feeLabel.text = usage?.fee.map { "\($0)" }

        dateLabel.text = usage?.date.map { ETCUsageTableViewCell.dateFormatter.string(from: $0) }

        if let entrance = usage?.entranceTollbooth, let exit = usage?.exitTollbooth {
            roadLabel.text = entrance.road.abbreviatedName
            tollboothLabel.text = entrance.name

            if entrance == exit {
                dashLabel.isHidden = true
                exitRoadView.isHidden = true
                exitTollboothLabel.isHidden = true
            } else {
                dashLabel.isHidden = false

                if entrance.road.name == exit.road.name {
                    exitRoadView.isHidden = true
                } else {
                    exitRoadView.isHidden = false
                    exitRoadLabel.text = exit.road.abbreviatedName
                }

                exitTollboothLabel.isHidden = false
                exitTollboothLabel.text = exit.name
            }
        } else {
            roadLabel.text = nil
            tollboothLabel.text = nil
            exitRoadLabel.text = nil
            exitRoadLabel.text = nil
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
}
