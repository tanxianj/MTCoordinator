# MTCoordinator

基于 UIKit 的模块化 Coordinator 导航框架，以 Swift Package 形式发布，支持 iOS 12+。

> 源自 [CoordinatorTest](https://github.com/tanxianj/CoordinatorTest) 项目的核心框架提取。

## 安装

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/tanxianj/MTCoordinator.git", from: "1.0.0")
]
```

或在 Xcode 中：**File → Add Package Dependencies** → 输入仓库地址。

### 本地开发

打开 `MTCoordinator.xcworkspace`，可同时编辑框架源码和 Example 项目。

## 核心文件

| 文件 | 职责 |
|------|------|
| `CoordinatorProtocol.swift` | Module、Coordinator 协议、NavigationFlowCoordinator、ModalFlowCoordinator、BackStrategy |
| `ModuleCoordinator.swift` | 核心导航逻辑、MulticastDelegate（线程安全）、InterceptorChain、数据回传 |
| `TransitionStyle.swift` | 转场动画（Fade/SlideUp/CrossDissolve + Pop 反向动画） |
| `NavigationInterceptor.swift` | 导航拦截器协议 + InterceptorChain |
| `BaseModuleViewController.swift` | VC 基类，提供 navigateTo/backTo/present/dismiss 等便捷方法 |
| `UIButton+Closure.swift` | UIButton 闭包扩展，兼容 iOS 12+ |

## 快速开始

### 1. 创建模块

```swift
import MTCoordinator

extension Module {
    static let home = Module("home") { _ in HomeViewController() }
}

class HomeViewController: BaseModuleViewController {
    override class var module: Module { .home }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "首页"
    }
}
```

### 2. 创建 AppCoordinator

```swift
import MTCoordinator

class AppCoordinator: NSObject, Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    weak var parentCoordinator: Coordinator?

    private(set) var tabCoordinators: [ModuleCoordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }

    func start() {
        _ = Module.home  // 触发注册

        let factory = DefaultModuleFactory()
        let coordinator = ModuleCoordinator(navigationController: navigationController, moduleFactory: factory)
        coordinator.delegates.add(self)
        tabCoordinators = [coordinator]
        addChild(coordinator)
        coordinator.navigateTo(.home, animated: false)
    }
}
```

### 3. 配置 SceneDelegate

```swift
import MTCoordinator

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController()

        appCoordinator = AppCoordinator(navigationController: nav)
        appCoordinator?.start()

        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

## 导航 API

```swift
// Push（支持转场动画）
navigateTo(.detail)
navigateTo(.detail, data: ["id": 42])
navigateTo(.detail, transition: .fade)
navigateTo(.profile, transition: .slideUp)
navigateTo(.detail, transition: .custom(push: MyPush(), pop: MyPop()))

// Pop
backTo(.home)
backTo(.home, data: "回传数据")
backTo(.profile, strategy: .insertThenPop)
pop()
popToRoot()

// 模态
presentModule(.settings)
dismissModule(data: "回传数据")

// 路径跳转
navigateTo(path: "/profile/settings/detail")
```

## 导航拦截器

```swift
class AuthInterceptor: NavigationInterceptor {
    func shouldNavigate(to module: Module, data: Any?) -> Bool {
        if module == .vipPage && !isVIP { return false }
        return true
    }
    func didIntercept(navigation module: Module, data: Any?) {
        // 弹出登录提示
    }
}
moduleCoordinator.interceptors.add(AuthInterceptor())
```

## 多播代理

```swift
moduleCoordinator.delegates.add(appCoordinator)     // 日志
moduleCoordinator.delegates.add(analyticsTracker)   // 埋点
moduleCoordinator.delegates.add(performanceMonitor) // 性能
```

## 自定义转场动画

Push 和 Pop 都有对应动画：

| 样式 | Push | Pop |
|------|------|-----|
| `.fade` | 淡入 | 淡出 |
| `.slideUp` | 从底部滑入 | 向底部滑出 |
| `.crossDissolve` | 交叉溶解 | 交叉溶解 |
| `.custom(push, pop)` | 自定义 | 自定义 |

## 项目结构

```
MTCoordinator/
├── MTCoordinator.xcworkspace      ← 打开这个（同时包含框架和 Example）
├── Package.swift                   ← SPM 包定义
├── Sources/
│   └── MTCoordinator/             ← 框架源码
│       ├── CoordinatorProtocol.swift
│       ├── ModuleCoordinator.swift
│       ├── TransitionStyle.swift
│       ├── NavigationInterceptor.swift
│       ├── BaseModuleViewController.swift
│       └── UIButton+Closure.swift
├── Example/
│   └── Example/                   ← 示例项目
│       ├── AppCoordinator.swift
│       ├── HomeViewController.swift
│       └── ProfileViewController.swift
└── README.md
```

## 环境

- iOS 12.0+
- Swift 5.7+
- Xcode 14+
