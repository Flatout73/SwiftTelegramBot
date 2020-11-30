//
//  EchoBot.swift
//  EchoBot
//
//  Created by Givi Pataridze on 31.05.2018.
//

import Foundation
import Telegrammer
import Vapor
import FluentMySQLDriver

let helpMessage = """
Type /register for participating.
If you have any questions about rules or policies telegram Anastasia @as4astie. Ping @flatout97 for questions about bot.
"""

let startMessage = """
🎁🎄🎅SECRET SANTA🎅🎄🎁

XoXo, New Year is coming! Let's create a holiday mood with gifts from Santa🎁🎄
Type /register for participating.
"""

let rulesMessage = """
After submitting your name, please write down your desired gift. You can change your desired gift through `/gift <desired gift>` (your Santa will consider, but can surprise you with something else). The limit per one gift is **$25**.
We will make sure that we have all the participants entered in the system and you will find out who you are Santa to on or before November 20th.
"""

let registrationMessage = """
You have successfully registered. Type /gift for selecting your gift.
"""

let admins = ["flatout97", "as4astie"]

final class SantaMiddleware: TelegrammerMiddleware {
    let bot: Bot
    let path: String
    var updater: Updater?
    lazy var dispatcher: Dispatcher = configureDispatcher()
    let app: Application
    private var database: Database {
        app.db
    }
    
    /// Dictionary for user sessions
    var userRegisterSessions = Set<Int64>()
    
    public init(path: String, settings: Bot.Settings, app: Application) throws {
        self.path = path
        self.bot = try Bot(settings: settings)
        self.app = app
    }
    
//    ///Conformance to `ServiceType` protocol, fabric methhod
//    static func makeService(for worker: Container) throws -> SantaBot {
//        guard let token = Environment.get("TELEGRAM_BOT_TOKEN") else {
//            throw CoreError(identifier: "Enviroment variables", reason: "Cannot find telegram bot token")
//        }
//
//        #if DEBUG
//        var settings = Bot.Settings(token: token, debugMode: true)
//        #else
//        var settings = Bot.Settings(token: token, debugMode: false)
//        #endif
//
//
//        /// Setting up webhooks https://core.telegram.org/bots/webhooks
//        /// Internal server address (Local IP), where server will starts
//        //settings.webhooksConfig?.ip = "127.0.0.1"
//
//        /// Internal server port, must be different from Vapor port
//        //settings.webhooksConfig.webhooksPort = 8181
//
//        /// External endpoint for your bot server
//        settings.webhooksConfig = Webhooks.Config(ip: "127.0.0.1", url: "https://secretsanta-258422.appspot.com/webhooks", port: 8181)
//
//        /// If you are using self-signed certificate, point it's filename
//        //settings.webhooksPublicCert = "public.pem"
//
//        return try SantaBot(settings: settings, container: worker)
//    }
////
//    init(settings: Bot.Settings, container: Container) throws {
//        self.bot = try Bot(settings: settings)
//        self.container = container
//        let dispatcher = try configureDispatcher()
//        self.dispatcher = dispatcher
//        self.updater = Updater(bot: bot, dispatcher: dispatcher)
//    }
    
    /// Initializing dispatcher, object that receive updates from Updater
    /// and pass them throught handlers pipeline
    func configureDispatcher() -> Dispatcher {
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
        
        let randomizeCommand = CommandHandler(commands: ["/randomize"], callback: randomizeHandler)
        dispatcher.add(handler: randomizeCommand)
        
        let giftCommand = CommandHandler(commands: ["/gift"], callback: giftHandler)
        dispatcher.add(handler: giftCommand)
        
        let santaCommand = CommandHandler(commands: ["/santa"], callback: santaHandler)
        dispatcher.add(handler: santaCommand)
        
        let participantsCommand = CommandHandler(commands: ["/participants"], callback: participantsHandler)
        dispatcher.add(handler: participantsCommand)
        
        let resendCommand = CommandHandler(commands: ["/resendMessages"], callback: resendHandler)
        dispatcher.add(handler: resendCommand)
        
        ///Creating and adding handler for ordinary text messages
        let message = MessageHandler(filters: Filters.text, callback: messageHandler)
        dispatcher.add(handler: message)
        
        return dispatcher
    }
    
    func resendHandler(_ update: Update, _ context: BotContext?) throws {
        guard let from = update.message?.from?.id else { return }
        guard let name = update.message?.from?.username, admins.contains(name) else {
            self.sendMessage("You don't have permissions", for: from)
            return
        }
        getUsers { users in
            let sendingUsers = users.filter({ $0.santaForUser != nil })
            for (i, user) in sendingUsers.enumerated() {
                guard let santaForUser = users.first(where: { $0.id == user.santaForUser }), let id = user.id else { continue }
                var message = """
                Congrats! You are Santa for \(santaForUser.name)
                """
                if let lastName = santaForUser.lastName {
                    message += " \(lastName)"
                }
                if let username = santaForUser.telegramUsername {
                    message += " (@\(username))"
                }
                if let gift = santaForUser.desiredGift {
                    message += "\nHe or She wants \"\(gift)\""
                }
                print("User \(user.id ?? -1) \(user.name) are santa for \(santaForUser.id ?? -1) \(santaForUser.name)")
                self.sendMessage(message, for: Int64(id))
            }
            
            self.sendMessage("Success!", for: from)
        }
    }
    
    func messageHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let tuser = message.from else { return }
        
        if userRegisterSessions.contains(tuser.id), let text = message.text {
            setGiftFor(tuser: tuser, gift: text, messageID: message.chat.id)
            userRegisterSessions.remove(tuser.id)
        } else {
             sendMessage(helpMessage, for: message.chat.id)
        }
    }
    
    func participantsHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let tuser = message.from else { return }
        getUsers { users in
            var message: String = "Participants: "
            users.forEach { message += $0.name + " " + ($0.lastName ?? "") + "\n" }
            self.sendMessage(message, for: tuser.id)
        }
    }
    
    func santaHandler(_ update: Update, _ context: BotContext?) throws {
//        guard let message = update.message,
//            let tuser = message.from else { return }
//        container.requestPooledConnection(to: .mysql).flatMap { conn -> Future<SantaUser?> in
//            let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: conn)
//            future.whenSuccess { user in
//                if let user = user {
//                    sendMessage(", for: <#T##Int64#>)
//                } else {
//
//                }
//            }
//
//            return future
//        }
    }
    
    fileprivate func setGiftFor(tuser: User, gift: String, messageID: Int64) {
        //container.requestPooledConnection(to: .mysql).whenSuccess { conn in
            let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: database)
            
            future.whenSuccess { user in
                guard user?.santaForUser == nil else {
                    self.sendMessage("You can no longer change your desired gift!", for: messageID)
                    return
                }
                if let user = user {
                    user.desiredGift = gift
                    user.save(on: self.database)
                    self.sendMessage("Success! Your gift is \(gift)", for: messageID)
                    print("Desired gift for user \(user.id ?? -1) \(user.telegramUsername ?? "") - \(gift)")
                } else {
                    self.sendMessage("Fail! You should register in secret santa firstly through /register.", for: messageID)
                }
            }
            
//            future
//                .always {
//                try? self.container.releasePooledConnection(database, to: .mysql)
//            }
        //}
    }
    
    func giftHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let tuser = message.from else { return }
        if let text = message.text?.components(separatedBy: .whitespaces)[1...].joined(separator: " "), !text.isEmpty {
            setGiftFor(tuser: tuser, gift: text, messageID: message.chat.id)
        } else {
            userRegisterSessions.insert(tuser.id)
            self.sendMessage("Type your wish: ", for: tuser.id)
        }
        
    }
    
    func randomizeHandler(_ update: Update, _ context: BotContext?) throws {
        guard let from = update.message?.from?.id else { return }
        guard let name = update.message?.from?.username, admins.contains(name) else {
            self.sendMessage("You don't have permissions", for: from)
            return
        }
        getUsers { users in
            var mutatedUsers = users.filter({ $0.santaForUser == nil })
            guard mutatedUsers.count > 1 else {
                self.sendMessage("Not enough users", for: from)
                return
            }
            mutatedUsers.shuffle()
            for (i, user) in mutatedUsers.enumerated() {
                if i < mutatedUsers.count - 1 {
                    user.santaForUser = mutatedUsers[i + 1].id
                } else {
                    user.santaForUser = mutatedUsers[0].id
                }
                user.save(on: self.database)
                guard let santaForUser = users.first(where: { $0.id == user.santaForUser }), let id = user.id else { continue }
                var message = """
                Congrats! You are Santa for \(santaForUser.name) \(santaForUser.lastName ?? "")
                """
                if let username = santaForUser.telegramUsername {
                    message += " (\(username))"
                }
                if let gift = santaForUser.desiredGift {
                    message += "\nHe or She wants \"\(gift)\""
                }
                print("User \(user.id ?? -1) \(user.name) are santa for \(santaForUser.id ?? -1) \(santaForUser.name)")
                self.sendMessage(message, for: Int64(id))
            }
            
            self.sendMessage("Success!", for: from)
        }
    }
    
    func rulesHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        sendMessage(rulesMessage, for: message.chat.id)
    }
    
    func helpHandler(_ update: Update, _ context: BotContext?) throws {
        print("I get update: ", update.message?.text)
        guard let message = update.message else {
            print("Message is nil")
            return
        }
        sendMessage(helpMessage, for: message.chat.id)
    }
    
    func startHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
       sendMessage(startMessage, for: message.chat.id)
    }
    
    func registerHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
                   let tuser = message.from else { return }
        
        //container.requestPooledConnection(to: .mysql).whenSuccess { conn in
            let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: database)
                
        future.flatMapThrowing { user in
                if user != nil {
                    let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "You have already successfully registered. Type /gift for changing desired gift.")
                    try self.bot.sendMessage(params: params)
                }  else {
                    let santaUser = SantaUser(id: Int(tuser.id),
                                              name: tuser.firstName,
                                              lastName: tuser.lastName,
                                              telegramUsername: tuser.username,
                                              desiredGift: nil,
                                              santaForUser: nil)
                    let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "You have successfully registered. What do you want as a gift? (limit $25)")
                    try self.bot.sendMessage(params: params)
                    
                    santaUser.create(on: self.database).map { _ in
                        print("User \(santaUser.name) \(santaUser.lastName ?? "") registered")
                    }
//                    .always {
//                        try? self.container.releasePooledConnection(conn, to: .mysql)
//                    }
                    self.userRegisterSessions.insert(tuser.id)
                }
//            }.always {
//                try? self.container.releasePooledConnection(conn, to: .mysql)
//            }
        }
        
        future.whenFailure { error in
            print(error)
        }
    }
    
    private func sendMessage(_ message: String, for id: Int64) {
        print("Sending message: ", message)
        let params = Bot.SendMessageParams(chatId: .chat(id), text: message)
        app.eventLoopGroup.next().scheduleTask(in: .seconds(1)) {
            do {
                try self.bot.sendMessage(params: params).whenFailure { error in
                    print("Message fail: ", error.logMessage, (error as? NSError)?.userInfo, (error as? NSError), (error as? NSError)?.debugDescription)
                    do {
                        try self.bot.sendMessage(params: params)
                    } catch {
                        print("Second message error: ", error)
                    }
                }
            } catch {
                print("Message error: ", error)
            }
        }
    }
    
    private func getUsers(completion: @escaping ([SantaUser]) -> Void) {
        //container.requestPooledConnection(to: .mysql).whenSuccess { conn in
        let allUsersFuture = SantaUser.query(on: database).all()
        allUsersFuture.whenSuccess { users in
            completion(users)
        }
//            .always {
//                try? self.container.releasePooledConnection(conn, to: .mysql)
//            }
       // }
    }
    
}
