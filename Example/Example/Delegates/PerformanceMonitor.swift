//
//  PerformanceMonitor.swift
//  Example
//
//  性能监控器 —— 监听导航事件，统计页面切换耗时
//

import Foundation
import MTCoordinator

class PerformanceMonitor: ModuleCoordinatorDelegate {

    static let shared = PerformanceMonitor()

    private var enterTimestamps: [String: Date] = [:]
    private(set) var navigationCount: Int = 0
    private(set) var failureCount: Int = 0

    private init() {}

    func coordinatorDidNavigate(to module: Module) {
        navigationCount += 1
        enterTimestamps[module.rawValue] = Date()
        print("⏱️ [Perf] 进入 \(module) | 总导航次数: \(navigationCount)")
    }

    func coordinatorDidReturn(to module: Module) {
        enterTimestamps[module.rawValue] = Date()
        print("⏱️ [Perf] 返回 \(module) | 总导航次数: \(navigationCount)")
    }

    func coordinatorDidFailNavigation(to module: Module, reason: String) {
        failureCount += 1
        print("⚠️ [Perf] 导航失败 \(module) | 失败次数: \(failureCount)")
    }

    func duration(for module: Module) -> TimeInterval? {
        guard let enter = enterTimestamps[module.rawValue] else { return nil }
        return Date().timeIntervalSince(enter)
    }

    func reset() {
        enterTimestamps.removeAll()
        navigationCount = 0
        failureCount = 0
    }
}
