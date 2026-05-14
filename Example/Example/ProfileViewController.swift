//
//  ProfileViewController.swift
//  Example
//

import UIKit
import MTCoordinator

extension Module {
    static let profile = Module("profile") { _ in ProfileViewController() }
}

class ProfileViewController: BaseModuleViewController {
    override class var module: Module { .profile }

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "👤 我的"
        view.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
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

        addButton(title: "返回 Home（回传数据）", color: .systemRed) { [weak self] in
            self?.backTo(.home, data: "来自 Profile 的问候")
        }
        addButton(title: "关闭模态", color: .systemGray) { [weak self] in
            self?.dismissModule(data: "模态回传数据")
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
    }
}
