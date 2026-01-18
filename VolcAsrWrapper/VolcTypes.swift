//
//  VolcTypes.swift
//  VolcAsrWrapper
//
//  Created by YourName.
//

import Foundation

/// 语音识别模型类型
public enum VolcAsrModel {
    /// 标准流式版 (WebSocket V2) - 对应资源: volcengine_input_common
    case standard
    
    /// 大模型流式版 (Seed V3) - 对应资源: volc.bigasr.sauc.duration
    case bigModel
    
    // 内部获取 Resource ID / Cluster
    var resourceID: String {
        switch self {
        case .standard: return "volcengine_input_common"
        case .bigModel: return "volc.bigasr.sauc.duration"
        }
    }
}

/// 初始化配置项
public struct VolcConfig {
    public let appId: String
    public let token: String // 填入原始 Token 即可，无需手动加 Bearer
    public let uid: String
    
    public init(appId: String, token: String, uid: String) {
        self.appId = appId
        self.token = token
        self.uid = uid
    }
}

/// 代理协议，用于接收结果和错误
public protocol VolcAsrDelegate: AnyObject {
    /// 收到识别结果
    /// - Parameters:
    ///   - text: 识别出的文本
    ///   - isFinal: 是否是最终结果 (目前大模型版支持较好，标准版视配置而定)
    func onAsrResult(text: String, isFinal: Bool)
    
    /// 发生错误
    func onAsrError(msg: String)
}
