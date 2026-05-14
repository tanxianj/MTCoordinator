//
//  NavigationInterceptor.swift
//  MTCoordinator
//
//  导航拦截器 —— 在导航发生前进行拦截判断
//
//  典型场景：
//  - 未登录用户点击需要登录的页面 → 拦截并弹出登录
//  - VIP 专属页面 → 拦截并弹出付费提示
//  - 维护中的功能 → 拦截并提示
//

import UIKit

// MARK: - 导航拦截器协议

/// 导航拦截器协议
///
/// 使用方式：
/// ```swift
/// class AuthInterceptor: NavigationInterceptor {
///     func shouldNavigate(to module: Module, data: Any?) -> Bool {
///         if module == .vipPage && !UserManager.isVIP {
///             return false  // 拦截
///         }
///         return true  // 放行
///     }
///
///     func didIntercept(navigation module: Module, data: Any?) {
///         // 被拦截后的操作：弹出登录页、VIP 提示等
///     }
/// }
///
/// moduleCoordinator.interceptors.add(AuthInterceptor())
/// ```
public protocol NavigationInterceptor: AnyObject {
    /// 导航前调用，返回 true 允许导航，返回 false 拦截
    /// - Parameters:
    ///   - module: 目标模块
    ///   - data: 传递的数据
    /// - Returns: 是否允许导航继续
    func shouldNavigate(to module: Module, data: Any?) -> Bool

    /// 导航被拦截时调用（可选实现）
    /// 用于执行拦截后的操作（如弹出登录页、提示等）
    func didIntercept(navigation module: Module, data: Any?)
}

public extension NavigationInterceptor {
    /// 默认空实现，不需要处理拦截后操作时可以不实现
    func didIntercept(navigation module: Module, data: Any?) {}
}

// MARK: - 拦截器容器

/// 拦截器容器 —— 支持多个拦截器链式判断
///
/// 任何一个拦截器返回 false，导航就会被拦截。
/// 拦截时会调用第一个返回 false 的拦截器的 didIntercept 方法。
///
/// 使用方式：
/// ```swift
/// let interceptors = InterceptorChain()
/// interceptors.add(authInterceptor)
/// interceptors.add(vipInterceptor)
///
/// if interceptors.canNavigate(to: .vipPage, data: nil) {
///     // 所有拦截器都放行，可以导航
/// }
/// ```
///
/// > 内部使用 NSHashTable.weakObjects() 弱引用存储，
/// > 拦截器被释放后自动从列表中移除，不会造成循环引用。
public class InterceptorChain {
    private let interceptors = NSHashTable<AnyObject>.weakObjects()

    public init() {}

    /// 添加拦截器（弱引用）
    public func add(_ interceptor: NavigationInterceptor) {
        interceptors.add(interceptor as AnyObject)
    }

    /// 移除拦截器
    public func remove(_ interceptor: NavigationInterceptor) {
        interceptors.remove(interceptor as AnyObject)
    }

    /// 检查是否允许导航
    ///
    /// 遍历所有拦截器，任何一个返回 false 就拦截。
    /// 被拦截时调用该拦截器的 `didIntercept` 方法。
    ///
    /// - Returns: true 表示所有拦截器都允许，false 表示被拦截
    public func canNavigate(to module: Module, data: Any?) -> Bool {
        for obj in interceptors.allObjects {
            guard let interceptor = obj as? NavigationInterceptor else { continue }
            if !interceptor.shouldNavigate(to: module, data: data) {
                interceptor.didIntercept(navigation: module, data: data)
                return false
            }
        }
        return true
    }

    /// 当前拦截器数量
    public var count: Int { interceptors.count }
}
