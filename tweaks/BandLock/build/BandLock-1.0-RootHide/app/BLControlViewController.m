#import "BLControlViewController.h"
#import "BLTelephonyManager.h"
#import "BLBandPickerViewController.h"
#import "BLNRBandPickerViewController.h"
#import "BLLanguageViewController.h"
#import "BLCountryBandsViewController.h"
#import "BLCountryProfile.h"
#import "BLCommon.h"
#import "BLBreadcrumb.h"

@interface BLControlViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UILabel *networkValue;
@property (nonatomic, strong) UILabel *servingValue;
@property (nonatomic, strong) UILabel *activeValue;
@property (nonatomic, strong) UILabel *activeNRValue;
@property (nonatomic, strong) UIView *activeNRRow;
@property (nonatomic, strong) UILabel *pendingValue;
@property (nonatomic, strong) UILabel *pendingNRValue;
@property (nonatomic, strong) UILabel *resultValue;
@property (nonatomic, strong) UILabel *modeValue;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIButton *countryManageButton;
@property (nonatomic, strong) UIButton *fiveGModeButton;
@property (nonatomic, strong) UIView *nrBandsCard;
@property (nonatomic, strong) UILabel *signalValue;
@property (nonatomic, strong) UIButton *signalStartButton;
@property (nonatomic, strong) UIButton *signalObserveButton;
@property (nonatomic, strong) UIButton *signalCancelButton;
@property (nonatomic, strong) NSTimer *signalTimer;
@property (nonatomic, assign) BOOL signalRunning;
@property (nonatomic, assign) BOOL signalRecoveryRequired;
@end

@implementation BLControlViewController

- (NSString *)currentLanguageName {
    NSString *code = BLCurrentLanguageCode();
    NSDictionary<NSString *, NSString *> *shortNames = @{
        @"es": @"Español",
        @"en": @"English",
        @"fr": @"Français",
        @"de": @"Deutsch",
        @"zh-Hant": @"繁體中文",
        @"zh-Hans": @"简体中文",
        @"ja": @"日本語"
    };
    return shortNames[code] ?: code ?: @"";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.manager = BLTelephonyManager.sharedManager;
    self.title = @"BandLock";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    UIButton *languageButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [languageButton setImage:[UIImage systemImageNamed:@"globe"] forState:UIControlStateNormal];
    [languageButton setTitle:[NSString stringWithFormat:@"  %@", [self currentLanguageName]] forState:UIControlStateNormal];
    languageButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    languageButton.accessibilityLabel = BLT(@"Cambiar idioma", @"Change language");
    [languageButton addTarget:self action:@selector(languageTapped:) forControlEvents:UIControlEventTouchUpInside];
    [languageButton sizeToFit];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:languageButton];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self buildUI];
    [self refreshDisplay];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshDisplay];
    [self startSignalPolling];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.signalTimer invalidate];
    self.signalTimer = nil;
}

- (UILabel *)valueLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    label.textColor = UIColor.secondaryLabelColor;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentRight;
    [label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    return label;
}

- (UIView *)rowWithTitle:(NSString *)title valueLabel:(UILabel **)outLabel {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = title;
    name.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    name.textColor = UIColor.labelColor;
    UILabel *value = [self valueLabel];
    value.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:name];
    [row addSubview:value];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:38],
        [name.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [name.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [value.leadingAnchor constraintGreaterThanOrEqualToAnchor:name.trailingAnchor constant:12],
        [value.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [value.topAnchor constraintEqualToAnchor:row.topAnchor constant:6],
        [value.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-6]
    ]];
    if (outLabel) *outLabel = value;
    return row;
}

- (UIView *)cardWithTitle:(NSString *)title content:(NSArray<UIView *> *)views {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 16.0;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    [card addSubview:stack];

    UILabel *heading = [[UILabel alloc] init];
    heading.text = title;
    heading.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    heading.textColor = UIColor.secondaryLabelColor;
    [stack addArrangedSubview:heading];
    for (UIView *view in views) [stack addArrangedSubview:view];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
    ]];
    return card;
}

- (UIButton *)buttonWithTitle:(NSString *)title symbol:(NSString *)symbol selector:(SEL)selector destructive:(BOOL)destructive {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:(destructive ? UIColor.systemRedColor : UIColor.systemBlueColor) forState:UIControlStateNormal];
    if (symbol.length) {
        [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
        button.tintColor = destructive ? UIColor.systemRedColor : UIColor.systemBlueColor;
    }
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 14;
    [self.scrollView addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:12],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    self.refreshButton = [self buttonWithTitle:BLT(@"Actualizar estado", @"Refresh status") symbol:@"arrow.clockwise" selector:@selector(refreshTapped:) destructive:NO];
    UILabel *network = nil;
    UILabel *serving = nil;
    UILabel *active = nil;
    UILabel *activeNR = nil;
    UIView *activeNRRow = [self rowWithTitle:BLT(@"Bandas 5G NR permitidas", @"Allowed 5G NR bands") valueLabel:&activeNR];
    UILabel *result = nil;
    UIView *statusCard = [self cardWithTitle:BLT(@"ESTADO", @"STATUS") content:@[
        self.refreshButton,
        [self rowWithTitle:BLT(@"Red actual", @"Current network") valueLabel:&network],
        [self rowWithTitle:BLT(@"Banda conectada", @"Serving band") valueLabel:&serving],
        [self rowWithTitle:BLT(@"Bandas LTE permitidas", @"Allowed LTE bands") valueLabel:&active],
        activeNRRow,
        [self rowWithTitle:BLT(@"Resultado", @"Result") valueLabel:&result]
    ]];
    self.networkValue = network;
    self.servingValue = serving;
    self.activeValue = active;
    self.activeNRValue = activeNR;
    self.activeNRRow = activeNRRow;
    self.resultValue = result;
    [self.stackView addArrangedSubview:statusCard];

    UIButton *automatic = [self buttonWithTitle:BLT(@"Modo automático", @"Automatic mode") symbol:@"antenna.radiowaves.left.and.right" selector:@selector(automaticTapped:) destructive:NO];
    UIButton *lteOnly = [self buttonWithTitle:BLT(@"Solo LTE / 4G", @"LTE / 4G only") symbol:@"4g.lte" selector:@selector(lteOnlyTapped:) destructive:NO];
    self.fiveGModeButton = [self buttonWithTitle:@"5G Auto / 5G On / 5G Only" symbol:@"5g" selector:@selector(fiveGModeTapped:) destructive:NO];
    UILabel *mode = nil;
    UIView *modeCard = [self cardWithTitle:BLT(@"MODO DE RED", @"NETWORK MODE") content:@[
        [self rowWithTitle:BLT(@"Configuración", @"Configuration") valueLabel:&mode],
        automatic,
        lteOnly,
        self.fiveGModeButton
    ]];
    self.modeValue = mode;
    [self.stackView addArrangedSubview:modeCard];

    self.countryManageButton = [self buttonWithTitle:@"" symbol:@"globe.europe.africa.fill" selector:@selector(manageCountryBandsTapped:) destructive:NO];
    self.countryManageButton.hidden = YES;
    UIButton *edit = [self buttonWithTitle:BLT(@"Editar bandas", @"Edit bands") symbol:@"slider.horizontal.3" selector:@selector(editBandsTapped:) destructive:NO];
    UIButton *apply = [self buttonWithTitle:BLT(@"Aplicar selección", @"Apply selection") symbol:@"checkmark.circle.fill" selector:@selector(applyTapped:) destructive:NO];
    UIButton *restorePrevious = [self buttonWithTitle:BLT(@"Restaurar selección anterior", @"Restore previous selection") symbol:@"arrow.uturn.backward" selector:@selector(restorePreviousTapped:) destructive:NO];
    UIButton *restoreAll = [self buttonWithTitle:BLT(@"Restaurar todas las soportadas", @"Restore all supported") symbol:@"arrow.counterclockwise.circle" selector:@selector(restoreAllTapped:) destructive:NO];
    UILabel *pending = nil;
    UIView *bandsCard = [self cardWithTitle:BLT(@"BANDAS LTE", @"LTE BANDS") content:@[
        [self rowWithTitle:BLT(@"Selección pendiente", @"Pending selection") valueLabel:&pending],
        self.countryManageButton, edit, apply, restorePrevious, restoreAll
    ]];
    self.pendingValue = pending;
    [self.stackView addArrangedSubview:bandsCard];

    UILabel *pendingNR = nil;
    UIButton *editNR = [self buttonWithTitle:BLT(@"Editar bandas 5G NR", @"Edit 5G NR bands") symbol:@"slider.horizontal.3" selector:@selector(editNRBandsTapped:) destructive:NO];
    UIButton *applyNR = [self buttonWithTitle:BLT(@"Aplicar selección 5G", @"Apply 5G selection") symbol:@"checkmark.circle.fill" selector:@selector(applyNRTapped:) destructive:NO];
    UIButton *restorePreviousNR = [self buttonWithTitle:BLT(@"Restaurar selección 5G anterior", @"Restore previous 5G selection") symbol:@"arrow.uturn.backward" selector:@selector(restorePreviousNRTapped:) destructive:NO];
    UIButton *restoreAllNR = [self buttonWithTitle:BLT(@"Restaurar todas las 5G soportadas", @"Restore all supported 5G bands") symbol:@"arrow.counterclockwise.circle" selector:@selector(restoreAllNRTapped:) destructive:NO];
    self.nrBandsCard = [self cardWithTitle:BLT(@"BANDAS 5G NR", @"5G NR BANDS") content:@[
        [self rowWithTitle:BLT(@"Selección pendiente", @"Pending selection") valueLabel:&pendingNR],
        editNR, applyNR, restorePreviousNR, restoreAllNR
    ]];
    self.pendingNRValue = pendingNR;
    self.nrBandsCard.hidden = YES;
    [self.stackView addArrangedSubview:self.nrBandsCard];

    UIButton *field = [self buttonWithTitle:BLT(@"Abrir Field Test", @"Open Field Test") symbol:@"wave.3.right.circle" selector:@selector(fieldTestTapped:) destructive:NO];
    UIView *toolsCard = [self cardWithTitle:BLT(@"HERRAMIENTAS", @"TOOLS") content:@[field]];
    [self.stackView addArrangedSubview:toolsCard];

    UIButton *probe = [self buttonWithTitle:BLT(@"Consultar intensidad (RootHide)", @"Read signal (RootHide)")
                                     symbol:@"waveform.path.ecg" selector:@selector(signalProbeTapped:) destructive:NO];
    self.signalStartButton = [self buttonWithTitle:BLT(@"Medir señal de bandas (2 LTE, PRUEBA)", @"Measure band signal (2 LTE, TEST)")
                                              symbol:@"antenna.radiowaves.left.and.right" selector:@selector(signalScanStartTapped:) destructive:NO];
    self.signalObserveButton = [self buttonWithTitle:BLT(@"Observar bandas LTE (sin desconectar)", @"Observe LTE bands (no disconnection)")
                                               symbol:@"waveform.path" selector:@selector(signalObserveTapped:) destructive:NO];
    self.signalCancelButton = [self buttonWithTitle:BLT(@"Cancelar barrido y restaurar", @"Cancel scan and restore")
                                               symbol:@"xmark.circle" selector:@selector(signalScanCancelTapped:) destructive:YES];
    UIButton *restore = [self buttonWithTitle:BLT(@"Recuperar bandas originales", @"Recover original bands")
                                       symbol:@"arrow.uturn.backward.circle" selector:@selector(signalScanRecoverTapped:) destructive:NO];
    self.signalValue = [self valueLabel];
    self.signalValue.textAlignment = NSTextAlignmentLeft;
    self.signalValue.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.signalValue.text = BLT(@"El barrido experimental exige Solo LTE/4G, una sola línea activa y RSRP mínimo de −115 dBm. Puede interrumpir todas las llamadas.",
                                @"Experimental scan requires LTE-only, a single active line and RSRP of at least −115 dBm. Calls may be interrupted.");
    [self.stackView addArrangedSubview:[self cardWithTitle:BLT(@"ANALIZADOR DE SEÑAL · ROOTHIDE (PRUEBA)",
                                                             @"SIGNAL ANALYZER · ROOTHIDE (TEST)")
                                                      content:@[probe, self.signalObserveButton, self.signalStartButton,
                                                                self.signalCancelButton, restore, self.signalValue]]];

    UILabel *version = [[UILabel alloc] init];
    NSString *bundleVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"—";
    version.text = [NSString stringWithFormat:@"BandLock Global %@", bundleVersion];
    version.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    version.textColor = UIColor.tertiaryLabelColor;
    version.numberOfLines = 0;
    version.textAlignment = NSTextAlignmentCenter;
    [self.stackView addArrangedSubview:version];
}

- (void)refreshDisplay {
    self.networkValue.text = self.manager.radioAccessTechnology ?: @"—";
    self.servingValue.text = self.manager.servingBand ?: @"—";
    self.activeValue.text = BLBandList(self.manager.activeBands);
    self.activeNRValue.text = BLNRBandList(self.manager.activeNRBands);
    self.pendingValue.text = BLBandList(self.manager.pendingBands);
    self.pendingNRValue.text = BLNRBandList(self.manager.pendingNRBands);
    self.resultValue.text = self.manager.hasRefreshedStatus ? (self.manager.detailText ?: @"") : @"";
    self.modeValue.text = self.manager.networkMode ?: @"—";
    self.activeNRRow.hidden = !self.manager.supports5G;
    self.nrBandsCard.hidden = !self.manager.supports5G || !self.manager.supportedNRBands.count;
    NSDictionary *selectedCountry = BLSelectedCountryRecord();
    self.countryManageButton.hidden = selectedCountry == nil;
    if (selectedCountry) {
        NSString *countryName = BLLocalizedCountryName(selectedCountry);
        [self.countryManageButton setTitle:[NSString stringWithFormat:BLT(@"Gestionar frecuencias de %@", @"Manage frequencies for %@"), countryName]
                                      forState:UIControlStateNormal];
    }
    self.refreshButton.enabled = !self.manager.busy;
    [self.refreshButton setTitle:(self.manager.busy ? BLT(@"Actualizando…", @"Refreshing…") : BLT(@"Actualizar estado", @"Refresh status")) forState:UIControlStateNormal];
    self.signalStartButton.enabled = !self.manager.busy && !self.signalRunning && !self.signalRecoveryRequired;
    self.signalObserveButton.enabled = !self.manager.busy && !self.signalRunning && !self.signalRecoveryRequired;
    self.signalCancelButton.enabled = self.signalRunning;
}

- (void)showAlert:(NSString *)message {
    BLBreadcrumb("UI showAlert begin");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock" message:message ?: @"" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    BLBreadcrumb("UI showAlert end");
}

- (void)manageCountryBandsTapped:(UIButton *)sender {
    NSDictionary *country = BLSelectedCountryRecord();
    if (!country) {
        [self showAlert:BLT(@"Selecciona primero un país desde la pestaña Países.", @"Select a country from the Countries tab first.")];
        return;
    }
    if (!self.manager.hasReadState) {
        [self showAlert:BLT(@"Pulsa «Actualizar estado» antes de gestionar las frecuencias del país.", @"Tap “Refresh status” before managing country frequencies.")];
        return;
    }
    NSArray *countryBands = BLSortedBands(country[@"bands"]);
    NSArray *countryNRBands = BLSortedBands(country[@"nr_bands"]);
    NSArray *compatibleLTE = BLIntersectBands(self.manager.supportedBands, countryBands);
    NSArray *compatibleNR = BLIntersectBands(self.manager.supportedNRBands, countryNRBands);
    if (!compatibleLTE.count && !compatibleNR.count) {
        [self showAlert:BLT(@"Este iPhone no reporta bandas LTE o 5G NR compatibles con el país seleccionado.", @"This iPhone does not report LTE or 5G NR bands compatible with the selected country.")];
        return;
    }
    BLCountryBandsViewController *controller = [[BLCountryBandsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)handleCompletion:(NSString *)action success:(BOOL)success message:(NSString *)message {
    BLBreadcrumbf("UI handleCompletion enter success=%d", success ? 1 : 0);
    [self refreshDisplay];
    BLBreadcrumb("UI refreshDisplay returned");
    if (!success && message.length) [self showAlert:message];
    BLBreadcrumb("UI handleCompletion end");
}

- (void)refreshTapped:(UIButton *)sender {
    BLBreadcrumbReset();
    BLBreadcrumb("UI refresh tap enter");
    __weak typeof(self) weakSelf = self;
    BLBreadcrumb("UI refresh tap calling manager");
    [self.manager refreshWithCompletion:^(BOOL success, NSString *message) {
        BLBreadcrumb("UI refresh completion block enter");
        [weakSelf handleCompletion:@"refresh" success:success message:message];
        BLBreadcrumb("UI refresh completion block end");
    }];
    BLBreadcrumb("UI refresh manager call returned");
    [self refreshDisplay];
    BLBreadcrumb("UI refresh tap display refreshed after busy");
    BLBreadcrumb("UI refresh tap return");
}

- (void)automaticTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self.manager setNetworkModeAutomatic:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"automatic" success:success message:message];
    }];
}

- (void)lteOnlyTapped:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Solo LTE / 4G", @"LTE / 4G only")
                                                                    message:BLT(@"Puede perderse temporalmente el servicio si no hay LTE disponible.", @"Service may be temporarily lost if LTE is unavailable.")
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Activar", @"Enable") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager setNetworkModeLTEOnly:^(BOOL success, NSString *message) {
            [weakSelf handleCompletion:@"lte-only" success:success message:message];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)languageTapped:(UIBarButtonItem *)sender {
    [self.navigationController pushViewController:[[BLLanguageViewController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
}

- (void)fiveGModeTapped:(UIButton *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"5G"
                                                                    message:BLT(@"Selecciona cómo debe priorizarse 5G. 5G Only solicita NR Standalone (SA).", @"Choose how 5G should be prioritized. 5G Only requests NR Standalone (SA).")
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"5G Auto" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager setNetworkMode5GAuto:^(BOOL success, NSString *message) { [weakSelf handleCompletion:@"5g-auto" success:success message:message]; }];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"5G On" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager setNetworkMode5GOn:^(BOOL success, NSString *message) { [weakSelf handleCompletion:@"5g-on" success:success message:message]; }];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"5G Only" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        UIAlertController *warning = [UIAlertController alertControllerWithTitle:@"5G Only (SA)"
                                                                          message:BLT(@"Este modo solicita únicamente 5G NR Standalone. Si tu operador, SIM o zona no admiten 5G SA, puedes perder temporalmente el servicio.", @"This mode requests 5G NR Standalone only. If your carrier, SIM or area does not support 5G SA, service may be temporarily lost.")
                                                                   preferredStyle:UIAlertControllerStyleAlert];
        [warning addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [warning addAction:[UIAlertAction actionWithTitle:BLT(@"Activar", @"Enable") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *confirm) {
            [weakSelf.manager setNetworkMode5GOnly:^(BOOL success, NSString *message) { [weakSelf handleCompletion:@"5g-only" success:success message:message]; }];
        }]];
        [weakSelf presentViewController:warning animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)editBandsTapped:(UIButton *)sender {
    if (!self.manager.supportedBands.count) {
        [self showAlert:BLT(@"Pulsa «Actualizar estado» antes de editar bandas.", @"Tap “Refresh status” before editing bands.")];
        return;
    }
    BLBandPickerViewController *picker = [[BLBandPickerViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)editNRBandsTapped:(UIButton *)sender {
    if (!self.manager.supportedNRBands.count) {
        [self showAlert:BLT(@"Este iPhone no reporta bandas 5G NR configurables. Actualiza el estado y comprueba que la línea tenga 5G.", @"This iPhone does not report configurable 5G NR bands. Refresh status and check that the line has 5G.")];
        return;
    }
    BLNRBandPickerViewController *picker = [[BLNRBandPickerViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)applyTapped:(UIButton *)sender {
    NSArray *bands = self.manager.pendingBands;
    if (!bands.count) {
        [self showAlert:BLT(@"No hay bandas pendientes para aplicar.", @"There are no pending bands to apply.")];
        return;
    }
    NSString *message = [NSString stringWithFormat:BLT(@"Se permitirán únicamente estas bandas LTE:\n\n%@", @"Only these LTE bands will be allowed:\n\n%@"), BLBandList(bands)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Aplicar selección", @"Apply selection") message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aplicar", @"Apply") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager applyPendingBandsWithCompletion:^(BOOL success, NSString *message) {
            [weakSelf handleCompletion:@"apply" success:success message:message];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyNRTapped:(UIButton *)sender {
    NSArray *bands = self.manager.pendingNRBands;
    if (!bands.count) {
        [self showAlert:BLT(@"No hay bandas 5G pendientes para aplicar.", @"There are no pending 5G bands to apply.")];
        return;
    }
    NSString *message = [NSString stringWithFormat:BLT(@"Se permitirán únicamente estas bandas 5G NR:\n\n%@", @"Only these 5G NR bands will be allowed:\n\n%@"), BLNRBandList(bands)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Aplicar selección 5G", @"Apply 5G selection") message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aplicar", @"Apply") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager applyPendingNRBandsWithCompletion:^(BOOL success, NSString *message) { [weakSelf handleCompletion:@"apply-nr" success:success message:message]; }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)restorePreviousTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self.manager restorePreviousBandsWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"restore-previous" success:success message:message];
    }];
}

- (void)restorePreviousNRTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self.manager restorePreviousNRBandsWithCompletion:^(BOOL success, NSString *message) { [weakSelf handleCompletion:@"restore-previous-nr" success:success message:message]; }];
}

- (void)restoreAllTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self.manager restoreAllSupportedBandsWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"restore-all" success:success message:message];
    }];
}

- (void)restoreAllNRTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self.manager restoreAllSupportedNRBandsWithCompletion:^(BOOL success, NSString *message) { [weakSelf handleCompletion:@"restore-all-nr" success:success message:message]; }];
}

- (void)fieldTestTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self.manager openFieldTestWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"field-test" success:success message:message];
    }];
}

- (void)signalProbeTapped:(UIButton *)sender {
    if (self.manager.busy) return;
    self.signalValue.text = BLT(@"Consultando CoreTelephony sin cambiar la conexión…",
                                @"Reading CoreTelephony without changing the network…");
    __weak typeof(self) weakSelf = self;
    [self.manager signalProbeWithCompletion:^(NSDictionary *result) {
        if (![result[@"success"] boolValue]) {
            [weakSelf showAlert:[result[@"message"] isKindOfClass:NSString.class] ? result[@"message"] : @"CoreTelephony error"];
            return;
        }
        NSMutableArray *lines = [NSMutableArray array];
        NSArray *measurements = [result[@"measurements"] isKindOfClass:NSArray.class] ? result[@"measurements"] : @[];
        for (NSDictionary *row in measurements) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSString *rat = [row[@"rat"] isKindOfClass:NSString.class] ? row[@"rat"] : @"—";
            NSNumber *band = [row[@"band"] isKindOfClass:NSNumber.class] ? row[@"band"] : nil;
            NSString *role = [row[@"role"] isKindOfClass:NSString.class] ? row[@"role"] : @"";
            NSString *label = band ? [NSString stringWithFormat:@"%@ %@%@", rat, [rat isEqual:@"NR"] ? @"n" : @"B", band] : rat;
            [lines addObject:[NSString stringWithFormat:@"%@ · %@ · %@", label, role, row[@"source"] ?: @"unknown"]];
            for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr"]) {
                id v = row[metric];
                if (![v isKindOfClass:NSNumber.class]) continue;
                NSString *unit = ([metric isEqual:@"rsrp"] || [metric isEqual:@"rssi"]) ? @"dBm" : @"dB";
                [lines addObject:[NSString stringWithFormat:@"  %@ %.1f %@", metric.uppercaseString, [v doubleValue], unit]];
            }
        }
        if (!measurements.count) {
            [lines addObject:BLT(@"Sin mediciones válidas. No se muestran ceros ficticios.",
                                  @"No validated metrics. Placeholder zeros are not displayed.")];
        }
        NSDictionary *diagnostics = [result[@"diagnostics"] isKindOfClass:NSDictionary.class] ? result[@"diagnostics"] : @{};
        [lines addObject:[NSString stringWithFormat:@"API: %@", diagnostics[@"typed_api"] ?: @"unknown"]];
        for (NSString *field in @[@"rsrp", @"rsrq", @"rssi", @"snr"]) {
            NSString *key = [@"legacy_serving_" stringByAppendingString:field];
            [lines addObject:[NSString stringWithFormat:@"legacy %@: %@", field.uppercaseString, diagnostics[key] ?: @"unknown"]];
        }
        NSString *power = [result[@"has_serving_power"] boolValue] ?
            BLT(@"Potencia LTE disponible. El barrido requiere cobertura suficiente y confirmación.",
                @"LTE power is available. Scanning requires sufficient coverage and explicit confirmation.") :
            BLT(@"RSRP/RSSI aún no disponibles: no se cortará la cobertura.",
                @"RSRP/RSSI still unavailable: cellular service will not be interrupted.");
        [lines addObject:power];
        weakSelf.signalValue.text = [lines componentsJoinedByString:@"\n"];
    }];
}

- (void)signalScanStartTapped:(UIButton *)sender {
    if (self.signalRunning || self.signalRecoveryRequired || self.manager.busy) return;
    NSString *warning = BLT(
        @"PRUEBA NO VALIDADA EN HARDWARE. Las dos bandas LTE se limitarán temporalmente una por una. Las llamadas, los datos y los servicios de emergencia pueden quedar sin cobertura. Debes tener otro teléfono disponible. No lo ejecutes durante llamadas o situaciones de emergencia. Selecciona «Solo LTE/4G» con una única SIM activa y buena cobertura (RSRP ≥ −115 dBm). La app intentará restaurar la configuración automáticamente, pero un fallo del módem puede impedirlo. ¿Iniciar?",
        @"HARDWARE-UNVALIDATED TEST. Two LTE bands will temporarily be permitted one at a time. Calls, mobile data and emergency services may lose coverage. Have a second phone available. Never test during calls or emergencies. Select LTE/4G only, one active SIM and strong signal (RSRP ≥ −115 dBm). Automatic restoration will be attempted but cannot be guaranteed. Start?");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Posible pérdida total de cobertura", @"Possible total loss of service")
        message:warning preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Iniciar prueba LTE", @"Start LTE test")
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager startSignalScanWithCompletion:^(NSDictionary *result) {
            if (![result[@"success"] boolValue]) {
                [weakSelf showAlert:[result[@"message"] isKindOfClass:NSString.class] ? result[@"message"] : @"Scan not started"];
                return;
            }
            weakSelf.signalRunning = YES;
            weakSelf.signalValue.text = result[@"message"] ?: @"Scan started";
            [weakSelf refreshDisplay];
            [weakSelf startSignalPolling];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)signalObserveTapped:(UIButton *)sender {
    if (self.signalRunning || self.signalRecoveryRequired || self.manager.busy) return;
    __weak typeof(self) weakSelf = self;
    [self.manager startPassiveSignalObservationWithCompletion:^(NSDictionary *result) {
        if (![result[@"success"] boolValue]) {
            [weakSelf showAlert:[result[@"message"] isKindOfClass:NSString.class]
                ? result[@"message"] : @"Observation did not start"];
            return;
        }
        weakSelf.signalRunning = YES;
        weakSelf.signalValue.text = BLT(
            @"Observando LTE sin cambiar bandas. Solo aparecerán las bandas usadas naturalmente por el iPhone.",
            @"Watching LTE without changing bands. Only naturally used bands will be measured.");
        [weakSelf refreshDisplay];
        [weakSelf startSignalPolling];
    }];
}

- (void)signalScanCancelTapped:(UIButton *)sender {
    if (!self.signalRunning) return;
    __weak typeof(self) weakSelf = self;
    [self.manager cancelSignalScanWithCompletion:^(NSDictionary *result) {
        weakSelf.signalValue.text = result[@"message"] ?: @"Cancellation requested";
        [weakSelf startSignalPolling];
    }];
}

- (void)signalScanRecoverTapped:(UIButton *)sender {
    if (self.signalRunning) return;
    __weak typeof(self) weakSelf = self;
    [self.manager recoverSignalScanWithCompletion:^(NSDictionary *result) {
        weakSelf.signalValue.text = result[@"message"] ?: @"Recovery requested";
        [weakSelf startSignalPolling];
    }];
}

- (void)startSignalPolling {
    if (!self.signalTimer) {
        self.signalTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self
            selector:@selector(signalPoll:) userInfo:nil repeats:YES];
    }
    [self signalPoll:nil];
}

- (void)signalPoll:(NSTimer *)timer {
    if (self.manager.busy) return;
    __weak typeof(self) weakSelf = self;
    [self.manager signalScanStatusWithCompletion:^(NSDictionary *status) {
        if (![status[@"phase"] isKindOfClass:NSString.class]) return;
        weakSelf.signalRunning = [status[@"running"] boolValue];
        weakSelf.signalRecoveryRequired = [status[@"recovery_required"] boolValue];
        [weakSelf refreshDisplay];
        BOOL passive = [status[@"read_only"] boolValue];
        [weakSelf.signalCancelButton setTitle:(passive
            ? BLT(@"Detener observación", @"Stop observation")
            : BLT(@"Cancelar barrido y restaurar", @"Cancel scan and restore"))
            forState:UIControlStateNormal];
        if ([status[@"phase"] isEqualToString:@"idle"]) return; // Keep read-only probe visible.
        NSMutableArray *lines = [NSMutableArray array];
        NSString *message = [status[@"message"] isKindOfClass:NSString.class] ? status[@"message"] : @"";
        [lines addObject:[NSString stringWithFormat:@"%@ · %@",
                            status[@"phase"], message]];
        NSArray *rows = [status[@"rows"] isKindOfClass:NSArray.class] ? status[@"rows"] : @[];
        for (NSDictionary *row in rows) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSMutableString *line = [NSMutableString stringWithFormat:@"LTE B%@: %@",
                row[@"band"] ?: @"—", row[@"status"] ?: @"no_measurement"];
            for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr"]) {
                NSNumber *value = row[metric];
                if ([value isKindOfClass:NSNumber.class]) [line appendFormat:@" · %@ %.1f", metric.uppercaseString, value.doubleValue];
            }
            [lines addObject:line];
        }
        weakSelf.signalValue.text = [lines componentsJoinedByString:@"\n"];
    }];
}

@end
