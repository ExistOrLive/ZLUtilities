//
//  ZLAGConnectManager.swift
//  ZLGitHubClient
//
//  Created by 朱猛 on 2024/2/24.
//  Copyright © 2024 ZM. All rights reserved.
//

import UIKit

public func ZLAGC() -> ZLAGConnectManager {
    ZLAGConnectManager.sharedInstance
}

@objc public class ZLAGConnectManager: NSObject {

    @objc public static let sharedInstance: ZLAGConnectManager = ZLAGConnectManager()
    
    /// 启动监控/分析
    @objc public func setup() {
        
    }
    
 
}

// MARK: - remote config
public extension ZLAGConnectManager {
    
    @objc func configAsBool(for key: String, defaultValue: Bool = false) -> Bool {
       return defaultValue
    }
    
    @objc func configAsInt(for key: String, defaultValue: Int = 0) -> Int {
        return defaultValue
    }
    
    @objc func configAsString(for key: String, defaultValue: String = "") -> String {
        return defaultValue
    }
    
    @objc func configAsJsonObject(for key: String, defaultValue: [String:Any] = [:]) -> [String:Any] {
        return defaultValue
    }
}

// MARK: - Analyze
public extension ZLAGConnectManager {
    
    @objc func reportEvent(eventId: String, params: [String:Any]) {
        
    }
    
}
