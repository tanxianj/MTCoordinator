//
//  AppCoordinator.swift
//  Example
//
//  应用级协调器：
//  - 未登录 → AuthCoordinator（登录页）
//  - 登录后 → ModuleCoordinator（首页）
//

import UIKit
import MTCoordinator

class AppCoordinator: NSObject, Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    weak var parentCoordinator: Coordinator?

    static weak var shared: AppCoordinator?

    var moduleCoordinator: ModuleCoordinator? {
        return tabCoordinators.first
    }

    private(set) var tabCoordinators: [ModuleCoordinator] = []
    private var isLoggedIn = false

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
        AppCoordinator.shared = self
    }

    func start() {
        // 注册所有模块
        _ = Module.login
        _ = Module.home
        _ = Module.profile

        if isLoggedIn {
            showMainFlow()
        } else {
            showAuthFlow()
        }
    }

    // MARK: - 登录流程

    private func showAuthFlow() {
        let auth = AuthCoordinator(navigationController: navigationController)
        auth.delegate = self
        addChild(auth)
        auth.start()
        print("👶 addChild(AuthCoordinator)")
    }

    // MARK: - 主页流程

    private func showMainFlow() {
        if let auth = findChild(ofType: AuthCoordinator.self) {
            removeChild(auth)
            print("🗑️ removeChild(AuthCoordinator)")
        }

        let factory = DefaultModuleFactory()
        let coordinator = ModuleCoordinator(navigationController: navigationController, moduleFactory: factory)
        coordinator.delegates.add(self)
        coordinator.delegates.add(AnalyticsTracker.shared)
        coordinator.delegates.add(PerformanceMonitor.shared)
        coordinator.delegates.add(NavigationHistory.shared)
        coordinator.interceptors.add(AuthInterceptor.shared)
        tabCoordinators = [coordinator]
        addChild(coordinator)
        coordinator.navigateTo(.home, animated: false)
        print("👶 addChild(ModuleCoordinator) | 进入主页")
    }

    // MARK: - 退出登录

    func logout() {
        isLoggedIn = false
        tabCoordinators = []
        removeAllChildren()
        print("🗑️ removeAllChildren() | 退出登录")
        showAuthFlow()
    }
}

// MARK: - AuthCoordinatorDelegate

extension AppCoordinator: AuthCoordinatorDelegate {
    func authCoordinatorDidFinish(_ coordinator: AuthCoordinator) {
        isLoggedIn = true
        showMainFlow()
    }
}

// MARK: - ModuleCoordinatorDelegate

extension AppCoordinator: ModuleCoordinatorDelegate {
    func coordinatorDidNavigate(to module: Module) {
        print("📍 导航到: \(module)")
    }
    func coordinatorDidReturn(to module: Module) {
        print("🔙 返回到: \(module)")
    }
    func coordinatorDidFailNavigation(to module: Module, reason: String) {
        print("❌ 导航失败: \(module) - \(reason)")
    }
}

// MARK: - 默认模块工厂

class DefaultModuleFactory: ModuleFactory {
    func makeViewController(for module: Module, data: Any?) -> (UIViewController & ModuleIdentifiable)? {
        if let builder = Module.builder(for: module) {
            return builder(data)
        }
        return nil
    }
}
