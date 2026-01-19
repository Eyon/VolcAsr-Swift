//
//  VolcAsrClient.swift
//  VolcAsrWrapper
//
//  Created by YourName.
//

import Foundation
import SpeechEngineToB

public class VolcAsrClient: NSObject, SpeechEngineDelegate {
    
    // MARK: - Public Properties
    public weak var delegate: VolcAsrDelegate?
    
    // MARK: - Private Properties
    private var engine: SpeechEngine?
    private let config: VolcConfig
    private var currentModel: VolcAsrModel = .standard
    
    // 内部常量 (SDK 头文件中未定义但协议需要的)
    private let PROTOCOL_WEBSOCKET = 0
    private let PROTOCOL_SEED = 1
    
    // MARK: - Initialization
    public init(config: VolcConfig) {
        self.config = config
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 配置并初始化引擎
    /// - Parameters:
    ///   - model: 识别模型 (标准版/大模型/豆包)
    ///   - params: 参数配置 (不传则使用默认值: 开启ITN/标点, 关闭VAD)
    public func setup(for model: VolcAsrModel, params: VolcAsrParams = VolcAsrParams()) {
        self.currentModel = model
        
        // 1. 清理旧引擎
        if engine != nil {
            engine?.destroy()
            engine = nil
        }
        
        // 2. 创建实例
        engine = SpeechEngine()
        engine?.createEngine(with: self)
        
        // 3. 配置核心环境 (鉴权、网络、音频源)
        configureCoreEnv(model: model)
        
        // 4. 配置业务参数 (核心映射逻辑)
        configureRecognitionParams(params: params)
        
        // 5. 初始化
        let ret = engine?.initEngine()
        if ret != SENoError {
            let errMsg = "[VolcAsr] 引擎初始化失败 Code: \(String(describing: ret))"
            print("❌ \(errMsg)")
            delegate?.onAsrError(msg: errMsg)
        } else {
            print("[VolcAsr] 引擎初始化成功: \(model)")
        }
    }
    
    /// 开始录音
    public func start() {
        print("[VolcAsr] Start Recording...")
        // 强制同步停止一次，确保状态复位
        _ = engine?.send(SEDirectiveSyncStopEngine, data: "")
        _ = engine?.send(SEDirectiveStartEngine, data: "")
    }
    
    /// 停止录音 (等待剩余结果返回)
    public func stop() {
        print("[VolcAsr] Stop Recording...")
        _ = engine?.send(SEDirectiveFinishTalking, data: "")
    }
    
    /// 立即取消 (不等待结果)
    public func cancel() {
        _ = engine?.send(SEDirectiveStopEngine, data: "")
    }
    
    // MARK: - Private Configuration
    
    private func configureCoreEnv(model: VolcAsrModel) {
        // 日志级别: Debug模式下开启详细日志
        #if DEBUG
        engine?.setStringParam(SE_LOG_LEVEL_DEBUG, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
        #else
        engine?.setStringParam(SE_LOG_LEVEL_WARN, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
        #endif
        
        // 引擎类型: ASR
        engine?.setStringParam(SE_ASR_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
        
        // 鉴权信息
        engine?.setStringParam(config.appId, forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine?.setStringParam(config.uid, forKey: SE_PARAMS_KEY_UID_STRING)
        
        // 音频源: 内置录音机
        engine?.setStringParam(SE_RECORDER_TYPE_RECORDER, forKey: SE_PARAMS_KEY_RECORDER_TYPE_STRING)
        
        // 协议与网络差异化配置
        switch model {
        case .standard:
            // V2 WebSocket 协议
            engine?.setStringParam("wss://openspeech.bytedance.com", forKey: SE_PARAMS_KEY_ASR_ADDRESS_STRING)
            engine?.setStringParam("/api/v2/asr", forKey: SE_PARAMS_KEY_ASR_URI_STRING)
            engine?.setStringParam("Bearer;" + config.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
            engine?.setStringParam(model.resourceID, forKey: SE_PARAMS_KEY_ASR_CLUSTER_STRING)
            // 标准版需要显式指定 protocol_type 为 0 (虽然通常是默认值)
            engine?.setIntParam(PROTOCOL_WEBSOCKET, forKey: SE_PARAMS_KEY_PROTOCOL_TYPE_INT)
            
        case .seedAsr, .bigModel:
            // V3 Seed 协议
            engine?.setStringParam("wss://openspeech.bytedance.com", forKey: SE_PARAMS_KEY_ASR_ADDRESS_STRING)
            engine?.setStringParam("/api/v3/sauc/bigmodel_async", forKey: SE_PARAMS_KEY_ASR_URI_STRING)
            // V3 不需要 Bearer 前缀
            engine?.setStringParam(config.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
            engine?.setStringParam(model.resourceID, forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)
            engine?.setIntParam(PROTOCOL_SEED, forKey: SE_PARAMS_KEY_PROTOCOL_TYPE_INT)
            
            // ⚠️ 关键: V3 大模型通常需要在 request params 中带上 model_name
            // 虽然 SDK 可能自动处理，但为了保险，显式添加
            engine?.setStringParam("bigmodel", forKey: "model_name")
        }
    }
    
    private func configureRecognitionParams(params: VolcAsrParams) {
        // --- 1. ITN (数字转写) ---
        // 对应头文件: SE_PARAMS_KEY_ASR_ENABLE_ITN_BOOL
        engine?.setBoolParam(params.enableItn, forKey: SE_PARAMS_KEY_ASR_ENABLE_ITN_BOOL)
        
        // --- 2. 标点符号 ---
        // 对应头文件: SE_PARAMS_KEY_ASR_SHOW_NLU_PUNC_BOOL (优先级高于普通的 SHOW_PUNC)
        engine?.setBoolParam(params.enablePunc, forKey: SE_PARAMS_KEY_ASR_SHOW_NLU_PUNC_BOOL)
        
        // --- 3. 顺滑 (DDC) ---
        // 对应头文件: SE_PARAMS_KEY_ASR_ENABLE_DDC_BOOL
        engine?.setBoolParam(params.enableDdc, forKey: SE_PARAMS_KEY_ASR_ENABLE_DDC_BOOL)
        
        // --- 4. 自动判停 (VAD) ---
        // 对应头文件: SE_PARAMS_KEY_ASR_AUTO_STOP_BOOL
        engine?.setBoolParam(params.autoStop, forKey: SE_PARAMS_KEY_ASR_AUTO_STOP_BOOL)
        
        if params.autoStop {
            // VAD 静音阈值: SE_PARAMS_KEY_VAD_TAIL_SILENCE_THRESHOLD_INT
            engine?.setIntParam(params.vadTailSilence, forKey: SE_PARAMS_KEY_VAD_TAIL_SILENCE_THRESHOLD_INT)
        }
        
        // --- 5. 结果返回模式 ---
        // 默认使用流式增量返回: SE_ASR_RESULT_TYPE_SINGLE
        engine?.setStringParam(SE_ASR_RESULT_TYPE_SINGLE, forKey: SE_PARAMS_KEY_ASR_RESULT_TYPE_STRING)
        
        // --- 6. 额外透传参数 ---
        print("[VolcAsr] 配置参数: ITN=\(params.enableItn), Punc=\(params.enablePunc), Extras=\(params.extras)")
        
        for (key, value) in params.extras {
            if let boolVal = value as? Bool {
                engine?.setBoolParam(boolVal, forKey: key)
            } else if let stringVal = value as? String {
                engine?.setStringParam(stringVal, forKey: key)
            } else if let intVal = value as? Int {
                engine?.setIntParam(intVal, forKey: key)
            } else if let doubleVal = value as? Double {
                engine?.setDoubleParam(doubleVal, forKey: key)
            }
        }
    }
    
    // MARK: - SDK Delegate
    
    public func onMessage(with type: SEMessageType, andData data: Data) {
        switch type {
        case SEAsrPartialResult, SEFinalResult:
            // 收到识别结果
            parseResult(data: data)
            
        case SEEngineError:
            // 收到错误
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["err_msg"] as? String {
                print("[VolcAsr] SDK Error: \(msg)")
                delegate?.onAsrError(msg: msg)
            }
            
        default:
            break
        }
    }
    
    private func parseResult(data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            var text: String?
            var isFinal = false
            
            // 解析标准版 (V2 - 结果在数组中)
            if let resultWrap = json["result"] as? [[String: Any]],
               let firstResult = resultWrap.first {
                text = firstResult["text"] as? String
            }
            // 解析大模型 (V3 - 结果在字典中)
            else if let resultDict = json["result"] as? [String: Any] {
                text = resultDict["text"] as? String
            }
            
            // 判断是否是 Final 包 (部分协议支持)
            // 注意：SDK 可能会通过 SEFinalResult 消息类型回调，这里也可以辅助判断
            
            if let validText = text, !validText.isEmpty {
                delegate?.onAsrResult(text: validText, isFinal: isFinal)
            }
        } catch {
            print("[VolcAsr] JSON Parse Error")
        }
    }
}
