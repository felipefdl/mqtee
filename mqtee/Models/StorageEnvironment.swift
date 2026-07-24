//
//  StorageEnvironment.swift
//  mqtee
//

import Foundation

enum StorageEnvironment {
    static let isRunningTests: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }()

    static let keyPrefix: String = {
        #if DEBUG
        if isRunningTests {
            return "test."
        }
        return "debug."
        #else
        return ""
        #endif
    }()

    static let sessionsDirName: String = {
        if isRunningTests {
            return "sessions-test"
        }
        #if DEBUG
        return "sessions-debug"
        #else
        return "sessions"
        #endif
    }()
}
