//
//  BaseModuleViewController.swift
//  MTCoordinator
//
//  所有模块 VC 的基类
//

import UIKit

open class BaseModuleViewController: UIViewController, ModuleIdentifiable, ModuleDataReceivable {
    open class var module: Module { fatalError("子类必须重写 module") }

    public var appCoordinator: Coordinator? {
        var root: Coordinator? = moduleCoordinator
        while let parent = root?.parentCoordinator { root = parent }
        return root
    }

    public var moduleCoordinator: ModuleCoordinator? {
        if let coordinator = navigationController?.associatedModuleCoordinator {
            return coordinator
        }
        return nil
    }

    public var isInModal: Bool {
        return presentingViewController != nil || navigationController?.presentingViewController != nil
    }

    public var activeNavigationController: UINavigationController? {
        return navigationController
    }

    open func receiveData(_ data: Any, from source: Module) {
        print("[\(Self.module)] 收到来自 [\(source)] 的数据: \(data)")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "\(Self.module)"
    }

    // MARK: - 便捷导航方法

    public func navigateTo(_ module: Module, data: Any? = nil, transition: TransitionStyle = .default, animated: Bool = true) {
        if isInModal, let nav = activeNavigationController {
            moduleCoordinator?.navigateInNav(nav, to: module, data: data, animated: animated)
        } else {
            moduleCoordinator?.navigateTo(module, data: data, transition: transition, animated: animated)
        }
    }

    public func navigateThrough(_ intermediates: [Module], to target: Module, targetData: Any? = nil, animated: Bool = true) {
        moduleCoordinator?.navigateThrough(intermediates, to: target, targetData: targetData, animated: animated)
    }

    public func backTo(_ module: Module, strategy: BackStrategy = .ignore, data: Any? = nil, source: Module? = nil, animated: Bool = true) {
        let sourceModule = source ?? Self.module
        if isInModal, let nav = activeNavigationController {
            let success = moduleCoordinator?.backInNav(nav, to: module, strategy: strategy, data: data, sourceModule: sourceModule, animated: animated) ?? false
            if !success {
                moduleCoordinator?.dismissModal(data: data, sourceModule: sourceModule, animated: animated)
            }
        } else {
            moduleCoordinator?.backTo(module, strategy: strategy, data: data, sourceModule: sourceModule, animated: animated)
        }
    }

    public func presentModule(_ module: Module, data: Any? = nil, wrapInNav: Bool = true, style: UIModalPresentationStyle = .pageSheet, animated: Bool = true) {
        moduleCoordinator?.present(module, data: data, wrapInNav: wrapInNav, style: style, animated: animated)
    }

    public func dismissModule(data: Any? = nil, source: Module? = nil, animated: Bool = true) {
        if isInModal {
            moduleCoordinator?.dismissModal(data: data, sourceModule: source ?? Self.module, animated: animated)
        } else { pop(animated: animated) }
    }

    public func pop(animated: Bool = true) {
        if isInModal, let nav = activeNavigationController {
            if nav.viewControllers.count <= 1 { moduleCoordinator?.dismissModal(animated: animated) }
            else { nav.popViewController(animated: animated) }
        } else { moduleCoordinator?.popCurrent(animated: animated) }
    }

    public func popToRoot(animated: Bool = true) {
        if isInModal, let nav = activeNavigationController { nav.popToRootViewController(animated: animated) }
        else { moduleCoordinator?.popToRoot(animated: animated) }
    }

    // MARK: - String 便捷方法

    public func navigateTo(_ rawModule: String, data: Any? = nil, animated: Bool = true) {
        navigateTo(Module(rawModule), data: data, animated: animated)
    }

    public func backTo(_ rawModule: String, strategy: BackStrategy = .ignore, data: Any? = nil, source: Module? = nil, animated: Bool = true) {
        backTo(Module(rawModule), strategy: strategy, data: data, source: source, animated: animated)
    }

    public func presentModule(_ rawModule: String, data: Any? = nil, wrapInNav: Bool = true, style: UIModalPresentationStyle = .pageSheet, animated: Bool = true) {
        presentModule(Module(rawModule), data: data, wrapInNav: wrapInNav, style: style, animated: animated)
    }

    public func navigateThrough(_ intermediates: [String], to target: String, targetData: Any? = nil, animated: Bool = true) {
        navigateThrough(intermediates.map { Module($0) }, to: Module(target), targetData: targetData, animated: animated)
    }

    // MARK: - 路径导航

    public func navigateTo(path: String, targetData: Any? = nil, animated: Bool = true) {
        let components = path.split(separator: "/").map { String($0) }
        guard let last = components.last else { return }
        let target = Module(last)
        let intermediates = components.dropLast().map { Module($0) }
        if intermediates.isEmpty { navigateTo(target, data: targetData, animated: animated) }
        else { navigateThrough(intermediates, to: target, targetData: targetData, animated: animated) }
    }
}
