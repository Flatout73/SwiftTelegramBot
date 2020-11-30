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
    settings.webhooksConfig = Webhooks.Config(ip: "0.0.0.0", url: "https://secretsanta-cko2sgb62q-uc.a.run.app/bot", port: 88)

    let santaMiddleware = try SantaMiddleware(path: "bot", settings: settings, app: app)
    app.middleware.use(santaMiddleware)
    //try santaMiddleware.setWebhooks()
    
    #if DEBUG
    let pconfig = MySQLConfiguration(hostname: "127.0.0.1", port: 3306,
                                     username: "debuguser",
                                     password: "***REMOVED***",
                                     database: "secretsanta",
                                     tlsConfiguration: .forClient(certificateVerification: .none))
    #else
//    let DBUser = Environment.get("DB_USER")                                                                             ?? "server"
//    let DBPassword = Environment.get("DB_PASSWORD")                                                                     ?? "***REMOVED***"
//    let DBDatabase = Environment.get("DB_DATABASE")                                                                      ?? "secretsantaaita_clone"
//    let DBIP = Environment.get("DB_IP")                                                                                     ?? "34.76.67.95"
//    let pconfig = MySQLConfiguration(hostname: DBIP, port: 3306,
//                                     username: DBUser,
//                                     password: DBPassword,
//                                     database: DBDatabase)
    let DBUser = Environment.get("DB_USER")!
    let DBPassword = Environment.get("DB_PASS")!
    let DBDatabase = Environment.get("DB_NAME")!
    let socketDir = Environment.get("DB_SOCKET_DIR") ?? "/cloudsql"
    let connection_name = Environment.get("CLOUD_SQL_CONNECTION_NAME")!
    print("socketPath", "\(socketDir)/\(connection_name)")
    let pconfig = MySQLConfiguration(unixDomainSocketPath: "\(socketDir)/\(connection_name)",
                                     username: DBUser,
                                     password: DBPassword,
                                     database: DBDatabase)
    #endif

    app.databases.use(.mysql(configuration: pconfig), as: .mysql)
    app.migrations.add(CreateSantaUser())
    do {
        try app.autoMigrate().wait()
    } catch {
        print(error.localizedDescription)
    }
    
//    services.register(KeyedCache.self) { container in
//        try container.keyedCache(for: .mysql)
//    }
    
   // config.prefer(DatabaseKeyedCache<ConfiguredDatabase<MySQLDatabase>>.self, for: KeyedCache.self)
    
    ///Registering vapor routes
    //let router = EngineRouter.default()
    try routes(app)
    //services.register(router, as: Router.self)
    
    #if DEBUG
    _ = try Updater(bot: santaMiddleware.bot, dispatcher: santaMiddleware.dispatcher).startLongpolling().wait()
    #else
    _ = try Updater(bot: santaMiddleware.bot, dispatcher: santaMiddleware.dispatcher).startWebhooks().wait()
    #endif
}
