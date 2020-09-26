//
//  URL+Path.swift
//  AppAnalyser
//
//  Created by Apple on 2020/9/22.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension String {
    
    var url: URL { URL(fileURLWithPath: self) }
    var absoluteURL: URL {
        if hasPrefix("/") {
            return URL(fileURLWithPath: self)
        }
        return URL(fileURLWithPath: self, relativeTo: URL.currentDirectoryURL)
    }
    
    var fileURL: URL { URL(fileURLWithPath: self, isDirectory: false) }
    var absoluteFileURL: URL {
        if hasPrefix("/") {
            return URL(fileURLWithPath: self, isDirectory: false)
        }
        return URL(fileURLWithPath: self, isDirectory: false, relativeTo: URL.currentDirectoryURL)
    }
    
    var directoryURL: URL { URL(fileURLWithPath: self, isDirectory: true) }
    var absoluteDirectoryURL: URL {
        if hasPrefix("/") {
            return URL(fileURLWithPath: self, isDirectory: true)
        }
        return URL(fileURLWithPath: self, isDirectory: true, relativeTo: URL.currentDirectoryURL)
    }
    
}

extension Array where Self.Element == String {
    
    public func localizedStandardSorted() -> [Element] {
        return sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
    }

}

extension URL {
    
    static var currentDirectoryURL: URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true) }
    
    var itemExists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    var itemOwnerAccountID: Int16? {
        (try? FileManager.default.attributesOfItem(atPath: path)[FileAttributeKey.ownerAccountID] as? NSNumber)?.int16Value
    }
    
    var itemGroupAccountID: Int16? {
        (try? FileManager.default.attributesOfItem(atPath: path)[FileAttributeKey.groupOwnerAccountID] as? NSNumber)?.int16Value
    }
    
    var itemPermissions: Int16? {
        (try? FileManager.default.attributesOfItem(atPath: path)[FileAttributeKey.posixPermissions] as? NSNumber)?.int16Value
    }
    
    var fileExists: Bool {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }
    
    var directoryExists: Bool {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    var directoryContents: [String]? { try? FileManager.default.contentsOfDirectory(atPath: path).localizedStandardSorted() }
    var directoryContentURLs: [URL]? { directoryContents?.map({ self.appendingPathComponent($0) }) }
    
    var propertyListContents: Any? { try? PropertyListSerialization.propertyList(from: Data.init(contentsOf: self), options: [], format: nil) }
    var JSONContents: Any? { try? JSONSerialization.jsonObject(with: Data.init(contentsOf: self), options: []) }
    func writePropertyList(_ object: Any) throws {
        try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0).write(to: self, options: [.withoutOverwriting])
    }
    func writeJSON(_ object: Any, options opt: JSONSerialization.WritingOptions = []) throws {
        try JSONSerialization.data(withJSONObject: object, options: opt).write(to: self, options: [.withoutOverwriting])
    }
    
    func hasExtension(_ ext: String) -> Bool { pathExtension == ext }
    func hasExtensions(_ exts: [String]) -> Bool { exts.contains(pathExtension) }
    func deletingPathExtensions(_ exts: [String]) -> URL {
        let allSlices = lastPathComponent.split(separator: ".").map({ String($0) })
        var slices = [String]()
        var skipAll = false
        for slice in allSlices.reversed() {
            if !skipAll && exts.contains(slice) {
                continue
            } else {
                slices.append(slice)
                skipAll = true
            }
        }
        return deletingLastPathComponent()
            .appendingPathComponent(
                slices.reversed()
                    .joined(separator: "."))
    }
    
    func takePlace(overwrite: Bool = false) throws {
        try Data().write(to: self, options: overwrite ? [.atomic] : [.withoutOverwriting])
    }
    func dump() {
        if directoryExists {
            let contents = directoryContents
            if contents != nil {
                Swift.dump(contents!)
            }
        }
        else if let contents = propertyListContents {
            Swift.dump(contents)
        }
        else if let contents = JSONContents {
            Swift.dump(contents)
        }
        else {
            Swift.print(path)
        }
    }
    
    func ensureUserPermissions(_ permissions: Int16? = nil) throws {
        if let permissions = permissions {
            try ensure(owner: Int16(getuid()), groupOwner: Int16(getgid()), permissions: permissions)
        } else if directoryExists {
            try ensure(owner: Int16(getuid()), groupOwner: Int16(getgid()), permissions: Int16(0o755))
        } else /* fileExists */ {
            try ensure(owner: Int16(getuid()), groupOwner: Int16(getgid()), permissions: Int16(0o644))
        }
    }
    
    func ensureUserDirectoryExists(permissions: Int16 = Int16(0o755), withIntermediateDirectories createIntermediates: Bool = false) throws {
        try ensureDirectoryExists(owner: Int16(getuid()), groupOwner: Int16(getgid()), permissions: permissions, withIntermediateDirectories: createIntermediates)
    }
    
    func ensure(owner: Int16, groupOwner: Int16, permissions: Int16 = Int16(0o755)) throws {
        try FileManager.default.setAttributes([
            FileAttributeKey.ownerAccountID      : NSNumber(value: owner),
            FileAttributeKey.groupOwnerAccountID : NSNumber(value: groupOwner),
            FileAttributeKey.posixPermissions    : NSNumber(value: permissions),
        ], ofItemAtPath: path)
    }
    
    func ensureDirectoryExists(owner: Int16, groupOwner: Int16, permissions: Int16 = Int16(0o755), withIntermediateDirectories createIntermediates: Bool = false) throws {
        if !itemExists {
            try FileManager.default.createDirectory(at: self, withIntermediateDirectories: createIntermediates, attributes: [
                FileAttributeKey.ownerAccountID      : NSNumber(value: owner),
                FileAttributeKey.groupOwnerAccountID : NSNumber(value: groupOwner),
                FileAttributeKey.posixPermissions    : NSNumber(value: permissions),
            ])
        } else {
            try ensure(owner: owner, groupOwner: groupOwner, permissions: permissions)
        }
    }
    
    func ensureOwnersAndPermissionsSameAs(_ url: URL) throws {
        let dstAttrs = try FileManager.default.attributesOfItem(atPath: url.path)
        try ensure(
            owner: (dstAttrs[FileAttributeKey.ownerAccountID] as! NSNumber).int16Value,
            groupOwner: (dstAttrs[FileAttributeKey.groupOwnerAccountID] as! NSNumber).int16Value,
            permissions: (dstAttrs[FileAttributeKey.posixPermissions] as! NSNumber).int16Value
        )
    }
    
    func ensureParentDirectoryExists() throws {
        guard !itemExists else { return }
        let parentDirectoryURL = deletingLastPathComponent()
        if !parentDirectoryURL.directoryExists {
            try parentDirectoryURL.ensureDirectoryExists(
                owner: Int16(getuid()),
                groupOwner: Int16(getgid()),
                permissions: Int16(0o755),
                withIntermediateDirectories: true
            )
        }
    }
    
    func removeIfExists() throws {
        if itemExists {
            try FileManager.default.removeItem(at: self)
        }
    }
    
    func remove() throws {
        try FileManager.default.removeItem(at: self)
    }
    
    func duplicate(to url: URL) throws {
        try FileManager.default.copyItem(at: self, to: url)
    }
    
    func relativePath(from base: URL) -> String? {
        // Ensure that both URLs represent files:
        guard self.isFileURL && base.isFileURL else {
            return nil
        }

        // Remove/replace "." and "..", make paths absolute:
        let destComponents = self.standardized.resolvingSymlinksInPath().pathComponents
        let baseComponents = base.standardized.resolvingSymlinksInPath().pathComponents

        // Find number of common path components:
        var i = 0
        while i < destComponents.count && i < baseComponents.count
            && destComponents[i] == baseComponents[i] {
                i += 1
        }

        // Build relative path:
        var relComponents = Array(repeating: "..", count: baseComponents.count - i)
        relComponents.append(contentsOf: destComponents[i...])
        return relComponents.joined(separator: "/")
    }
    
}
