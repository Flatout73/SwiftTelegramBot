import Vapor
import Fluent
import FluentMySQLDriver
import Telegrammer

/// Called before your application initializes.
public func configure(_ app: Application) throws {
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    ///Registering bot as a vapor service
    let botToken = Environment.get("BOT_TOKEN")
    var settings = Bot.Settings(token: botToken)
    settings.webhooksConfig = Webhooks.Config(ip: "0.0.0.0", url: "<url>", port: 88)

    let santaMiddleware = try SantaMiddleware(path: "bot", settings: settings, app: app)
    app.middleware.use(santaMiddleware)
    //try santaMiddleware.setWebhooks()
    
    #if DEBUG
    let pconfig = MySQLConfiguration(hostname: "127.0.0.1", port: 3306,
                                     username: "debuguser",
                                     password: "qwerty123",
                                     database: "secretsanta",
                                     tlsConfiguration: .forClient(certificateVerification: .none))
    #else
    guard let DBUser = Environment.get("DB_USER"),
          let DBPassword = Environment.get("DB_PASS"),
          let DBDatabase = Environment.get("DB_NAME"),
          let connection_name = Environment.get("CLOUD_SQL_CONNECTION_NAME") else {
        print("Wrong environment params")
        return
    }
    let socketDir = Environment.get("DB_SOCKET_DIR") ?? "/cloudsql"
    
    print("socketPath", "\(socketDir)/\(connection_name)")
    let pconfig = MySQLConfiguration(unixDomainSocketPath: "\(socketDir)/\(connection_name)",
                                     username: DBUser,
                                     password: DBPassword,
                                     database: DBDatabase)
    #endif

    app.databases.use(.mysql(configuration: pconfig), as: .mysql)
    app.migrations.add(CreateSantaUser())
    //app.migrations.add(AddressUserUpdate())
    do {
        try app.autoMigrate().wait()
    } catch {
        print(error.localizedDescription)
    }
    
    try routes(app)
    
    #if DEBUG
    _ = try Updater(bot: santaMiddleware.bot, dispatcher: santaMiddleware.dispatcher).startLongpolling().wait()
    #else
    _ = try Updater(bot: santaMiddleware.bot, dispatcher: santaMiddleware.dispatcher).startWebhooks().wait()
    #endif
}
