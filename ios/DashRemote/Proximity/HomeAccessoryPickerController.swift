//
//  HomeAccessoryPickerController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2023/08/17.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import HomeKit

protocol HomeAccessoryPickerControllerDelegate: NSObjectProtocol {
    func homeAccessoryPickerController(_ pickerController: HomeAccessoryPickerController, didFinishPickingAccessory accessory: HMAccessory)
}

class HomeAccessoryPickerController: UITableViewController {
    static let cellReuseIdentifier = "UITableViewCell"

    let serviceType: String

    weak var delegate: HomeAccessoryPickerControllerDelegate?

    private lazy var homeManager = {
        let homeManager = HMHomeManager()
        homeManager.delegate = self
        return homeManager
    }()

    init(serviceType: String) {
        self.serviceType = serviceType
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var dataSource = DataSource(tableView: tableView) { tableView, indexPath, accessory in
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
        cell.textLabel?.text = accessory.name
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = .init(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonDidTap))

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)

        dataSource.defaultRowAnimation = .none

        updateData()
    }

    private func updateData() {
        let accessoriesByHome = homeManager.homes.reduce(into: [HMHome: [HMAccessory]]()) { dictionary, home in
            if let accessories = home.servicesWithTypes([HMServiceTypeLockMechanism])?.compactMap({ $0.accessory }) {
                dictionary[home] = accessories
            }
        }

        var snapshot = NSDiffableDataSourceSnapshot<HMHome, HMAccessory>()

        snapshot.appendSections(accessoriesByHome.keys.map { $0 })

        for (home, accessories) in accessoriesByHome {
            snapshot.appendItems(accessories, toSection: home)
        }

        dataSource.apply(snapshot)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let accessory = dataSource.itemIdentifier(for: indexPath) else { return }
        delegate?.homeAccessoryPickerController(self, didFinishPickingAccessory: accessory)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @objc func cancelButtonDidTap() {
        dismiss(animated: true)
    }
}

extension HomeAccessoryPickerController: HMHomeManagerDelegate {
    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        if status.contains(.authorized) {
            updateData()
        }
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        updateData()
    }
}

private class DataSource: UITableViewDiffableDataSource<HMHome, HMAccessory> {
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let home = sectionIdentifier(for: section) else { return nil }
        return home.name
    }
}
