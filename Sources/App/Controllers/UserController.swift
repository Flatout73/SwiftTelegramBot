//
//  UserController.swift
//  App
//
//  Created by Leonid Liadveikin on 08.11.2019.
//

import Vapor
import Fluent

class UserController {
    func index(on database: Database) throws -> EventLoopFuture<[SantaUser]> {
        return SantaUser.query(on: database)
            .all()
    }
    
    func create(on request: Request) throws -> EventLoopFuture<SantaUser> {
        let user = try request.content.decode(SantaUser.self)
        return user.create(on: request.db)
            .map { user }
    }
}
