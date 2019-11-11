//
//  User.swift
//  App
//
//  Created by Leonid Liadveikin on 08.11.2019.
//

import Foundation
import Vapor
import FluentMySQL

final class SantaUser: MySQLModel, MySQLMigration, Content, Parameter {
    var id: Int?
    var name: String
    var lastName: String?
    var telegramUsername: String?
    var desiredGift: String?
    var santaForUser: Int?
    
    init(id: Int?, name: String, lastName: String?, telegramUsername: String?, desiredGift: String?, santaForUser: Int?) {
        self.id = id
        self.name = name
        self.lastName = lastName
        self.telegramUsername = telegramUsername
        self.desiredGift = desiredGift
        self.santaForUser = santaForUser
    }
}

struct GiftMigration: MySQLMigration {
    static func prepare(on conn: MySQLConnection) -> Future<Void> {
        return conn.raw("""
        ALTER TABLE SantaUser MODIFY COLUMN desiredGift TEXT;
        """).run()
    }
    
    static func revert(on conn: MySQLConnection) -> Future<Void> {
        return conn.future(())
    }
}
