//
//  ModuleCoordinator.swift
//  MTCoordinator
//
//  核心模块协调器，负责所有模块间的导航逻辑
//

import UIKit

// MARK: - 模块工厂协议

public protocol ModuleFactory {
    func makeViewController(for module: Module, data: Any?) -> (UIViewController & ModuleIdentifiable)?
}

// MARK: - 多播代理（线程安全）

public class MulticastDelegate<T> {
    private let delegates = NSHashTable<AnyObject>.weakObjects()
    private let queue = DispatchQueue(label: "com.coordinator.multicastDelegate", attributes: .concurrent)

    public init() {}

    public func add(_ delegate: T) {
        queue.async(flags: .barrier) {
            self.delegates.add(delegate as AnyObject)
        }
    }

    public func remove(_ delegate: T) {
        queue.async(flags: .barrier) {
            self.delegates.remove(delegate as AnyObject)
        }
    }

    public func invoke(_ invocation: @escaping (T) -> Void) {
        queue.sync {
            let allDelegates = self.delegates.allObjects.compactMap { $0 as? T }
            for delegate in allDelegates {
                invocation(delegate)
            }
        }
    }

    public var count: Int {
        return queue.sync { delegates.count }
    }
}

// MARK: - 导航事件回调

public protocol ModuleCoordinatorDelegate: AnyObject {
    func coordinatorDidNavigate(to module: Module)
    func coordinatorDidReturn(to module: Module)
    func coordinatorDidFailNavigation(to module: Module, reason: String)
}

public extension ModuleCoordinatorDelegate {
    func coordinatorDidNavigate(to module: Module) {}
    func coordinatorDidReturn(to module: Module) {}
    func coordinatorDidFailNavigation(to module: Module, reason: String) {}
}

// MARK: - ModuleCoordinator

open class ModuleCoordinator: NSObject, Coordinator {
    public var childCoordinators: [Coordinator] = []
    public var navigationController: UINavigationController
    public weak var parentCoordinator: Coordinator?
    public let delegates = MulticastDelegate<ModuleCoordinatorDelegate>()
    public let interceptors = InterceptorChain()

    private let moduleFactory: ModuleFactory
    private var transitionDelegate: TransitionDelegate?

    public init(navigationController: UINavigationController, moduleFactory: ModuleFactory) {
        self.navigationController = navigationController
        self.moduleFactory = moduleFactory
        super.init()
        self.navigationController.delegate = self
        self.navigationController.associatedModuleCoordinator = self
    }

    open func start() {}

    // MARK: - Push 跳转

    @discardableResult
    public func navigateTo(_ module: Module, data: Any? = nil, transition: TransitionStyle = .default, animated: Bool = true) -> Bool {
        if !interceptors.canNavigate(to: module, data: data) {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "被拦截器拦截") }
            return false
        }
        guard let vc = moduleFactory.makeViewController(for: module, data: data) else {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "工厂无法创建模块: \(module)") }
            return false
        }
        if !navigationController.viewControllers.isEmpty {
            vc.hidesBottomBarWhenPushed = true
        }
        applyTransition(transition)
        navigationController.pushViewController(vc, animated: animated)
        delegates.invoke { $0.coordinatorDidNavigate(to: module) }
        return true
    }

    // MARK: - 经过中间模块跳转

    @discardableResult
    public func navigateThrough(_ intermediates: [Module], to target: Module, targetData: Any? = nil, animated: Bool = true) -> Bool {
        var newVCs: [UIViewController] = []
        for module in intermediates {
            guard let vc = moduleFactory.makeViewController(for: module, data: nil) else {
                delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "工厂无法创建中间模块: \(module)") }
                return false
            }
            vc.hidesBottomBarWhenPushed = true
            newVCs.append(vc)
        }
        guard let targetVC = moduleFactory.makeViewController(for: target, data: targetData) else {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: target, reason: "工厂无法创建目标模块: \(target)") }
            return false
        }
        targetVC.hidesBottomBarWhenPushed = true
        var vcs = navigationController.viewControllers
        vcs.append(contentsOf: newVCs)
        vcs.append(targetVC)
        navigationController.setViewControllers(vcs, animated: animated)
        delegates.invoke { $0.coordinatorDidNavigate(to: target) }
        return true
    }

    // MARK: - Pop 返回（支持策略）

    @discardableResult
    public func backTo(_ module: Module, strategy: BackStrategy = .ignore, data: Any? = nil, sourceModule: Module? = nil, animated: Bool = true) -> Bool {
        let source = sourceModule ?? currentTopModule
        if let targetVC = findViewController(for: module) {
            navigationController.popToViewController(targetVC, animated: animated)
            delegates.invoke { $0.coordinatorDidReturn(to: module) }
            if let data = data, let source = source, let receiver = targetVC as? ModuleDataReceivable {
                afterTransition(animated: animated) { receiver.receiveData(data, from: source) }
            }
            return true
        }
        switch strategy {
        case .insertThenPop:
            return handleInsertThenPop(module: module, data: data, source: source, animated: animated)
        case .pushAsNew:
            return handlePushAsNew(module: module, data: data, source: source, animated: animated)
        case .ignore:
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "模块 \(module) 不在导航栈中，策略为忽略") }
            return false
        case .custom(let handler):
            handler(navigationController)
            return true
        }
    }

    // MARK: - 模态弹出

    @discardableResult
    public func present(_ module: Module, data: Any? = nil, wrapInNav: Bool = true, style: UIModalPresentationStyle = .pageSheet, transition: UIModalTransitionStyle = .coverVertical, animated: Bool = true, completion: (() -> Void)? = nil) -> Bool {
        if !interceptors.canNavigate(to: module, data: data) {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "被拦截器拦截") }
            return false
        }
        guard let vc = moduleFactory.makeViewController(for: module, data: data) else {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "工厂无法创建模块: \(module)") }
            return false
        }
        let presented: UIViewController
        if wrapInNav {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = style
            // 将当前 coordinator 绑定到模态的 nav 上，这样模态内的 VC 也能获取到 moduleCoordinator
            nav.associatedModuleCoordinator = self
            presented = nav
        } else {
            vc.modalPresentationStyle = style
            presented = vc
        }
        presented.modalTransitionStyle = transition
        let presenter = navigationController.topPresentedViewController
        presenter.present(presented, animated: animated, completion: completion)
        delegates.invoke { $0.coordinatorDidNavigate(to: module) }
        return true
    }

    public func dismissModal(data: Any? = nil, sourceModule: Module? = nil, animated: Bool = true, completion: (() -> Void)? = nil) {
        let topPresented = navigationController.topPresentedViewController
        let source = sourceModule ?? (topPresented as? ModuleIdentifiable)?.module
            ?? ((topPresented as? UINavigationController)?.topViewController as? ModuleIdentifiable)?.module
        var modalRoot: UIViewController = topPresented
        while let parent = modalRoot.presentingViewController,
              parent.presentedViewController !== navigationController.presentedViewController {
            modalRoot = parent
        }
        let targetVC = navigationController.topViewController
        modalRoot.dismiss(animated: animated) { [weak self] in
            if let data = data, let source = source, let receiver = targetVC as? ModuleDataReceivable {
                receiver.receiveData(data, from: source)
            }
            if let module = (targetVC as? ModuleIdentifiable)?.module {
                self?.delegates.invoke { $0.coordinatorDidReturn(to: module) }
            }
            completion?()
        }
    }

    // MARK: - Pop 操作

    public func popCurrent(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }

    public func popToRoot(animated: Bool = true) {
        navigationController.popToRootViewController(animated: animated)
    }

    // MARK: - 模态内导航

    @discardableResult
    public func navigateInNav(_ nav: UINavigationController, to module: Module, data: Any? = nil, animated: Bool = true) -> Bool {
        guard let vc = moduleFactory.makeViewController(for: module, data: data) else {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "工厂无法创建模块: \(module)") }
            return false
        }
        nav.pushViewController(vc, animated: animated)
        delegates.invoke { $0.coordinatorDidNavigate(to: module) }
        return true
    }

    @discardableResult
    public func backInNav(_ nav: UINavigationController, to module: Module, strategy: BackStrategy = .ignore, data: Any? = nil, sourceModule: Module? = nil, animated: Bool = true) -> Bool {
        let source = sourceModule ?? (nav.topViewController as? ModuleIdentifiable)?.module
        if let targetVC = nav.viewControllers.first(where: { ($0 as? ModuleIdentifiable)?.module == module }) {
            nav.popToViewController(targetVC, animated: animated)
            if let data = data, let source = source, let receiver = targetVC as? ModuleDataReceivable {
                afterNavTransition(nav, animated: animated) { receiver.receiveData(data, from: source) }
            }
            delegates.invoke { $0.coordinatorDidReturn(to: module) }
            return true
        }
        switch strategy {
        case .insertThenPop:
            guard let newVC = moduleFactory.makeViewController(for: module, data: data) else { return false }
            var vcs = nav.viewControllers
            let insertIndex = max(vcs.count - 1, 0)
            vcs.insert(newVC, at: insertIndex)
            nav.setViewControllers(vcs, animated: false)
            nav.popToViewController(newVC, animated: animated)
            if let data = data, let source = source, let receiver = newVC as? ModuleDataReceivable {
                afterNavTransition(nav, animated: animated) { receiver.receiveData(data, from: source) }
            }
            delegates.invoke { $0.coordinatorDidReturn(to: module) }
            return true
        case .pushAsNew:
            return navigateInNav(nav, to: module, data: data, animated: animated)
        case .ignore:
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "模块 \(module) 不在模态导航栈中，策略为忽略") }
            return false
        case .custom(let handler):
            handler(nav)
            return true
        }
    }

    // MARK: - 栈查询

    public func isModuleInStack(_ module: Module) -> Bool {
        return findViewController(for: module) != nil
    }

    public var currentModules: [Module] {
        return navigationController.viewControllers.compactMap { ($0 as? ModuleIdentifiable)?.module }
    }
}

// MARK: - Private Helpers

private extension ModuleCoordinator {
    var currentTopModule: Module? {
        return (navigationController.topViewController as? ModuleIdentifiable)?.module
    }

    func findViewController(for module: Module) -> UIViewController? {
        return navigationController.viewControllers.first { ($0 as? ModuleIdentifiable)?.module == module }
    }

    func handleInsertThenPop(module: Module, data: Any?, source: Module?, animated: Bool) -> Bool {
        guard let newVC = moduleFactory.makeViewController(for: module, data: data) else {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "工厂无法创建模块: \(module)") }
            return false
        }
        var vcs = navigationController.viewControllers
        let insertIndex = max(vcs.count - 1, 0)
        vcs.insert(newVC, at: insertIndex)
        navigationController.setViewControllers(vcs, animated: false)
        navigationController.popToViewController(newVC, animated: animated)
        delegates.invoke { $0.coordinatorDidReturn(to: module) }
        if let data = data, let source = source, let receiver = newVC as? ModuleDataReceivable {
            afterTransition(animated: animated) { receiver.receiveData(data, from: source) }
        }
        return true
    }

    func handlePushAsNew(module: Module, data: Any?, source: Module?, animated: Bool) -> Bool {
        guard let newVC = moduleFactory.makeViewController(for: module, data: data) else {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "工厂无法创建模块: \(module)") }
            return false
        }
        if let data = data, let source = source, let receiver = newVC as? ModuleDataReceivable {
            receiver.receiveData(data, from: source)
        }
        navigationController.pushViewController(newVC, animated: animated)
        delegates.invoke { $0.coordinatorDidNavigate(to: module) }
        return true
    }

    func afterTransition(animated: Bool, completion: @escaping () -> Void) {
        if animated, let coordinator = navigationController.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in completion() }
        } else { completion() }
    }

    func afterNavTransition(_ nav: UINavigationController, animated: Bool, completion: @escaping () -> Void) {
        if animated, let coordinator = nav.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in completion() }
        } else { completion() }
    }

    func applyTransition(_ transition: TransitionStyle) {
        guard let animators = transition.makeAnimators() else { return }
        let delegate = TransitionDelegate(pushAnimator: animators.push, popAnimator: animators.pop, originalDelegate: self)
        self.transitionDelegate = delegate
        navigationController.delegate = delegate
    }
}

// MARK: - UINavigationControllerDelegate

extension ModuleCoordinator: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        cleanupOrphanedFlowCoordinators()
    }

    private func cleanupOrphanedFlowCoordinators() {
        let currentStackCount = navigationController.viewControllers.count
        let orphaned = childCoordinators.compactMap { $0 as? NavigationFlowCoordinator }.filter { flow in
            currentStackCount <= flow.flowEntryIndex
        }
        for flow in orphaned {
            removeChild(flow)
            print("🧹 自动清理失效子协调器: \(type(of: flow)) | 子协调器数量: \(childCoordinators.count)")
        }
    }
}

// MARK: - 数据回传协议

public protocol ModuleDataReceivable: AnyObject {
    func receiveData(_ data: Any, from source: Module)
}

// MARK: - UINavigationController 扩展

public extension UINavigationController {
    private enum AssociatedKeys {
        static var moduleCoordinator: UInt8 = 0
    }

    weak var associatedModuleCoordinator: ModuleCoordinator? {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.moduleCoordinator) as? WeakBox<ModuleCoordinator>)?.value }
        set {
            let box: WeakBox<ModuleCoordinator>? = newValue.map { WeakBox($0) }
            objc_setAssociatedObject(self, &AssociatedKeys.moduleCoordinator, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

// MARK: - UIViewController 扩展

public extension UIViewController {
    var topPresentedViewController: UIViewController {
        presentedViewController?.topPresentedViewController ?? self
    }
}
