//
//  UserController.swift
//  App
//
//  Created by Leonid Liadveikin on 08.11.2019.
//

import Vapor

class UserController {
    func index(_ req: Request) throws -> Future<[SantaUser]> {
        return SantaUser.query(on: req).all()
    }
    
    func create(_ req: Request) throws -> Future<SantaUser> {
        return try req.content.decode(SantaUser.self).flatMap { user in
            return user.save(on: req)
        }
    }
}
