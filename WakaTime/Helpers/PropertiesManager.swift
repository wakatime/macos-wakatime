//
//  PropertiesManager.swift
//  WakaTime
//
//  Created by Michael Mavris on 11/05/2023.
//

import Foundation

class PropertiesManager {
    static var shouldLaunchOnLogin: Bool {
        get {
            guard UserDefaults.standard.string(forKey: "launch_on_login") != nil else {
                UserDefaults.standard.set(true, forKey: "launch_on_login")
                return true
            }

            return UserDefaults.standard.bool(forKey: "launch_on_login")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "launch_on_login")
            UserDefaults.standard.synchronize()
        }
    }
}
