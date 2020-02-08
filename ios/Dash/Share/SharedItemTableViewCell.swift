//
//  SharedItemTableViewCell.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/04.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class SharedItemTableViewCell: UITableViewCell {
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!

    var item: SharedItemProtocol? {
        didSet {
            switch item {
            case let location as Location:
                iconImageView.image = UIImage(systemName: "mappin")
                iconImageView.tintColor = UIColor(named: "Location Icon Color")
                nameLabel.text = location.name
                detailLabel.text = location.url.absoluteString
            case let webpage as Webpage:
                iconImageView.image = UIImage(systemName: "link")
                iconImageView.tintColor = UIColor.link
                nameLabel.text = webpage.title
                detailLabel.text = webpage.url.absoluteString
            default:
                iconImageView.image = UIImage(systemName: "questionmark")
                iconImageView.tintColor = .lightGray
                nameLabel.text = "不明なアイテム"
                detailLabel.text = nil
            }
        }
    }
}