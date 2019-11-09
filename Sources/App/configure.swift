import Vapor
import FluentMySQL

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Setting up HTTPServer
   // let serverConfig = NIOServerConfig.default(hostname: "127.0.0.1")
    //services.register(serverConfig)
    
    var middlewareConfig = MiddlewareConfig()
    middlewareConfig.use(ErrorMiddleware.self)
    middlewareConfig.use(SessionsMiddleware.self)
    services.register(middlewareConfig)
    
    ///Registering bot as a vapor service
    services.register(EchoBot.self)
    
    try services.register(FluentMySQLProvider())
    
//    #if DEBUG
//    let pconfig = MySQLDatabaseConfig(hostname: "localhost", port: 5432, username: "postgres", password: "depo", database: "secretsanta")
//    #else
    let DBUser = "admin" //Environment.get("DB_USER") ?? ""
    let DBPassword = "***REMOVED***" //Environment.get("DB_PASSWORD") ?? ""
    let DBDatabase = "secretsantaaita" //Environment.get("DB_DATABASE") ?? ""
    let DBIP = "104.155.14.177" //Environment.get("DB_IP") ?? "104.155.14.177"
    let pconfig = MySQLDatabaseConfig(hostname: DBIP, port: 3306, username: DBUser, password: DBPassword, database: DBDatabase)
//    #endif
    let mysql = MySQLDatabase(config: pconfig)
    
    var databases = DatabasesConfig()
    databases.add(database: mysql, as: .mysql)
    services.register(databases)
    
    var migrations = MigrationConfig()
    migrations.add(model: SantaUser.self, database: .mysql)
    services.register(migrations)
    
    services.register(KeyedCache.self) { container in
        try container.keyedCache(for: .mysql)
    }
    
    config.prefer(DatabaseKeyedCache<ConfiguredDatabase<MySQLDatabase>>.self, for: KeyedCache.self)
    
    ///Registering vapor routes
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
}
