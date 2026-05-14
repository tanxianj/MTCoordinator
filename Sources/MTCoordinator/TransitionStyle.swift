//
//  TransitionStyle.swift
//  MTCoordinator
//
//  自定义转场动画支持（push + pop 双向动画）
//
//  提供几种内置转场动画，也支持完全自定义：
//  - .default：系统默认 push/pop 动画
//  - .fade：淡入淡出（push 淡入，pop 淡出）
//  - .slideUp：从底部滑入/滑出（push 上滑，pop 下滑）
//  - .crossDissolve：交叉溶解
//  - .custom(push, pop)：完全自定义 push 和 pop 动画
//
//  push 和 pop 都会使用对应的动画，返回时不会突然变成系统默认动画。
//  只影响当次 push 和对应的 pop，在该 VC 上继续 push 新页面时使用系统默认动画。
//

import UIKit

// MARK: - 转场样式枚举

/// 导航转场动画样式
///
/// push 和 pop 都会使用对应的动画效果：
/// - fade: push 淡入，pop 淡出
/// - slideUp: push 从底部滑入，pop 向底部滑出
/// - crossDissolve: push/pop 都是交叉溶解
///
/// 使用方式：
/// ```swift
/// navigateTo(.detail, transition: .fade)
/// navigateTo(.profile, transition: .slideUp)
/// navigateTo(.settings, transition: .custom(push: MyPushAnim(), pop: MyPopAnim()))
/// ```
public enum TransitionStyle {
    /// 系统默认动画（push 从右滑入，pop 从右滑出）
    case `default`
    /// 淡入淡出（push 淡入，pop 淡出）
    case fade
    /// 从底部滑入/滑出（push 上滑入，pop 下滑出）
    case slideUp
    /// 交叉溶解
    case crossDissolve
    /// 完全自定义转场动画（分别指定 push 和 pop 的 animator）
    case custom(push: UIViewControllerAnimatedTransitioning, pop: UIViewControllerAnimatedTransitioning)
}

// MARK: - TransitionStyle 辅助方法

public extension TransitionStyle {
    /// 根据样式创建 push 和 pop 的 animator 对
    /// .default 返回 nil（使用系统动画）
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

// MARK: - 转场动画代理

/// 转场动画代理 —— 设置在 UINavigationController 上，拦截 push/pop 动画
///
/// 工作原理：
/// 1. navigateTo 时如果指定了非 .default 的 transition，设置此代理
/// 2. push 时记录目标 VC，返回 pushAnimator
/// 3. pop 该 VC 时返回 popAnimator（反向动画）
/// 4. pop 动画完成后自动恢复原始 delegate
/// 5. 在该 VC 上继续 push 新页面时返回 nil（使用系统默认动画）
///
/// 这样 push 和 pop 都有对应的自定义动画，不会出现"去的时候有动画，回来没有"的问题。
public class TransitionDelegate: NSObject, UINavigationControllerDelegate {
    private let pushAnimator: UIViewControllerAnimatedTransitioning
    private let popAnimator: UIViewControllerAnimatedTransitioning
    /// 原始的 delegate（通常是 ModuleCoordinator 自己），pop 完成后恢复
    public weak var originalDelegate: UINavigationControllerDelegate?
    /// 记录用自定义动画 push 进来的 VC，pop 该 VC 后恢复原始 delegate
    private weak var pushedViewController: UIViewController?

    public init(pushAnimator: UIViewControllerAnimatedTransitioning,
                popAnimator: UIViewControllerAnimatedTransitioning,
                originalDelegate: UINavigationControllerDelegate?) {
        self.pushAnimator = pushAnimator
        self.popAnimator = popAnimator
        self.originalDelegate = originalDelegate
        super.init()
    }

    public func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push:
            // 只有第一次 push（pushedViewController == nil）时才用自定义动画
            if pushedViewController == nil {
                pushedViewController = toVC
                return pushAnimator
            }
            // 后续的 push（在自定义动画页面上继续 push 新页面）用系统默认
            return nil
        case .pop:
            // 只有 pop 我们 push 进来的那个 VC 时才用自定义动画
            if fromVC === pushedViewController {
                return popAnimator
            }
            return nil
        default:
            return nil
        }
    }

    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // 如果被 push 的 VC 已经不在栈中了（说明已被 pop），恢复原始 delegate
        if let pushed = pushedViewController,
           !navigationController.viewControllers.contains(pushed) {
            navigationController.delegate = originalDelegate
            originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        } else if pushedViewController == nil {
            // pushedViewController 已被释放（dealloc），恢复
            navigationController.delegate = originalDelegate
            originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        } else {
            // push 完成，转发给原始 delegate（但不恢复，等 pop 时再恢复）
            originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        }
    }
}

// MARK: - 内置转场动画

/// 淡入转场动画（用于 push）
public class FadeInTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval

    public init(duration: TimeInterval = 0.3) { self.duration = duration }

    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }

    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.addSubview(toView)
        toView.alpha = 0
        UIView.animate(withDuration: duration, animations: {
            toView.alpha = 1
        }) { _ in
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}

/// 淡出转场动画（用于 pop）
public class FadeOutTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval

    public init(duration: TimeInterval = 0.3) { self.duration = duration }

    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }

    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let fromView = ctx.view(forKey: .from),
              let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.insertSubview(toView, belowSubview: fromView)
        UIView.animate(withDuration: duration, animations: {
            fromView.alpha = 0
        }) { _ in
            fromView.alpha = 1
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}

/// 从底部滑入转场动画（用于 push）
public class SlideUpTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval

    public init(duration: TimeInterval = 0.35) { self.duration = duration }

    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }

    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let toView = ctx.view(forKey: .to),
              let toVC = ctx.viewController(forKey: .to) else { ctx.completeTransition(false); return }
        let container = ctx.containerView
        let finalFrame = ctx.finalFrame(for: toVC)
        toView.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
        container.addSubview(toView)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut,
            animations: { toView.frame = finalFrame }
        ) { _ in
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}

/// 向底部滑出转场动画（用于 pop）
public class SlideDownTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval

    public init(duration: TimeInterval = 0.3) { self.duration = duration }

    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }

    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let fromView = ctx.view(forKey: .from),
              let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.insertSubview(toView, belowSubview: fromView)
        let offscreen = fromView.frame.offsetBy(dx: 0, dy: fromView.frame.height)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseIn,
            animations: { fromView.frame = offscreen }
        ) { _ in
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}

/// 交叉溶解转场动画（push 和 pop 通用）
public class CrossDissolveTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let duration: TimeInterval

    public init(duration: TimeInterval = 0.3) { self.duration = duration }

    public func transitionDuration(using ctx: UIViewControllerContextTransitioning?) -> TimeInterval { duration }

    public func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let fromView = ctx.view(forKey: .from),
              let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        ctx.containerView.addSubview(toView)
        toView.alpha = 0
        UIView.animate(withDuration: duration, animations: {
            fromView.alpha = 0
            toView.alpha = 1
        }) { _ in
            fromView.alpha = 1
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
    }
}
