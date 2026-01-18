# VolcAsrWrapper - 火山引擎语音识别 Swift 封装

这是一个轻量级的 Swift 封装库，用于快速集成火山引擎（Volcengine）的语音识别服务。
目前支持以下两种模型的一键切换：
1. **标准版 (Standard)**: 适用于日常短语音识别 (WebSocket V2)。
2. **大模型版 (BigModel)**: 适用于长语音和高精度识别 (Seed V3)。

---

## 🚀 1. 新项目集成步骤 (只需 1 分钟)

### 第一步：Pod 环境配置
打开终端，进入你的新项目目录：

```bash
cd /path/to/your/NewProject
pod init
```

### 第二步：修改 Podfile
打开生成的 `Podfile`，**完全复制**以下内容（注意替换 `Target` 名称）：

```ruby
platform :ios, '12.0'

target 'YourAppName' do # <--- 记得改成你的项目名
  use_frameworks!

  # 火山引擎核心库 (支持大模型的新版)
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

回到终端执行安装：
```bash
pod install
```

### 第三步：导入文件
1. 打开新生成的 `.xcworkspace` 文件。
2. 将本仓库中的 `VolcAsrWrapper` 文件夹（包含 `VolcTypes.swift` 和 `VolcAsrClient.swift`）直接**拖入** Xcode 项目中。
3. 勾选 **"Copy items if needed"**。

### 第四步：权限设置 (重要!)
打开项目的 `Info.plist`，添加麦克风权限：
* **Key**: `Privacy - Microphone Usage Description`
* **Value**: "我们需要您的声音来进行语音识别" (或自定义文案)

---

## 💻 2. 代码调用示例

### 在 App 启动时 (App入口)
```swift
import SpeechEngineToB

@main
struct YourApp: App {
    init() {
        // 必须调用环境准备
        SpeechEngine.prepareEnvironment()
    }
    // ...
}
```

### 在 ViewModel 或 Controller 中
```swift
class MyViewModel: VolcAsrDelegate {
    
    private var asrClient: VolcAsrClient!
    
    init() {
        // 1. 配置鉴权信息
        let config = VolcConfig(
            appId: "你的APPID",
            token: "你的TOKEN",  // 直接填原始Token，无需Bearer
            uid: "user_001"
        )
        
        // 2. 初始化客户端
        asrClient = VolcAsrClient(config: config)
        asrClient.delegate = self
        
        // 3. 设置模型 (选 .standard 或 .bigModel)
        asrClient.setup(for: .bigModel)
    }
    
    func start() {
        asrClient.start()
    }
    
    func stop() {
        asrClient.stop()
    }
    
    // MARK: - Delegate
    func onAsrResult(text: String, isFinal: Bool) {
        print("识别结果: \(text)")
    }
    
    func onAsrError(msg: String) {
        print("报错: \(msg)")
    }
}
```
