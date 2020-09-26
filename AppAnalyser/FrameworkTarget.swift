//
//  FrameworkTarget.swift
//  AppAnalyser
//
//  Created by Apple on 2020/9/25.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation


class FrameworkTarget: Target {
    
    static let bundleExtension = "framework"
    static let bestProductType = "com.apple.product-type.framework"
    
    enum Category: CustomStringConvertible {
        case framework
        case standalone  // dylib
        var description: String {
            switch self {
            case .framework:
                return "Framework"
            case .standalone:
                return "Standalone Dynamic Library"
            }
        }
    }
    
    let category: Category
    let platforms: [Platform]
    let bundleIdentifier: String
    let bundlePath: String
    let executablePath: String
    
    var bundleURL: URL { URL(fileURLWithPath: bundlePath) }
    var executableURL: URL { URL(fileURLWithPath: executablePath) }
    
    init(category: Category, platforms: [Platform], bundleIdentifier: String, bundleURL: URL, executableURL: URL) {
        self.category = category
        self.platforms = platforms
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundleURL.path
        self.executablePath = executableURL.path
    }
    
    var childTargets = [Target]()
    
    var description: String { "Framework Target" }
    
}

