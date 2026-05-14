//
//  AppCoordinator.swift
//  Example
//
//  示例 AppCoordinator —— 演示如何使用 MTCoordinator 框架
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

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
        AppCoordinator.shared = self
    }

    func start() {
        // 注册模块
        _ = Module.home
        _ = Module.profile

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
