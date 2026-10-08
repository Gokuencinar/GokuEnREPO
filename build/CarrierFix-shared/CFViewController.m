#import "CFViewController.h"
#import "CFCarrierManager.h"
#if CARRIERFIX_IOS17_UPDATE
#import "CFCarrierUpdateManager.h"
#endif

@interface CFViewController ()
@property(nonatomic,strong) CFCarrierManager *manager;
@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UIButton *applyButton;
@property(nonatomic,strong) UIButton *restoreButton;
@property(nonatomic,strong) UILabel *safetyLabel;
#if CARRIERFIX_IOS17_UPDATE
@property(nonatomic,strong) UIButton *exportCarrierUpdateButton;
#endif
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
    subtitle.text = @"Experimental Cricket SMS/IMS repair for jailbroken iOS 16/17. CarrierFix refuses unknown carrier schemas and verifies a restorable backup before enabling Apply.";
#if CARRIERFIX_IOS17_UPDATE
    subtitle.text = @"Cricket SMS diagnostic and carrier update preparation. The official Apple update can be exported, but cannot be installed by CarrierFix or forced onto unsupported iOS versions.";
#endif

    self.textView = [UITextView new];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.textView.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.75];
    self.textView.layer.cornerRadius = 12.0;
    self.textView.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);

    UIButton *diagnose = [self buttonWithTitle:@"Refresh + verify backup" action:@selector(refreshDiagnosticTapped)];
    self.applyButton = [self buttonWithTitle:@"Apply Cricket SMS Fix" action:@selector(applyFix)];
    self.restoreButton = [self buttonWithTitle:@"Restore Original" action:@selector(restoreOriginal)];
    UIButton *copy = [self buttonWithTitle:@"Copy diagnostic" action:@selector(copyDiagnostic)];

    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[diagnose, self.applyButton, self.restoreButton, copy]];
#if CARRIERFIX_IOS17_UPDATE
    self.exportCarrierUpdateButton = [self buttonWithTitle:@"Prepare official Cricket update" action:@selector(prepareOfficialCricketUpdate)];
    [buttons addArrangedSubview:self.exportCarrierUpdateButton];
#endif
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
#if CARRIERFIX_IOS17_UPDATE
    warning.text = @"Cricket 58.1 is listed by Apple for iOS 17.5+. This build only verifies and exports the IPCC; it does not install unsupported carrier bundles. Never delete the eSIM or change file permissions.";
#endif

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
    if ([initial[@"ok"] boolValue] && [initial[@"cricket"] boolValue] && [initial[@"schemaSafe"] boolValue] && [initial[@"writable"] boolValue] && ![initial[@"fixApplied"] boolValue]) {
        backupReady = [self.manager prepareForApply:&backupMessage];
    }
    NSDictionary *d = [self.manager diagnose];
    self.textView.text = [self.manager diagnosticText];

    BOOL canApply = [d[@"ok"] boolValue] && [d[@"cricket"] boolValue] && [d[@"schemaSafe"] boolValue] && [d[@"writable"] boolValue] && ![d[@"fixApplied"] boolValue] && backupReady;
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
        else if ([d[@"fixApplied"] boolValue]) reason = @"The IMS/SMS target flags are already present. No patch is needed.";
        else reason = backupMessage ?: @"Backup/restore preflight did not pass.";
        self.safetyLabel.text = [NSString stringWithFormat:@"Apply disabled: %@", reason ?: @"unknown reason"];
    }
}

- (void)refreshDiagnosticTapped {
    [self refreshDiagnostic];
    NSDictionary *diagnostic = [self.manager diagnose];
    NSString *title = @"Diagnostic refreshed";
    NSString *message = nil;

    if (![diagnostic[@"ok"] boolValue]) {
        title = @"Carrier not found";
        message = diagnostic[@"message"] ?: @"CarrierFix could not read the active carrier overlay. No changes were made.";
    } else if (![diagnostic[@"cricket"] boolValue]) {
        title = @"Cricket not detected";
        message = @"CarrierFix refreshed the diagnostic, but it did not detect an active Cricket / ATT_aio profile. Nothing was changed.";
    } else if (![diagnostic[@"schemaSafe"] boolValue]) {
        title = @"Unsupported carrier profile";
        message = diagnostic[@"schemaReason"] ?: @"CarrierFix cannot safely patch this carrier schema. Nothing was changed.";
    } else if (![diagnostic[@"writable"] boolValue]) {
        title = @"Carrier overlay is read-only";
        message = [NSString stringWithFormat:
                   @"Refresh worked and Cricket was detected, but CarrierFix cannot write the active overlay from this app.\n\nCarrier file writable: %@\nOverlay folder writable: %@\nApp UID: %@\nCarrier owner UID: %@ (mode %@)\n\nNo backup or changes were made. Tap Copy diagnostic and send the full report. Do not change file permissions manually.%@",
                   [diagnostic[@"fileWritable"] boolValue] ? @"YES" : @"NO",
                   [diagnostic[@"directoryWritable"] boolValue] ? @"YES" : @"NO",
                   diagnostic[@"effectiveUID"], diagnostic[@"fileOwner"], diagnostic[@"fileMode"],
                   [diagnostic[@"fixApplied"] boolValue] ? @"\n\nThe IMS/SMS target flags are already present in this profile; that does not mean SMS is working." : @""];
    } else if ([diagnostic[@"fixApplied"] boolValue]) {
        message = @"The IMS/SMS target flags are already present in this carrier profile. CarrierFix did not write anything because this patch has no new change to apply. Test SMS normally; these flags alone do not guarantee that SMS works.";
    } else if (![diagnostic[@"backupAvailable"] boolValue]) {
        title = @"Backup not ready";
        message = @"Cricket was detected and the carrier overlay is writable, but CarrierFix could not verify a restorable backup. Apply stays disabled. Tap Copy diagnostic and send the report.";
    } else {
        message = @"Cricket was detected and the original carrier configuration was backed up and verified. Apply is ready, but this build is still experimental.";
    }
    [self showMessage:message title:title];
}

- (void)applyFix {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Apply Cricket SMS Fix?" message:@"The verified original backup will be kept. CarrierFix patches only the validated IMS/SMS compatibility keys and requires an existing IMS APN. Failed verification triggers an automatic restore." preferredStyle:UIAlertControllerStyleAlert];
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

#if CARRIERFIX_IOS17_UPDATE
- (void)shareCarrierFile:(NSURL *)fileURL {
    if (!fileURL || ![[NSFileManager defaultManager] fileExistsAtPath:fileURL.path]) {
        [self showMessage:@"The selected file is no longer available in CarrierFix's private storage." title:@"File missing"];
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.exportCarrierUpdateButton;
    activity.popoverPresentationController.sourceRect = self.exportCarrierUpdateButton.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)showPreparedCarrierFiles:(NSURL *)ipcc original:(NSURL *)original {
    NSString *details = [NSString stringWithFormat:@"Cricket 58.1 was downloaded from Apple and its SHA-384 was verified. Apple lists this update for iOS 17.5 and newer; this phone runs iOS %@. CarrierFix has NOT installed it and cannot guarantee the system will accept it. The original overlay was copied for reference, but a working restore is NOT verified. Save that copy privately, not in a public chat. Jailbreak processes with the same mobile UID may access these files.", UIDevice.currentDevice.systemVersion ?: @"unknown"];
    UIAlertController *options = [UIAlertController alertControllerWithTitle:@"Carrier update prepared (NOT installed)"
          message:details
          preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [options addAction:[UIAlertAction actionWithTitle:@"Save original reference copy"
                                                  style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf shareCarrierFile:original];
    }]];
    [options addAction:[UIAlertAction actionWithTitle:@"Export Apple .ipcc"
                                                  style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf shareCarrierFile:ipcc];
    }]];
    [options addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:options animated:YES completion:nil];
}

- (void)prepareOfficialCricketUpdate {
    NSDictionary *d = [self.manager diagnose];
    if (![d[@"ok"] boolValue] || ![d[@"cricket"] boolValue] || ![d[@"model"] isEqualToString:@"iPhone16,2"] ||
        ![d[@"ios"] hasPrefix:@"17."]) {
        [self showMessage:@"This export is limited to the known Cricket profile on iPhone 15 Pro Max with iOS 17. No carrier settings were changed." title:@"Unsupported device"];
        return;
    }
    NSString *confirmMessage = [NSString stringWithFormat:@"This will save a local reference copy of the active Cricket overlay and download Apple's original 58.1 .ipcc after SHA-384 verification. It will NOT install or apply anything. Apple lists 58.1 for iOS 17.5+, so compatibility with iOS %@ is NOT established unless Apple offers it. Do not force an update or rely on the reference copy as a verified restore. Continue?", d[@"ios"] ?: @"unknown"];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Prepare Cricket 58.1?"
        message:confirmMessage
        preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Prepare only" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.exportCarrierUpdateButton.enabled) return;
        NSString *path = [d[@"path"] isKindOfClass:NSString.class] ? d[@"path"] : @"";
        NSDictionary *now = [strongSelf.manager diagnose];
        if (![now[@"path"] isEqualToString:path] || ![now[@"cricket"] boolValue]) {
            [strongSelf showMessage:@"The active carrier changed before the snapshot. No update was downloaded." title:@"Carrier changed"];
            return;
        }
        NSError *snapshotError = nil;
        NSURL *original = nil;
        if (![CFCarrierUpdateManager archiveCarrierAtPath:path model:d[@"model"] output:&original error:&snapshotError]) {
            [strongSelf showMessage:snapshotError.localizedDescription ?: @"Could not save a verified reference copy of the active carrier." title:@"Preparation stopped"];
            return;
        }
        strongSelf.exportCarrierUpdateButton.enabled = NO;
        [strongSelf.exportCarrierUpdateButton setTitle:@"Verifying Apple download..." forState:UIControlStateNormal];
        [CFCarrierUpdateManager downloadOfficialCricket58WithCompletion:^(NSURL *ipcc, NSError *downloadError) {
            typeof(self) owner = weakSelf;
            if (!owner) return;
            owner.exportCarrierUpdateButton.enabled = YES;
            [owner.exportCarrierUpdateButton setTitle:@"Prepare official Cricket update" forState:UIControlStateNormal];
            if (!ipcc) {
                [owner showMessage:[NSString stringWithFormat:@"%@\n\nThe original reference copy was saved privately; no carrier settings were changed.", downloadError.localizedDescription ?: @"The official Apple download could not be verified."] title:@"Preparation stopped"];
                return;
            }
            NSDictionary *latest = [owner.manager diagnose];
            if (![latest[@"path"] isEqualToString:path] || ![latest[@"cricket"] boolValue]) {
                [owner showMessage:@"The active carrier/SIM changed while the update was downloading. Files were only saved privately; no update was installed." title:@"Carrier changed"];
                return;
            }
            [owner showPreparedCarrierFiles:ipcc original:original];
        }];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}
#endif

- (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
