import Vapor
import FluentMySQL

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Setting up HTTPServer
//    let serverConfig = NIOServerConfig.default(hostname: "127.0.0.1")
//    services.register(serverConfig)
    
    var middlewareConfig = MiddlewareConfig()
    middlewareConfig.use(ErrorMiddleware.self)
    middlewareConfig.use(SessionsMiddleware.self)
    services.register(middlewareConfig)
    
    ///Registering bot as a vapor service
    services.register(SantaBot.self)
    
    try services.register(FluentMySQLProvider())
    
    #if DEBUG
    let pconfig = MySQLDatabaseConfig(hostname: "localhost", port: 3306, username: "root", password: "***REMOVED***", database: "secretsanta", transport: MySQLTransportConfig.unverifiedTLS)
    #else
    let DBUser = Environment.get("DB_USER") ?? "server"
    let DBPassword = Environment.get("DB_PASSWORD") ?? "***REMOVED***"
    let DBDatabase = Environment.get("DB_DATABASE") ?? "secretsantaaita_clone"
    let DBIP = Environment.get("DB_IP") ?? "34.76.67.95"
    let pconfig = MySQLDatabaseConfig(hostname: DBIP, port: 3306, username: DBUser, password: DBPassword, database: DBDatabase, characterSet: .utf8mb4_unicode_ci)
    #endif
    let mysql = MySQLDatabase(config: pconfig)
    
    var databases = DatabasesConfig()
    databases.add(database: mysql, as: .mysql)
    services.register(databases)
    
    var migrations = MigrationConfig()
    migrations.add(model: SantaUser.self, database: .mysql)
    migrations.add(migration: GiftMigration.self, database: .mysql)
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
