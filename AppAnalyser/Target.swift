//
//  Target.swift
//  AppAnalyser
//
//  Created by Apple on 2020/9/25.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol Target: CustomStringConvertible {
    
    typealias Platform = String
    
    var platforms: [Platform] { get }
    var bundleIdentifier: String { get }
    var bundleURL: URL { get }
    var bundlePath: String { get }
    var executableURL: URL { get }
    var executablePath: String { get }
    
    var childTargets: [Target] { get set }
    
}

