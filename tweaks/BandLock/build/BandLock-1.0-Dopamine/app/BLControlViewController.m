#import "BLControlViewController.h"
#import "BLTelephonyManager.h"
#import "BLBandPickerViewController.h"
#import "BLNRBandPickerViewController.h"
#import "BLLanguageViewController.h"
#import "BLCountriesViewController.h"
#import "BLCountryBandsViewController.h"
#import "BLCountryProfile.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import "BLBreadcrumb.h"
#import "../../BLHardwareCapabilities.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface BLControlHero : UIView
@property (nonatomic, strong) CAGradientLayer *backgroundGradient;
@end
@implementation BLControlHero
- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundGradient = [CAGradientLayer layer];
        self.backgroundGradient.colors = @[
            (__bridge id)[UIColor colorWithRed:0.08 green:0.20 blue:0.34 alpha:1].CGColor,
            (__bridge id)[UIColor colorWithRed:0.04 green:0.47 blue:0.49 alpha:1].CGColor];
        self.backgroundGradient.startPoint = CGPointMake(0, 0);
        self.backgroundGradient.endPoint = CGPointMake(1, 1);
        [self.layer insertSublayer:self.backgroundGradient atIndex:0];
        self.layer.cornerRadius = 22;
        self.layer.masksToBounds = YES;
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.backgroundGradient.frame = self.bounds;
}
@end

// Compact, accessible disclosure panel. No UISwitch or hidden radio side effects.
@interface BLControlDisclosure : UIView
@property (nonatomic, strong) UIStackView *body;
@property (nonatomic, strong) UIImageView *chevron;
@property (nonatomic, strong) UIButton *trigger;
@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, assign) BOOL expanded;
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle
                       symbol:(NSString *)symbol content:(NSArray<UIView *> *)views
                     expanded:(BOOL)expanded;
- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated;
@end

@implementation BLControlDisclosure
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle
                       symbol:(NSString *)symbol content:(NSArray<UIView *> *)views
                     expanded:(BOOL)expanded {
    self = [super init];
    if (!self) return nil;
    self.sectionTitle = title;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.layer.cornerRadius = 20;
    self.layer.borderWidth = 0.5;
    self.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.20].CGColor;

    UIStackView *column = [UIStackView new];
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 0;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:column];
    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:15],
        [column.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-15],
        [column.topAnchor constraintEqualToAnchor:self.topAnchor constant:10],
        [column.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10]
    ]];

    UIView *header = [UIView new];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [header.heightAnchor constraintGreaterThanOrEqualToConstant:59].active = YES;
    UIImageView *symbolView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    symbolView.translatesAutoresizingMaskIntoConstraints = NO;
    symbolView.tintColor = [UIColor colorWithRed:0.07 green:0.66 blue:0.59 alpha:1];
    symbolView.contentMode = UIViewContentModeScaleAspectFit;
    symbolView.backgroundColor = [[UIColor colorWithRed:0.07 green:0.66 blue:0.59 alpha:1] colorWithAlphaComponent:0.12];
    symbolView.layer.cornerRadius = 13;
    symbolView.clipsToBounds = YES;
    symbolView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
    [header addSubview:symbolView];
    UILabel *name = [UILabel new];
    name.text = title;
    name.textColor = UIColor.labelColor;
    name.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    UILabel *detail = [UILabel new];
    detail.text = subtitle;
    detail.textColor = UIColor.secondaryLabelColor;
    detail.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    detail.numberOfLines = 2;
    detail.hidden = subtitle.length == 0;
    UIStackView *copy = [UIStackView new];
    copy.axis = UILayoutConstraintAxisVertical;
    copy.spacing = 3;
    copy.translatesAutoresizingMaskIntoConstraints = NO;
    [copy addArrangedSubview:name];
    [copy addArrangedSubview:detail];
    [header addSubview:copy];
    self.chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    self.chevron.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevron.tintColor = UIColor.tertiaryLabelColor;
    [header addSubview:self.chevron];
    [NSLayoutConstraint activateConstraints:@[
        [symbolView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [symbolView.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [symbolView.widthAnchor constraintEqualToConstant:43],
        [symbolView.heightAnchor constraintEqualToConstant:43],
        [copy.leadingAnchor constraintEqualToAnchor:symbolView.trailingAnchor constant:12],
        [copy.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [copy.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevron.leadingAnchor constant:-10],
        [self.chevron.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-4],
        [self.chevron.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [self.chevron.widthAnchor constraintEqualToConstant:13],
        [self.chevron.heightAnchor constraintEqualToConstant:16]
    ]];
    self.trigger = [UIButton buttonWithType:UIButtonTypeCustom];
    self.trigger.translatesAutoresizingMaskIntoConstraints = NO;
    self.trigger.accessibilityTraits = UIAccessibilityTraitButton;
    [self.trigger addTarget:self action:@selector(toggleTapped:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:self.trigger];
    [NSLayoutConstraint activateConstraints:@[
        [self.trigger.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [self.trigger.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [self.trigger.topAnchor constraintEqualToAnchor:header.topAnchor],
        [self.trigger.bottomAnchor constraintEqualToAnchor:header.bottomAnchor]
    ]];
    [column addArrangedSubview:header];
    self.body = [UIStackView new];
    self.body.axis = UILayoutConstraintAxisVertical;
    self.body.spacing = 11;
    self.body.layoutMarginsRelativeArrangement = YES;
    self.body.layoutMargins = UIEdgeInsetsMake(10, 2, 12, 2);
    for (UIView *item in views) [self.body addArrangedSubview:item];
    [column addArrangedSubview:self.body];
    [self setExpanded:expanded animated:NO];
    return self;
}

- (void)toggleTapped:(UIButton *)sender { [self setExpanded:!self.expanded animated:YES]; }
- (void)setExpanded:(BOOL)expanded { [self setExpanded:expanded animated:NO]; }
- (void)setExpanded:(BOOL)expanded animated:(BOOL)animated {
    _expanded = expanded;
    self.body.hidden = !expanded;
    self.chevron.transform = expanded ? CGAffineTransformMakeRotation((CGFloat)M_PI) : CGAffineTransformIdentity;
    self.trigger.accessibilityLabel = [NSString stringWithFormat:@"%@ · %@",
        self.sectionTitle, expanded ? BLT(@"Contraer", @"Collapse") : BLT(@"Expandir", @"Expand")];
    self.trigger.accessibilityValue = expanded ? BLT(@"Abierto", @"Expanded") : BLT(@"Cerrado", @"Collapsed");
    if (animated) [UIView animateWithDuration:0.2 animations:^{ [self.superview layoutIfNeeded]; }];
}
@end

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
@property (nonatomic, strong) UILabel *heroNetworkValue;
@property (nonatomic, strong) UILabel *heroBandValue;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UILabel *countryValue;
@property (nonatomic, strong) UIButton *countrySelectButton;
@property (nonatomic, strong) UIButton *countryManageButton;
@property (nonatomic, strong) UIButton *fiveGModeButton;
@property (nonatomic, strong) UIView *nrBandsCard;
@property (nonatomic, strong) BLControlDisclosure *signalSection;
@property (nonatomic, strong) BLControlDisclosure *safetySection;
@property (nonatomic, strong) UIButton *radioAutomaticButton;
@property (nonatomic, strong) UIButton *radioLTEButton;
@property (nonatomic, strong) UIButton *applyLTEButton;
@property (nonatomic, strong) UIButton *restoreLTEPreviousButton;
@property (nonatomic, strong) UIButton *restoreLTEAllButton;
@property (nonatomic, strong) UILabel *signalValue;
@property (nonatomic, strong) UIButton *signalStartButton;
@property (nonatomic, copy) NSArray<UIButton *> *signalObserveButtons;
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
    card.layer.cornerRadius = 20.0;
    card.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    card.layer.borderWidth = 0.5;

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

- (BLControlDisclosure *)disclosure:(NSString *)title subtitle:(NSString *)subtitle
                             symbol:(NSString *)symbol views:(NSArray<UIView *> *)views {
    return [[BLControlDisclosure alloc] initWithTitle:title subtitle:subtitle
                                               symbol:symbol content:views expanded:NO];
}

- (void)openAnalyzerTapped:(UIButton *)sender {
    UITabBarController *tabs = self.tabBarController;
    if (tabs.viewControllers.count > 1) tabs.selectedIndex = 1;
}

- (UIView *)overviewHero {
    BLControlHero *hero = [[BLControlHero alloc] init];
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *body = [[UIStackView alloc] init];
    body.axis = UILayoutConstraintAxisVertical;
    body.spacing = 12;
    body.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *eyebrow = [UILabel new];
    eyebrow.text = BLT(@"CONEXIÓN", @"CONNECTION");
    eyebrow.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    eyebrow.textColor = [UIColor colorWithWhite:1 alpha:0.73];
    [body addArrangedSubview:eyebrow];
    UIStackView *status = [UIStackView new];
    status.axis = UILayoutConstraintAxisHorizontal;
    status.distribution = UIStackViewDistributionFillEqually;
    status.spacing = 16;
    self.heroNetworkValue = [UILabel new];
    self.heroBandValue = [UILabel new];
    NSArray<NSString *> *titles = @[BLT(@"RED", @"NETWORK"), BLT(@"BANDA", @"BAND")];
    NSArray<UILabel *> *values = @[self.heroNetworkValue, self.heroBandValue];
    for (NSUInteger i = 0; i < values.count; i++) {
        UIStackView *column = [UIStackView new];
        column.axis = UILayoutConstraintAxisVertical;
        column.spacing = 5;
        UILabel *caption = [UILabel new];
        caption.text = titles[i];
        caption.textColor = [UIColor colorWithWhite:1 alpha:0.70];
        caption.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        [column addArrangedSubview:caption];
        UILabel *item = values[i];
        item.numberOfLines = 2;
        item.lineBreakMode = NSLineBreakByWordWrapping;
        item.adjustsFontSizeToFitWidth = YES;
        item.minimumScaleFactor = 0.72;
        item.textColor = UIColor.whiteColor;
        item.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
        [column addArrangedSubview:item];
        [status addArrangedSubview:column];
    }
    [body addArrangedSubview:status];
    if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18) {
        UILabel *readOnly = [UILabel new];
        readOnly.text = BLT(@"Cambio de modo sujeto a verificación", @"Mode change requires verification");
        readOnly.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        readOnly.textColor = [UIColor colorWithWhite:1 alpha:0.77];
        [body addArrangedSubview:readOnly];
    }
    [hero addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [body.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:19],
        [body.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor constant:-19],
        [body.topAnchor constraintEqualToAnchor:hero.topAnchor constant:18],
        [body.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-20]
    ]];
    return hero;
}

- (UIButton *)buttonWithTitle:(NSString *)title symbol:(NSString *)symbol selector:(SEL)selector destructive:(BOOL)destructive {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.textAlignment = NSTextAlignmentLeft;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.84;
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

    [self.stackView addArrangedSubview:[self overviewHero]];

    self.refreshButton = [self buttonWithTitle:BLT(@"Actualizar", @"Refresh") symbol:@"arrow.clockwise" selector:@selector(refreshTapped:) destructive:NO];
    UIButton *analyzerShortcut = [self buttonWithTitle:BLT(@"Analizador", @"Analyzer")
                                                symbol:@"waveform.path.ecg" selector:@selector(openAnalyzerTapped:) destructive:NO];
    analyzerShortcut.backgroundColor = [UIColor colorWithRed:0.07 green:0.64 blue:0.56 alpha:1];
    analyzerShortcut.tintColor = UIColor.whiteColor;
    [analyzerShortcut setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    analyzerShortcut.layer.cornerRadius = 15;
    analyzerShortcut.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    analyzerShortcut.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.refreshButton.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.refreshButton.layer.cornerRadius = 15;
    self.refreshButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.refreshButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    UIStackView *quickActions = [UIStackView new];
    quickActions.axis = UILayoutConstraintAxisHorizontal;
    quickActions.spacing = 10;
    quickActions.distribution = UIStackViewDistributionFillEqually;
    [quickActions addArrangedSubview:analyzerShortcut];
    [quickActions addArrangedSubview:self.refreshButton];
    [analyzerShortcut.heightAnchor constraintGreaterThanOrEqualToConstant:54].active = YES;
    [self.stackView addArrangedSubview:quickActions];

    UILabel *network = nil;
    UILabel *serving = nil;
    UILabel *active = nil;
    UILabel *activeNR = nil;
    UIView *activeNRRow = [self rowWithTitle:BLT(@"Bandas 5G NR permitidas", @"Allowed 5G NR bands") valueLabel:&activeNR];
    UILabel *result = nil;
    BLControlDisclosure *statusCard = [self disclosure:BLT(@"Detalles de red", @"Network details")
        subtitle:nil
        symbol:@"chart.bar.xaxis" views:@[
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

    UIButton *automatic = [self buttonWithTitle:BLT(@"Modo automático", @"Automatic mode") symbol:@"antenna.radiowaves.left.and.right" selector:@selector(automaticTapped:) destructive:NO];
    UIButton *lteOnly = [self buttonWithTitle:BLT(@"Solo LTE / 4G", @"LTE / 4G only") symbol:@"4g.lte" selector:@selector(lteOnlyTapped:) destructive:NO];
    self.radioAutomaticButton = automatic;
    self.radioLTEButton = lteOnly;
    self.fiveGModeButton = [self buttonWithTitle:@"5G Auto / 5G On / 5G Only" symbol:@"5g" selector:@selector(fiveGModeTapped:) destructive:NO];
    UILabel *mode = nil;
    BLControlDisclosure *modeCard = [self disclosure:BLT(@"Modo de red", @"Network mode")
        subtitle:nil
        symbol:@"antenna.radiowaves.left.and.right" views:@[
        [self rowWithTitle:BLT(@"Configuración", @"Configuration") valueLabel:&mode],
        automatic,
        lteOnly,
        self.fiveGModeButton
    ]];
    self.modeValue = mode;

    UILabel *countryValue = nil;
    UIView *countryRow = [self rowWithTitle:BLT(@"País", @"Country") valueLabel:&countryValue];
    self.countryValue = countryValue;
    self.countrySelectButton = [self buttonWithTitle:BLT(@"Cambiar país", @"Change country")
                                                 symbol:@"globe.europe.africa.fill"
                                               selector:@selector(selectCountryTapped:) destructive:NO];
    self.countryManageButton = [self buttonWithTitle:BLT(@"Frecuencias del país", @"Country frequencies")
                                                 symbol:@"dot.radiowaves.left.and.right"
                                               selector:@selector(manageCountryBandsTapped:) destructive:NO];
    UIButton *edit = [self buttonWithTitle:BLT(@"Editar bandas", @"Edit bands") symbol:@"slider.horizontal.3" selector:@selector(editBandsTapped:) destructive:NO];
    UIButton *apply = [self buttonWithTitle:BLT(@"Aplicar selección", @"Apply selection") symbol:@"checkmark.circle.fill" selector:@selector(applyTapped:) destructive:NO];
    UIButton *restorePrevious = [self buttonWithTitle:BLT(@"Restaurar selección anterior", @"Restore previous selection") symbol:@"arrow.uturn.backward" selector:@selector(restorePreviousTapped:) destructive:NO];
    UIButton *restoreAll = [self buttonWithTitle:BLT(@"Restaurar todas las soportadas", @"Restore all supported") symbol:@"arrow.counterclockwise.circle" selector:@selector(restoreAllTapped:) destructive:NO];
    self.applyLTEButton = apply;
    self.restoreLTEPreviousButton = restorePrevious;
    self.restoreLTEAllButton = restoreAll;
    UILabel *pending = nil;
    UIView *bandsCard = [self cardWithTitle:BLT(@"BANDAS LTE", @"LTE BANDS") content:@[
        countryRow,
        self.countrySelectButton,
        self.countryManageButton,
        [self rowWithTitle:BLT(@"Seleccionadas", @"Selected") valueLabel:&pending],
        edit, apply
    ]];
    self.pendingValue = pending;
    [self.stackView addArrangedSubview:bandsCard];
    // The normal dashboard exposes just a signal shortcut and band selection.
    // Destructive/recovery and radio mode operations remain in separate panels.
    [self.stackView addArrangedSubview:statusCard];
    [self.stackView addArrangedSubview:modeCard];

    UILabel *pendingNR = nil;
    UIButton *editNR = [self buttonWithTitle:BLT(@"Editar bandas 5G NR", @"Edit 5G NR bands") symbol:@"slider.horizontal.3" selector:@selector(editNRBandsTapped:) destructive:NO];
    UIButton *applyNR = [self buttonWithTitle:BLT(@"Aplicar selección 5G", @"Apply 5G selection") symbol:@"checkmark.circle.fill" selector:@selector(applyNRTapped:) destructive:NO];
    UIButton *restorePreviousNR = [self buttonWithTitle:BLT(@"Restaurar selección 5G anterior", @"Restore previous 5G selection") symbol:@"arrow.uturn.backward" selector:@selector(restorePreviousNRTapped:) destructive:NO];
    UIButton *restoreAllNR = [self buttonWithTitle:BLT(@"Restaurar todas las 5G soportadas", @"Restore all supported 5G bands") symbol:@"arrow.counterclockwise.circle" selector:@selector(restoreAllNRTapped:) destructive:NO];
    self.nrBandsCard = [self disclosure:BLT(@"Bandas 5G NR", @"5G NR bands")
        subtitle:nil
        symbol:@"antenna.radiowaves.left.and.right" views:@[
        [self rowWithTitle:BLT(@"Selección pendiente", @"Pending selection") valueLabel:&pendingNR],
        editNR, applyNR, restorePreviousNR, restoreAllNR
    ]];
    self.pendingNRValue = pendingNR;
    self.nrBandsCard.hidden = YES;
    [self.stackView addArrangedSubview:self.nrBandsCard];

    UIButton *field = [self buttonWithTitle:BLT(@"Abrir Field Test", @"Open Field Test") symbol:@"wave.3.right.circle" selector:@selector(fieldTestTapped:) destructive:NO];
    BLControlDisclosure *toolsCard = [self disclosure:BLT(@"Herramientas", @"Tools")
        subtitle:nil symbol:@"wrench.and.screwdriver" views:@[field]];
    [self.stackView addArrangedSubview:toolsCard];

    // Coverage measurements, live cells and technology scans now live in the
    // Analyzer tab. Control keeps only the emergency recovery action so a
    // pending journal can always be resolved even if Analyzer is unavailable.
    UIButton *restore = [self buttonWithTitle:BLT(@"Recuperar bandas originales", @"Recover original bands")
                                       symbol:@"arrow.uturn.backward.circle" selector:@selector(signalScanRecoverTapped:) destructive:NO];
    self.safetySection = [self disclosure:BLT(@"Restauración y seguridad", @"Recovery and safety")
        subtitle:nil
        symbol:@"cross.case" views:@[restorePrevious, restoreAll, restore]];
    [self.stackView addArrangedSubview:self.safetySection];

}

- (void)refreshDisplay {
    BOOL readOnly18 = [NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 18;
    self.heroNetworkValue.text = self.manager.radioAccessTechnology ?: @"—";
    self.heroBandValue.text = self.manager.servingBand ?: @"—";
    self.networkValue.text = self.manager.radioAccessTechnology ?: @"—";
    self.servingValue.text = self.manager.servingBand ?: @"—";
    self.activeValue.text = BLBandList(self.manager.activeBands);
    self.activeNRValue.text = BLNRBandList(self.manager.activeNRBands);
    NSUInteger pendingCount = self.manager.pendingBands.count;
    self.pendingValue.text = pendingCount
        ? [NSString stringWithFormat:BLT(@"%lu bandas", @"%lu bands"), (unsigned long)pendingCount]
        : BLT(@"Sin selección", @"None selected");
    NSUInteger pendingNRCount = self.manager.pendingNRBands.count;
    self.pendingNRValue.text = pendingNRCount
        ? [NSString stringWithFormat:BLT(@"%lu bandas", @"%lu bands"), (unsigned long)pendingNRCount]
        : BLT(@"Sin selección", @"None selected");
    self.resultValue.text = self.manager.hasRefreshedStatus ? (self.manager.detailText ?: @"") : @"";
    self.modeValue.text = self.manager.networkMode ?: @"—";
    self.activeNRRow.hidden = readOnly18 || !self.manager.supports5G;
    self.nrBandsCard.hidden = readOnly18 || !self.manager.supports5G || !self.manager.supportedNRBands.count;
    self.fiveGModeButton.hidden = readOnly18 || !self.manager.supports5G;
    self.radioAutomaticButton.enabled = !self.manager.busy;
    self.radioLTEButton.enabled = !self.manager.busy;
    self.fiveGModeButton.enabled = !self.manager.busy;
    // LTE selection worked in 1.5 and is again supported on iOS 18. Keep NR
    // writes gated separately; LTE apply/restore use the verified LTE writer.
    self.applyLTEButton.hidden = NO;
    self.applyLTEButton.enabled = !self.manager.busy && !self.signalRunning && !self.signalRecoveryRequired;
    self.restoreLTEPreviousButton.hidden = NO;
    self.restoreLTEPreviousButton.enabled = !self.manager.busy && !self.signalRunning && !self.signalRecoveryRequired;
    self.restoreLTEAllButton.hidden = NO;
    self.restoreLTEAllButton.enabled = !self.manager.busy && !self.signalRunning && !self.signalRecoveryRequired;
    NSDictionary *selectedCountry = BLSelectedCountryRecord();
    BOOL countryActionsEnabled = !self.manager.busy && !self.signalRunning && !self.signalRecoveryRequired;
    self.countrySelectButton.enabled = countryActionsEnabled;
    self.countryManageButton.hidden = NO;
    self.countryManageButton.enabled = selectedCountry != nil && countryActionsEnabled;
    if (selectedCountry) {
        NSString *countryName = BLLocalizedCountryName(selectedCountry);
        self.countryValue.text = countryName;
    } else {
        self.countryValue.text = BLT(@"Sin seleccionar", @"Not selected");
    }
    self.refreshButton.enabled = !self.manager.busy;
    [self.refreshButton setTitle:(self.manager.busy ? BLT(@"Actualizando…", @"Refreshing…") : BLT(@"Actualizar", @"Refresh")) forState:UIControlStateNormal];
    self.signalStartButton.hidden = readOnly18;
    self.signalStartButton.enabled = !readOnly18 && !self.manager.busy && !self.signalRunning && !self.signalRecoveryRequired;
    for (UIButton *button in self.signalObserveButtons) {
        button.enabled = !self.manager.busy && !self.signalRunning &&
                         !self.signalRecoveryRequired &&
                         !(button.tag == 5 && BLDeviceIsKnownLTEOnly());
    }
    self.signalCancelButton.enabled = self.signalRunning;
    if (self.signalRunning || self.signalRecoveryRequired) [self.safetySection setExpanded:YES animated:NO];
}

- (void)showAlert:(NSString *)message {
    BLBreadcrumb("UI showAlert begin");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock" message:message ?: @"" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    BLBreadcrumb("UI showAlert end");
}

- (void)openCountryBandsForSelectedCountry {
    NSDictionary *country = BLSelectedCountryRecord();
    if (!country) {
        BLCountriesViewController *picker = [[BLCountriesViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        picker.selectCountryOnly = YES;
        [self.navigationController pushViewController:picker animated:YES];
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
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:BLT(@"Atrás", @"Back")
                                                                    style:UIBarButtonItemStylePlain target:nil action:nil];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)selectCountryTapped:(UIButton *)sender {
    if (self.manager.busy || self.signalRunning || self.signalRecoveryRequired) return;
    BLCountriesViewController *picker = [[BLCountriesViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    picker.selectCountryOnly = YES;
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)ensureBandStateThen:(dispatch_block_t)block {
    if (self.manager.hasReadState) {
        if (block) block();
        return;
    }
    if (self.manager.busy) return;
    __weak typeof(self) weakSelf = self;
    [self.manager refreshWithCompletion:^(BOOL success, NSString *message) {
        [weakSelf refreshDisplay];
        if (!success) {
            [weakSelf showAlert:message.length ? message : BLT(@"No se pudo cargar el estado de bandas.", @"Could not load band status.")];
            return;
        }
        if (block) block();
    }];
    [self refreshDisplay];
}

- (void)manageCountryBandsTapped:(UIButton *)sender {
    if (!BLSelectedCountryRecord()) {
        [self openCountryBandsForSelectedCountry];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self ensureBandStateThen:^{ [weakSelf openCountryBandsForSelectedCountry]; }];
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
    __weak typeof(self) weakSelf = self;
    [self ensureBandStateThen:^{
        if (!weakSelf.manager.supportedBands.count) {
            [weakSelf showAlert:BLT(@"Este iPhone no reporta bandas LTE configurables.", @"This iPhone does not report configurable LTE bands.")];
            return;
        }
        BLBandPickerViewController *picker = [[BLBandPickerViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        [weakSelf.navigationController pushViewController:picker animated:YES];
    }];
}

- (void)editNRBandsTapped:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    [self ensureBandStateThen:^{
        if (!weakSelf.manager.supportedNRBands.count) {
            [weakSelf showAlert:BLT(@"Este iPhone no reporta bandas 5G NR configurables.", @"This iPhone does not report configurable 5G NR bands.")];
            return;
        }
        BLNRBandPickerViewController *picker = [[BLNRBandPickerViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        [weakSelf.navigationController pushViewController:picker animated:YES];
    }];
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
    self.signalValue.text = BLT(@"Consultando señal…", @"Reading signal…");
    __weak typeof(self) weakSelf = self;
    [self.manager signalProbeWithCompletion:^(NSDictionary *result) {
        if (![result[@"success"] boolValue]) {
            [weakSelf showAlert:[result[@"message"] isKindOfClass:NSString.class]
                ? result[@"message"] : BLT(@"No se pudo leer la señal.", @"Could not read signal.")];
            return;
        }
        NSMutableArray *lines = [NSMutableArray array];
        NSArray *measurements = [result[@"measurements"] isKindOfClass:NSArray.class] ? result[@"measurements"] : @[];
        for (NSDictionary *row in measurements) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSString *rat = [row[@"rat"] isKindOfClass:NSString.class] ? row[@"rat"] : @"—";
            NSNumber *band = [row[@"band"] isKindOfClass:NSNumber.class] ? row[@"band"] : nil;
            NSString *role = [row[@"role"] isKindOfClass:NSString.class] ? row[@"role"] : @"";
            NSString *displayRAT = [rat isEqualToString:@"NR"] ? @"5G" : ([rat isEqualToString:@"LTE"] ? @"4G" : rat);
            NSString *label = band ? [NSString stringWithFormat:@"%@ %@%@", displayRAT,
                [rat isEqualToString:@"NR"] ? @"n" : @"B", band] : displayRAT;
            [lines addObject:[NSString stringWithFormat:@"%@%@", label,
                [role isEqualToString:@"neighbor"] ? BLT(@" · Vecina", @" · Neighbor") : @""]];
            for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
                id v = row[metric];
                if (![v isKindOfClass:NSNumber.class]) continue;
                NSString *unit = ([metric isEqual:@"rsrp"] || [metric isEqual:@"rssi"]) ? @"dBm" : @"dB";
                [lines addObject:[NSString stringWithFormat:@"  %@ %.1f %@", metric.uppercaseString, [v doubleValue], unit]];
            }
        }
        if (!measurements.count) {
            [lines addObject:BLT(@"Sin señal disponible", @"No signal available")];
        }
        // Source/API metadata stays in the daemon diagnostics, not the UI.
        weakSelf.signalValue.text = [lines componentsJoinedByString:@"\n"];
    }];
}

- (void)signalScanStartTapped:(UIButton *)sender {
    if (self.signalRunning || self.signalRecoveryRequired || self.manager.busy) return;
    NSString *warning = BLT(
        @"Prueba experimental de bandas LTE. Las bandas se limitarán temporalmente una por una y puedes perder llamadas, datos o cobertura de emergencia. No la ejecutes durante una llamada o situación de emergencia. BandLock intentará restaurar la configuración al terminar, pero la recuperación no está garantizada. ¿Iniciar?",
        @"Experimental LTE band test. Bands will be limited one at a time and calls, data or emergency coverage may be interrupted. Do not run it during a call or emergency. BandLock will try to restore the previous configuration when finished, but recovery cannot be guaranteed. Start?");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Posible pérdida total de cobertura", @"Possible total loss of service")
        message:warning preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Iniciar prueba LTE", @"Start LTE test")
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager startSignalScanWithCompletion:^(NSDictionary *result) {
            if (![result[@"success"] boolValue]) {
                [weakSelf showAlert:[result[@"message"] isKindOfClass:NSString.class]
                    ? result[@"message"] : BLT(@"No se pudo iniciar el barrido.", @"Could not start the scan.")];
                return;
            }
            weakSelf.signalRunning = YES;
            weakSelf.signalValue.text = result[@"message"] ?: BLT(@"Barrido iniciado.", @"Scan started.");
            [weakSelf refreshDisplay];
            [weakSelf startSignalPolling];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)signalObserveTapped:(UIButton *)sender {
    if (self.signalRunning || self.signalRecoveryRequired || self.manager.busy) return;
    NSInteger index = sender.tag - 2;
    NSArray<NSString *> *technologyCodes = @[@"2G", @"3G", @"LTE", @"NR"];
    if (index < 0 || index >= (NSInteger)technologyCodes.count) return;
    NSString *rat = technologyCodes[(NSUInteger)index];
    NSString *display = [rat isEqualToString:@"LTE"] ? @"4G" :
        ([rat isEqualToString:@"NR"] ? @"5G" : rat);
    NSString *warning = [NSString stringWithFormat:BLT(
        @"BandLock cambiará temporalmente la línea a %@ para buscar bandas detectadas en celdas servidoras y vecinas. Durante el cambio puede perderse cobertura, llamadas o datos. Al terminar o cancelar se volverá a solicitar el modo anterior. ¿Iniciar barrido?",
        @"BandLock will temporarily switch the line to %@ to find bands detected on serving and neighboring cells. Coverage, calls or data may be lost during the switch. When finished or cancelled, the previous mode will be requested again. Start scan?"), display];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:BLT(@"Barrido %@", @"%@ scan"), display]
                         message:warning
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel")
                                             style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Iniciar", @"Start")
                                             style:UIAlertActionStyleDestructive
                                           handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager startTechnologySignalScanForRAT:rat completion:^(NSDictionary *result) {
            if (![result[@"success"] boolValue]) {
                [weakSelf showAlert:[result[@"message"] isKindOfClass:NSString.class]
                    ? result[@"message"] : BLT(@"No se pudo iniciar el barrido.", @"Could not start the scan.")];
                return;
            }
            weakSelf.signalRunning = YES;
            weakSelf.signalValue.text = [NSString stringWithFormat:
                BLT(@"Cambiando temporalmente a %@ y buscando bandas…",
                    @"Temporarily switching to %@ and scanning bands…"), display];
            [weakSelf refreshDisplay];
            [weakSelf startSignalPolling];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)signalScanCancelTapped:(UIButton *)sender {
    if (!self.signalRunning) return;
    __weak typeof(self) weakSelf = self;
    [self.manager cancelSignalScanWithCompletion:^(NSDictionary *result) {
        weakSelf.signalValue.text = result[@"message"] ?: BLT(@"Cancelación solicitada.", @"Cancellation requested.");
        [weakSelf startSignalPolling];
    }];
}

- (void)signalScanRecoverTapped:(UIButton *)sender {
    if (self.signalRunning) return;
    __weak typeof(self) weakSelf = self;
    [self.manager recoverSignalScanWithCompletion:^(NSDictionary *result) {
        weakSelf.signalValue.text = result[@"message"] ?: BLT(@"Recuperación solicitada.", @"Recovery requested.");
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
        // rhui9 left the three-second polling timer alive indefinitely after
        // a scan finished. Repeated scan_status IPC is unnecessary while idle
        // and can keep waking the daemon (confirmed in device logs).
        if (!weakSelf.signalRunning && !weakSelf.signalRecoveryRequired) {
            [weakSelf.signalTimer invalidate];
            weakSelf.signalTimer = nil;
        }
        [weakSelf refreshDisplay];
        BOOL passive = [status[@"read_only"] boolValue];
        [weakSelf.signalCancelButton setTitle:(passive
            ? BLT(@"Detener observación", @"Stop observation")
            : BLT(@"Cancelar barrido y restaurar", @"Cancel scan and restore"))
            forState:UIControlStateNormal];
        if ([status[@"phase"] isEqualToString:@"idle"]) return; // Keep read-only probe visible.
        NSMutableArray *lines = [NSMutableArray array];
        NSString *message = [status[@"message"] isKindOfClass:NSString.class] ? status[@"message"] : @"";
        if (message.length) [lines addObject:message];
        NSArray *rows = [status[@"rows"] isKindOfClass:NSArray.class] ? status[@"rows"] : @[];
        for (NSDictionary *row in rows) {
            if (![row isKindOfClass:NSDictionary.class]) continue;
            NSString *rat = row[@"rat"];
            NSString *display = [rat isEqualToString:@"NR"] ? @"5G" :
                ([rat isEqualToString:@"LTE"] ? @"4G" : (rat ?: @"Red"));
            NSMutableString *line = [NSMutableString stringWithString:display];
            NSNumber *band = [row[@"band"] isKindOfClass:NSNumber.class] ? row[@"band"] : nil;
            if (band)
                [line appendFormat:@" %@%@", [rat isEqualToString:@"NR"] ? @"n" : @"B", row[@"band"]];
            if (band && ([rat isEqualToString:@"LTE"] || [rat isEqualToString:@"3G"])) {
                NSString *frequency = BLGFrequencyForBand(band);
                NSString *duplex = BLGDuplexForBand(band);
                if (frequency.length) [line appendFormat:@" · %@", frequency];
                if (duplex.length) [line appendFormat:@" · %@", duplex];
            }
            if ([row[@"role"] isEqualToString:@"neighbor"])
                [line appendString:BLT(@" · Vecina", @" · Neighbor")];
            NSString *statusCode = [row[@"status"] isKindOfClass:NSString.class] ? row[@"status"] : @"";
            NSDictionary *statusLabels = @{
                @"measured": BLT(@"Medida", @"Measured"),
                @"measured_pre_sweep": BLT(@"Medida previa", @"Pre-sweep reading"),
                @"detected": BLT(@"Registrada sin métrica", @"Registered without metric"),
                @"no_signal": BLT(@"Sin señal", @"No signal"),
                @"query_failed": BLT(@"Consulta fallida", @"Query failed"),
                @"write_failed": BLT(@"No se pudo fijar", @"Could not lock"),
                @"readback_unverified": BLT(@"Banda no verificada", @"Band not verified")
            };
            NSString *statusLabel = statusLabels[statusCode];
            if (statusLabel.length) [line appendFormat:@" · %@", statusLabel];
            for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
                NSNumber *value = row[metric];
                if (![value isKindOfClass:NSNumber.class]) continue;
                BOOL dbm = [metric isEqualToString:@"rsrp"] || [metric isEqualToString:@"rssi"] ||
                           [metric isEqualToString:@"rscp"];
                [line appendFormat:@" · %@ %.1f %@", metric.uppercaseString,
                    value.doubleValue, dbm ? @"dBm" : @"dB"];
            }
            [lines addObject:line];
        }
        weakSelf.signalValue.text = [lines componentsJoinedByString:@"\n"];
    }];
}

@end
