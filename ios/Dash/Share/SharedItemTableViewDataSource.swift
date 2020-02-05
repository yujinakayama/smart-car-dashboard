//
//  SharedItemTableViewDataSource.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/06.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class SharedItemTableViewDataSource: UITableViewDiffableDataSource<Date, SharedItem.Identifier> {
    var titleForHeaderInSection: ((UITableView, Int) -> String?)?

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let titleForHeaderInSection = titleForHeaderInSection {
            return titleForHeaderInSection(tableView, section)
        } else {
            return nil
        }
    }
}
