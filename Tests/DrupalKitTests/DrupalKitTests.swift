import XCTest
@testable import DrupalKit
import MySQLNIO

final class DrupalKitTests: XCTestCase {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let databasePassword = DrupalKitTests.commandOutput("/usr/local/bin/op", "read", "op://ess-infrastructure/mysql-root/password")
    var db: MySQLConnection! = nil
    
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
    
    override func setUp() async throws {
        let eventLoop = group.any()
        db = try await MySQLConnection.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 3306),
                                               username: "root",
                                               database: "ess_drupal",
                                               password: databasePassword,
                                               on: eventLoop).get()
    }
    
    override func tearDown() async throws {
        try await db.close().get()
    }
    
    func assertIsStuart(user: DrupalUser?) {
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.name, "Stuart Malone")
        XCTAssertEqual(user?.email, "samalone@edgewoodsailing.org")
        XCTAssertEqual(user?.enabled, true)
        XCTAssertEqual(user?.uid, 3)
    }
    
    func testFindUserByName() async throws {
        let user = await db.findUser(name: "Stuart Malone")
        assertIsStuart(user: user)
    }
    
    func testFindUserByEmail() async throws {
        let user = await db.findUser(email: "samalone@edgewoodsailing.org")
        assertIsStuart(user: user)
    }
    
    func testFindUserByUID() async throws {
        let user = await db.findUser(uid: 3)
        assertIsStuart(user: user)
    }
    
    func testLogin() async throws {
        let pw = DrupalKitTests.commandOutput("/usr/local/bin/op", "read", "op://Personal/h7qfpqkoszgsxhokskzrimccea/password")
        let user = await db.login(name: "Stuart Malone", password: pw)
        assertIsStuart(user: user)
        XCTAssertEqual(user?.hasPermission("view adult statements"), true)
    }
}
