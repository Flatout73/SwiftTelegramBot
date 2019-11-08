//
//  User.swift
//  App
//
//  Created by Leonid Liadveikin on 08.11.2019.
//

import Foundation
import Vapor
import FluentPostgreSQL

struct SantaUser: PostgreSQLModel {
    var id: Int?
    var name: String
    var telegramUsername: String?
    var desiredGift: String?
    var santaForUser: Int?
}

extension SantaUser: Migration, Content, Parameter { }
