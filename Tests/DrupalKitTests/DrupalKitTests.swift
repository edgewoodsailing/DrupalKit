import XCTest
@testable import DrupalKit
import MySQLNIO

final class DrupalKitTests: XCTestCase {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let databasePassword = DrupalKitTests.commandOutput("/usr/local/bin/op", "read", "op://Personal/pl5wgp55jjef5akjhmk4ilzvam/password")
    
    static func commandOutput(_ cmd: String, _ args: String...) -> String {
        let task = Process()
        task.launchPath = cmd
        task.arguments = args

        let outpipe = Pipe()
        task.standardOutput = outpipe

        task.launch()
        
        var output = ""
        if let outdata = try? outpipe.fileHandleForReading.readToEnd(),
           let string = String(data: outdata, encoding: .utf8) {
            output = string.trimmingCharacters(in: .newlines)
        }
        
        task.waitUntilExit()

        return output
    }
    
    func assertIsStuart(user: DrupalUser?) {
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.name, "Stuart Malone")
        XCTAssertEqual(user?.email, "samalone@edgewoodsailing.org")
        XCTAssertEqual(user?.enabled, true)
        XCTAssertEqual(user?.uid, 3)
    }
    
    func withDatabase(action: (DrupalDatabase) async throws -> ()) async throws {
        let eventLoop = group.any()
        let connection = try await MySQLConnection.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 3306),
                                                   username: "root",
                                                   database: "ess_drupal",
                                                   password: databasePassword,
                                                   on: eventLoop).get()
        let db = DrupalDatabase(db: connection)
        try await action(db)
        try await connection.close().get()
    }
    
    func testFindUserByName() async throws {
        try await withDatabase { db in
            let user = await db.findUser(name: "Stuart Malone")
            assertIsStuart(user: user)
        }
    }
    
    func testFindUserByEmail() async throws {
        try await withDatabase { db in
            let user = await db.findUser(email: "samalone@edgewoodsailing.org")
            assertIsStuart(user: user)
        }
    }
    
    func testFindUserByUID() async throws {
        try await withDatabase { db in
            let user = await db.findUser(uid: 3)
            assertIsStuart(user: user)
        }
    }
    
    func testLogin() async throws {
        let pw = DrupalKitTests.commandOutput("/usr/local/bin/op", "read", "op://Personal/h7qfpqkoszgsxhokskzrimccea/password")
        try await withDatabase { db in
            let user = await db.login(name: "Stuart Malone", password: pw)
            assertIsStuart(user: user)
        }
    }
}
