//
//  AnalyticsTracker.swift
//  Example
//
//  埋点监听器 —— 监听导航事件，上报页面曝光和退出
//

import Foundation
import MTCoordinator

class AnalyticsTracker: ModuleCoordinatorDelegate {

    static let shared = AnalyticsTracker()
    private init() {}

    func coordinatorDidNavigate(to module: Module) {
        trackEvent("page_view", params: ["module": module.rawValue])
    }

    func coordinatorDidReturn(to module: Module) {
        trackEvent("page_return", params: ["module": module.rawValue])
    }

    func coordinatorDidFailNavigation(to module: Module, reason: String) {
        trackEvent("navigation_error", params: ["module": module.rawValue, "reason": reason])
    }

    private func trackEvent(_ event: String, params: [String: String]) {
        let paramsStr = params.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        print("📊 [Analytics] \(event) | \(paramsStr)")
    }
}
