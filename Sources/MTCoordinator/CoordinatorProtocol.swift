//
//  CoordinatorProtocol.swift
//  MTCoordinator
//
//  定义了 Coordinator 架构的基础协议和类型：
//  1. Module 结构体 —— 模块的唯一标识（分散定义，各模块自行声明）
//  2. ModuleIdentifiable —— 让 VC 声明自己属于哪个模块
//  3. BackStrategy —— 返回时目标不存在的处理策略
//  4. NavigationFlowCoordinator —— Push 方式子协调器自动清理协议
//  5. ModalFlowCoordinator —— 模态方式子协调器自动清理协议
//  6. Coordinator 协议 —— 协调器的基础能力（子协调器管理、启动）
//

import UIKit

// MARK: - 模块标识

/// 模块的唯一标识（类似 Notification.Name 的设计）
///
/// 采用 struct + 静态常量的方式，而不是集中式枚举。
/// 好处：每个模块在自己的文件里声明标识，新增模块不需要修改公共文件。
///
/// 使用方式：
/// ```swift
/// // 在 HomeViewController.swift 中声明标识 + 创建方法：
/// extension Module {
///     static let home = Module("home") { _ in HomeViewController() }
/// }
/// ```
public struct Module: Hashable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// 声明模块的同时注册创建方法（推荐用法）
    ///
    /// 使用方式：
    /// ```swift
    /// static let home = Module("home") { data in
    ///     let vc = HomeViewController()
    ///     vc.initialData = data
    ///     return vc
    /// }
    /// ```
    public init(_ rawValue: String, builder: @escaping (Any?) -> (UIViewController & ModuleIdentifiable)?) {
        self.rawValue = rawValue
        Module.builderRegistry[rawValue] = builder
    }

    public var description: String { rawValue }

    // MARK: - 全局创建方法注册表

    /// 存储各模块的创建闭包，key 用 rawValue（String）
    public private(set) static var builderRegistry: [String: (Any?) -> (UIViewController & ModuleIdentifiable)?] = [:]

    /// 根据 rawValue 查找 builder
    public static func builder(for module: Module) -> ((Any?) -> (UIViewController & ModuleIdentifiable)?)? {
        return builderRegistry[module.rawValue]
    }

    /// 手动注册模块创建方法
    ///
    /// 使用方式：
    /// ```swift
    /// Module.register("detail") { data in DetailViewController() }
    /// ```
    public static func register(_ rawValue: String, builder: @escaping (Any?) -> (UIViewController & ModuleIdentifiable)?) {
        builderRegistry[rawValue] = builder
    }
}

// MARK: - 模块标识协议

/// 让 ViewController 声明自己属于哪个模块
/// 用于在导航栈中查找特定模块的 VC
///
/// 使用方式：
/// ```swift
/// class HomeViewController: BaseModuleViewController {
///     override class var module: Module { .home }  // 声明这是 home 模块
/// }
/// ```
public protocol ModuleIdentifiable {
    /// 类级别的模块标识（子类重写这个）
    static var module: Module { get }
    /// 实例级别的模块标识（自动从类级别获取，不需要重写）
    var module: Module { get }
}

public extension ModuleIdentifiable {
    /// 默认实现：实例的 module 直接取类的 module，不用每个实例都写
    var module: Module { Self.module }
}

// MARK: - 返回策略

/// 当调用 backTo 返回某个模块，但该模块不在当前导航栈中时，该怎么处理？
///
/// 举例：当前栈是 [Home, Detail]，你调用 backTo(.profile)，
/// 但 Profile 不在栈里，这时就需要策略来决定行为：
public enum BackStrategy {
    /// 创建目标模块并插入到当前页面下方，然后 pop 回去
    /// 效果：看起来像正常的返回动画，栈变成 [Home, Profile]
    case insertThenPop

    /// 直接 push 一个新的目标模块到栈顶
    /// 效果：栈变成 [Home, Detail, Profile]
    case pushAsNew

    /// 什么都不做，静默失败
    case ignore

    /// 完全自定义处理，闭包参数是当前的 UINavigationController
    /// 你可以在闭包里做任何导航操作
    /// 例如：.custom { nav in nav.setViewControllers([HomeVC()], animated: true) }
    case custom((UINavigationController) -> Void)
}

// MARK: - Push 方式子协调器协议

/// Push 方式的子协调器需要遵循此协议
/// 用于侧滑返回时自动检测并清理已失效的子协调器
///
/// 工作原理：
/// 当用户侧滑返回导致子协调器管理的 VC 全部被 pop 出栈时，
/// ModuleCoordinator 会自动调用 removeChild 清理该子协调器
///
/// 使用方式：
/// ```swift
/// class OrderFlowCoordinator: NSObject, Coordinator, NavigationFlowCoordinator {
///     private(set) var flowEntryIndex: Int = 0
///
///     func start() {
///         flowEntryIndex = navigationController.viewControllers.count
///         // push 页面...
///     }
/// }
/// ```
public protocol NavigationFlowCoordinator: Coordinator {
    /// 进入子流程前的导航栈深度（start() 时记录）
    /// 当导航栈深度 <= 此值时，说明子流程的 VC 已全部被 pop
    var flowEntryIndex: Int { get }
}

// MARK: - 模态方式子协调器协议

/// 模态方式的子协调器可遵循此协议，用于自动检测并清理已失效的模态子协调器
///
/// 工作原理：
/// 当模态被 dismiss 后（无论是用户下拉关闭还是代码 dismiss），
/// 如果开发者忘记在 delegate 中调用 removeChild，
/// 父协调器可以通过检查 `presentedNavigationController.presentingViewController == nil`
/// 来判断模态已关闭，自动执行 removeChild 清理。
///
/// 使用方式：
/// ```swift
/// class MyModalFlowCoordinator: NSObject, Coordinator, ModalFlowCoordinator {
///     private let modalNav = UINavigationController()
///     var presentedNavigationController: UINavigationController { modalNav }
///     // ...
/// }
/// ```
///
/// > 注意：遵循此协议后，即使忘记实现 `UIAdaptivePresentationControllerDelegate`，
/// > 父协调器也能在下次检查时自动清理。但仍建议实现 delegate 以获得即时清理。
public protocol ModalFlowCoordinator: Coordinator {
    /// 模态弹出使用的 NavigationController
    /// 当此 nav 的 presentingViewController 为 nil 时，说明模态已被 dismiss
    var presentedNavigationController: UINavigationController { get }
}

// MARK: - Coordinator 协议

/// 协调器的基础协议
/// 每个 Coordinator 负责管理一组相关的导航流程
///
/// 层级关系：
/// ```
/// AppCoordinator（根协调器）
///   └── ModuleCoordinator（模块协调器，管理所有模块间的跳转）
///       └── 子协调器（OrderFlow / SettingsFlow / ...）
/// ```
public protocol Coordinator: AnyObject {
    /// 子协调器数组，用于保持强引用防止被释放
    var childCoordinators: [Coordinator] { get set }
    /// 该协调器使用的导航控制器
    var navigationController: UINavigationController { get }
    /// 父协调器（弱引用，避免循环引用）
    var parentCoordinator: Coordinator? { get set }

    /// 启动协调器，开始导航流程
    func start()
    /// 带数据启动协调器
    func start(with data: Any?)
}

public extension Coordinator {
    /// 默认实现：带数据启动时直接调用无参 start
    func start(with data: Any?) {
        start()
    }

    // MARK: - 子 Coordinator 管理

    /// 添加子协调器，并建立父子关系
    func addChild(_ coordinator: Coordinator) {
        coordinator.parentCoordinator = self
        childCoordinators.append(coordinator)
    }

    /// 移除指定的子协调器
    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }

    /// 移除所有子协调器
    func removeAllChildren() {
        childCoordinators.removeAll()
    }

    /// 递归查找指定类型的子协调器
    /// 会深度遍历整个协调器树
    func findChild<T: Coordinator>(ofType type: T.Type) -> T? {
        for child in childCoordinators {
            if let found = child as? T { return found }
            // 递归查找子协调器的子协调器
            if let found = child.findChild(ofType: type) { return found }
        }
        return nil
    }

    /// 检测并清理已失效的模态子协调器
    ///
    /// 场景：模态被 dismiss 后，如果 delegate 回调未正确触发 removeChild，
    /// 子协调器会残留在 childCoordinators 中。此方法通过检查模态的
    /// presentingViewController 是否为 nil 来判断模态是否已关闭。
    ///
    /// 建议在适当时机调用（如导航事件回调等）
    func cleanupOrphanedModalCoordinators() {
        let orphaned = childCoordinators.compactMap { $0 as? ModalFlowCoordinator }.filter { modal in
            // 如果模态的 nav 已经不在 presented 链上，说明已被 dismiss
            modal.presentedNavigationController.presentingViewController == nil
        }
        for modal in orphaned {
            removeChild(modal)
            print("🧹 自动清理失效模态子协调器: \(type(of: modal)) | 子协调器数量: \(childCoordinators.count)")
        }
    }

    // MARK: - 调试

    /// 从根协调器开始打印整棵协调器树
    func printCoordinatorTree() {
        // 沿着 parentCoordinator 往上找到根节点
        var root: Coordinator = self
        while let parent = root.parentCoordinator {
            root = parent
        }
        print("🌳 协调器树:")
        _printTree(coordinator: root, indent: "  ")
    }

    private func _printTree(coordinator: Coordinator, indent: String) {
        let name = String(describing: type(of: coordinator))
        print("\(indent)└── \(name)")
        for child in coordinator.childCoordinators {
            _printTree(coordinator: child, indent: indent + "    ")
        }
    }
}
