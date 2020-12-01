//
//  User.swift
//  App
//
//  Created by Leonid Liadveikin on 08.11.2019.
//

import Foundation
import Vapor
import Fluent
import FluentMySQLDriver

final class SantaUser: Model, Content {
    static let schema: String = "santa_users"
    @ID(custom: "id")
    var id: Int?
    @Field(key: "name")
    var name: String
    @OptionalField(key: "lastName")
    var lastName: String?
    @OptionalField(key: "telegramUsername")
    var telegramUsername: String?
    @OptionalField(key: "desiredGift")
    var desiredGift: String?
    @OptionalField(key: "address")
    var address: String?
    @OptionalField(key: "santaForUser")
    var santaForUser: Int?
    
    init() { }
    
    init(id: Int, name: String, lastName: String?,
         telegramUsername: String?, desiredGift: String?, santaForUser: Int?) {
        self.id = id
        self.name = name
        self.lastName = lastName
        self.telegramUsername = telegramUsername
        self.desiredGift = desiredGift
        self.santaForUser = santaForUser
    }
}

struct CreateSantaUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SantaUser.schema)
            .id()
            .field("name", .string, .required)
            .field("lastName", .string)
            .field("telegramUsername", .string)
            .field("desiredGift", .custom("TEXT"))
            .field("santaForUser", .int64)
            .field("address", .custom("TEXT"))
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SantaUser.schema).delete()
    }
}

struct AddressUserUpdate: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SantaUser.schema)
            .field("address", .custom("TEXT"))
            .update()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(SantaUser.schema).delete()
    }
}
