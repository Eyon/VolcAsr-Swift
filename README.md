# VolcAsrWrapper - 火山引擎语音识别 Swift 封装

这是一个轻量级的 Swift 封装库，用于快速集成火山引擎（Volcengine）的语音识别服务。
该封装库屏蔽了底层 WebSocket (V2) 和 Seed (V3) 协议的差异，支持一键切换火山引擎的三大核心语音产品：

1.  **豆包语音识别 2.0**: **(推荐)** 火山引擎最新一代旗舰模型，识别率高，响应速度快。
2.  **流式语音识别大模型**: 通用大模型版本，适用于长语音场景。
3.  **一句话识别(1分钟内)**: 基础版本，适用于短指令和简单交互。

---

## 🚀 1. 新项目集成步骤

### 第一步：Pod 环境配置
打开终端，进入你的新项目目录：

```bash
cd /path/to/your/NewProject
pod init
```

### 第二步：修改 Podfile
打开生成的 `Podfile`，**完全复制**以下内容（注意替换 `Target` 名称）。

```ruby
platform :ios, '12.0'

target 'YourAppName' do # <--- 记得改成你的项目名
  use_frameworks!

  # 火山引擎核心库
  pod 'SpeechEngineToB', '0.0.14.1-bugfix'
  # 网络依赖库
  pod 'SocketRocket'

end

# 消除 iOS 版本过低的警告脚本
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

执行安装：
```bash
pod install
```

### 第三步：导入文件
1. 打开新生成的 `.xcworkspace` 文件。
2. 将本仓库中的 `VolcAsrWrapper` 文件夹（包含 `VolcTypes.swift` 和 `VolcAsrClient.swift`）直接**拖入** Xcode 项目中。
3. 勾选 **"Copy items if needed"**。

### 第四步：权限设置
打开项目的 `Info.plist`，添加麦克风权限：
* **Key**: `Privacy - Microphone Usage Description`
* **Value**: "我们需要您的声音来进行语音识别"

---

## 💻 2. 快速开始

### 2.1 初始化 SDK 环境 (App入口)
在 `App` 结构体的 `init` 中必须调用初始化，否则引擎无法加载。

```swift
import SwiftUI
import SpeechEngineToB // 引入核心库

@main
struct YourApp: App {
    init() {
        // ✅ 必须在 App 启动时调用
        SpeechEngine.prepareEnvironment()
    }
    // ...
}
```

### 2.2 基础调用示例

```swift
class MyViewModel: VolcAsrDelegate {
    private var client: VolcAsrClient!
    
    init() {
        // 1. 配置鉴权 (填入控制台获取的信息)
        let config = VolcConfig(
            appId: "你的APPID",
            token: "你的TOKEN",
            uid: "user_001"
        )
        
        // 2. 初始化
        client = VolcAsrClient(config: config)
        client.delegate = self
        
        // 3. 启动引擎 (推荐使用 豆包语音识别 2.0)
        client.setup(for: .seedAsr)
    }
    
    func start() { client.start() }
    func stop() { client.stop() }
    
    // MARK: - Delegate
    func onAsrResult(text: String, isFinal: Bool) {
        print("识别结果: \(text)")
    }
    
    func onAsrError(msg: String) {
        print("❌ 报错: \(msg)")
    }
}
```

---

## 📋 3. 模型对照表

在 `setup(for:)` 方法中，Wrapper 会自动映射以下资源 ID。请确保你在火山引擎控制台创建的应用已绑定相应的资源包：

| 枚举值 (`VolcAsrModel`) | 官方产品名称 | 资源 ID (Resource ID) | 协议版本 |
| :--- | :--- | :--- | :--- |
| **`.seedAsr`** | **豆包语音识别 2.0** | `volc.seedasr.sauc.duration` | Seed V3 |
| **`.bigModel`** | **流式语音识别大模型** | `volc.bigasr.sauc.duration` | Seed V3 |
| **`.standard`** | **一句话识别(1 分钟内)** | `volcengine_input_common` | WebSocket V2 |

---

## ⚙️ 4. 进阶配置

Wrapper 提供了强类型的 `VolcAsrParams` 结构体，让你可以轻松控制识别行为。

### 4.1 控制数字转写与标点
```swift
// 创建自定义配置
let params = VolcAsrParams(
    enableItn: true,   // ✅ true: 输出 "24" (阿拉伯数字); false: 输出 "二十四" (中文数字)
    enablePunc: true,  // ✅ true: 输出带标点 "你好，世界。"; false: 输出无标点 "你好 世界"
    enableDdc: true    // ✅ true: 顺滑模式，自动去除 "嗯、啊" 等语气词
)

client.setup(for: .seedAsr, params: params)
```

### 4.2 开启自动判停 (VAD)
```swift
let vadParams = VolcAsrParams(
    autoStop: true,       // 开启自动判停
    vadTailSilence: 2000  // 静音阈值：2000ms (2秒无声自动结束)
)

client.setup(for: .seedAsr, params: vadParams)
```

### 4.3 扩展高级参数
如果需要传递 SDK 支持但本库未封装的参数（如语种），可使用 `extras`：

```swift
import SpeechEngineToB 

func setupAdvanced() {
    var params = VolcAsrParams()
    params.extras = [
        // 切换为英语
        SE_PARAMS_KEY_ASR_LANGUAGE_STRING: "en-US"
    ]
    client.setup(for: .seedAsr, params: params)
}
```