import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
//        let viewController = LucasKanadeViewController()
        let viewController = SIFTViewController()
//        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemRed
        window = UIWindow()
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        return true
    }

}
