//
//  UIButton+Closure.swift
//  MTCoordinator
//
//  UIButton 闭包扩展 —— 兼容 iOS 12+
//

import UIKit

public extension UIButton {
    func onTap(_ action: @escaping () -> Void) {
        let wrapper = ClosureWrapper(action)
        objc_setAssociatedObject(self, &AssociatedKeys.tapAction, wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        guard let wrapper = objc_getAssociatedObject(self, &AssociatedKeys.tapAction) as? ClosureWrapper else { return }
        wrapper.action()
    }

    private enum AssociatedKeys {
        static var tapAction: UInt8 = 0
    }
}

private class ClosureWrapper {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}
