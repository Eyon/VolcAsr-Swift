//
//  VolcTypes.swift
//  VolcAsrWrapper
//
//  Created by YourName.
//

import Foundation

// MARK: - 模型类型定义
public enum VolcAsrModel {
    /// 一句话识别-1 分钟版 (WebSocket V2)
    /// 适用于：短语音、指令交互
    case standard
    
    /// 大模型流式版 (Seed V3)
    /// 适用于：长语音、高精度要求场景
    case bigModel
    
    /// 豆包大模型 2.0 (Seed V3 - 小时版)
    /// 适用于：最新模型，效果最好
    case seedAsr
    
    /// 内部使用的 Resource ID
    var resourceID: String {
        switch self {
        case .standard: return "volcengine_input_common"
        case .bigModel: return "volc.bigasr.sauc.duration"
        case .seedAsr:  return "volc.seedasr.sauc.duration"
        }
    }
}

// MARK: - 基础鉴权配置
public struct VolcConfig {
    public let appId: String
    public let token: String
    public let uid: String
    
    public init(appId: String, token: String, uid: String) {
        self.appId = appId
        self.token = token
        self.uid = uid
    }
}

// MARK: - 核心识别参数配置 (Strong Typed)
/// 用于控制识别行为的参数集合
/// 这里的每个属性都对应 SDK 内部的一个常量配置
public struct VolcAsrParams {
    
    // --- 核心显示控制 ---
    
    /// 是否开启逆文本标准化 (ITN)
    /// true: 输出 "24" (推荐); false: 输出 "二十四"
    public var enableItn: Bool
    
    /// 是否显示标点符号
    public var enablePunc: Bool
    
    /// 是否开启顺滑 (DDC)
    /// true: 去除 "嗯"、"啊" 等语气词
    public var enableDdc: Bool
    
    // --- 交互控制 ---
    
    /// 是否开启服务端自动判停 (VAD)
    /// true: 用户停止说话一段时间后，SDK 会自动结束录音并返回结果
    public var autoStop: Bool
    
    /// VAD 自动判停的静音阈值 (毫秒)
    /// 默认 2000ms (即 2秒无声则判停)，仅在 autoStop = true 时生效
    /// 对应常量: SE_PARAMS_KEY_VAD_TAIL_SILENCE_THRESHOLD_INT
    public var vadTailSilence: Int
    
    // --- 高级控制 ---
    
    /// 额外的自定义参数 (用于透传 SDK 支持但本结构体未封装的参数)
    public var extras: [String: Any]
    
    /// 初始化默认配置
    public init(enableItn: Bool = true,
                enablePunc: Bool = true,
                enableDdc: Bool = false,
                autoStop: Bool = false,
                vadTailSilence: Int = 2000,
                extras: [String : Any] = [:]) {
        self.enableItn = enableItn
        self.enablePunc = enablePunc
        self.enableDdc = enableDdc
        self.autoStop = autoStop
        self.vadTailSilence = vadTailSilence
        self.extras = extras
    }
}

// MARK: - 代理协议
public protocol VolcAsrDelegate: AnyObject {
    /// 收到识别结果
    /// - Parameters:
    ///   - text: 识别出的文本
    ///   - isFinal: 是否是最终结果
    func onAsrResult(text: String, isFinal: Bool)
    
    /// 发生错误
    func onAsrError(msg: String)
}
