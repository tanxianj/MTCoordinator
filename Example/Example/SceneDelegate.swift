//
//  SceneDelegate.swift
//  Example
//

import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController()
        nav.navigationBar.prefersLargeTitles = true

        appCoordinator = AppCoordinator(navigationController: nav)
        appCoordinator?.start()

        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
    }
}
