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
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        addButton(title: "去 Profile", color: .systemBlue) { [weak self] in
            self?.navigateTo(.profile)
        }
        addButton(title: "🎬 Fade 转场 → Profile", color: .systemPink) { [weak self] in
            self?.navigateTo(.profile, transition: .fade)
        }
        addButton(title: "🎬 SlideUp 转场 → Profile", color: .systemOrange) { [weak self] in
            self?.navigateTo(.profile, transition: .slideUp)
        }
        addButton(title: "模态弹出 Profile", color: .systemPurple) { [weak self] in
            self?.presentModule(.profile)
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
