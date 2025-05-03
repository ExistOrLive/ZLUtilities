//
//  ZLRemoteConfigManager.swift
//  ZLUtilities
//
//  Created by 朱猛 on 2025/5/2.
//


public func ZLRCM() -> ZLRemoteConfigManager {
    ZLRemoteConfigManager.sharedInstance
}

/// 远程配置管理器
/// 下载，更新，获取远程配置
/// 支持 Bool，Int， String，以及 [String:Any] 配置格式
/// 支持app版本，系统版本等限制条件
@objc public class ZLRemoteConfigManager: NSObject {
    
    /// 远程配置管理器单例
    @objc public static let sharedInstance = ZLRemoteConfigManager()
    
    static let configUserDefaultKey = "ZLRemoteConfigManager_Config"
    
    static let configUpdateTimeUserDefaultKey = "ZLRemoteConfigManager_ConfigUpdateTime"
    
    /// 内存缓存 读写锁
    private var configLock = pthread_rwlock_t()
    
    /// 是否初始化
    private var isInit: Bool = false
    
    /// 远程配置链接
    private var configURL: String = ""
    
    
    /// config 内存缓存
    private var _memoryConfig: [String:Any] = [:]
    private var memoryConfig: [String:Any] {
        get {
            pthread_rwlock_rdlock(&configLock)
            let config = _memoryConfig
            pthread_rwlock_unlock(&configLock)
            return config
        }
        set {
            pthread_rwlock_wrlock(&configLock)
            _memoryConfig = newValue
            pthread_rwlock_unlock(&configLock)
        }
    }
    
    /// config 磁盘缓存
    private var diskConfig: [String:Any] {
        set {
            UserDefaults.standard.set(newValue, forKey: ZLRemoteConfigManager.configUserDefaultKey)
            UserDefaults.standard.synchronize()
        }
        get {
            UserDefaults.standard.value(forKey: ZLRemoteConfigManager.configUserDefaultKey) as? [String:Any] ?? [:]
        }
    }
    
    /// config 更新时间
    private var configUpdateTime: CFAbsoluteTime {
        set {
            UserDefaults.standard.set(newValue, forKey: ZLRemoteConfigManager.configUpdateTimeUserDefaultKey)
            UserDefaults.standard.synchronize()
        }
        get {
            UserDefaults.standard.double(forKey: ZLRemoteConfigManager.configUpdateTimeUserDefaultKey)
        }
    }
    
    override init() {
        super.init()
        pthread_rwlock_init(&configLock, nil)      /// 初始化读写锁
    }
    

    /// 启动远程配置管理器
    /// configURL： 远程配置的链接
    @objc public func setupManager(configURL: String) {
        guard !configURL.isEmpty else {
            assertionFailure("ZLRemoteConfigManager setupManager: configURL is Empty")
            return
        }
        
        self.configURL = configURL
        
        self.memoryConfig = diskConfig
        
        self.isInit = true
        
        self.requestConfig()    /// 更新配置
        
        self.setupAppBecomeActiveSchedule { /// 配置从后台进前台检查配置更新
            self.requestConfigWhenNeed()
        }
    }
    
    
    func setupAppBecomeActiveSchedule(callback: @escaping (() -> Void)) {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { (notify) in
            callback()
        }
    }

    
}


// MARK: - update config
extension ZLRemoteConfigManager {
    
    
    func requestConfigWhenNeed() {
        guard self.isInit else { return }
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - configUpdateTime > 600 else { return }  /// 同一次启动，从后台进前台超过600s更新
        
        requestConfig()
    }
    
    func requestConfig() {
        let startTime = Date().timeIntervalSince1970
        DispatchQueue.global().async {
            do {
                if let url = URL(string: self.configURL ?? "") {
                    let data = try Data(contentsOf: url, options: .uncached)
                    if var config = self.parseToJson(with: data) {
                        let time = Date().timeIntervalSince1970 - startTime
                        self.memoryConfig = config
                        self.diskConfig = config
                        self.configUpdateTime = CFAbsoluteTimeGetCurrent()
                        analytics.log(.zlRemoteConfigDownload(result: true, duration: time, errorMsg: "config url \(self.configURL ?? "")"))
                    } else {
                        let time = Date().timeIntervalSince1970 - startTime
                        analytics.log(.zlRemoteConfigDownload(result: false, duration: time, errorMsg: "config parse error: config url \(self.configURL ?? "")"))
                    }
                } else {
                    analytics.log(.zlRemoteConfigDownload(result: false, duration: 0, errorMsg: "config url \(self.configURL ?? "") is invalid"))
                }
            } catch let err {
                let time = Date().timeIntervalSince1970 - startTime
                analytics.log(.zlRemoteConfigDownload(result: false, duration: time, errorMsg: "config url \(self.configURL ?? "") download fail \(err.localizedDescription)"))
            }
        }
    }
    
    func parseToJson(with data: Data?) -> [String: Any]? {
        guard let data = data else { return nil }
        do {
            let configs = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            return configs
        }
        catch {
            return nil
        }
    }
}


// MARK: - get config method
extension ZLRemoteConfigManager {
    
    public func configAsBool(for key: String, defaultValue: Bool = false) -> Bool {
        if let config = configModelFor(for: key),
           let value = value(by: config) as? Bool {
            return value
        }
        return defaultValue
    }
    
    public func configAsInt(for key: String, defaultValue: Int = 0) -> Int {
        if let config = configModelFor(for: key),
           let value = value(by: config) as? Int {
            return value
        }
        return defaultValue
    }
    
    public func configAsString(for key: String, defaultValue: String = "") -> String {
        if let config = configModelFor(for: key),
           let value = value(by: config) as? String {
            return value
        }
        return defaultValue
    }
    
    public func configAsJsonObject(for key: String, defaultValue: [String:Any] = [:]) -> [String:Any] {
        if let config = configModelFor(for: key),
           let value = value(by: config) as? [String:Any] {
            return value
        }
        return defaultValue
    }
}

extension ZLRemoteConfigManager {
    
    func configModelFor(for key: String) -> ZLRemoteConfigModel? {
        guard let dic = memoryConfig[key] as? [String:Any],
              let model = ZLRemoteConfigModel(JSON: dic) else {
            return nil
        }
        return model
    }
    
    func value(by model: ZLRemoteConfigModel) -> Any? {
        guard !model.settings.isEmpty else {
            return  model.value       /// 不存在条件直接返回value
        }
        
        var isMatch = false
        /// 每个setting、只要要有一个满足，那么就满足。优先级是数组顺序的优先级
        for setting in model.settings {
            
            
            let value = setting.value      /// 命中条件的直接
            
            let conditionRealtion = setting.conditionRelation /// 多条件是 且 还是 或
            
            if setting.conditionArray.isEmpty { /// 条件未空直接过滤
                continue
            }
        
            var isAllMatch = true
            /// 遍历条件
            for condition in setting.conditionArray {
                
                let conditionValue = condition.conditionValue 
                
                switch condition.conditionType {
                case .appVersion:
                    /// APP版本号校验
                    if !conditionValue.filter({!$0.isValidVersion}).isEmpty ||
                        !_compareMatch(option: condition.conditionOption, value: conditionValue, compareValue:ZLDeviceInfo.getAppShortVersion(), isSystem: true) {
                        isAllMatch = false
                    } else if conditionRealtion == .or {
                        return value
                    }
                case .osVersion:
                    /// 系统版本号校验
                    if !conditionValue.filter({!$0.isValidVersion}).isEmpty ||
                        !_compareMatch(option: condition.conditionOption, value: conditionValue, compareValue:ZLDeviceInfo.getDeviceSystemVersion(), isSystem: true) {
                        isAllMatch = false
                    } else if conditionRealtion == .or {
                        return value
                    }
                case .unknown:
                    break
                }
            }
            // 所有条件都遍历完了，都满足，那么isMatch 应该是true。此时直接返回value
            if isAllMatch && conditionRealtion == .and {
                return value
            }
        }
        return model.value
    }
   
    

    /// 包含、相等、不当等的比较操作
    private func _eMatch(option: ZLRemoteConfigSetOption, value: [String], compareValue: String) -> Bool{
        guard let vFirst = value.first else { return false }
        switch option {
        case .contain:
            return value.contains(compareValue)
        case .eq:
            return vFirst == compareValue
        case .ne:
            return vFirst != compareValue
        default:
            return false
        }
    }
    /// 版本比较、系统比较的操作。
    private func _compareMatch(option: ZLRemoteConfigSetOption, value: [String], compareValue: String, isSystem: Bool) -> Bool {
        guard let vFirst = value.first else { return false }
        switch option {
        case .gt:
            // 版本号大于，下发的值。
            return compareValue.versionCompare(version: vFirst) > 0
        case .gte:
            // 版本号大于等于，下发的值。
            return compareValue.versionCompare(version: vFirst) >= 0
        case .lt:
            // 版本号小于，下发的值。
            return compareValue.versionCompare(version: vFirst) < 0
        case .lte:
            return compareValue.versionCompare(version: vFirst) <= 0
        case .eq:
            if isSystem {
                return compareValue == vFirst
            }
            return compareValue.versionCompare(version: vFirst) == 0
        case .ne:
            if isSystem {
                return compareValue != vFirst
            }
            return compareValue.versionCompare(version: vFirst) != 0
        case .contain:
            if isSystem {
                return value.contains(compareValue)
            }
            for x in value {
                if compareValue.versionCompare(version: x) == 0 {
                    return true
                }
            }
            return false
        case .unknown:
            return false
        }
    }
    
    
}


private extension String {

    var isValidVersion: Bool {
        for x in self.components(separatedBy: ".") {
            let digits = CharacterSet.decimalDigits
            if x.hasPrefix("-") {
                return false
            }
            if x.rangeOfCharacter(from: digits.inverted) != nil {
                return false
            }
        }
        return true
    }

    /// 版本号比较 ver1 > ver2 返回1，== 返回0， < 返回-1
    func versionCompare (version: String) -> Int {
        let version1 = self
        let version2 = version
        let verCounts1 = version1.components(separatedBy: ".")
        let verCounts2 = version2.components(separatedBy: ".")
        let count = min(version1.count, version2.count)

        for index in 0 ..< count {
            guard index < verCounts1.count else { continue }
            let count1 = verCounts1[index].intValue
            guard index < verCounts2.count else { continue }
            let count2 = verCounts2[index].intValue
            if count1 > count2 {
                return 1
            } else if count1 < count2 {
                return -1
            }
            // 相等继续循环
        }

        // 如果相等，位数判断
        if verCounts1.count > verCounts2.count {
            return 1
        } else if verCounts1.count < verCounts2.count {
            return -1
        }
        return 0
    }

    var intValue: Int {
        if self.isEmpty {
            return 0
        }
        let str = self.pregReplace(pattern: "[^\\d]+", with: "")
        return Int(str) ?? 0
    }


    //使用正则表达式替换
    func pregReplace(pattern: String, with: String,
                     options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return "" }
        return regex.stringByReplacingMatches(in: self, options: [],
                                              range: NSRange(location: 0, length: self.count),
                                              withTemplate: with)
    }
}
