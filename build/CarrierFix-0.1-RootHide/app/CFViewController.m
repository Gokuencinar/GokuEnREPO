#import "CFViewController.h"
#import "CFCarrierManager.h"

@interface CFViewController ()
@property(nonatomic,strong) CFCarrierManager *manager;
@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UIButton *applyButton;
@property(nonatomic,strong) UIButton *restoreButton;
@end

@implementation CFViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"CarrierFix";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.manager = [CFCarrierManager new];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.numberOfLines = 0;
    subtitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    subtitle.text = @"Experimental Cricket SMS/IMS repair for older jailbroken iOS versions. CarrierFix backs up the active carrier configuration before making any change.";

    self.textView = [UITextView new];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.textView.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.75];
    self.textView.layer.cornerRadius = 12.0;
    self.textView.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);

    UIButton *diagnose = [self buttonWithTitle:@"Refresh diagnostic" action:@selector(refreshDiagnostic)];
    self.applyButton = [self buttonWithTitle:@"Apply Cricket SMS Fix" action:@selector(applyFix)];
    self.restoreButton = [self buttonWithTitle:@"Restore Original" action:@selector(restoreOriginal)];
    UIButton *copy = [self buttonWithTitle:@"Copy diagnostic" action:@selector(copyDiagnostic)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[diagnose, self.applyButton, self.restoreButton, copy]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 10;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *warning = [UILabel new];
    warning.translatesAutoresizingMaskIntoConstraints = NO;
    warning.numberOfLines = 0;
    warning.font = [UIFont systemFontOfSize:12];
    warning.textColor = UIColor.secondaryLabelColor;
    warning.text = @"After Apply/Restore, toggle Airplane Mode for ~30 seconds or reboot. If calling/data/SMS gets worse, restore immediately. CarrierFix does not enable RCS on iOS versions that do not contain Apple's RCS stack.";

    [self.view addSubview:subtitle];
    [self.view addSubview:self.textView];
    [self.view addSubview:buttons];
    [self.view addSubview:warning];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [subtitle.topAnchor constraintEqualToAnchor:g.topAnchor constant:16],
        [subtitle.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [subtitle.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [self.textView.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:14],
        [self.textView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [self.textView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [self.textView.heightAnchor constraintGreaterThanOrEqualToConstant:245],
        [buttons.topAnchor constraintEqualToAnchor:self.textView.bottomAnchor constant:14],
        [buttons.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [buttons.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [warning.topAnchor constraintEqualToAnchor:buttons.bottomAnchor constant:14],
        [warning.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [warning.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [warning.bottomAnchor constraintLessThanOrEqualToAnchor:g.bottomAnchor constant:-12]
    ]];

    [self refreshDiagnostic];
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = UIColor.tertiarySystemBackgroundColor;
    button.layer.cornerRadius = 10;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)refreshDiagnostic {
    NSDictionary *d = [self.manager diagnose];
    self.textView.text = [self.manager diagnosticText];
    BOOL readable = [d[@"ok"] boolValue];
    BOOL cricket = [d[@"cricket"] boolValue];
    self.applyButton.enabled = readable && cricket;
    self.applyButton.alpha = self.applyButton.enabled ? 1.0 : 0.45;
}

- (void)applyFix {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Apply Cricket SMS Fix?" message:@"CarrierFix will back up the active carrier plist, then patch only IMS/SMS-related keys and the IMS APN. This is experimental." preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *message = nil;
        BOOL ok = [weakSelf.manager applyCricketSMSFix:&message];
        [weakSelf refreshDiagnostic];
        [weakSelf showMessage:message ?: (ok ? @"Applied." : @"Failed.") title:ok ? @"Applied" : @"Not applied"];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)restoreOriginal {
    NSString *message = nil;
    BOOL ok = [self.manager restoreOriginal:&message];
    [self refreshDiagnostic];
    [self showMessage:message ?: (ok ? @"Restored." : @"Restore failed.") title:ok ? @"Restored" : @"Not restored"];
}

- (void)copyDiagnostic {
    UIPasteboard.generalPasteboard.string = [self.manager diagnosticText];
    [self showMessage:@"Diagnostic copied. It intentionally excludes phone number, IMSI and ICCID." title:@"Copied"];
}

- (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
