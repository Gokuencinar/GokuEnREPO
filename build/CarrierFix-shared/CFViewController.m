#import "CFViewController.h"
#import "CFCarrierManager.h"

@interface CFViewController ()
@property(nonatomic,strong) CFCarrierManager *manager;
@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UIButton *applyButton;
@property(nonatomic,strong) UIButton *restoreButton;
@property(nonatomic,strong) UILabel *safetyLabel;
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
    subtitle.text = @"Experimental Cricket SMS/IMS repair for jailbroken iOS 16. CarrierFix refuses unknown iOS 16 carrier schemas and verifies a restorable backup before enabling Apply.";

    self.textView = [UITextView new];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.textView.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.75];
    self.textView.layer.cornerRadius = 12.0;
    self.textView.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);

    UIButton *diagnose = [self buttonWithTitle:@"Refresh + verify backup" action:@selector(refreshDiagnostic)];
    self.applyButton = [self buttonWithTitle:@"Apply Cricket SMS Fix" action:@selector(applyFix)];
    self.restoreButton = [self buttonWithTitle:@"Restore Original" action:@selector(restoreOriginal)];
    UIButton *copy = [self buttonWithTitle:@"Copy diagnostic" action:@selector(copyDiagnostic)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[diagnose, self.applyButton, self.restoreButton, copy]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 10;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    self.safetyLabel = [UILabel new];
    self.safetyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.safetyLabel.numberOfLines = 0;
    self.safetyLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];

    UILabel *warning = [UILabel new];
    warning.translatesAutoresizingMaskIntoConstraints = NO;
    warning.numberOfLines = 0;
    warning.font = [UIFont systemFontOfSize:12];
    warning.textColor = UIColor.secondaryLabelColor;
    warning.text = @"After Apply/Restore, toggle Airplane Mode for ~30 seconds or reboot. If calling/data/SMS gets worse, restore immediately. CarrierFix does not backport RCS.";

    [self.view addSubview:subtitle];
    [self.view addSubview:self.textView];
    [self.view addSubview:self.safetyLabel];
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
        [self.textView.heightAnchor constraintGreaterThanOrEqualToConstant:235],
        [self.safetyLabel.topAnchor constraintEqualToAnchor:self.textView.bottomAnchor constant:10],
        [self.safetyLabel.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [self.safetyLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [buttons.topAnchor constraintEqualToAnchor:self.safetyLabel.bottomAnchor constant:10],
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
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:46.0].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)refreshDiagnostic {
    NSDictionary *initial = [self.manager diagnose];
    NSString *backupMessage = nil;
    BOOL backupReady = NO;
    if ([initial[@"ok"] boolValue] && [initial[@"cricket"] boolValue] && [initial[@"schemaSafe"] boolValue] && [initial[@"writable"] boolValue]) {
        backupReady = [self.manager prepareForApply:&backupMessage];
    }
    NSDictionary *d = [self.manager diagnose];
    self.textView.text = [self.manager diagnosticText];

    BOOL canApply = [d[@"ok"] boolValue] && [d[@"cricket"] boolValue] && [d[@"schemaSafe"] boolValue] && [d[@"writable"] boolValue] && backupReady;
    self.applyButton.enabled = canApply;
    self.applyButton.alpha = canApply ? 1.0 : 0.45;
    BOOL canRestore = [self.manager hasVerifiedBackupForActiveCarrier];
    self.restoreButton.enabled = canRestore;
    self.restoreButton.alpha = canRestore ? 1.0 : 0.45;

    if (canApply) {
        self.safetyLabel.textColor = UIColor.systemGreenColor;
        self.safetyLabel.text = backupMessage.length ? backupMessage : @"Safety preflight passed. Apply is enabled.";
    } else {
        self.safetyLabel.textColor = UIColor.systemOrangeColor;
        NSString *reason = nil;
        if (![d[@"cricket"] boolValue]) reason = @"Cricket / ATT_aio not detected.";
        else if (![d[@"writable"] boolValue]) reason = @"Carrier overlay is not safely writable in this environment.";
        else if (![d[@"schemaSafe"] boolValue]) reason = d[@"schemaReason"];
        else reason = backupMessage ?: @"Backup/restore preflight did not pass.";
        self.safetyLabel.text = [NSString stringWithFormat:@"Apply disabled: %@", reason ?: @"unknown reason"];
    }
}

- (void)applyFix {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Apply Cricket SMS Fix?" message:@"The verified original backup will be kept. CarrierFix patches only the existing IMS/SMS schema and IMS APN. Failed verification triggers an automatic restore." preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *message = nil;
        BOOL ok = [weakSelf.manager applyCricketSMSFix:&message];
        [weakSelf refreshDiagnostic];
        [weakSelf showMessage:message ?: (ok ? @"Applied." : @"Failed.") title:ok ? @"Applied + verified" : @"Not applied"];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)restoreOriginal {
    NSString *message = nil;
    BOOL ok = [self.manager restoreOriginal:&message];
    [self refreshDiagnostic];
    [self showMessage:message ?: (ok ? @"Restored." : @"Restore failed.") title:ok ? @"Restored + verified" : @"Not restored"];
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