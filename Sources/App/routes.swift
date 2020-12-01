//
//  routes.swift
//  GithubUpdater
//
//  Created by Givi Pataridze on 02.06.2018.
//

import Vapor
import Telegrammer
import Fluent

enum SantaError: Error {
    case dispatcher
}

public func routes(_ app: Application) throws {
    //TODO: Add Leaf for presenting users in html
 //   let userController = UserController()
//    app.get("users") { request in
//        try userController.index(on: request.db).flatMap {
//            var userWithoutAddress = $0
//            userWithoutAddress.address = nil
//            return userWithoutAddress
//        }
//    }
    
    app.get("_ah/health", use: { request throws -> String in
        print("health")
        return "OK"
    })
    
    app.get("_ah/start", use: { request throws -> String in
        print("health start")
        return "OK"
    })
    
    app.get("_ah/stop", use: { request throws -> String in
        print("health stop")
        return "OK"
    })
}
