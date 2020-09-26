//
//  AppAnalyser.swift
//  AppAnalyser
//
//  Created by Apple on 2020/9/22.
//  Copyright © 2020 JST. All rights reserved.
//

import ArgumentParser
import Cocoa
import Logging


struct AppAnalyser: ParsableCommand {
    
    static let sharedLogger = Logger(label: "Analyser")
    
    @Argument(help: "The path to an .app bundle.")
    var path: String
    
    func run() throws {
        let guessedTarget = try AppAnalyser.guessedBundleTarget(from: URL(fileURLWithPath: path))
        dump(guessedTarget)
    }
    
    static func guessedFileTarget(from executableURL: URL, parent: Target) -> Target {
        
        // standalone dynamic library
        if executableURL.hasExtensions(["dylib", "so"]) {
            return FrameworkTarget(
                category: .standalone,
                platforms: parent.platforms,
                bundleIdentifier: parent.bundleIdentifier,
                bundleURL: parent.bundleURL,
                executableURL: executableURL
            )
        }
        
        // command line tool
        return AppTarget(
            category: .commandLineTool,
            platforms: parent.platforms,
            bundleIdentifier: parent.bundleIdentifier,
            bundleURL: parent.bundleURL,
            executableURL: executableURL
        )
        
    }
    
    static func guessedBundleTarget(from bundleURL: URL, parent: Target? = nil) throws -> Target {
        
        var inheritedPlatforms = parent?.platforms
        var testTarget: Target?
        
        guard bundleURL.hasExtensions(["app", "appex", "framework"]) else {
            throw ValidationError("bundle url has unsupported path extension: \(bundleURL.pathExtension)")
        }
        
        var infoPlistURL: URL?
        infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist", isDirectory: false)
        if !infoPlistURL!.itemExists {
            infoPlistURL = bundleURL.appendingPathComponent("Info.plist", isDirectory: false)
        }
        if !infoPlistURL!.itemExists {
            infoPlistURL = bundleURL.appendingPathComponent("Resources/Info.plist", isDirectory: false)
        }
        guard infoPlistURL!.fileExists else {
            throw ValidationError("cannot locate Info.plist: \(infoPlistURL!.path)")
        }
        
        guard let infoPlistContent = infoPlistURL!.propertyListContents as? [String: Any] else {
            throw ValidationError("cannot read contents of Info.plist: \(infoPlistURL!.path)")
        }
        guard let bundleIdentifier = infoPlistContent["CFBundleIdentifier"] as? String else {
            throw ValidationError("missing required CFBundleIdentifier key in Info.plist: \(infoPlistURL!.path)")
        }
        guard let bundleExecutable = infoPlistContent["CFBundleExecutable"] as? String else {
            throw ValidationError("missing required CFBundleExecutable key in Info.plist: \(infoPlistURL!.path)")
        }
        inheritedPlatforms = (infoPlistContent["CFBundleSupportedPlatforms"] as? [String]) ?? ["MacOSX"]
        
        var bundleExecutableURL: URL?
        bundleExecutableURL = bundleURL.appendingPathComponent(bundleExecutable, isDirectory: false)
        if !bundleExecutableURL!.fileExists {
            bundleExecutableURL = bundleURL
                .appendingPathComponent("Contents/MacOS", isDirectory: true)
                .appendingPathComponent(bundleExecutable, isDirectory: false)
        }
        if !bundleExecutableURL!.fileExists {
            bundleExecutableURL = bundleURL.appendingPathComponent(
                bundleURL.deletingPathExtension().lastPathComponent,
                isDirectory: false
            )  // fall back
        }
        bundleExecutableURL = bundleExecutableURL!.resolvingSymlinksInPath()
        guard bundleExecutableURL!.fileExists else {
            throw ValidationError("cannot locate bundle executable: \(bundleExecutableURL!.path)")
        }
        
        var executableEntitlements: Entitlements?
        if bundleURL.hasExtensions(["app", "appex"]) {
            do {
                executableEntitlements = try EntitlementsReader(bundleExecutableURL!.path).readEntitlements()
            } catch {
                AppAnalyser.sharedLogger.warning("cannot read entitlements from executable: \(bundleExecutableURL!.path)")
            }
        }
        
        var embeddedProfileURL: URL?
        embeddedProfileURL = bundleURL.appendingPathComponent("Contents/embedded.provisionprofile", isDirectory: false)
        if !embeddedProfileURL!.itemExists {
            embeddedProfileURL = bundleURL.appendingPathComponent("embedded.provisionprofile", isDirectory: false)
        }
        var embeddedProfile: ProvisioningProfile?
        if embeddedProfileURL!.fileExists {
            embeddedProfile = try ProvisioningProfile.parse(from: try Data(contentsOf: embeddedProfileURL!))
        }
        
        if bundleURL.hasExtension("app") {
            testTarget = AppTarget(
                category: .application,
                platforms: inheritedPlatforms!,
                bundleIdentifier: bundleIdentifier,
                bundleURL: bundleURL,
                executableURL: bundleExecutableURL!,
                executableEntitlements: executableEntitlements,
                embeddedMobileProvision: embeddedProfile
            )
        }
        else if bundleURL.hasExtension("framework") {
            testTarget = FrameworkTarget(
                category: .framework,
                platforms: inheritedPlatforms!,
                bundleIdentifier: bundleIdentifier,
                bundleURL: bundleURL,
                executableURL: bundleExecutableURL!
            )
        }
        else if bundleURL.hasExtension("appex"), let appexProperties = infoPlistContent["NSExtension"] as? [String: Any], let appexCategory = appexProperties["NSExtensionPointIdentifier"] as? String
        {
            testTarget = AppExTarget(
                category: appexCategory,
                platforms: inheritedPlatforms!,
                bundleIdentifier: bundleIdentifier,
                bundleURL: bundleURL,
                executableURL: bundleExecutableURL!,
                executableEntitlements: executableEntitlements,
                embeddedMobileProvision: embeddedProfile
            )
        }
        
        guard inheritedPlatforms != nil, testTarget != nil else {
            throw ValidationError("cannot locate at least one valid target from bundle: \(bundleURL.path)")
        }
        
        // process child items
        let childItemEnumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: [.isDirectoryKey, .isExecutableKey, .isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])!
        
        for case let childItemURL as URL in childItemEnumerator {
            
            // skip bundle executable of root target
            if childItemURL == bundleExecutableURL {
                continue
            }
            
            let childItemAttributes = try childItemURL.resourceValues(forKeys: [.isDirectoryKey, .isExecutableKey, .isRegularFileKey])
            if !(childItemAttributes.isDirectory!) && childItemAttributes.isRegularFile! && childItemAttributes.isExecutable!
            {
                let handler = try FileHandle(forReadingFrom: childItemURL)
                let magic = [UInt8](handler.readData(ofLength: 4))
                if magic == [ 0xca, 0xfe, 0xba, 0xbe ] /* FAT Binaries */ || magic == [ 0xcf, 0xfa, 0xed, 0xfe ]
                {
                    let childTarget = guessedFileTarget(from: childItemURL, parent: testTarget!)
                    testTarget!.childTargets.append(childTarget)
                }
            }
            else if childItemAttributes.isDirectory! && childItemURL.hasExtensions(["app", "appex", "framework"]) {
                let childTarget = try guessedBundleTarget(from: childItemURL, parent: testTarget!)
                testTarget!.childTargets.append(childTarget)
                childItemEnumerator.skipDescendants()
            }
            
        }
        
        return testTarget!
        
    }
    
}

