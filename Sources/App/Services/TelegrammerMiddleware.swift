//
//  File.swift
//
//
//  Created by Givi on 18.02.2020.
//

import Vapor
import Telegrammer

public protocol TelegrammerMiddleware: Middleware {
    var dispatcher: Dispatcher { get }
    var path: String { get }
    var bot: Bot { get }
}

public extension TelegrammerMiddleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard request.url.path == "/\(path)" else {
            return next.respond(to: request)
        }
        guard let body = request.body.data else {
            request.logger.critical("Received empty request from Telegram Server")
            return next.respond(to: request)
        }

        dispatcher.enqueue(bytebuffer: body)

        return request.eventLoop.makeSucceededFuture(Response())
    }

    func setWebhooks() throws -> EventLoopFuture<Bool> {
        guard let config = bot.settings.webhooksConfig else {
            throw CoreError(
                type: .internal,
                reason: "Initialization parameters wasn't found in enviroment variables"
            )
        }

        var cert: InputFile? = nil

        if let publicCert = config.publicCert {
            switch publicCert {
                case .file(url: let url):
                    guard let fileHandle = FileHandle(forReadingAtPath: url) else {
                        let errorDescription = "Public key '\(publicCert)' was specified for HTTPS server, but wasn't found"
                        throw CoreError(
                            type: .internal,
                            reason: errorDescription
                        )
                    }
                    cert = InputFile(data: fileHandle.readDataToEndOfFile(), filename: url)
                case .text(content: let textCert):
                    guard let strData = textCert.data(using: .utf8) else {
                        let errorDescription = "Public key body '\(textCert)' was specified for HTTPS server, but it cannot be converted into Data type"
                        throw CoreError(
                            type: .internal,
                            reason: errorDescription
                        )
                    }
                    cert = InputFile(data: strData, filename: "public.pem")
            }
        }

        let params = Bot.SetWebhookParams(url: config.url, certificate: cert)
        return try bot.setWebhook(params: params)
    }
}
