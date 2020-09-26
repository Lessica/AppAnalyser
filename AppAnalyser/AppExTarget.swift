//
//  AppExTarget.swift
//  AppAnalyser
//
//  Created by Apple on 2020/9/25.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation


class AppExTarget: Target {
    
    static let bundleExtension = "appex"
    static let bestProductType = "com.apple.product-type.app-extension"
    
    typealias Category = String
    
    let category: Category
    let platforms: [Platform]
    let bundleIdentifier: String
    let bundlePath: String
    let executablePath: String
    
    var executableEntitlements: Entitlements?
    var embeddedMobileProvision: ProvisioningProfile?
    var bundleURL: URL { URL(fileURLWithPath: bundlePath) }
    var executableURL: URL { URL(fileURLWithPath: executablePath) }
    
    init(category: Category, platforms: [Platform], bundleIdentifier: String, bundleURL: URL, executableURL: URL) {
        self.category = category
        self.platforms = platforms
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundleURL.path
        self.executablePath = executableURL.path
        self.executableEntitlements = nil
        self.embeddedMobileProvision = nil
    }
    
    convenience init(
        category: Category,
        platforms: [Platform],
        bundleIdentifier: String,
        bundleURL: URL,
        executableURL: URL,
        executableEntitlements: Entitlements?,
        embeddedMobileProvision: ProvisioningProfile?
    )
    {
        self.init(
            category: category,
            platforms: platforms,
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL,
            executableURL: executableURL
        )
        self.executableEntitlements = executableEntitlements
        self.embeddedMobileProvision = embeddedMobileProvision
    }
    
    var childTargets = [Target]()
    var description: String { "Application Extension Target" }
    
}

