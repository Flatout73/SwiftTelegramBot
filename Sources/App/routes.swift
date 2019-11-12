//
//  routes.swift
//  GithubUpdater
//
//  Created by Givi Pataridze on 02.06.2018.
//

import Vapor
import Telegrammer

enum SantaError: Error {
    case dispatcher
}

public func routes(_ router: Router) throws {
    let userController = UserController()
    router.get("users", use: userController.index)
    router.post("users", use: userController.create)
    
    router.get("_ah/health", use: { request in
        return "OK"
    })
    
    router.post("/webhooks", use: { request throws -> String in
        print("Webhook: ", request)
        guard let dispatcher = try request.make(SantaBot.self).dispatcher else {
            print("Dispatcher error")
            throw SantaError.dispatcher
        }
        let future = try request.content.decode(Update.self)
        future.whenSuccess { update in
            print("Webhook OK", update.message?.text)
            dispatcher.enqueue(updates: [update])
        }
        _ = future.thenIfErrorThrowing { error in
            print("Parsing error: ", error)
            print(request.content)
            throw error
        }

        return "OK"
    })
}
