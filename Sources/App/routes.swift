//
//  routes.swift
//  GithubUpdater
//
//  Created by Givi Pataridze on 02.06.2018.
//

import Vapor
import Telegrammer

public func routes(_ router: Router) throws {
    let userController = UserController()
    router.get("users", use: userController.index)
    router.post("users", use: userController.create)
    
    router.get("_ah/health", use: { request in
        return "OK"
    })
    
    router.post("/webhooks", use: { request -> String in
        print("Webhook: ", request)
        guard let dispatcher = try request.make(SantaBot.self).dispatcher else {
            print("Dispatcher error")
            return "Error"
        }
        try request.content.decode(Update.self).whenSuccess { update in
            dispatcher.enqueue(updates: [update])
        }
        return "OK"
    })
}
