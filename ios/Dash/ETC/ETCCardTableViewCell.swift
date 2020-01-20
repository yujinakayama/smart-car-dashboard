//
//  ETCCardTableViewCell.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCCardTableViewCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var checkmarkImageView: UIImageView!

    var card: ETCCardManagedObject! {
        didSet {
            if let name = card.name {
                nameLabel.text = name
                nameLabel.textColor = UIColor.label
            } else {
                nameLabel.text = card.tentativeName
                nameLabel.textColor = UIColor.secondaryLabel
            }
        }
    }

    var isCurrentCard = false {
        didSet {
            checkmarkImageView.isHidden = !isCurrentCard
        }
    }
}
