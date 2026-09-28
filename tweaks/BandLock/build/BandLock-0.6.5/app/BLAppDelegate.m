#import "BLAppDelegate.h"
#import "BLControlViewController.h"
#import "BLCountriesViewController.h"
#import "BLCommon.h"
#import "BLTelephonyManager.h"
#import "BLDiagnostics.h"

@implementation BLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BLDiagLog(@"AppDelegate didFinish begin");
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

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

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[controlNav, countriesNav];

    UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
    [navAppearance configureWithDefaultBackground];
    navAppearance.largeTitleTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:34 weight:UIFontWeightBold]};
    UINavigationBar.appearance.standardAppearance = navAppearance;
    UINavigationBar.appearance.scrollEdgeAppearance = navAppearance;

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];
    BLDiagLog(@"AppDelegate didFinish complete");
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if (![[url.scheme lowercaseString] isEqualToString:@"bandlock"] || ![[url.host lowercaseString] isEqualToString:@"diag"]) return NO;
    NSString *command = url.path.lowercaseString ?: @"";
    BLDiagLog([NSString stringWithFormat:@"diag URL %@", command]);
    if ([command isEqualToString:@"/ping"]) {
        BLDiagLog(@"diag ping OK");
        return YES;
    }
    if ([command isEqualToString:@"/refresh"]) {
        [BLTelephonyManager.sharedManager refreshWithCompletion:^(BOOL success, NSString *message) {
            BLDiagLog([NSString stringWithFormat:@"diag refresh completion success=%d message=%@", success, message]);
        }];
        return YES;
    }
    return YES;
}

@end
