#import "BLAppDelegate.h"
#import "BLControlViewController.h"
#import "BLCountriesViewController.h"
#import "BLCommon.h"

@implementation BLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    BLControlViewController *control = [[BLControlViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
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
    return YES;
}

@end
