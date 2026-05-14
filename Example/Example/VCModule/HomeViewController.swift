//
//  HomeViewController.swift
//  Example
//

import UIKit
import MTCoordinator

extension Module {
    static let home = Module("home") { _ in HomeViewController() }
}

class HomeViewController: BaseModuleViewController {
    override class var module: Module { .home }

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "🏠 首页"
        setupUI()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -40),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -80)
        ])

        // MARK: - 基础导航
        addButton(title: "去 Profile", color: .systemBlue) { [weak self] in
            self?.navigateTo(.profile)
        }
        addButton(title: "模态弹出 Profile", color: .systemPurple) { [weak self] in
            self?.presentModule(.profile)
        }

        // MARK: - 转场动画
        addButton(title: "🎬 Fade → Profile", color: .systemPink) { [weak self] in
            self?.navigateTo(.profile, transition: .fade)
        }
        addButton(title: "🎬 SlideUp → Profile", color: .systemOrange) { [weak self] in
            self?.navigateTo(.profile, transition: .slideUp)
        }
        addButton(title: "🎬 CrossDissolve → Profile", color: .systemPink.withAlphaComponent(0.6)) { [weak self] in
            self?.navigateTo(.profile, transition: .crossDissolve)
        }

        // MARK: - 拦截器演示
        addButton(title: "🚫 模拟未登录 → Profile（被拦截）", color: .systemRed.withAlphaComponent(0.7)) { [weak self] in
            AuthInterceptor.shared.isLoggedIn = false
            self?.navigateTo(.profile)
        }
        addButton(title: "✅ 恢复登录状态", color: .systemGreen.withAlphaComponent(0.7)) { [weak self] in
            AuthInterceptor.shared.isLoggedIn = true
            let alert = UIAlertController(title: "已恢复", message: "可正常访问 Profile", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }

        // MARK: - 导航历史
        addButton(title: "📜 打印导航历史", color: .systemGray) { [weak self] in
            NavigationHistory.shared.printHistory()
            let count = NavigationHistory.shared.records.count
            let alert = UIAlertController(title: "导航历史", message: "共 \(count) 条，已打印到控制台", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }

        // MARK: - 调试
        addButton(title: "打印协调器树 🌳", color: .systemGray) { [weak self] in
            self?.moduleCoordinator?.printCoordinatorTree()
        }

        // MARK: - 退出登录
        addButton(title: "退出登录", color: .systemRed) { [weak self] in
            AppCoordinator.shared?.logout()
        }
    }

    private func addButton(title: String, color: UIColor, action: @escaping () -> Void) {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.backgroundColor = color
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        btn.onTap { action() }
        stackView.addArrangedSubview(btn)
    }

    override func receiveData(_ data: Any, from source: Module) {
        super.receiveData(data, from: source)
        let alert = UIAlertController(title: "收到数据", message: "来自 [\(source)]: \(data)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
