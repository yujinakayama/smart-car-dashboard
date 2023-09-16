//
//  OpenDash.swift
//  OpenDash
//
//  Created by Yuji Nakayama on 2023/06/20.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import AppIntents

struct OpenDash: AppIntent {
    static var title: LocalizedStringResource = "Open Dash"
    static var description: IntentDescription? = IntentDescription("Opens Dash app.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
