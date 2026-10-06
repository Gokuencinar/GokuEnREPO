#import "BLAppDelegate.h"
#import "BLControlViewController.h"
#import "BLCountriesViewController.h"
#import "BLInfoViewController.h"
#import "BLCommon.h"
#import "BLLocalization.h"
#import "BLTelephonyManager.h"
#import "BLBreadcrumb.h"

@implementation BLAppDelegate

- (UITabBarController *)buildRootTabsWithSelectedIndex:(NSUInteger)selectedIndex {
    BLControlViewController *control = [[BLControlViewController alloc] init];
    UINavigationController *controlNav = [[UINavigationController alloc] initWithRootViewController:control];
    controlNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:BLT(@"Control", @"Control")
                                                     image:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"]
                                                       tag:0];

    BLCountriesViewController *countries = [[BLCountriesViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *countriesNav = [[UINavigationController alloc] initWithRootViewController:countries];
    countriesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:BLT(@"Países", @"Countries")
                                                       image:[UIImage systemImageNamed:@"globe.europe.africa.fill"]
                                                         tag:1];

    BLInfoViewController *info = [[BLInfoViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *infoNav = [[UINavigationController alloc] initWithRootViewController:info];
    infoNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:BLT(@"Ajustes", @"Settings")
                                                  image:[UIImage systemImageNamed:@"gearshape.fill"]
                                                    tag:2];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[controlNav, countriesNav, infoNav];
    if (selectedIndex < tabs.viewControllers.count) tabs.selectedIndex = selectedIndex;

    return tabs;
}

- (void)rebuildRootInterfacePreservingTab:(BOOL)preserveTab {
    NSUInteger selectedIndex = 0;
    if (preserveTab && [self.window.rootViewController isKindOfClass:[UITabBarController class]]) {
        selectedIndex = ((UITabBarController *)self.window.rootViewController).selectedIndex;
    }
    self.window.rootViewController = [self buildRootTabsWithSelectedIndex:selectedIndex];
}

- (void)languageDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{ [self rebuildRootInterfacePreservingTab:YES]; });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
    [navAppearance configureWithDefaultBackground];
    navAppearance.largeTitleTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:34 weight:UIFontWeightBold]};
    UINavigationBar.appearance.standardAppearance = navAppearance;
    UINavigationBar.appearance.scrollEdgeAppearance = navAppearance;

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(languageDidChange:) name:BLLanguageDidChangeNotification object:nil];
    [self rebuildRootInterfacePreservingTab:NO];
    [self.window makeKeyAndVisible];
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    BLBreadcrumbf("deep link enter scheme=%s host=%s path=%s",
                  url.scheme.UTF8String ?: "(null)",
                  url.host.UTF8String ?: "(null)",
                  url.path.UTF8String ?: "(null)");
    if (![[url.scheme lowercaseString] isEqualToString:@"bandlock"] || ![[url.host lowercaseString] isEqualToString:@"diag"]) {
        BLBreadcrumb("deep link rejected");
        return NO;
    }
    NSString *command = url.path.lowercaseString ?: @"";
    if ([command isEqualToString:@"/ping"]) {
        BLBreadcrumb("deep link ping accepted");
        return YES;
    }
    if ([command isEqualToString:@"/refresh"]) {
        BLBreadcrumb("deep link refresh begin");
        [BLTelephonyManager.sharedManager refreshWithCompletion:^(BOOL success, NSString *message) {
            BLBreadcrumbf("deep link refresh completion success=%d message=%s",
                          success ? 1 : 0,
                          message.UTF8String ?: "(null)");
        }];
        BLBreadcrumb("deep link refresh queued");
        return YES;
    }
    BLBreadcrumb("deep link unknown command accepted");
    return YES;
}

@end
