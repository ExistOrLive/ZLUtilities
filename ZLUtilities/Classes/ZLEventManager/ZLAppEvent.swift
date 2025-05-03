//
//  ZLAppEvent.swift
//  ZLServiceFramework
//
//  Created by 朱猛 on 2021/4/2.
//  Copyright © 2021 ZM. All rights reserved.
//

import UIKit
import FirebaseAnalytics
import Umbrella

public let analytics : Umbrella.Analytics<ZLAppEvent> = {
    let tmpAnalytics =  Umbrella.Analytics<ZLAppEvent>()
    tmpAnalytics.register(provider:ZLFirebaseProvider())
    return tmpAnalytics
}()

final class ZLFirebaseProvider : ProviderType {
    func log(_ eventName: String, parameters: [String : Any]?) {
        FirebaseAnalytics.Analytics.logEvent(eventName, parameters: parameters)
    }
}


@objcMembers public class ZLAppEventForOC : NSObject {
            
    public class func urlUse(url : String){
        analytics.log(.URLUse(url: url))
    }
    
    public class func urlFailed(url : String, error: String?){
        analytics.log(.URLFailed(url: url , error: error ?? ""))
    }
    
    public class func dbActionFailed(sql:String,error:String?){
        analytics.log(.DBActionFailed(sql: sql, error: error ?? ""))
    }
}




public enum ZLAppEvent {
    case githubOAuth(result:Bool,step:Int,msg:String,duration:TimeInterval)     /// OAuth 登录
    case viewItem(name:String)
    case URLUse(url:String)
    case URLFailed(url:String,error:String)
    case ScreenView(screenName:String,screenClass:String)
    case SearchItem(key:String)
    case DBActionFailed(sql:String,error:String)
    case AD(success:Bool)
    case githubAvatarDownload(result:Bool,duration:TimeInterval,type:Int,url: String,cacheType: Int,errorMsg:String)   /// 头像下载
    case zlRemoteConfigDownload(result:Bool,duration:TimeInterval,errorMsg:String)   /// 远程配置文件下载
    case zlRemoteConfigError(errorMsg: String, configStr: String)                    /// 配置解析失败
    

}

extension ZLAppEvent : EventType {
    public func name(for provider: ProviderType) -> String? {
        switch self {
        case .githubOAuth:
            return "githubOAuth"
        case .viewItem:
            return AnalyticsEventViewItem
        case .URLUse:
            return "URLUse"
        case .URLFailed:
            return "URLFailed"
        case .ScreenView:
            return AnalyticsEventScreenView
        case .SearchItem:
            return AnalyticsEventSearch
        case .DBActionFailed:
            return "DBActionFailed"
        case .AD:
            return "Advertisement"
        case .githubAvatarDownload:
            return "githubAvatarDownload"
        case .zlRemoteConfigDownload:
            return "zlRemoteConfigDownload"
        case .zlRemoteConfigError:
            return "zlRemoteConfigError"
        }
        
        

    }
    public func parameters(for provider: ProviderType) -> [String: Any]? {
        switch self {
        case .githubOAuth(let result,let step,let msg,let duration):
            return ["result": result,
                    "step": step,
                    "msg": msg,
                    "duration": duration]
        case .viewItem(let name):
            return ["itemName":name]
        case .URLUse(let url):
            return ["url":url]
        case .URLFailed(let url, let error):
            return ["url":url,"error":error]
        case .ScreenView(let screenName, let screenClass):
            return [AnalyticsParameterScreenName:screenName,AnalyticsParameterScreenClass:screenClass]
        case .SearchItem(let key):
            return ["key":key]
        case .DBActionFailed(let sql, let error):
            return ["sql":sql,"error":error]
        case .AD(let success):
            return ["success":success]
        case .githubAvatarDownload(let result,let duration,let type,let url,let cacheType,let errorMsg):
            return ["result": result,
                    "duration": duration,
                    "type": type,
                    "url": url,
                    "cacheType": cacheType,
                    "errorMsg": errorMsg]
        case .zlRemoteConfigDownload(let result, let duration,let errorMsg):
            return ["result": result,
                    "duration":duration,
                    "errorMsg": errorMsg]
        case .zlRemoteConfigError(let errorMsg,let configStr):
            return ["errorMsg": errorMsg,
                    "configStr":configStr]
        }
    }
}
