//
//  routes.swift
//  GithubUpdater
//
//  Created by Givi Pataridze on 02.06.2018.
//

import Vapor

public func routes(_ router: Router) throws {
    let userController = UserController()
    router.get("users", use: userController.index)
    router.post("users", use: userController.create)
}
