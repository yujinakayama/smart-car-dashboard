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
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
}
