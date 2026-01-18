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
    
    // Constants
    private let KEY_RESOURCE_ID = "resource_id"
    private let KEY_PROTOCOL_TYPE = "protocol_type"
    private let PROTOCOL_WEBSOCKET = 0
    private let PROTOCOL_SEED = 1
    
    // MARK: - Initialization
    public init(config: VolcConfig) {
        self.config = config
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 配置引擎 (切换模型时调用)
    public func setup(for model: VolcAsrModel) {
        self.currentModel = model
        
        // 1. 销毁旧实例
        if engine != nil {
            engine?.destroy()
            engine = nil
        }
        
        // 2. 创建新实例
        engine = SpeechEngine()
        engine?.createEngine(with: self)
        
        // 3. 通用基础配置
        engine?.setStringParam(SE_ASR_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)
        // 调试阶段建议开启 DEBUG，上线可改为 WARN
        engine?.setStringParam(SE_LOG_LEVEL_DEBUG, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
        engine?.setStringParam(config.appId, forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine?.setStringParam(config.uid, forKey: SE_PARAMS_KEY_UID_STRING)
        
        // 4. 差异化配置 (核心分流逻辑)
        switch model {
        case .standard:
            print("[VolcAsr] 初始化: 标准版 (WebSocket/V2)")
            engine?.setStringParam("wss://openspeech.bytedance.com", forKey: SE_PARAMS_KEY_ASR_ADDRESS_STRING)
            engine?.setStringParam("/api/v2/asr", forKey: SE_PARAMS_KEY_ASR_URI_STRING)
            // 标准版需要手动加 Bearer
            engine?.setStringParam("Bearer;" + config.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
            engine?.setStringParam(model.resourceID, forKey: SE_PARAMS_KEY_ASR_CLUSTER_STRING)
            engine?.setIntParam(PROTOCOL_WEBSOCKET, forKey: KEY_PROTOCOL_TYPE)
            
        case .bigModel:
            print("[VolcAsr] 初始化: 大模型 (Seed/V3)")
            engine?.setStringParam("wss://openspeech.bytedance.com", forKey: SE_PARAMS_KEY_ASR_ADDRESS_STRING)
            engine?.setStringParam("/api/v3/sauc/bigmodel", forKey: SE_PARAMS_KEY_ASR_URI_STRING)
            // 大模型不需要 Bearer
            engine?.setStringParam(config.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)
            engine?.setStringParam(model.resourceID, forKey: KEY_RESOURCE_ID)
            engine?.setIntParam(PROTOCOL_SEED, forKey: KEY_PROTOCOL_TYPE)
        }
        
        // 5. 音频源与功能配置
        engine?.setStringParam(SE_RECORDER_TYPE_RECORDER, forKey: SE_PARAMS_KEY_RECORDER_TYPE_STRING)
        engine?.setBoolParam(true, forKey: SE_PARAMS_KEY_ASR_SHOW_NLU_PUNC_BOOL)
        
        // 6. 初始化
        let ret = engine?.initEngine()
        if ret != SENoError {
            let err = "引擎初始化失败 Code: \(String(describing: ret))"
            print("[VolcAsr] ❌ \(err)")
            delegate?.onAsrError(msg: err)
        }
    }
    
    /// 开始录音识别
    public func start() {
        print("[VolcAsr] Start Recording...")
        _ = engine?.send(SEDirectiveSyncStopEngine, data: "")
        _ = engine?.send(SEDirectiveStartEngine, data: "")
    }
    
    /// 停止录音
    public func stop() {
        print("[VolcAsr] Stop Recording...")
        _ = engine?.send(SEDirectiveFinishTalking, data: "")
    }
    
    // MARK: - SDK Delegate
    public func onMessage(with type: SEMessageType, andData data: Data) {
        if type == SEAsrPartialResult || type == SEFinalResult {
            parseResult(data: data)
        } else if type == SEEngineError {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["err_msg"] as? String {
                print("[VolcAsr] SDK Error: \(msg)")
                delegate?.onAsrError(msg: msg)
            }
        }
    }
    
    private func parseResult(data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            var text: String?
            
            // 兼容标准版 (数组结构)
            if let resultWrap = json["result"] as? [[String: Any]],
               let firstResult = resultWrap.first {
                text = firstResult["text"] as? String
            }
            // 兼容大模型版 (字典结构)
            else if let resultDict = json["result"] as? [String: Any] {
                text = resultDict["text"] as? String
            }
            
            if let validText = text {
                delegate?.onAsrResult(text: validText, isFinal: false)
            }
        } catch {
            print("[VolcAsr] JSON Parse Error")
        }
    }
}
