//
//  AppDelegate.swift
//  Example
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if #available(iOS 13.0, *) {
            // iOS 13+ 走 SceneDelegate
        } else {
            let window = UIWindow(frame: UIScreen.main.bounds)
            let nav = UINavigationController()
            nav.navigationBar.prefersLargeTitles = true

            appCoordinator = AppCoordinator(navigationController: nav)
            appCoordinator?.start()

            window.rootViewController = nav
            window.makeKeyAndVisible()
            self.window = window
        }
        return true
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
