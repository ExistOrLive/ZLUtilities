//
//  ZLRemoteConfigModel.swift
//  Pods
//
//  Created by 朱猛 on 2025/5/2.
//

import Foundation
import ObjectMapper


enum ZLRemoteConfigSetConditionType: String {
    case appVersion                 ///
    case osVersion
//    case build
//    case model
//    case validTime
//    ///  用户Id
//    case userId
//    case deviceId
//    case isGray
    case unknown
    
    
    static let transform = TransformOf<ZLRemoteConfigSetConditionType, String>(fromJSON: { (value: String?) -> ZLRemoteConfigSetConditionType? in
        return ZLRemoteConfigSetConditionType(rawValue: value ?? "") ?? .unknown
    }, toJSON: { (value: ZLRemoteConfigSetConditionType?) -> String? in
        return value?.rawValue
    })
}


// gt("大于"),gte("大于等于"),eq("等于"),ne("不等于"),lt("小于"),lte("小于等于"),in("包含")
enum ZLRemoteConfigSetOption: String {
    /// 大于
    case gt
    /// 大于等于
    case gte
    /// 等于
    case eq
    /// 不等于
    case ne
    /// 小于
    case lt
    /// 小于等于
    case lte
    /// 包含
    case contain = "in"
    
    case unknown = "unknown"
    
    static let transform = TransformOf<ZLRemoteConfigSetOption, String>(fromJSON: { (value: String?) -> ZLRemoteConfigSetOption? in
        return ZLRemoteConfigSetOption(rawValue: value ?? "") ?? .none
    }, toJSON: { (value: ZLRemoteConfigSetOption?) -> String? in
        return value?.rawValue
    })
}


enum ZLRemoteConfigConditionRelation: String {
    /// 或
    case or
    /// 且
    case and
    
    case unknown = "unknown"

    
    static let transform = TransformOf<ZLRemoteConfigConditionRelation, String>(fromJSON: { (value: String?) -> ZLRemoteConfigConditionRelation? in
        return ZLRemoteConfigConditionRelation(rawValue: value ?? "") ?? .unknown
    }, toJSON: { (value: ZLRemoteConfigConditionRelation?) -> String? in
        return value?.rawValue
    })
}

class ZLRemoteConfigModel: NSObject, Mappable {
    
    /// 默认value
    var value: Any?
    /// 配置值的设置：（按条件匹配配置）
    var settings: [ZLRemoteConfigSettingModel] = []
    
    required init?(map: ObjectMapper.Map) {}
    
    func mapping(map: ObjectMapper.Map) {
        value <- map["value"]
        settings <- map["settings"]
    }
    
}




class ZLRemoteConfigSettingModel: NSObject, Mappable {
    
    /// 符合条件的值
    var value: Any?
    /// and： 多条件同时符合  or：多条件有一个符合
    var conditionRelation: ZLRemoteConfigConditionRelation = .unknown
    /// 条件列表
    var conditionArray: [ZLRemoteConfigConditionModel] = []
    
    required init?(map: ObjectMapper.Map) {}
    
    func mapping(map: ObjectMapper.Map) {
        value <- map["value"]
        conditionRelation <- (map["conditionRelation"],ZLRemoteConfigConditionRelation.transform)
        conditionArray <- map["conditionArray"]
    }
    
}


class ZLRemoteConfigConditionModel: NSObject,Mappable {
    
    /// 条件类型
    var conditionType: ZLRemoteConfigSetConditionType = .unknown
    /// 条件匹配方式
    var conditionOption: ZLRemoteConfigSetOption = .unknown
    /// 条件值
    var conditionValue: [String] = []
    
    required init?(map: ObjectMapper.Map) {}
    
    func mapping(map: ObjectMapper.Map) {
        conditionType <- (map["conditionType"],ZLRemoteConfigSetConditionType.transform)
        conditionOption <- (map["conditionOption"],ZLRemoteConfigSetOption.transform)
        conditionValue <- map["conditionValue"]
    }
    
}
