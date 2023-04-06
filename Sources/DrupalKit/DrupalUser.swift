//
//  DrupalUser.swift
//  
//
//  Created by Stuart A. Malone on 4/5/23.
//

import Foundation
import MySQLNIO
import Crypto

public struct DrupalUser: Codable {
    public let uid: Int
    public let name: String
    public let email: String
    public let enabled: Bool
    public var permissions: Set<String> = []
    
    public init(uid: Int, name: String, email: String, enabled: Bool) {
        self.uid = uid
        self.name = name
        self.email = email
        self.enabled = enabled
    }
    
    public init(row: MySQLRow) {
        self.uid = row.column("uid")?.int ?? 0
        self.name = row.column("name")?.string ?? ""
        self.email = row.column("mail")?.string ?? ""
        self.enabled = row.column("status")?.bool ?? false
    }
    
    public func hasPermission(_ permission: String) -> Bool {
        return permissions.contains(permission)
    }
    
    public static func md5(string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
    
    public mutating func loadPermissions(from db: MySQLDatabase) async {
        do {
            var newPermissions: Set<String> = []
            try await db.query("SELECT p.perm FROM ess_drupal.permission AS p JOIN ess_drupal.users_roles AS ur USING (rid) WHERE ur.uid = ?", [MySQLData(int: uid)]) { row in
                if let perm = row.column("perm")?.string {
                    for p in perm.split(separator: ", ") {
                        newPermissions.insert(String(p))
                    }
                }
            }.get()
            self.permissions = newPermissions
        }
        catch {
            print(error)
        }
    }
}

extension MySQLDatabase {
    
    private func getUser(sql: String, binds: [MySQLData]) async -> DrupalUser? {
        var user: DrupalUser? = nil
        do {
            try await query(sql,binds) { row in
                user = DrupalUser(row: row)
            }.get()
            await user?.loadPermissions(from: self)
        }
        catch {
            print(error)
        }
        return user
    }
    
    public func findUser(name: String) async -> DrupalUser? {
        return await getUser(sql: "SELECT uid, name, mail, status FROM ess_drupal.users WHERE name = ? LIMIT 1",
                             binds: [MySQLData(string: name)])
    }
    
    public func findUser(email: String) async -> DrupalUser? {
        return await getUser(sql: "SELECT uid, name, mail, status FROM ess_drupal.users WHERE mail = ? LIMIT 1",
                             binds: [MySQLData(string: email)])
    }
    
    public func findUser(uid: Int) async -> DrupalUser? {
        return await getUser(sql: "SELECT uid, name, mail, status FROM ess_drupal.users WHERE uid = ? LIMIT 1",
                             binds: [MySQLData(int: uid)])
    }
    
    public func login(name: String, password: String) async -> DrupalUser? {
        return await getUser(sql: "SELECT uid, name, mail, status FROM ess_drupal.users WHERE status AND name = ? AND pass = ? LIMIT 1",
                                 binds: [MySQLData(string: name), MySQLData(string: DrupalUser.md5(string: password))])
    }
    
    public func login(email: String, password: String) async -> DrupalUser? {
        return await getUser(sql: "SELECT uid, name, mail, status FROM ess_drupal.users WHERE status AND mail = ? AND pass = ? LIMIT 1",
                                 binds: [MySQLData(string: email), MySQLData(string: DrupalUser.md5(string: password))])
    }

}
