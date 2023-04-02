//
//  BundleExtension.swift
//  WakaTime
//
//  Created by chester on 2023/4/2.
//

import Foundation

extension Bundle {
    var displayName: String {
        readFromInfoDict(key: "CFBundleDisplayName") ?? "displayName null"
    }

    var version: String {
        readFromInfoDict(key: "CFBundleShortVersionString") ?? "version null"
    }

    var build: String {
        readFromInfoDict(key: "CFBundleVersion") ?? "build null"
    }

    private func readFromInfoDict(key: String) -> String? {
        infoDictionary?[key] as? String
    }
}
