import Vapor
import FluentPostgreSQL

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
    
    try services.register(FluentPostgreSQLProvider())
    
    #if DEBUG
    let pconfig = PostgreSQLDatabaseConfig(hostname: "localhost", port: 5432, username: "postgres", database: "secretsanta", password: "depo", transport: .cleartext)
    #else
    let DBUser = Environment.get("DB_USER") ?? ""
    let DBPassword = Environment.get("DB_PASSWORD") ?? ""
    let DBDatabase = Environment.get("DB_DATABASE") ?? ""
    let DBIP = Environment.get("DB_IP") ?? ""
    let pconfig = PostgreSQLDatabaseConfig(hostname: DBIP, port: 5432, username: DBUser, database: DBDatabase, password: DBPassword, transport: .standardTLS)
    #endif
    let postgres = PostgreSQLDatabase(config: pconfig)
    
    var databases = DatabasesConfig()
    databases.add(database: postgres, as: .psql)
    services.register(databases)
    
    var migrations = MigrationConfig()
    migrations.add(model: SantaUser.self, database: .psql)
    services.register(migrations)
    
    services.register(KeyedCache.self) { container in
        try container.keyedCache(for: .psql)
    }
    
    config.prefer(DatabaseKeyedCache<ConfiguredDatabase<PostgreSQLDatabase>>.self, for: KeyedCache.self)
    
    ///Registering vapor routes
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
}
