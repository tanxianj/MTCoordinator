//
//  LoginViewController.swift
//  Example
//

import UIKit
import MTCoordinator

extension Module {
    static let login = Module("login") { _ in LoginViewController() }
}

class LoginViewController: BaseModuleViewController {
    override class var module: Module { .login }

    var onLoginSuccess: (() -> Void)?

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "🔐 登录"
        setupUI()
    }

    private func setupUI() {
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        addButton(title: "登录成功 → 进入首页", color: .systemGreen) { [weak self] in
            self?.onLoginSuccess?()
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
}
