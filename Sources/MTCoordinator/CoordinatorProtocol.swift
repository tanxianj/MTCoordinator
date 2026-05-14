//
//  CoordinatorProtocol.swift
//  MTCoordinator
//
//  定义了 Coordinator 架构的基础协议和类型：
//  1. Module 结构体 —— 模块的唯一标识（分散定义，各模块自行声明）
//  2. ModuleIdentifiable —— 让 VC 声明自己属于哪个模块
//  3. BackStrategy —— 返回时目标不存在的处理策略
//  4. Coordinator 协议 —— 协调器的基础能力（子协调器管理、启动）
//

import UIKit

// MARK: - 模块标识

/// 模块的唯一标识（类似 Notification.Name 的设计）
///
/// 采用 struct + 静态常量的方式，而不是集中式枚举。
/// 好处：每个模块在自己的文件里声明标识，新增模块不需要修改公共文件。
public struct Module: Hashable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// 声明模块的同时注册创建方法（推荐用法）
    public init(_ rawValue: String, builder: @escaping (Any?) -> (UIViewController & ModuleIdentifiable)?) {
        self.rawValue = rawValue
        Module.builderRegistry[rawValue] = builder
    }

    public var description: String { rawValue }

    // MARK: - 全局创建方法注册表

    public private(set) static var builderRegistry: [String: (Any?) -> (UIViewController & ModuleIdentifiable)?] = [:]

    public static func builder(for module: Module) -> ((Any?) -> (UIViewController & ModuleIdentifiable)?)? {
        return builderRegistry[module.rawValue]
    }

    public static func register(_ rawValue: String, builder: @escaping (Any?) -> (UIViewController & ModuleIdentifiable)?) {
        builderRegistry[rawValue] = builder
    }
}

// MARK: - 模块标识协议

public protocol ModuleIdentifiable {
    static var module: Module { get }
    var module: Module { get }
}

public extension ModuleIdentifiable {
    var module: Module { Self.module }
}

// MARK: - 返回策略

public enum BackStrategy {
    case insertThenPop
    case pushAsNew
    case ignore
    case custom((UINavigationController) -> Void)
}

// MARK: - Push 方式子协调器协议

public protocol NavigationFlowCoordinator: Coordinator {
    var flowEntryIndex: Int { get }
}

// MARK: - 模态方式子协调器协议

public protocol ModalFlowCoordinator: Coordinator {
    var presentedNavigationController: UINavigationController { get }
}

// MARK: - Coordinator 协议

public protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get }
    var parentCoordinator: Coordinator? { get set }

    func start()
    func start(with data: Any?)
}

public extension Coordinator {
    func start(with data: Any?) {
        start()
    }

    func addChild(_ coordinator: Coordinator) {
        coordinator.parentCoordinator = self
        childCoordinators.append(coordinator)
    }

    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }

    func removeAllChildren() {
        childCoordinators.removeAll()
    }

    func findChild<T: Coordinator>(ofType type: T.Type) -> T? {
        for child in childCoordinators {
            if let found = child as? T { return found }
            if let found = child.findChild(ofType: type) { return found }
        }
        return nil
    }

    func cleanupOrphanedModalCoordinators() {
        let orphaned = childCoordinators.compactMap { $0 as? ModalFlowCoordinator }.filter { modal in
            modal.presentedNavigationController.presentingViewController == nil
        }
        for modal in orphaned {
            removeChild(modal)
            print("🧹 自动清理失效模态子协调器: \(type(of: modal)) | 子协调器数量: \(childCoordinators.count)")
        }
    }

    func printCoordinatorTree() {
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
