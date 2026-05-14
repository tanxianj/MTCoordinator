//
//  AuthInterceptor.swift
//  Example
//
//  登录拦截器示例 —— 演示 NavigationInterceptor 的用法
//

import UIKit
import MTCoordinator

class AuthInterceptor: NavigationInterceptor {

    static let shared = AuthInterceptor()

    var isLoggedIn: Bool = true
    var authRequiredModules: Set<Module> = [.profile]

    private init() {}

    func shouldNavigate(to module: Module, data: Any?) -> Bool {
        if authRequiredModules.contains(module) && !isLoggedIn {
            return false
        }
        return true
    }

    func didIntercept(navigation module: Module, data: Any?) {
        print("🚫 [AuthInterceptor] 拦截导航到 \(module)，原因：未登录")

        guard let topVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?
            .rootViewController?.topPresentedViewController else { return }

        let alert = UIAlertController(
            title: "需要登录",
            message: "访问「\(module)」需要先登录",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        topVC.present(alert, animated: true)
    }
}
