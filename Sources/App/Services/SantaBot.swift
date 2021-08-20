import Foundation
import Telegrammer
import Vapor
import FluentMySQLDriver

let moneyLimit = 15

let helpMessage = """
Type /register <password> for participating.
Ping @flatout97 for questions about bot.
"""

let startMessage = """
🎁🎄🎅SECRET SANTA🎅🎄🎁

XoXo, New Year is coming! Let's create a holiday mood with gifts from Santa🎁🎄
Type /register <password> for participating.
"""

let rulesMessage = """
After registration, please write down your address and desired gift. You can change your desired gift through `/gift <desired gift>` (your Santa will consider, but can surprise you with something else). The limit per one gift is **$\(moneyLimit)** or 1000 ₽.
We will make sure that we have all the participants entered in the system and you will find out who you are Santa to on or before Decmber 10th.

Type /address for entering your delivery address.
"""

let registrationMessage = """
You have successfully registered. Type /gift for changing your gift and /address for changing your delivery address in any time before randomize. Your Santa will consider, but can surprise you with something else. The limit per one gift is $\(moneyLimit) or 1000 ₽.
We will make sure that we have all the participants entered in the system and you will find out who you are Santa to on or before December 10th.

Ping @flatout97 for questions about bot.

What do you want as a gift? (limit $\(moneyLimit))
"""

let admins = ["flatout97"]

private let password = "12345678"

final class SantaMiddleware: TelegrammerMiddleware {
    enum UserState {
        case password
        case gift
        case address
    }
    let bot: Bot
    let path: String
    var updater: Updater?
    lazy var dispatcher: Dispatcher = configureDispatcher()
    let app: Application
    private var database: Database {
        app.db
    }
    
    var userSessions: [Int64: UserState] = [:]
    var userGiftSessions = Set<Int64>()
    
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
        
        let addressCommand = CommandHandler(commands: ["/address"], callback: addressHandler)
        dispatcher.add(handler: addressCommand)
        
        let participantsCommand = CommandHandler(commands: ["/participants"], callback: participantsHandler)
        dispatcher.add(handler: participantsCommand)
        
        let resendCommand = CommandHandler(commands: ["/resendMessages"], callback: resendHandler)
        dispatcher.add(handler: resendCommand)
        
        let infoCommand = CommandHandler(commands: ["/info"], callback: infoHandler)
        dispatcher.add(handler: infoCommand)
        
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
            for user in sendingUsers {
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
                self.sendMessage(message, for: Int64(id), with: 1)
            }
            
            self.sendMessage("Success!", for: from)
        }
    }
    
    func messageHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let tuser = message.from else { return }

        if let state = userSessions[tuser.id] {
            switch state {
            case .password:
                if message.text == password {
                    try register(tuser: tuser, for: message.chat.id)
                } else {
                    sendMessage("Wrong password!", for: message.chat.id)
                }
            case .gift:
                if let text = message.text {
                    setGiftFor(tuser: tuser, gift: text, messageID: message.chat.id) { [weak self] success in
                        guard success else { return }
                        self?.sendMessage("Write your delivery address", for: message.chat.id)
                        self?.userSessions[tuser.id] = .address
                    }
                }
            case .address:
                if let text = message.text {
                    setAddress(tuser: tuser, address: text, messageID: message.chat.id)
                    userSessions[tuser.id] = nil
                }
            }
        } else if userGiftSessions.contains(tuser.id), let text = message.text {
            setGiftFor(tuser: tuser, gift: text, messageID: message.chat.id)
            userGiftSessions.remove(tuser.id)
        } else {
            sendMessage("Error!\n\(rulesMessage)", for: message.chat.id)
        }
    }
    
    func participantsHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let tuser = message.from else { return }
        getUsers { users in
            var message: String = "Participants:\n"
            for (i, user) in users.enumerated() {
                message += "\(i + 1). \(user.name) \(user.lastName ?? "") (@\(user.telegramUsername ?? ""))\n"
            }
            self.sendMessage(message, for: tuser.id)
        }
    }
    
    fileprivate func setGiftFor(tuser: User, gift: String, messageID: Int64, completion: ((Bool) -> Void)? = nil) {
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
                    completion?(true)
                }
                future.whenFailure { error in
                    self.sendMessage(error.localizedDescription, for: messageID)
                    completion?(false)
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
            userGiftSessions.insert(tuser.id)
            self.sendMessage("Type your wish: ", for: tuser.id)
        }
    }
    
    private func setAddress(tuser: User, address: String, messageID: Int64) {
        let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: database)
        
        future.whenSuccess { user in
            guard user?.santaForUser == nil else {
                self.sendMessage("You can no longer change your address!", for: messageID)
                return
            }
            if let user = user {
                user.address = address
                let future = user.save(on: self.database)
                future.whenSuccess {
                    self.sendMessage("Success! Your address is \(user.address ?? "error")", for: messageID)
                }
                future.whenFailure { error in
                    self.sendMessage(error.localizedDescription, for: messageID)
                }
                print("Address for user \(user.id ?? -1) \(user.telegramUsername ?? "") - \(address)")
            } else {
                self.sendMessage("Fail! You should register in secret santa firstly through /register.", for: messageID)
            }
        }
    }
    
    func addressHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let tuser = message.from else { return }
        if let text = message.text?.components(separatedBy: .whitespaces)[1...].joined(separator: " "), !text.isEmpty {
            setAddress(tuser: tuser, address: text, messageID: message.chat.id)
        } else {
            self.sendMessage("Error! Set address using: /address <your address>", for: tuser.id)
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

                guard let santaForUser = users.first(where: { $0.id == user.santaForUser }), let id = user.id else { continue }
                var message = """
                Congrats! You are Santa for \(santaForUser.name) \(santaForUser.lastName ?? "")
                """
                if let username = santaForUser.telegramUsername {
                    message += " (@\(username))"
                }
                if let gift = santaForUser.desiredGift {
                    message += "\nHe or She wants \"\(gift)\""
                }
                if let address = santaForUser.address {
                    message += "\nAddress: \(address)"
                }
                print("User \(user.id ?? -1) \(user.name) are santa for \(santaForUser.id ?? -1) \(santaForUser.name)")
                self.sendMessage(message, for: Int64(id), with: 1)
            }
            
            //Check this command on 40+ users in cloud run, because previosly it is crashed when i try save every user separately.
            //https://github.com/vapor/fluent-kit/issues/114
            //https://theswiftdev.com/get-started-with-the-fluent-orm-framework-in-vapor-4/
            let future = mutatedUsers.map { $0.save(on: self.database) }.flatten(on: self.app.eventLoopGroup.next())
            future.whenFailure { error in
                self.sendMessage(error.localizedDescription, for: from)
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
    
    private func register(tuser: User, for chatID: Int64) throws {
        let santaUser = SantaUser(id: Int(tuser.id),
                                  name: tuser.firstName,
                                  lastName: tuser.lastName,
                                  telegramUsername: tuser.username,
                                  desiredGift: nil,
                                  santaForUser: nil)
        let params = Bot.SendMessageParams(chatId: .chat(chatID), text: registrationMessage)
        try self.bot.sendMessage(params: params)
        
        santaUser.create(on: self.database).whenSuccess { _ in
            print("User \(santaUser.name) \(santaUser.lastName ?? "") registered")
        }
        
        userSessions[tuser.id] = .gift
    }
    
    func registerHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
                   let tuser = message.from else { return }
        let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: database)
                
        _ = future.flatMapThrowing { user in
            if user != nil {
                let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "You have already successfully registered. Type /gift for changing desired gift.")
                try self.bot.sendMessage(params: params)
            }  else {
                guard let components = message.text?.components(separatedBy: .whitespaces),
                      components.count > 1, components[1] == password else {
                    self.sendMessage("Write password: ", for: message.chat.id)
                    self.userSessions[tuser.id] = .password
                    return
                }
                
                try self.register(tuser: tuser, for: message.chat.id)
            }
        }
        
        future.whenFailure { error in
            print(error)
        }
    }
    
    func infoHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
                   let tuser = message.from else { return }
        let future: Future<SantaUser?> = SantaUser.find(Int(tuser.id), on: database)
        
        _ = future.flatMapThrowing { user in
            if let user = user {
                var info = "Your info:\nName: \(user.name)"
                if let gift = user.desiredGift {
                    info += "\nYour gift is \(gift)"
                }
                if let address = user.address {
                    info += "\nYour address is \(address)"
                }
                
                self.sendMessage(info, for: message.chat.id)
            } else {
                let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "You have not registered!")
                try self.bot.sendMessage(params: params)
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
        allUsersFuture.whenFailure { error in
            print(error.localizedDescription)
        }
    }
    
}
