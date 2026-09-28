from pathlib import Path
import plistlib
import base64

root=Path("BetterWiFi-RH")

# Reuse the exact credits avatar already used by BandLock.
avatar_b64=Path("credits_avatar.b64").read_text()
avatar=base64.b64decode(avatar_b64)
(root/"prefs/Resources/CreditsAvatar.jpg").write_bytes(avatar)

controller=root/"prefs/BWRHRootListController.m"
s=controller.read_text()

if '#import <UIKit/UIKit.h>' not in s:
    s=s.replace('#import <Preferences/PSSpecifier.h>\n', '#import <Preferences/PSSpecifier.h>\n#import <UIKit/UIKit.h>\n')

impl='@implementation BWRHRootListController\n'
if impl not in s:
    raise SystemExit("implementation anchor not found")

methods=r'''
- (NSString *)bwrh_creditsTextSpanish:(NSString *)spanish english:(NSString *)english {
    NSInteger mode = BWRHPrefsLanguageMode();
    if (mode == 1) return spanish;
    if (mode == 2) return english;
    NSString *language = [NSLocale preferredLanguages].firstObject ?: @"en";
    return [[language lowercaseString] hasPrefix:@"es"] ? spanish : english;
}

- (UIImage *)bwrh_creditsAvatarImage {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"CreditsAvatar" ofType:@"jpg"];
    UIImage *source = path.length ? [UIImage imageWithContentsOfFile:path] : nil;
    if (!source) return [UIImage systemImageNamed:@"person.crop.circle.fill"];

    CGSize size = CGSizeMake(64.0, 64.0);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect bounds = (CGRect){CGPointZero, size};
        [[UIBezierPath bezierPathWithOvalInRect:bounds] addClip];
        CGFloat scale = MAX(size.width / source.size.width, size.height / source.size.height);
        CGSize drawSize = CGSizeMake(source.size.width * scale, source.size.height * scale);
        CGRect drawRect = CGRectMake((size.width - drawSize.width) * 0.5,
                                     (size.height - drawSize.height) * 0.5,
                                     drawSize.width,
                                     drawSize.height);
        [source drawInRect:drawRect];
    }];
}

- (UIButton *)bwrh_creditsButtonWithTitle:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    UIButtonConfiguration *configuration = [UIButtonConfiguration tintedButtonConfiguration];
    configuration.title = title;
    configuration.image = symbol.length ? [UIImage systemImageNamed:symbol] : nil;
    configuration.imagePadding = 8.0;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    button.configuration = configuration;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
    return button;
}

- (void)bwrh_openRepository {
    NSURL *url = [NSURL URLWithString:@"https://github.com/Gokuencinar/GokuEnREPO"];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)bwrh_buyCoffee {
    NSURL *url = [NSURL URLWithString:@"https://buymeacoffee.com/gokuen"];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)bwrh_installCreditsFooter {
    UITableView *table = [self table];
    if (!table) return;

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(table.bounds), 242.0)];
    footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIImageView *avatarView = [[UIImageView alloc] initWithImage:[self bwrh_creditsAvatarImage]];
    avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.accessibilityLabel = @"Gokuencinar · GokuEn";

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = @"Gokuencinar · GokuEn";
    nameLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.adjustsFontForContentSizeCategory = YES;

    UILabel *creditsLabel = [[UILabel alloc] init];
    creditsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    creditsLabel.text = [self bwrh_creditsTextSpanish:@"Créditos de BetterWiFi RH" english:@"BetterWiFi RH credits"];
    creditsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    creditsLabel.textColor = UIColor.secondaryLabelColor;
    creditsLabel.textAlignment = NSTextAlignmentCenter;
    creditsLabel.adjustsFontForContentSizeCategory = YES;

    UIButton *repoButton = [self bwrh_creditsButtonWithTitle:
        [self bwrh_creditsTextSpanish:@"Visitar GokuEnREPO" english:@"Visit GokuEnREPO"]
        symbol:@"link"
        action:@selector(bwrh_openRepository)];

    UIButton *coffeeButton = [self bwrh_creditsButtonWithTitle:@"Buy Me a Coffee"
        symbol:@"cup.and.saucer.fill"
        action:@selector(bwrh_buyCoffee)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[repoButton, coffeeButton]];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 8.0;
    buttons.alignment = UIStackViewAlignmentFill;
    buttons.distribution = UIStackViewDistributionFillEqually;

    [footer addSubview:avatarView];
    [footer addSubview:nameLabel];
    [footer addSubview:creditsLabel];
    [footer addSubview:buttons];

    [NSLayoutConstraint activateConstraints:@[
        [avatarView.topAnchor constraintEqualToAnchor:footer.topAnchor constant:18.0],
        [avatarView.centerXAnchor constraintEqualToAnchor:footer.centerXAnchor],
        [avatarView.widthAnchor constraintEqualToConstant:64.0],
        [avatarView.heightAnchor constraintEqualToConstant:64.0],

        [nameLabel.topAnchor constraintEqualToAnchor:avatarView.bottomAnchor constant:8.0],
        [nameLabel.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:20.0],
        [nameLabel.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-20.0],

        [creditsLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2.0],
        [creditsLabel.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:20.0],
        [creditsLabel.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-20.0],

        [buttons.topAnchor constraintEqualToAnchor:creditsLabel.bottomAnchor constant:12.0],
        [buttons.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:32.0],
        [buttons.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-32.0],
        [buttons.bottomAnchor constraintLessThanOrEqualToAnchor:footer.bottomAnchor constant:-14.0]
    ]];

    table.tableFooterView = footer;
}

'''
if '- (void)bwrh_installCreditsFooter' not in s:
    s=s.replace(impl,impl+methods,1)

old='''- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"BetterWiFi RH";
}
'''
new='''- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"BetterWiFi RH";
    [self bwrh_installCreditsFooter];
}
'''
if old not in s:
    raise SystemExit("viewDidLoad anchor not found")
s=s.replace(old,new,1)

old='''            [self reloadSpecifiers];
            self.title = @"BetterWiFi RH";
        });
'''
new='''            [self reloadSpecifiers];
            self.title = @"BetterWiFi RH";
            [self bwrh_installCreditsFooter];
        });
'''
if old not in s:
    raise SystemExit("language reload anchor not found")
s=s.replace(old,new,1)

controller.write_text(s)

# Version bump.
p=root/"control"
t=p.read_text().replace("Version: 0.3.10","Version: 0.3.11")
if "Version: 0.3.11" not in t:
    raise SystemExit("control version bump failed")
p.write_text(t)

p=root/"prefs/Resources/Info.plist"
info=plistlib.loads(p.read_bytes())
info["CFBundleShortVersionString"]="0.3.11"
info["CFBundleVersion"]="14"
p.write_bytes(plistlib.dumps(info,fmt=plistlib.FMT_XML,sort_keys=False))

print(f"BetterWiFi RH 0.3.11 credits patch applied; avatar bytes={len(avatar)}")
