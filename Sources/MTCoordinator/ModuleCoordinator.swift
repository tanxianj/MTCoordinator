//
//  ModuleCoordinator.swift
//  MTCoordinator
//
//  核心模块协调器，负责所有模块间的导航逻辑：
//  - Push/Pop 导航（navigateTo / backTo）
//  - 模态弹出/关闭（present / dismissModal）
//  - 模态内导航（navigateInNav / backInNav）
//  - 导航栈查询（isModuleInStack / currentModules）
//  - 导航拦截器（interceptors）
//  - 多播代理（delegates）
//  - 自定义转场动画（transition）
//

import UIKit

// MARK: - 模块工厂协议

/// 模块工厂 —— 负责根据 Module 枚举创建对应的 ViewController
///
/// 为什么用工厂模式？
/// - 解耦：ModuleCoordinator 不需要知道具体的 VC 类型
/// - 集中管理：所有模块的创建逻辑在一个地方
/// - 易扩展：新增模块只需在工厂的 switch 中加一个 case
public protocol ModuleFactory {
    /// 根据模块标识创建 ViewController
    /// - Parameters:
    ///   - module: 要创建的模块
    ///   - data: 传递给模块的初始数据（可选）
    /// - Returns: 同时遵循 UIViewController 和 ModuleIdentifiable 的实例，创建失败返回 nil
    func makeViewController(for module: Module, data: Any?) -> (UIViewController & ModuleIdentifiable)?
}

// MARK: - 多播代理（线程安全）

/// 多播代理容器 —— 支持多个对象同时监听同一事件
///
/// 内部使用 NSHashTable.weakObjects() 存储弱引用，
/// 监听方被释放后自动从列表中移除，不会造成循环引用。
/// 通过并发队列 + barrier 保证线程安全。
///
/// 使用方式：
/// ```swift
/// let delegates = MulticastDelegate<ModuleCoordinatorDelegate>()
/// delegates.add(analyticsTracker)
/// delegates.add(performanceMonitor)
/// delegates.invoke { $0.coordinatorDidNavigate(to: .home) }
/// ```
public class MulticastDelegate<T> {
    private let delegates = NSHashTable<AnyObject>.weakObjects()
    private let queue = DispatchQueue(label: "com.coordinator.multicastDelegate", attributes: .concurrent)

    public init() {}

    /// 添加监听方（弱引用，不会造成循环引用）
    public func add(_ delegate: T) {
        queue.async(flags: .barrier) {
            self.delegates.add(delegate as AnyObject)
        }
    }

    /// 移除指定监听方
    public func remove(_ delegate: T) {
        queue.async(flags: .barrier) {
            self.delegates.remove(delegate as AnyObject)
        }
    }

    /// 向所有监听方广播事件
    public func invoke(_ invocation: @escaping (T) -> Void) {
        queue.sync {
            let allDelegates = self.delegates.allObjects.compactMap { $0 as? T }
            for delegate in allDelegates {
                invocation(delegate)
            }
        }
    }

    /// 当前监听方数量
    public var count: Int {
        return queue.sync { delegates.count }
    }
}

// MARK: - 导航事件回调

/// 导航事件代理 —— 用于监听导航行为（日志、埋点等）
public protocol ModuleCoordinatorDelegate: AnyObject {
    /// 成功跳转到某个模块时调用
    func coordinatorDidNavigate(to module: Module)
    /// 成功返回到某个模块时调用
    func coordinatorDidReturn(to module: Module)
    /// 导航失败时调用（比如工厂创建失败、目标不在栈中等）
    func coordinatorDidFailNavigation(to module: Module, reason: String)
}

/// 提供默认空实现，这样代理不需要实现所有方法
public extension ModuleCoordinatorDelegate {
    func coordinatorDidNavigate(to module: Module) {}
    func coordinatorDidReturn(to module: Module) {}
    func coordinatorDidFailNavigation(to module: Module, reason: String) {}
}

// MARK: - ModuleCoordinator

/// 核心模块协调器
///
/// 整体架构：
/// ```
/// SceneDelegate
///   └── AppCoordinator          （应用级协调器，负责启动）
///         └── ModuleCoordinator （模块级协调器，负责所有导航）
///               ├── navigateTo    → push 跳转
///               ├── backTo        → pop 返回（支持策略）
///               ├── present       → 模态弹出
///               ├── dismissModal  → 模态关闭
///               ├── navigateInNav → 模态内 push
///               └── backInNav     → 模态内 pop
/// ```
open class ModuleCoordinator: NSObject, Coordinator {
    public var childCoordinators: [Coordinator] = []
    /// 主导航控制器（非模态环境下使用）
    public var navigationController: UINavigationController
    public weak var parentCoordinator: Coordinator?

    /// 导航事件多播代理，支持多个监听方（埋点、日志、性能监控等）
    ///
    /// 使用方式：
    /// ```swift
    /// moduleCoordinator.delegates.add(analyticsTracker)
    /// moduleCoordinator.delegates.add(appCoordinator)
    /// ```
    public let delegates = MulticastDelegate<ModuleCoordinatorDelegate>()

    /// 导航拦截器链，在导航发生前进行拦截判断
    ///
    /// 使用方式：
    /// ```swift
    /// moduleCoordinator.interceptors.add(authInterceptor)
    /// ```
    public let interceptors = InterceptorChain()

    /// 模块工厂，用于创建 VC
    private let moduleFactory: ModuleFactory
    /// 用于自定义转场动画的临时代理（动画完成后自动恢复）
    private var transitionDelegate: TransitionDelegate?

    public init(navigationController: UINavigationController, moduleFactory: ModuleFactory) {
        self.navigationController = navigationController
        self.moduleFactory = moduleFactory
        super.init()
        // 设置自己为 nav 的代理，用于监听导航栈变化
        self.navigationController.delegate = self
        // 将自己绑定到 nav 上，VC 可通过 nav.associatedModuleCoordinator 直接获取
        self.navigationController.associatedModuleCoordinator = self
    }

    open func start() {}

    // MARK: - Push 跳转

    /// 跳转到指定模块（push 到导航栈顶）
    ///
    /// 示例：
    /// ```swift
    /// moduleCoordinator.navigateTo(.profile)
    /// moduleCoordinator.navigateTo(.detail, data: ["id": 42])
    /// moduleCoordinator.navigateTo(.detail, transition: .fade)
    /// ```
    ///
    /// - Parameters:
    ///   - module: 目标模块
    ///   - data: 传递给目标模块的数据
    ///   - transition: 转场动画样式（默认使用系统动画）
    ///   - animated: 是否有动画
    /// - Returns: 是否成功
    @discardableResult
    public func navigateTo(_ module: Module, data: Any? = nil, transition: TransitionStyle = .default, animated: Bool = true) -> Bool {
        // 拦截器检查
        if !interceptors.canNavigate(to: module, data: data) {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "被拦截器拦截") }
            return false
        }
        // 通过工厂创建目标 VC
        guard let vc = moduleFactory.makeViewController(for: module, data: data) else {
            delegates.invoke { $0.coordinatorDidFailNavigation(to: module, reason: "工厂无法创建模块: \(module)") }
            return false
        }
        // 非根页面 push 时隐藏 TabBar
        if !navigationController.viewControllers.isEmpty {
            vc.hidesBottomBarWhenPushed = true
        }
        // 设置自定义转场动画（如果有）
        applyTransition(transition)
        navigationController.pushViewController(vc, animated: animated)
        delegates.invoke { $0.coordinatorDidNavigate(to: module) }
        return true
    }

    // MARK: - 经过中间模块跳转

    /// 跳转到目标模块，同时在栈中插入中间模块
    ///
    /// 效果：用户看到的是直接跳到目标页面（有 push 动画），
    /// 但返回时会依次经过中间页面。
    ///
    /// 示例：
    /// ```swift
    /// navigateThrough([.profile, .settings], to: .detail)
    /// // 栈变成：[Home, Profile, Settings, Detail]
    /// // 返回时：Detail → Settings → Profile → Home
    /// ```
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

    /// 返回到指定模块
    ///
    /// 工作流程：
    /// 1. 先在导航栈中查找目标模块
    /// 2. 找到了 → 直接 pop 回去
    /// 3. 没找到 → 根据 strategy 决定怎么处理
    ///
    /// 示例：
    /// ```swift
    /// backTo(.home)                                    // 返回 Home，不存在则忽略
    /// backTo(.home, data: "回传消息")                    // 返回并回传数据
    /// backTo(.profile, strategy: .insertThenPop)       // 不存在则插入再返回
    /// ```
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

    /// 模态弹出一个模块
    ///
    /// 示例：
    /// ```swift
    /// present(.profile)                                          // 默认包裹 nav
    /// present(.detail, data: someData, wrapInNav: false)         // 不包裹 nav
    /// present(.settings, style: .fullScreen)                     // 全屏模态
    /// present(.profile, transition: .crossDissolve)              // 交叉溶解转场
    /// ```
    @discardableResult
    public func present(_ module: Module, data: Any? = nil, wrapInNav: Bool = true, style: UIModalPresentationStyle = .pageSheet, transition: UIModalTransitionStyle = .coverVertical, animated: Bool = true, completion: (() -> Void)? = nil) -> Bool {
        // 拦截器检查
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
            // 包裹一层 nav，这样模态内部也能 push/pop
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
        // 从最顶层的 VC 弹出，这样即使已经有模态也能继续弹
        let presenter = navigationController.topPresentedViewController
        presenter.present(presented, animated: animated, completion: completion)
        delegates.invoke { $0.coordinatorDidNavigate(to: module) }
        return true
    }

    /// 关闭当前模态，支持回传数据
    ///
    /// 无论模态内 push 了多少层，都会一次性关闭整个模态
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

    /// 返回上一个模块（pop 栈顶）
    public func popCurrent(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }

    /// 返回到根模块（pop 到栈底）
    public func popToRoot(animated: Bool = true) {
        navigationController.popToRootViewController(animated: animated)
    }

    // MARK: - 模态内导航

    /// 在指定的 nav 中 push 模块（用于模态内导航）
    ///
    /// 为什么需要这个方法？
    /// 模态弹出时会创建一个新的 UINavigationController，
    /// 模态内的 push/pop 需要操作这个新 nav，而不是主 nav。
    /// BaseModuleViewController 会自动判断当前环境，调用对应的方法。
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

    /// 在指定的 nav 中返回到某个模块（用于模态内导航）
    ///
    /// 逻辑和 backTo 一样，只是操作的是传入的 nav 而不是主 nav
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

    /// 检查某个模块是否在主导航栈中
    public func isModuleInStack(_ module: Module) -> Bool {
        return findViewController(for: module) != nil
    }

    /// 获取主导航栈中所有模块的列表
    public var currentModules: [Module] {
        return navigationController.viewControllers.compactMap { ($0 as? ModuleIdentifiable)?.module }
    }
}


// MARK: - Private Helpers（内部辅助方法）

private extension ModuleCoordinator {

    /// 获取当前主导航栈顶的模块标识
    var currentTopModule: Module? {
        return (navigationController.topViewController as? ModuleIdentifiable)?.module
    }

    /// 在主导航栈中查找指定模块的 VC
    func findViewController(for module: Module) -> UIViewController? {
        return navigationController.viewControllers.first { ($0 as? ModuleIdentifiable)?.module == module }
    }

    /// 处理 .insertThenPop 策略
    ///
    /// 工作原理：
    /// 假设当前栈是 [Home, Detail]，要返回 Profile（不在栈中）
    /// 1. 创建 ProfileVC
    /// 2. 插入到 Detail 前面 → 栈变成 [Home, Profile, Detail]
    /// 3. pop 到 Profile → 栈变成 [Home, Profile]
    /// 4. 用户看到的效果：像正常返回一样的动画
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

    /// 处理 .pushAsNew 策略
    ///
    /// 直接 push 一个新的目标模块到栈顶
    /// 栈会变长，不会移除任何已有的 VC
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

    /// 在主 nav 的转场动画完成后执行回调
    ///
    /// 优先使用 transitionCoordinator 精确捕获动画完成时机，
    /// 如果没有活跃的转场（比如 animated=false），则立即执行
    func afterTransition(animated: Bool, completion: @escaping () -> Void) {
        if animated, let coordinator = navigationController.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in completion() }
        } else { completion() }
    }

    /// 在指定 nav 的转场动画完成后执行回调（用于模态内导航）
    func afterNavTransition(_ nav: UINavigationController, animated: Bool, completion: @escaping () -> Void) {
        if animated, let coordinator = nav.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in completion() }
        } else { completion() }
    }

    /// 应用自定义转场动画
    ///
    /// 如果 transition 不是 .default，临时替换 nav 的 delegate 为 TransitionDelegate，
    /// TransitionDelegate 会在 pop 动画完成后自动恢复原始 delegate（即 ModuleCoordinator 自己）
    /// push 和 pop 都会使用对应的自定义动画
    func applyTransition(_ transition: TransitionStyle) {
        guard let animators = transition.makeAnimators() else { return }
        let delegate = TransitionDelegate(pushAnimator: animators.push, popAnimator: animators.pop, originalDelegate: self)
        self.transitionDelegate = delegate
        navigationController.delegate = delegate
    }
}

// MARK: - UINavigationControllerDelegate

extension ModuleCoordinator: UINavigationControllerDelegate {
    /// 每当导航栈显示新的 VC 时触发
    /// 用于捕获用户手势返回（侧滑返回）等系统行为，并清理失效的子协调器
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        cleanupOrphanedFlowCoordinators()
    }

    /// 检测并清理已失效的 push 方式子协调器
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

/// 模块接收回传数据的协议
///
/// 当从 B 模块返回 A 模块并携带数据时，A 模块的 receiveData 会被调用
/// source 参数自动标识数据来自哪个模块
///
/// 使用方式：在 VC 中重写 receiveData 处理回传数据
/// ```swift
/// override func receiveData(_ data: Any, from source: Module) {
///     print("收到来自 \(source) 的数据: \(data)")
/// }
/// ```
public protocol ModuleDataReceivable: AnyObject {
    func receiveData(_ data: Any, from source: Module)
}

// MARK: - UINavigationController 扩展

public extension UINavigationController {
    private enum AssociatedKeys {
        static var moduleCoordinator: UInt8 = 0
    }

    /// 该 NavigationController 对应的 ModuleCoordinator（弱引用）
    ///
    /// 在 ModuleCoordinator 初始化时自动绑定，VC 通过此属性 O(1) 获取 coordinator，
    /// 无需依赖全局单例遍历 tabCoordinators。
    ///
    /// 使用 WeakBox 包装实现弱引用语义，避免循环引用：
    /// ModuleCoordinator 强持有 nav，nav 通过 weak associated object 反向引用 coordinator
    weak var associatedModuleCoordinator: ModuleCoordinator? {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.moduleCoordinator) as? WeakBox<ModuleCoordinator>)?.value }
        set {
            let box: WeakBox<ModuleCoordinator>? = newValue.map { WeakBox($0) }
            objc_setAssociatedObject(self, &AssociatedKeys.moduleCoordinator, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

/// 弱引用包装器，用于 associated object 的 weak 语义
private class WeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

// MARK: - UIViewController 扩展

public extension UIViewController {
    /// 递归获取最顶层的 presented ViewController
    ///
    /// 用于处理多层模态的情况：
    /// 主页面 → present 模态A → present 模态B
    /// 调用 navigationController.topPresentedViewController 会返回模态B
    var topPresentedViewController: UIViewController {
        presentedViewController?.topPresentedViewController ?? self
    }
}
