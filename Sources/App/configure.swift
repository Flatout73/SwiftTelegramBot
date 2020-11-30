import Vapor
import Fluent
import FluentMySQLDriver
import Telegrammer

/// Called before your application initializes.
public func configure(_ app: Application) throws {
    /// Setting up HTTPServer
//    let serverConfig = NIOServerConfig.default(hostname: "127.0.0.1")
//    services.register(serverConfig)
    
//    var middlewareConfig = MiddlewareConfig()
//    middlewareConfig.use(ErrorMiddleware.self)
//    middlewareConfig.use(SessionsMiddleware.self)
//    services.register(middlewareConfig)
    
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    ///Registering bot as a vapor service
    var settings = Bot.Settings(token: "***REMOVED***")
    settings.webhooksConfig = Webhooks.Config(ip: "0.0.0.0", url: "https://test.url", port: 88)

    let santaMiddleware = try SantaMiddleware(path: "bot", settings: settings, app: app)
    app.middleware.use(santaMiddleware)
    
    let dconfig: MySQLConfiguration = {
    #if DEBUG
    let pconfig = MySQLConfiguration(hostname: "127.0.0.1", port: 3306,
                                     username: "debuguser",
                                     password: "***REMOVED***",
                                     database: "secretsanta",
                                     tlsConfiguration: .forClient(certificateVerification: .none))
    return pconfig
    #else
    let DBUser = Environment.get("DB_USER")                                                                             ?? "server"
    let DBPassword = Environment.get("DB_PASSWORD")                                                                     ?? "***REMOVED***"
    let DBDatabase = Environment.get("DB_DATABASE")                                                                      ?? "secretsantaaita_clone"
    let DBIP = Environment.get("DB_IP")                                                                                     ?? "34.76.67.95"
    let pconfig = MySQLDatabaseConfig(hostname: DBIP, port: 3306, username: DBUser,
                                      password: DBPassword, database: DBDatabase, characterSet: .utf8mb4_unicode_ci)
    #endif
    }()

    app.databases.use(.mysql(configuration: dconfig), as: .mysql)
    app.migrations.add(CreateSantaUser())
    try app.autoMigrate().wait()
    
//    services.register(KeyedCache.self) { container in
//        try container.keyedCache(for: .mysql)
//    }
    
   // config.prefer(DatabaseKeyedCache<ConfiguredDatabase<MySQLDatabase>>.self, for: KeyedCache.self)
    
    ///Registering vapor routes
    //let router = EngineRouter.default()
    try routes(app)
    //services.register(router, as: Router.self)
    
    _ = try Updater(bot: santaMiddleware.bot, dispatcher: santaMiddleware.dispatcher).startLongpolling().wait()
}
