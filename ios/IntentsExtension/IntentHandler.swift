//
//  IntentHandler.swift
//  IntentsExtension
//
//  Created by Yuji Nakayama on 2021/11/20.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Intents

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is GetCurrentAudioOutputTypeIntent:
            return GetCurrentAudioOutputTypeIntentHandler()
        default:
            fatalError()
        }
    }
}
