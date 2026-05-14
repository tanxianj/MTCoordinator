//
//  AuthCoordinator.swift
//  Example
//
//  登录流程协调器
//

import UIKit
import MTCoordinator

protocol AuthCoordinatorDelegate: AnyObject {
    func authCoordinatorDidFinish(_ coordinator: AuthCoordinator)
}

class AuthCoordinator: NSObject, Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    weak var parentCoordinator: Coordinator?
    weak var delegate: AuthCoordinatorDelegate?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let loginVC = LoginViewController()
        loginVC.onLoginSuccess = { [weak self] in
            guard let self = self else { return }
            self.delegate?.authCoordinatorDidFinish(self)
        }
        navigationController.setViewControllers([loginVC], animated: false)
    }
}
