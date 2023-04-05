//
//  DrupalDatabase.swift
//  
//
//  Created by Stuart A. Malone on 4/5/23.
//

import Foundation
import MySQLNIO
import Crypto

public struct DrupalDatabase {
    let db: MySQLDatabase
    
    public init(db: MySQLDatabase) {
        self.db = db
    }
    
    private func makeUser(_ row: MySQLRow) -> DrupalUser {
        return DrupalUser(uid: row.column("uid")?.int ?? 0,
                          name: row.column("name")?.string ?? "",
                          email: row.column("mail")?.string ?? "",
                          enabled: row.column("status")?.bool ?? false)
    }
    
    public static func md5(string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
    
    public func login(name: String, password: String) async -> DrupalUser? {
        var user: DrupalUser? = nil
        do {
            try await db.query("SELECT uid, name, mail, status FROM users WHERE status AND name = ? AND pass = ? LIMIT 1",
                               [MySQLData(string: name), MySQLData(string: DrupalDatabase.md5(string: password))]) { row in
                user = makeUser(row)
            }.get()
        }
        catch {
            print(error)
        }
        return user
    }
    
    public func login(email: String, password: String) async -> DrupalUser? {
        var user: DrupalUser? = nil
        do {
            try await db.query("SELECT uid, name, mail, status FROM users WHERE status AND mail = ? AND pass = ? LIMIT 1",
                               [MySQLData(string: email), MySQLData(string: DrupalDatabase.md5(string: password))]) { row in
                user = makeUser(row)
            }.get()
        }
        catch {
            print(error)
        }
        return user
    }
    
    public func findUser(name: String) async -> DrupalUser? {
        var user: DrupalUser? = nil
        do {
            try await db.query("SELECT uid, name, mail, status FROM users WHERE name = ? LIMIT 1", [MySQLData(string: name)]) { row in
                user = makeUser(row)
            }.get()
        }
        catch {
            print(error)
        }
        return user
    }
    
    public func findUser(email: String) async -> DrupalUser? {
        var user: DrupalUser? = nil
        do {
            try await db.query("SELECT uid, name, mail, status FROM users WHERE mail = ? LIMIT 1", [MySQLData(string: email)]) { row in
                user = makeUser(row)
            }.get()
        }
        catch {
            print(error)
        }
        return user
    }
    
    public func findUser(uid: Int) async -> DrupalUser? {
        var user: DrupalUser? = nil
        do {
            try await db.query("SELECT uid, name, mail, status FROM users WHERE uid = ? LIMIT 1", [MySQLData(int: uid)]) { row in
                user = makeUser(row)
            }.get()
        }
        catch {
            print(error)
        }
        return user
    }
}
