//
//  TransitionStyle.swift
//  MTCoordinator
//
//  自定义转场动画支持（push + pop 双向动画）
//

import UIKit

// MARK: - 转场样式枚举

public enum TransitionStyle {
    case `default`
    case fade
    case slideUp
    case crossDissolve
    case custom(push: UIViewControllerAnimatedTransitioning, pop: UIViewControllerAnimatedTransitioning)
}

// MARK: - TransitionStyle 辅助方法

public extension TransitionStyle {
    func makeAnimators() -> (push: UIViewControllerAnimatedTransitioning, pop: UIViewControllerAnimatedTransitioning)? {
        switch self {
        case .default: return nil
        case .fade: return (push: FadeInTransition(), pop: FadeOutTransition())
        case .slideUp: return (push: SlideUpTransition(), pop: SlideDownTransition())
        case .crossDissolve: return (push: CrossDissolveTransition(), pop: CrossDissolveTransition())
        case .custom(let push, let pop): return (push: push, pop: pop)
        }
    }
}

// MARK: - TransitionDelegate

public class TransitionDelegate: NSObject, UINavigationControllerDelegate {
    private let pushAnimator: UIViewControllerAnimatedTransitioning
    private let popAnimator: UIViewControllerAnimatedTransitioning
    public weak var originalDelegate: UINavigationControllerDelegate?
    private weak var pushedViewController: UIViewController?

    public init(pushAnimator: UIViewControllerAnimatedTransitioning, popAnimator: UIViewControllerAnimatedTransitioning, originalDelegate: UINavigationControllerDelegate?) {
        self.pushAnimator = pushAnimator
        self.popAnimator = popAnimator
        self.originalDelegate = originalDelegate
        super.init()
    }

    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push:
            if pushedViewController == nil {
                pushedViewController = toVC
                return pushAnimator
            }
            return nil
        case .pop:
            if fromVC === pushedViewController { return popAnimator }
            return nil
        default: return nil
        }
    }

    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if let pushed = pushedViewController, !navigationController.viewControllers.contains(pushed) {
            navigationController.delegate = originalDelegate
            originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        } else if pushedViewController == nil {
            navigationController.delegate = originalDelegate
            originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        } else {
            originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        }
    }
}

// MARK: - 内置转场动画

public class FadeInTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval
    public init(duration: TimeInterval = 0.3) { self.duration = duration }
    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }
    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.addSubview(toView)
        toView.alpha = 0
        UIView.animate(withDuration: duration, animations: { toView.alpha = 1 }) { _ in ctx.completeTransition(!ctx.transitionWasCancelled) }
    }
}

public class FadeOutTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval
    public init(duration: TimeInterval = 0.3) { self.duration = duration }
    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }
    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let fromView = ctx.view(forKey: .from), let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.insertSubview(toView, belowSubview: fromView)
        UIView.animate(withDuration: duration, animations: { fromView.alpha = 0 }) { _ in
            fromView.alpha = 1
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}

public class SlideUpTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval
    public init(duration: TimeInterval = 0.35) { self.duration = duration }
    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }
    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let toView = ctx.view(forKey: .to), let toVC = ctx.viewController(forKey: .to) else { ctx.completeTransition(false); return }
        let container = ctx.containerView
        let finalFrame = ctx.finalFrame(for: toVC)
        toView.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
        container.addSubview(toView)
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: { toView.frame = finalFrame }) { _ in ctx.completeTransition(!ctx.transitionWasCancelled) }
    }
}

public class SlideDownTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval
    public init(duration: TimeInterval = 0.3) { self.duration = duration }
    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }
    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let fromView = ctx.view(forKey: .from), let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.insertSubview(toView, belowSubview: fromView)
        let offscreen = fromView.frame.offsetBy(dx: 0, dy: fromView.frame.height)
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseIn, animations: { fromView.frame = offscreen }) { _ in ctx.completeTransition(!ctx.transitionWasCancelled) }
    }
}

public class CrossDissolveTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval
    public init(duration: TimeInterval = 0.3) { self.duration = duration }
    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }
    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let fromView = ctx.view(forKey: .from), let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.addSubview(toView)
        toView.alpha = 0
        UIView.animate(withDuration: duration, animations: { fromView.alpha = 0; toView.alpha = 1 }) { _ in
            fromView.alpha = 1
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}
