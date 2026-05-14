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

## 框架源码（Sources/MTCoordinator/）

| 文件 | 职责 |
|------|------|
| `CoordinatorProtocol.swift` | Module、Coordinator 协议、NavigationFlowCoordinator、ModalFlowCoordinator、BackStrategy |
| `ModuleCoordinator.swift` | 核心导航逻辑、MulticastDelegate（线程安全）、数据回传、子协调器自动清理 |
| `TransitionStyle.swift` | 转场动画（Fade/SlideUp/CrossDissolve + Pop 反向动画）、TransitionDelegate |
| `NavigationInterceptor.swift` | 导航拦截器协议 + InterceptorChain |
| `BaseModuleViewController.swift` | VC 基类，提供 navigateTo/backTo/present/dismiss 等便捷方法 |

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

## 登录 + TabBar 架构

### 场景一：登录后切换到 TabBar 页面

```swift
import MTCoordinator

class AppCoordinator: NSObject, Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    weak var parentCoordinator: Coordinator?

    private(set) var tabCoordinators: [ModuleCoordinator] = []
    private(set) var tabBarController: UITabBarController?
    private var isLoggedIn = false

    func start() {
        if isLoggedIn { showMainFlow() }
        else { showAuthFlow() }
    }

    // 登录流程
    private func showAuthFlow() {
        let auth = AuthCoordinator(navigationController: navigationController)
        auth.delegate = self
        addChild(auth)
        auth.start()
    }

    // 登录成功后切换到 TabBar
    private func showMainFlow() {
        if let auth = findChild(ofType: AuthCoordinator.self) {
            removeChild(auth)
        }

        let factory = DefaultModuleFactory()

        // Tab 1: 首页
        let homeNav = UINavigationController()
        homeNav.tabBarItem = UITabBarItem(title: "首页", image: nil, tag: 0)
        let homeCoordinator = ModuleCoordinator(navigationController: homeNav, moduleFactory: factory)
        homeCoordinator.delegates.add(self)
        addChild(homeCoordinator)
        homeCoordinator.navigateTo(.home, animated: false)

        // Tab 2: 我的
        let profileNav = UINavigationController()
        profileNav.tabBarItem = UITabBarItem(title: "我的", image: nil, tag: 1)
        let profileCoordinator = ModuleCoordinator(navigationController: profileNav, moduleFactory: factory)
        profileCoordinator.delegates.add(self)
        addChild(profileCoordinator)
        profileCoordinator.navigateTo(.profile, animated: false)

        tabCoordinators = [homeCoordinator, profileCoordinator]

        let tabBar = UITabBarController()
        tabBar.viewControllers = [homeNav, profileNav]
        self.tabBarController = tabBar

        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([tabBar], animated: true)
    }

    // 退出登录
    func logout() {
        isLoggedIn = false
        tabCoordinators = []
        tabBarController = nil
        removeAllChildren()
        navigationController.setNavigationBarHidden(false, animated: false)
        showAuthFlow()
    }
}

// AuthCoordinator 完成后回调
extension AppCoordinator: AuthCoordinatorDelegate {
    func authCoordinatorDidFinish(_ coordinator: AuthCoordinator) {
        isLoggedIn = true
        showMainFlow()
    }
}
```

### 场景二：直接显示 TabBar（无登录流程）

```swift
import MTCoordinator

class AppCoordinator: NSObject, Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    weak var parentCoordinator: Coordinator?

    private(set) var tabCoordinators: [ModuleCoordinator] = []
    private(set) var tabBarController: UITabBarController?

    func start() {
        let factory = DefaultModuleFactory()

        // Tab 1: 首页
        let homeNav = UINavigationController()
        homeNav.tabBarItem = UITabBarItem(title: "首页", image: nil, tag: 0)
        let homeCoordinator = ModuleCoordinator(navigationController: homeNav, moduleFactory: factory)
        addChild(homeCoordinator)
        homeCoordinator.navigateTo(.home, animated: false)

        // Tab 2: 我的
        let profileNav = UINavigationController()
        profileNav.tabBarItem = UITabBarItem(title: "我的", image: nil, tag: 1)
        let profileCoordinator = ModuleCoordinator(navigationController: profileNav, moduleFactory: factory)
        addChild(profileCoordinator)
        profileCoordinator.navigateTo(.profile, animated: false)

        tabCoordinators = [homeCoordinator, profileCoordinator]

        let tabBar = UITabBarController()
        tabBar.viewControllers = [homeNav, profileNav]
        self.tabBarController = tabBar

        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([tabBar], animated: false)
    }
}
```

> **关键点**：每个 Tab 有独立的 `UINavigationController` + `ModuleCoordinator`，导航互不干扰。
> push 时自动隐藏 TabBar（`hidesBottomBarWhenPushed = true`）。

---

## 项目结构

```
MTCoordinator/
├── MTCoordinator.xcworkspace       ← 打开这个（同时包含框架和 Example）
├── Package.swift                    ← SPM 包定义
├── Sources/
│   └── MTCoordinator/              ← 框架源码
│       ├── CoordinatorProtocol.swift
│       ├── ModuleCoordinator.swift
│       ├── TransitionStyle.swift
│       ├── NavigationInterceptor.swift
│       └── BaseModuleViewController.swift
├── Example/
│   ├── Package.swift               ← 让 Xcode 不在 Package 视图中显示此目录
│   ├── Example.xcodeproj
│   └── Example/
│       ├── APP/                    ← AppDelegate + SceneDelegate
│       ├── Coordinator/            ← AppCoordinator + AuthCoordinator
│       ├── Delegates/              ← 埋点/性能/历史/拦截器示例
│       ├── Extension/              ← UIButton+Closure（iOS 12 兼容）
│       └── VCModule/               ← 页面模块（Home/Login/Profile）
└── README.md
```

## 环境

- iOS 12.0+
- Swift 5.7+
- Xcode 14+
