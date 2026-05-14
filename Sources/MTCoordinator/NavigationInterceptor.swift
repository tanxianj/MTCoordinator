//
//  NavigationInterceptor.swift
//  MTCoordinator
//
//  导航拦截器 —— 在导航发生前进行拦截判断
//

import UIKit

public protocol NavigationInterceptor: AnyObject {
    func shouldNavigate(to module: Module, data: Any?) -> Bool
    func didIntercept(navigation module: Module, data: Any?)
}

public extension NavigationInterceptor {
    func didIntercept(navigation module: Module, data: Any?) {}
}

public class InterceptorChain {
    private let interceptors = NSHashTable<AnyObject>.weakObjects()

    public init() {}

    public func add(_ interceptor: NavigationInterceptor) {
        interceptors.add(interceptor as AnyObject)
    }

    public func remove(_ interceptor: NavigationInterceptor) {
        interceptors.remove(interceptor as AnyObject)
    }

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

    public var count: Int { interceptors.count }
}
