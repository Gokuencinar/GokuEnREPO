#import "BLControlViewController.h"
#import "BLTelephonyManager.h"
#import "BLBandPickerViewController.h"
#import "BLCommon.h"
#import "BLDiagnostics.h"

@interface BLControlViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UILabel *networkValue;
@property (nonatomic, strong) UILabel *servingValue;
@property (nonatomic, strong) UILabel *activeValue;
@property (nonatomic, strong) UILabel *pendingValue;
@property (nonatomic, strong) UILabel *resultValue;
@property (nonatomic, strong) UILabel *modeValue;
@property (nonatomic, strong) UIButton *refreshButton;
@end

@implementation BLControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    BLDiagLog(@"Control viewDidLoad");
    self.manager = BLTelephonyManager.sharedManager;
    self.title = @"BandLock";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    [self buildUI];
    [self refreshDisplay];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshDisplay];
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
    UILabel *result = nil;
    UIView *statusCard = [self cardWithTitle:BLT(@"ESTADO", @"STATUS") content:@[
        self.refreshButton,
        [self rowWithTitle:BLT(@"Red actual", @"Current network") valueLabel:&network],
        [self rowWithTitle:BLT(@"Banda conectada", @"Serving band") valueLabel:&serving],
        [self rowWithTitle:BLT(@"Bandas permitidas", @"Allowed bands") valueLabel:&active],
        [self rowWithTitle:BLT(@"Resultado", @"Result") valueLabel:&result]
    ]];
    self.networkValue = network;
    self.servingValue = serving;
    self.activeValue = active;
    self.resultValue = result;
    [self.stackView addArrangedSubview:statusCard];

    UIButton *automatic = [self buttonWithTitle:BLT(@"Modo automÃ¡tico", @"Automatic mode") symbol:@"antenna.radiowaves.left.and.right" selector:@selector(automaticTapped:) destructive:NO];
    UIButton *lteOnly = [self buttonWithTitle:BLT(@"Solo LTE / 4G", @"LTE / 4G only") symbol:@"4g.lte" selector:@selector(lteOnlyTapped:) destructive:NO];
    UILabel *mode = nil;
    UIView *modeCard = [self cardWithTitle:BLT(@"MODO DE RED", @"NETWORK MODE") content:@[
        [self rowWithTitle:BLT(@"ConfiguraciÃ³n", @"Configuration") valueLabel:&mode],
        automatic,
        lteOnly
    ]];
    self.modeValue = mode;
    [self.stackView addArrangedSubview:modeCard];

    UIButton *edit = [self buttonWithTitle:BLT(@"Editar bandas", @"Edit bands") symbol:@"slider.horizontal.3" selector:@selector(editBandsTapped:) destructive:NO];
    UIButton *apply = [self buttonWithTitle:BLT(@"Aplicar selecciÃ³n", @"Apply selection") symbol:@"checkmark.circle.fill" selector:@selector(applyTapped:) destructive:NO];
    UIButton *restorePrevious = [self buttonWithTitle:BLT(@"Restaurar selecciÃ³n anterior", @"Restore previous selection") symbol:@"arrow.uturn.backward" selector:@selector(restorePreviousTapped:) destructive:NO];
    UIButton *restoreAll = [self buttonWithTitle:BLT(@"Restaurar todas las soportadas", @"Restore all supported") symbol:@"arrow.counterclockwise.circle" selector:@selector(restoreAllTapped:) destructive:NO];
    UILabel *pending = nil;
    UIView *bandsCard = [self cardWithTitle:BLT(@"BANDAS LTE", @"LTE BANDS") content:@[
        [self rowWithTitle:BLT(@"SelecciÃ³n pendiente", @"Pending selection") valueLabel:&pending],
        edit, apply, restorePrevious, restoreAll
    ]];
    self.pendingValue = pending;
    [self.stackView addArrangedSubview:bandsCard];

    UIButton *field = [self buttonWithTitle:BLT(@"Abrir Field Test", @"Open Field Test") symbol:@"wave.3.right.circle" selector:@selector(fieldTestTapped:) destructive:NO];
    UIView *toolsCard = [self cardWithTitle:BLT(@"HERRAMIENTAS", @"TOOLS") content:@[field]];
    [self.stackView addArrangedSubview:toolsCard];

    UILabel *version = [[UILabel alloc] init];
    version.text = @"BandLock Global 0.6.4 Â· UIKit buttons + diagnostics";
    version.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    version.textColor = UIColor.tertiaryLabelColor;
    version.numberOfLines = 0;
    version.textAlignment = NSTextAlignmentCenter;
    [self.stackView addArrangedSubview:version];
}

- (void)refreshDisplay {
    self.networkValue.text = self.manager.radioAccessTechnology ?: @"â€”";
    self.servingValue.text = self.manager.servingBand ?: @"â€”";
    self.activeValue.text = BLBandList(self.manager.activeBands);
    self.pendingValue.text = BLBandList(self.manager.pendingBands);
    self.resultValue.text = self.manager.detailText ?: @"â€”";
    self.modeValue.text = self.manager.networkMode ?: @"â€”";
    self.refreshButton.enabled = !self.manager.busy;
    [self.refreshButton setTitle:(self.manager.busy ? BLT(@"Actualizandoâ€¦", @"Refreshingâ€¦") : BLT(@"Actualizar estado", @"Refresh status")) forState:UIControlStateNormal];
}

- (void)showAlert:(NSString *)message {
    BLDiagLog([NSString stringWithFormat:@"showAlert: %@", message ?: @"(nil)"]);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock" message:message ?: @"" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleCompletion:(NSString *)action success:(BOOL)success message:(NSString *)message {
    BLDiagLog([NSString stringWithFormat:@"completion %@ success=%d message=%@", action, success, message]);
    [self refreshDisplay];
    if (!success && message.length) [self showAlert:message];
}

- (void)refreshTapped:(UIButton *)sender {
    BLDiagLog(@"tap refresh");
    [self refreshDisplay];
    __weak typeof(self) weakSelf = self;
    [self.manager refreshWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"refresh" success:success message:message];
    }];
}

- (void)automaticTapped:(UIButton *)sender {
    BLDiagLog(@"tap automatic");
    __weak typeof(self) weakSelf = self;
    [self.manager setNetworkModeAutomatic:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"automatic" success:success message:message];
    }];
}

- (void)lteOnlyTapped:(UIButton *)sender {
    BLDiagLog(@"tap lte-only");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Solo LTE / 4G", @"LTE / 4G only")
                                                                    message:BLT(@"Puede perderse temporalmente el servicio si no hay LTE disponible.", @"Service may be temporarily lost if LTE is unavailable.")
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Activar", @"Enable") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        BLDiagLog(@"confirm lte-only");
        [weakSelf.manager setNetworkModeLTEOnly:^(BOOL success, NSString *message) {
            [weakSelf handleCompletion:@"lte-only" success:success message:message];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editBandsTapped:(UIButton *)sender {
    BLDiagLog(@"tap edit-bands");
    if (!self.manager.supportedBands.count) {
        [self showAlert:BLT(@"Pulsa Â«Actualizar estadoÂ» antes de editar bandas.", @"Tap â€œRefresh statusâ€ before editing bands.")];
        return;
    }
    BLBandPickerViewController *picker = [[BLBandPickerViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)applyTapped:(UIButton *)sender {
    BLDiagLog(@"tap apply");
    NSArray *bands = self.manager.pendingBands;
    if (!bands.count) {
        [self showAlert:BLT(@"No hay bandas pendientes para aplicar.", @"There are no pending bands to apply.")];
        return;
    }
    NSString *message = [NSString stringWithFormat:BLT(@"Se permitirÃ¡n Ãºnicamente estas bandas LTE:\n\n%@", @"Only these LTE bands will be allowed:\n\n%@"), BLBandList(bands)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Aplicar selecciÃ³n", @"Apply selection") message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aplicar", @"Apply") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        BLDiagLog(@"confirm apply");
        [weakSelf.manager applyPendingBandsWithCompletion:^(BOOL success, NSString *message) {
            [weakSelf handleCompletion:@"apply" success:success message:message];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)restorePreviousTapped:(UIButton *)sender {
    BLDiagLog(@"tap restore-previous");
    __weak typeof(self) weakSelf = self;
    [self.manager restorePreviousBandsWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"restore-previous" success:success message:message];
    }];
}

- (void)restoreAllTapped:(UIButton *)sender {
    BLDiagLog(@"tap restore-all");
    __weak typeof(self) weakSelf = self;
    [self.manager restoreAllSupportedBandsWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"restore-all" success:success message:message];
    }];
}

- (void)fieldTestTapped:(UIButton *)sender {
    BLDiagLog(@"tap field-test");
    __weak typeof(self) weakSelf = self;
    [self.manager openFieldTestWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf handleCompletion:@"field-test" success:success message:message];
    }];
}

@end
