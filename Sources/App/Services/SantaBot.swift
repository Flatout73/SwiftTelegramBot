import Foundation
import Telegrammer
import Vapor
import FluentMySQLDriver

let moneyLimit = 15

let helpMessage = """
Type /register <password> for participating.
If you have any questions about rules or policies telegram Sasha @sashaborch. Ping @flatout97 for questions about bot.
"""

let startMessage = """
🎁🎄🎅SECRET SANTA🎅🎄🎁

XoXo, New Year is coming! Let's create a holiday mood with gifts from Santa🎁🎄
Type /register <password> for participating.
"""

let rulesMessage = """
After registration, please write down your desired gift. You can change your desired gift through `/gift <desired gift>` (your Santa will consider, but can surprise you with something else). The limit per one gift is **$\(moneyLimit)** or 1000 ₽.
We will make sure that we have all the participants entered in the system and you will find out who you are Santa to on or before Decmber 10th.
"""

let registrationMessage = """
You have successfully registered. Type /gift for selecting your gift.
"""

let admins = ["flatout97", "sashaborch"]

private let password = "***REMOVED***"

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
            var message: String = "Participants:\n"
            for (i, user) in users.enumerated() {
                message += "\(i + 1). \(user.name) \(user.lastName ?? "") (@\(user.telegramUsername ?? "")\n"
            }
            self.sendMessage(message, for: tuser.id)
        }
    }
    
    fileprivate func setGiftFor(tuser: User, gift: String, messageID: Int64) {
        let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: database)
        
        future.whenSuccess { user in
            guard user?.santaForUser == nil else {
                self.sendMessage("You can no longer change your desired gift!", for: messageID)
                return
            }
            if let user = user {
                user.desiredGift = gift
                let future = user.save(on: self.database)
                future.whenSuccess {
                    self.sendMessage("Success! Your gift is \(user.desiredGift ?? "error")", for: messageID)
                }
                future.whenFailure { error in
                    self.sendMessage(error.localizedDescription, for: messageID)
                }
                print("Desired gift for user \(user.id ?? -1) \(user.telegramUsername ?? "") - \(gift)")
            } else {
                self.sendMessage("Fail! You should register in secret santa firstly through /register.", for: messageID)
            }
        }
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
                let future = user.save(on: self.database).whenFailure { error in
                    self.sendMessage(error.localizedDescription, for: from)
                }
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
            
            self.sendMessage("Finished!", for: from)
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
        guard let components = message.text?.components(separatedBy: .whitespaces),
              components.count > 1, components[1] == password else {
            sendMessage("You should write password for registration. /register <password>", for: message.chat.id)
            return
        }
        
        let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: database)
                
        _ = future.flatMapThrowing { user in
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
                let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "You have successfully registered. What do you want as a gift? (limit $\(moneyLimit)")
                try self.bot.sendMessage(params: params)
                
                santaUser.create(on: self.database).whenSuccess { _ in
                    print("User \(santaUser.name) \(santaUser.lastName ?? "") registered")
                }
                self.userRegisterSessions.insert(tuser.id)
            }
        }
        
        future.whenFailure { error in
            print(error)
        }
    }
    
    private func sendMessage(_ message: String, for id: Int64, with delay: Int64? = nil) {
        print("Sending message: ", message)
        
        if let delay = delay {
            app.eventLoopGroup.next().scheduleTask(in: .seconds(delay)) { [weak self] in
                self?.sendMessageWithRetry(message, for: id)
            }
        } else {
            sendMessageWithRetry(message, for: id)
        }
    }
    
    private func sendMessageWithRetry(_ message: String, for id: Int64) {
        let params = Bot.SendMessageParams(chatId: .chat(id), text: message)
        do {
            try self.bot.sendMessage(params: params).whenFailure { error in
                print("Message fail: ", error.logMessage, (error as? NSError)?.userInfo, (error as? NSError), (error as? NSError)?.debugDescription)
                self.app.eventLoopGroup.next().scheduleTask(in: .seconds(1)) {
                    do {
                        try self.bot.sendMessage(params: params)
                    } catch {
                        print("Second message error: ", error)
                    }
                }
            }
        } catch {
            print("Message error: ", error)
        }
    }
    
    private func getUsers(completion: @escaping ([SantaUser]) -> Void) {
        let allUsersFuture = SantaUser.query(on: database).all()
        allUsersFuture.whenSuccess { users in
            completion(users)
        }
    }
    
}
