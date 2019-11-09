//
//  EchoBot.swift
//  EchoBot
//
//  Created by Givi Pataridze on 31.05.2018.
//

import Foundation
import Telegrammer
import Vapor

let helpMessage = """
Type /register for participating.
If you have any questions about rules or policies telegram Anastasia @as4astie.
"""

let startMessage = """
🎁🎄🎅SECRET SANTA🎅🎄🎁

XoXo, New Year is coming! Let's create a holiday mood with gifts from Santa🎁🎄
Type /register for participating.
"""

let rulesMessage = """
After submitting your name, please write down your desired gift ( your Santa will consider,but can surprise you with something else).
We will make sure that we have all the participants entered in the system and you will find out who you are Santa to on or before November 20th.
"""

let registrationMessage = """
You have successfully registered. Type /gift for selecting your gift.
"""

final class EchoBot: ServiceType {
    let bot: Bot
    let container: Container
    var updater: Updater?
    var dispatcher: Dispatcher?
    
    /// Dictionary for user echo modes
    var userEchoModes: [Int64: Bool] = [:]
    
    ///Conformance to `ServiceType` protocol, fabric methhod
    static func makeService(for worker: Container) throws -> EchoBot {
        guard let token = Environment.get("TELEGRAM_BOT_TOKEN") else {
            throw CoreError(identifier: "Enviroment variables", reason: "Cannot find telegram bot token")
        }
        
        var settings = Bot.Settings(token: token, debugMode: true)
    
        /// Setting up webhooks https://core.telegram.org/bots/webhooks
        /// Internal server address (Local IP), where server will starts
        //settings.webhooksConfig?.ip = "127.0.0.1"
        
        /// Internal server port, must be different from Vapor port
        //settings.webhooksConfig.webhooksPort = 8181
        
        /// External endpoint for your bot server
        // settings.webhooksUrl = "https://website.com/webhooks"
        
        /// If you are using self-signed certificate, point it's filename
        // settings.webhooksPublicCert = "public.pem"
        
        return try EchoBot(settings: settings, container: worker)
    }
    
    init(settings: Bot.Settings, container: Container) throws {
        self.bot = try Bot(settings: settings)
        self.container = container
        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }
    
    /// Initializing dispatcher, object that receive updates from Updater
    /// and pass them throught handlers pipeline
    func configureDispatcher() throws -> Dispatcher {
        ///Dispatcher - handle all incoming messages
        let dispatcher = Dispatcher(bot: bot)
        
        let helpCommand = CommandHandler(commands: ["/help"], callback: helpHandler)
        dispatcher.add(handler: helpCommand)
        
        ///Creating and adding handler for command /echo
        let commandHandler = CommandHandler(commands: ["/start"], callback: startHandler)
        dispatcher.add(handler: commandHandler)
        
        let rulesCommand = CommandHandler(commands: ["/rules"], callback: rulesHandler)
        dispatcher.add(handler: rulesCommand)
        
        let registerCommand = CommandHandler(commands: ["/register"], callback: registerHandler)
        dispatcher.add(handler: registerCommand)
        
        ///Creating and adding handler for ordinary text messages
//        let echoHandler = MessageHandler(filters: Filters.text, callback: echoResponse)
//        dispatcher.add(handler: echoHandler)
        
        return dispatcher
    }
    
    func rulesHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: rulesMessage)
        try bot.sendMessage(params: params)
    }
    
    func helpHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: helpMessage)
        try bot.sendMessage(params: params)
    }
    
    func startHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: startMessage)
        try bot.sendMessage(params: params)
    }
    
    func registerHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
                   let user = message.from else { return }
        
        let santaUser = SantaUser(id: Int(user.id),
                                  name: user.firstName,
                                  lastName: user.lastName,
                                  telegramUsername: user.username,
                                  desiredGift: nil,
                                  santaForUser: nil)
        print(santaUser)
        container.requestPooledConnection(to: .mysql).flatMap { conn in
            santaUser.create(on: conn).map { users in
                print("just found \(users) users")
            }.always {
                try? self.container.releasePooledConnection(conn, to: .mysql)
            }
        }
    }
}

extension EchoBot {
    ///Callback for Command handler, which send Echo mode status for user
    func echoModeSwitch(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        var onText = ""
        if let on = userEchoModes[user.id] {
            onText = on ? "OFF" : "ON"
            userEchoModes[user.id] = !on
        } else {
            onText = "ON"
            userEchoModes[user.id] = true
        }
        
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "Echo mode turned \(onText)")
        try bot.sendMessage(params: params)
    }
    
    ///Callback for Message handler, which send echo message to user
    func echoResponse(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from,
            let on = userEchoModes[user.id],
            on == true else { return }
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: message.text!)
        try bot.sendMessage(params: params)
    }
}
