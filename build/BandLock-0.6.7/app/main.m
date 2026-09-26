#import <UIKit/UIKit.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

static void BLProbeLog(const char *message) {
    int fd = open("/var/mobile/BandLock-0.6.7-probe.log", O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) return;
    write(fd, message, strlen(message));
    close(fd);
}

@interface BLMinimalViewController : UIViewController
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation BLMinimalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    BLProbeLog("viewDidLoad\n");
    self.title = @"BandLock 0.6.7";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"UI minima lista";
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    self.statusLabel = label;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:@"Probar boton" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    [button addTarget:self action:@selector(testTapped:) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:label];
    [self.view addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30],
        [button.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [button.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:28],
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:48]
    ]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BLProbeLog("auto dispatch fired\n");
        [self testTapped:nil];
    });
}

- (void)testTapped:(UIButton *)sender {
    BLProbeLog("button tapped\n");
    self.statusLabel.text = @"Boton OK";
    [sender setTitle:@"Funciona" forState:UIControlStateNormal];
}

@end

@interface BLMinimalAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation BLMinimalAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BLProbeLog("didFinishLaunching begin\n");
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    BLMinimalViewController *root = [[BLMinimalViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    BLProbeLog("didFinishLaunching complete\n");
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    BLProbeLog("openURL\n");
    return YES;
}

@end

int main(int argc, char *argv[]) {
    BLProbeLog("variant=no-container\n");
    BLProbeLog("enter main\n");
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"BLMinimalAppDelegate");
    }
}
