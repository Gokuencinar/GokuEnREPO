#import "BLAnalyzerViewController.h"
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLLocalization.h"
#import "BLGBandMetadata.h"
#import "BLCountryProfile.h"
#import "BLCountriesViewController.h"
#import "../../BLHardwareCapabilities.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <float.h>

// NetMonitor-inspired coverage view for the data CoreTelephony actually exposes
// on iOS. Never invent PCI/TAC/CID/channel information when the modem does not
// provide it. Persist only RAT, band and physical signal metrics.
static NSString *const BLAnalyzerHistoryKey = @"BLAnalyzerTypedLTEHistory.v1";
static NSString *const BLAnalyzerLastScanIDKey = @"BLAnalyzerLastPersistedScanID.v1";
static NSUInteger const BLAnalyzerMaxSamples = 300;

static UIColor *BLAnalyzerInk(void) { return [UIColor colorWithRed:0.06 green:0.10 blue:0.19 alpha:1]; }
static UIColor *BLAnalyzerTeal(void) { return [UIColor colorWithRed:0.05 green:0.74 blue:0.66 alpha:1]; }
static UIColor *BLAnalyzerMuted(void) { return [UIColor colorWithRed:0.78 green:0.82 blue:0.89 alpha:1]; }

static NSNumber *BLAnalyzerMetric(id candidate, NSString *name) {
    if (![candidate isKindOfClass:NSNumber.class]) return nil;
    double value = [candidate doubleValue];
    if (!isfinite(value)) return nil;
    if ([name isEqualToString:@"rsrp"] && (value < -160 || value > -40)) return nil;
    if ([name isEqualToString:@"rssi"] && (value < -160 || value > -20)) return nil;
    if ([name isEqualToString:@"rsrq"] && (value < -40 || value > 10)) return nil;
    if ([name isEqualToString:@"snr"] && (value < -50 || value > 50)) return nil;
    if ([name isEqualToString:@"rscp"] && (value < -130 || value > -20)) return nil;
    if ([name isEqualToString:@"ecno"] && (value < -40 || value >= 0)) return nil;
    return @(value);
}

static NSString *BLAnalyzerDisplayRAT(NSString *rat) {
    if ([rat isEqualToString:@"LTE"]) return @"4G";
    if ([rat isEqualToString:@"NR"]) return @"5G";
    return rat.length ? rat : @"Red";
}

static NSString *BLAnalyzerCellKey(NSDictionary *row) {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in @[@"rat", @"role", @"source", @"band", @"cell_id",
                            @"physical_cell_id", @"psc", @"tac", @"lac", @"channel"]) {
        id value = row[key];
        [parts addObject:[value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]
                            ? [value description] : @"-"];
    }
    return [parts componentsJoinedByString:@"/"];
}

static NSString *BLAnalyzerPrimaryMetricName(NSString *rat) {
    if ([rat isEqualToString:@"3G"]) return @"rscp";
    if ([rat isEqualToString:@"2G"]) return @"rssi";
    return @"rsrp";
}

static NSNumber *BLAnalyzerPrimaryMetric(NSDictionary *row) {
    NSString *name = BLAnalyzerPrimaryMetricName(row[@"rat"]);
    return BLAnalyzerMetric(row[name], name);
}

static NSString *BLAnalyzerQuality(NSDictionary *row) {
    NSNumber *primary = BLAnalyzerPrimaryMetric(row);
    if (!primary) return BLT(@"Sin dato", @"No data");
    double value = primary.doubleValue;
    NSString *rat = row[@"rat"];
    double great = -80, good = -90, moderate = -100, poor = -110;
    if ([rat isEqualToString:@"3G"]) { great = -70; good = -85; moderate = -95; poor = -105; }
    else if ([rat isEqualToString:@"2G"]) { great = -65; good = -75; moderate = -85; poor = -95; }
    if (value >= great) return BLT(@"Excelente", @"Great");
    if (value >= good) return BLT(@"Buena", @"Good");
    if (value >= moderate) return BLT(@"Moderada", @"Moderate");
    if (value >= poor) return BLT(@"Mala", @"Poor");
    return BLT(@"Muy mala", @"Very poor");
}

static UIColor *BLAnalyzerQualityColor(NSDictionary *row) {
    NSString *quality = BLAnalyzerQuality(row);
    if ([quality isEqualToString:BLT(@"Excelente", @"Great")]) return UIColor.systemGreenColor;
    if ([quality isEqualToString:BLT(@"Buena", @"Good")]) return UIColor.systemTealColor;
    if ([quality isEqualToString:BLT(@"Moderada", @"Moderate")]) return UIColor.systemYellowColor;
    if ([quality isEqualToString:BLT(@"Mala", @"Poor")]) return UIColor.systemOrangeColor;
    if ([quality isEqualToString:BLT(@"Muy mala", @"Very poor")]) return UIColor.systemRedColor;
    return BLAnalyzerMuted();
}

static float BLAnalyzerSignalProgress(NSDictionary *row) {
    NSNumber *primary = BLAnalyzerPrimaryMetric(row);
    if (!primary) return 0.0f;
    NSString *rat = row[@"rat"];
    double low = -120.0, high = -70.0;
    if ([rat isEqualToString:@"3G"]) { low = -115.0; high = -65.0; }
    else if ([rat isEqualToString:@"2G"]) { low = -105.0; high = -55.0; }
    double normalized = (primary.doubleValue - low) / (high - low);
    return (float)MAX(0.0, MIN(1.0, normalized));
}

static NSString *BLAnalyzerMetricUnit(NSString *metric) {
    return ([metric isEqualToString:@"rsrp"] || [metric isEqualToString:@"rssi"] ||
            [metric isEqualToString:@"rscp"]) ? @"dBm" : @"dB";
}

static NSString *BLAnalyzerBandDetail(NSString *rat, NSNumber *band) {
    if (!band) return @"";
    if ([rat isEqualToString:@"NR"]) {
        NSString *frequency = BLGNRFrequencyForBand(band);
        NSString *duplex = BLGNRDuplexForBand(band);
        if (frequency.length && duplex.length) return [NSString stringWithFormat:@"%@ · %@", frequency, duplex];
        return frequency.length ? frequency : duplex;
    }
    if ([rat isEqualToString:@"LTE"]) {
        NSString *frequency = BLGFrequencyForBand(band);
        NSString *duplex = BLGDuplexForBand(band);
        if (frequency.length && duplex.length) return [NSString stringWithFormat:@"%@ · %@", frequency, duplex];
        return frequency.length ? frequency : duplex;
    }
    return @"";
}

static NSNumber *BLAnalyzerReferenceFrequencyForRow(NSDictionary *row) {
    NSString *rat = [row[@"rat"] isKindOfClass:NSString.class] ? row[@"rat"] : nil;
    NSNumber *channel = [row[@"channel"] isKindOfClass:NSNumber.class] ? row[@"channel"] : nil;
    if (!rat.length || !channel) return nil;
    NSInteger n = channel.integerValue;
    if ([rat isEqualToString:@"3G"]) {
        if (n >= 10562 && n <= 10838) return @2100;
        if (n >= 9662 && n <= 9938) return @1900;
        if (n >= 1162 && n <= 1513) return @1800;
        if (n >= 1537 && n <= 1738) return @1700;
        if (n >= 4357 && n <= 4458) return @850;
        if (n >= 2937 && n <= 3088) return @900;
    } else if ([rat isEqualToString:@"2G"]) {
        if ((n >= 0 && n <= 124) || (n >= 975 && n <= 1023)) return @900;
        if (n >= 128 && n <= 251) return @850;
        if (n >= 811 && n <= 885) return @1800;
        if (n >= 512 && n <= 810) {
            NSArray<NSNumber *> *country = BLCountryFrequenciesForRAT(BLSelectedCountryRecord(), @"2G");
            BOOL dcs = [country containsObject:@1800];
            BOOL pcs = [country containsObject:@1900];
            if (dcs != pcs) return dcs ? @1800 : @1900;
        }
    }
    return nil;
}

@interface BLAnalyzerGraph : UIView
@property (nonatomic, copy) NSArray<NSDictionary *> *samples;
@end

@implementation BLAnalyzerGraph
- (void)setSamples:(NSArray<NSDictionary *> *)samples { _samples = [samples copy]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    CGFloat x0 = 14, x1 = CGRectGetWidth(rect)-14, y0 = 14, y1 = CGRectGetHeight(rect)-14;
    if (x1 <= x0 || y1 <= y0) return;
    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1 alpha:0.13].CGColor);
    for (NSUInteger i = 0; i <= 4; i++) {
        CGFloat y = y0 + (y1-y0)*i/4.0;
        CGContextMoveToPoint(context, x0, y);
        CGContextAddLineToPoint(context, x1, y);
    }
    CGContextStrokePath(context);
    NSMutableArray<NSNumber *> *values = [NSMutableArray array];
    for (NSDictionary *sample in self.samples) {
        NSNumber *value = BLAnalyzerPrimaryMetric(sample);
        if (value) [values addObject:value];
    }
    if (!values.count) return;
    double lowest = -130, highest = -60;
    for (NSNumber *value in values) {
        lowest = MIN(lowest, floor(value.doubleValue/10.0)*10.0);
        highest = MAX(highest, ceil(value.doubleValue/10.0)*10.0);
    }
    if (highest-lowest < 20) { highest += 10; lowest -= 10; }
    CGContextSetLineWidth(context, 2.5);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetStrokeColorWithColor(context, BLAnalyzerTeal().CGColor);
    for (NSUInteger i = 0; i < values.count; i++) {
        CGFloat x = values.count == 1 ? (x0+x1)/2.0 : x0+(x1-x0)*i/(values.count-1.0);
        CGFloat y = y1-(y1-y0)*(values[i].doubleValue-lowest)/(highest-lowest);
        if (!i) CGContextMoveToPoint(context, x, y); else CGContextAddLineToPoint(context, x, y);
    }
    CGContextStrokePath(context);
}
@end

@interface BLAnalyzerViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *bandLabel;
@property (nonatomic, strong) UILabel *qualityLabel;
@property (nonatomic, strong) UILabel *networkDetailLabel;
@property (nonatomic, strong) UILabel *caStatusLabel;
@property (nonatomic, strong) UILabel *rsrpLabel;
@property (nonatomic, strong) UILabel *rsrpTitleLabel;
@property (nonatomic, strong) UILabel *snrLabel;
@property (nonatomic, strong) UILabel *rsrqLabel;
@property (nonatomic, strong) UILabel *rsrqTitleLabel;
@property (nonatomic, strong) UILabel *rssiLabel;
@property (nonatomic, strong) UILabel *rssiTitleLabel;
@property (nonatomic, strong) UIStackView *cellsStack;
@property (nonatomic, strong) UILabel *scanStatusLabel;
@property (nonatomic, strong) UIStackView *scanRowsStack;
@property (nonatomic, strong) UISegmentedControl *scanTechnology;
@property (nonatomic, strong) UIButton *scanCountryButton;
@property (nonatomic, strong) UILabel *scanBandsLabel;
@property (nonatomic, strong) UIButton *scanButton;
@property (nonatomic, strong) UIButton *scanCancelButton;
@property (nonatomic, strong) UIButton *scanRecoverButton;
@property (nonatomic, strong) UILabel *historyLabel;
@property (nonatomic, strong) UILabel *comparisonLabel;
@property (nonatomic, strong) BLAnalyzerGraph *graph;
@property (nonatomic, strong) UILabel *graphStatsLabel;
@property (nonatomic, strong) UIButton *monitorButton;
@property (nonatomic, strong) UIButton *readButton;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSTimer *scanTimer;
@property (nonatomic, assign) BOOL monitoring;
@property (nonatomic, assign) BOOL requesting;
@property (nonatomic, assign) BOOL scanRunning;
@property (nonatomic, assign) BOOL recoveryRequired;
@property (nonatomic, copy) NSArray<NSDictionary *> *history;
@property (nonatomic, copy) NSArray<NSDictionary *> *currentMeasurements;
@property (nonatomic, copy) NSArray<NSDictionary *> *currentScanMeasurements;
@property (nonatomic, copy) NSString *lastPersistedScanID;
@end

@implementation BLAnalyzerViewController

- (UILabel *)text:(NSString *)text size:(CGFloat)size color:(UIColor *)color weight:(UIFontWeight)weight {
    UILabel *label = [UILabel new];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    return label;
}

- (UIStackView *)columnWithSpace:(CGFloat)space {
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = space;
    return stack;
}

- (UIStackView *)metricWithTitle:(NSString *)title valueLabel:(UILabel * __strong *)outLabel
                     titleLabel:(UILabel * __strong *)outTitle {
    UIStackView *item = [self columnWithSpace:3];
    UILabel *heading = [self text:title size:11 color:BLAnalyzerMuted() weight:UIFontWeightSemibold];
    UILabel *value = [self text:@"—" size:20 color:UIColor.whiteColor weight:UIFontWeightBold];
    [item addArrangedSubview:heading];
    [item addArrangedSubview:value];
    if (outLabel) *outLabel = value;
    if (outTitle) *outTitle = heading;
    return item;
}

- (UIView *)panelWithTitle:(NSString *)title children:(NSArray<UIView *> *)children {
    UIView *panel = [UIView new];
    panel.backgroundColor = [UIColor colorWithRed:0.10 green:0.16 blue:0.27 alpha:1];
    panel.layer.cornerRadius = 16;
    UIStackView *body = [self columnWithSpace:9];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [body addArrangedSubview:[self text:title size:12 color:BLAnalyzerMuted() weight:UIFontWeightBold]];
    for (UIView *child in children) [body addArrangedSubview:child];
    [panel addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [body.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],
        [body.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],
        [body.topAnchor constraintEqualToAnchor:panel.topAnchor constant:12],
        [body.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-12]
    ]];
    return panel;
}

- (UIButton *)action:(NSString *)title icon:(NSString *)symbol selector:(SEL)selector strong:(BOOL)strong {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = strong ? BLAnalyzerTeal() : [UIColor colorWithWhite:1 alpha:0.09];
    button.layer.cornerRadius = 13;
    button.tintColor = strong ? BLAnalyzerInk() : UIColor.whiteColor;
    [button setTitleColor:button.tintColor forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.manager = BLTelephonyManager.sharedManager;
    self.title = BLT(@"Analizador", @"Analyzer");
    self.view.backgroundColor = BLAnalyzerInk();
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationController.navigationBar.tintColor = BLAnalyzerTeal();
    self.navigationController.navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    self.history = [self readHistory];
    self.lastPersistedScanID = [NSUserDefaults.standardUserDefaults stringForKey:BLAnalyzerLastScanIDKey];

    self.scroll = [UIScrollView new];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scroll];
    self.stack = [self columnWithSpace:12];
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:12],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-30],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    self.bandLabel = [self text:@"—" size:28 color:UIColor.whiteColor weight:UIFontWeightBold];
    self.qualityLabel = [self text:BLT(@"Sin datos", @"No data") size:15 color:BLAnalyzerTeal() weight:UIFontWeightBold];
    self.networkDetailLabel = [self text:@"—" size:13 color:BLAnalyzerMuted() weight:UIFontWeightMedium];
    self.caStatusLabel = [self text:BLT(@"CA: esperando información del módem", @"CA: waiting for modem information")
                                  size:12 color:BLAnalyzerMuted() weight:UIFontWeightSemibold];
    self.statusLabel = [self text:BLT(@"Buscando celda servidora…", @"Looking for serving cell…")
        size:12 color:BLAnalyzerTeal() weight:UIFontWeightMedium];
    UIStackView *metricRow = [UIStackView new];
    metricRow.axis = UILayoutConstraintAxisHorizontal;
    metricRow.distribution = UIStackViewDistributionFillEqually;
    metricRow.spacing = 12;
    [metricRow addArrangedSubview:[self metricWithTitle:@"RSRP · dBm" valueLabel:&_rsrpLabel titleLabel:&_rsrpTitleLabel]];
    [metricRow addArrangedSubview:[self metricWithTitle:@"SNR · dB" valueLabel:&_snrLabel titleLabel:NULL]];
    UIStackView *minorRow = [UIStackView new];
    minorRow.axis = UILayoutConstraintAxisHorizontal;
    minorRow.spacing = 12;
    minorRow.distribution = UIStackViewDistributionFillEqually;
    [minorRow addArrangedSubview:[self metricWithTitle:@"RSRQ · dB" valueLabel:&_rsrqLabel titleLabel:&_rsrqTitleLabel]];
    [minorRow addArrangedSubview:[self metricWithTitle:@"RSSI · dBm" valueLabel:&_rssiLabel titleLabel:&_rssiTitleLabel]];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"COBERTURA ACTUAL", @"CURRENT COVERAGE")
        children:@[self.bandLabel, self.qualityLabel, self.networkDetailLabel, self.caStatusLabel, self.statusLabel, metricRow, minorRow]]];

    self.cellsStack = [self columnWithSpace:6];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"CELDAS Y PORTADORAS", @"CELLS & CARRIERS")
        children:@[self.cellsStack]]];

    self.readButton = [self action:BLT(@"Actualizar ahora", @"Refresh now") icon:@"arrow.clockwise"
                                selector:@selector(readTapped:) strong:YES];
    self.monitorButton = [self action:BLT(@"Pausar monitor", @"Pause monitor") icon:@"pause.circle.fill"
                                   selector:@selector(monitorTapped:) strong:NO];
    UIStackView *liveActions = [UIStackView new];
    liveActions.axis = UILayoutConstraintAxisHorizontal;
    liveActions.distribution = UIStackViewDistributionFillEqually;
    liveActions.spacing = 9;
    [liveActions addArrangedSubview:self.readButton];
    [liveActions addArrangedSubview:self.monitorButton];
    [self.stack addArrangedSubview:liveActions];

    self.scanTechnology = [[UISegmentedControl alloc] initWithItems:@[@"Auto", @"2G", @"3G", @"4G", @"5G"]];
    self.scanTechnology.selectedSegmentIndex = 0;
    self.scanTechnology.selectedSegmentTintColor = BLAnalyzerTeal();
    [self.scanTechnology setTitleTextAttributes:@{NSForegroundColorAttributeName: BLAnalyzerInk(),
                                                   NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightBold]}
                                        forState:UIControlStateSelected];
    [self.scanTechnology setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor}
                                        forState:UIControlStateNormal];
    [self.scanTechnology setTitleTextAttributes:@{NSForegroundColorAttributeName:
        [UIColor colorWithWhite:1 alpha:0.24],
        NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]}
                                        forState:UIControlStateDisabled];
    if (BLDeviceIsKnownLTEOnly()) {
        [self.scanTechnology setTitle:@"5G —" forSegmentAtIndex:4];
        [self.scanTechnology setEnabled:NO forSegmentAtIndex:4];
    }
    [self.scanTechnology addTarget:self action:@selector(updateCountryScanSummary) forControlEvents:UIControlEventValueChanged];
    self.scanCountryButton = [self action:BLT(@"Elegir país", @"Choose country")
                                       icon:@"globe.europe.africa.fill"
                                   selector:@selector(selectScanCountry:) strong:NO];
    self.scanBandsLabel = [self text:@"" size:12 color:BLAnalyzerMuted() weight:UIFontWeightMedium];
    self.scanButton = [self action:BLT(@"Iniciar barrido de cobertura", @"Start coverage scan")
                                 icon:@"antenna.radiowaves.left.and.right" selector:@selector(scanTapped:) strong:YES];
    self.scanCancelButton = [self action:BLT(@"Cancelar y restaurar", @"Cancel & restore")
                                       icon:@"xmark.circle" selector:@selector(scanCancelTapped:) strong:NO];
    self.scanRecoverButton = [self action:BLT(@"Recuperar configuración original", @"Recover original configuration")
                                        icon:@"arrow.uturn.backward.circle" selector:@selector(scanRecoverTapped:) strong:NO];
    self.scanStatusLabel = [self text:BLT(@"Usa Auto para observar la red actual o elige una tecnología para hacer un barrido dirigido.",
                                              @"Use Auto to observe the current network or choose a technology for a directed scan.")
                                  size:13 color:BLAnalyzerMuted() weight:UIFontWeightMedium];
    self.scanRowsStack = [self columnWithSpace:6];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"RED Y BARRIDO", @"NETWORK & SCAN")
        children:@[self.scanCountryButton, self.scanTechnology, self.scanBandsLabel,
                   self.scanButton, self.scanCancelButton, self.scanRecoverButton,
                   self.scanStatusLabel, self.scanRowsStack]]];
    [self updateCountryScanSummary];
    [self updateScanButtons];

    self.graph = [BLAnalyzerGraph new];
    self.graph.backgroundColor = UIColor.clearColor;
    self.graph.translatesAutoresizingMaskIntoConstraints = NO;
    [self.graph.heightAnchor constraintEqualToConstant:160].active = YES;
    self.graphStatsLabel = [self text:@"—" size:12 color:BLAnalyzerMuted() weight:UIFontWeightMedium];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"EVOLUCIÓN DE SEÑAL", @"SIGNAL TREND")
        children:@[self.graphStatsLabel, self.graph]]];

    self.comparisonLabel = [self text:@"—" size:14 color:UIColor.whiteColor weight:UIFontWeightMedium];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"COMPARATIVA POR BANDA", @"BAND COMPARISON") children:@[self.comparisonLabel]]];
    self.historyLabel = [self text:@"—" size:13 color:UIColor.whiteColor weight:UIFontWeightRegular];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"HISTORIAL", @"HISTORY") children:@[self.historyLabel]]];

    UIButton *png = [self action:BLT(@"Guardar PNG", @"Save PNG") icon:@"photo.on.rectangle.angled"
                               selector:@selector(pngTapped:) strong:NO];
    UIButton *export = [self action:BLT(@"Exportar JSON", @"Export JSON") icon:@"square.and.arrow.up"
                                  selector:@selector(exportTapped:) strong:NO];
    UIButton *clear = [self action:BLT(@"Borrar historial", @"Clear history") icon:@"trash"
                                 selector:@selector(clearTapped:) strong:NO];
    UIStackView *exportActions = [UIStackView new];
    exportActions.axis = UILayoutConstraintAxisHorizontal;
    exportActions.distribution = UIStackViewDistributionFillEqually;
    exportActions.spacing = 9;
    [exportActions addArrangedSubview:png];
    [exportActions addArrangedSubview:export];
    [self.stack addArrangedSubview:exportActions];
    [self.stack addArrangedSubview:clear];
    [self rebuildMeasurementStack:self.cellsStack rows:@[] scan:NO];
    [self rebuildMeasurementStack:self.scanRowsStack rows:@[] scan:YES];
    [self refreshHistoryUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateCountryScanSummary];
    [self startMonitoring];
    [self scanPoll:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
    [self.scanTimer invalidate];
    self.scanTimer = nil;
}

- (void)dealloc { [self.timer invalidate]; [self.scanTimer invalidate]; }

- (UIView *)measurementCard:(NSDictionary *)row scan:(BOOL)scan {
    UIView *card = [UIView new];
    BOOL serving = [row[@"role"] isEqualToString:@"serving"];
    BOOL secondary = [row[@"role"] isEqualToString:@"secondary"];
    UIColor *roleColor = serving ? BLAnalyzerTeal() : (secondary ? UIColor.systemCyanColor : UIColor.systemYellowColor);
    card.backgroundColor = serving
        ? [UIColor colorWithWhite:1 alpha:0.10]
        : [UIColor colorWithWhite:1 alpha:(secondary ? 0.085 : 0.065)];
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = serving ? 1.0 : 0.5;
    card.layer.borderColor = [roleColor colorWithAlphaComponent:serving ? 0.48 : 0.34].CGColor;
    UIStackView *body = [self columnWithSpace:5];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [body.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:11],
        [body.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-11],
        [body.topAnchor constraintEqualToAnchor:card.topAnchor constant:8],
        [body.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-8]
    ]];
    NSString *rat = [row[@"rat"] isKindOfClass:NSString.class] ? row[@"rat"] : @"";
    NSNumber *band = [row[@"band"] isKindOfClass:NSNumber.class] ? row[@"band"] : nil;
    NSNumber *referenceFrequency = [row[@"reference_frequency_mhz"] isKindOfClass:NSNumber.class]
        ? row[@"reference_frequency_mhz"] : nil;
    if (!referenceFrequency) referenceFrequency = BLAnalyzerReferenceFrequencyForRow(row);
    NSString *role = secondary ? BLT(@"SECUNDARIA LTE", @"LTE SECONDARY") :
        ([row[@"role"] isEqualToString:@"neighbor"] ? BLT(@"VECINA", @"NEIGHBOR") : BLT(@"SERVIDORA", @"SERVING"));
    NSString *prefix = BLAnalyzerDisplayRAT(rat);
    NSString *bandText = @"";
    if (band) {
        if ([rat isEqualToString:@"NR"]) bandText = [NSString stringWithFormat:@" n%@", band];
        else if ([rat isEqualToString:@"LTE"]) bandText = [NSString stringWithFormat:@" B%@", band];
        else bandText = [NSString stringWithFormat:@" · CT %@", band];
    }
    UIStackView *header = [UIStackView new];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 6;
    UILabel *title = [self text:[NSString stringWithFormat:@"%@ · %@%@", role, prefix, bandText]
                             size:13 color:roleColor weight:UIFontWeightBold];
    [header addArrangedSubview:title];
    UIView *spacer = [UIView new];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [header addArrangedSubview:spacer];
    if (scan) {
        NSDictionary *labels = @{
            @"measured": BLT(@"MEDIDA", @"MEASURED"),
            @"measured_frequency_unknown": BLT(@"MEDIDA · FREC. DESCONOCIDA", @"MEASURED · FREQ. UNKNOWN"),
            @"measured_pre_sweep": BLT(@"MEDIDA PREVIA", @"PRE-SWEEP"),
            @"detected": BLT(@"DETECTADA", @"DETECTED"),
            @"detected_frequency_unknown": BLT(@"DETECTADA · FREC. DESCONOCIDA", @"DETECTED · FREQ. UNKNOWN"),
            @"no_signal": BLT(@"SIN SEÑAL", @"NO SIGNAL"),
            @"query_failed": BLT(@"FALLO", @"FAILED"),
            @"write_failed": BLT(@"NO FIJADA", @"NOT LOCKED"),
            @"readback_unverified": BLT(@"NO VERIFICADA", @"UNVERIFIED")
        };
        UILabel *state = [self text:[NSString stringWithFormat:@" %@ ", labels[row[@"status"]] ?: @""]
                               size:10 color:UIColor.whiteColor weight:UIFontWeightBold];
        state.backgroundColor = [UIColor colorWithWhite:1 alpha:0.16];
        state.layer.cornerRadius = 7;
        state.layer.masksToBounds = YES;
        state.tag = 714;
        [header addArrangedSubview:state];
    } else {
        UILabel *quality = [self text:[NSString stringWithFormat:@" %@ ", BLAnalyzerQuality(row)]
                                 size:11 color:BLAnalyzerQualityColor(row) weight:UIFontWeightBold];
        quality.backgroundColor = [BLAnalyzerQualityColor(row) colorWithAlphaComponent:0.20];
        quality.layer.cornerRadius = 7;
        quality.layer.masksToBounds = YES;
        quality.tag = 713;
        [header addArrangedSubview:quality];
    }
    [body addArrangedSubview:header];

    NSString *detail = BLAnalyzerBandDetail(rat, band);
    if (!detail.length && referenceFrequency)
        detail = [NSString stringWithFormat:@"%@ MHz · %@", referenceFrequency,
                  BLT(@"frecuencia verificada por canal", @"frequency verified from channel")];
    if (!detail.length && [row[@"frequency_unverified"] boolValue])
        detail = BLT(@"Frecuencia no expuesta por CoreTelephony; la celda se conserva como diagnóstico",
                     @"Frequency not exposed by CoreTelephony; the cell is kept as a diagnostic");
    if (detail.length) [body addArrangedSubview:[self text:detail size:11 color:BLAnalyzerMuted() weight:UIFontWeightSemibold]];

    NSString *primaryName = BLAnalyzerPrimaryMetricName(rat);
    NSNumber *primaryValue = BLAnalyzerMetric(row[primaryName], primaryName);
    NSString *primaryText = primaryValue
        ? [NSString stringWithFormat:@"%@  %.1f %@", primaryName.uppercaseString,
                                      primaryValue.doubleValue, BLAnalyzerMetricUnit(primaryName)]
        : [NSString stringWithFormat:@"%@  —", primaryName.uppercaseString];
    UILabel *primaryLabel = [self text:primaryText size:(serving ? 21 : 18)
                                 color:UIColor.whiteColor weight:UIFontWeightBold];
    primaryLabel.font = [UIFont monospacedSystemFontOfSize:(serving ? 21 : 18) weight:UIFontWeightBold];
    primaryLabel.tag = 711;
    [body addArrangedSubview:primaryLabel];

    UIProgressView *strength = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    strength.progress = BLAnalyzerSignalProgress(row);
    strength.progressTintColor = BLAnalyzerQualityColor(row);
    strength.trackTintColor = [UIColor colorWithWhite:1 alpha:0.08];
    strength.tag = 715;
    [body addArrangedSubview:strength];

    NSMutableArray<NSString *> *metrics = [NSMutableArray array];
    for (NSString *metric in @[@"rsrp", @"rscp", @"rssi", @"rsrq", @"ecno", @"snr"]) {
        if ([metric isEqualToString:primaryName]) continue;
        NSNumber *value = BLAnalyzerMetric(row[metric], metric);
        if (!value) continue;
        [metrics addObject:[NSString stringWithFormat:@"%@ %.1f %@", metric.uppercaseString,
                            value.doubleValue, BLAnalyzerMetricUnit(metric)]];
    }
    UILabel *metricLabel = [self text:(metrics.count ? [metrics componentsJoinedByString:@"   "] :
                                      BLT(@"Sin métricas secundarias", @"No secondary metrics"))
                                    size:11.5 color:UIColor.whiteColor weight:UIFontWeightMedium];
    metricLabel.tag = 712;
    metricLabel.font = [UIFont monospacedSystemFontOfSize:11.5 weight:UIFontWeightMedium];
    [body addArrangedSubview:metricLabel];

    NSMutableArray *identity = [NSMutableArray array];
    NSString *channelLabel = [rat isEqualToString:@"2G"] ? @"ARFCN" :
                             ([rat isEqualToString:@"3G"] ? @"UARFCN" :
                              ([rat isEqualToString:@"NR"] ? @"NRARFCN" : @"EARFCN"));
    NSDictionary *technical = @{@"cell_id": @"Cell ID", @"physical_cell_id": @"PCI",
                                 @"psc": @"PSC", @"tac": @"TAC", @"lac": @"LAC",
                                 @"channel": channelLabel};
    for (NSString *key in @[@"cell_id", @"physical_cell_id", @"psc", @"tac", @"lac", @"channel"]) {
        if ([row[key] isKindOfClass:NSNumber.class])
            [identity addObject:[NSString stringWithFormat:@"%@ %@", technical[key], row[key]]];
    }
    if (identity.count) {
        UILabel *technicalLabel = [self text:[identity componentsJoinedByString:@"   "]
                                        size:10.5 color:BLAnalyzerMuted() weight:UIFontWeightSemibold];
        technicalLabel.font = [UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightSemibold];
        [body addArrangedSubview:technicalLabel];
    }
    return card;
}

- (void)rebuildMeasurementStack:(UIStackView *)stack rows:(NSArray<NSDictionary *> *)rows scan:(BOOL)scan {
    // Reuse the existing cards on every timer tick. Replacing arrangedSubviews
    // triggers a visible scroll/layout flash even for an unchanged measurement.
    if (rows.count && stack.arrangedSubviews.count == rows.count) {
        BOOL sameIdentity = YES;
        for (NSUInteger index = 0; index < rows.count; index++) {
            NSDictionary *row = rows[index];
            UIView *card = stack.arrangedSubviews[index];
            NSString *identity = BLAnalyzerCellKey(row);
            if (![card.accessibilityIdentifier isEqualToString:identity]) {
                sameIdentity = NO;
                break;
            }
        }
        if (sameIdentity) {
            for (NSUInteger index = 0; index < rows.count; index++) {
                UIView *card = stack.arrangedSubviews[index];
                NSDictionary *row = rows[index];
                NSString *primaryName = BLAnalyzerPrimaryMetricName(row[@"rat"]);
                NSNumber *primaryValue = BLAnalyzerMetric(row[primaryName], primaryName);
                UILabel *primaryLabel = (UILabel *)[card viewWithTag:711];
                if ([primaryLabel isKindOfClass:UILabel.class]) {
                    NSString *value = primaryValue
                        ? [NSString stringWithFormat:@"%@  %.1f %@", primaryName.uppercaseString,
                                                      primaryValue.doubleValue, BLAnalyzerMetricUnit(primaryName)]
                        : [NSString stringWithFormat:@"%@  —", primaryName.uppercaseString];
                    if (![primaryLabel.text isEqualToString:value]) primaryLabel.text = value;
                }
                NSMutableArray *metrics = [NSMutableArray array];
                for (NSString *metric in @[@"rsrp", @"rscp", @"rssi", @"rsrq", @"ecno", @"snr"]) {
                    if ([metric isEqualToString:primaryName]) continue;
                    NSNumber *value = BLAnalyzerMetric(row[metric], metric);
                    if (value) [metrics addObject:[NSString stringWithFormat:@"%@ %.1f %@",
                        metric.uppercaseString, value.doubleValue, BLAnalyzerMetricUnit(metric)]];
                }
                UILabel *metricLabel = (UILabel *)[card viewWithTag:712];
                if ([metricLabel isKindOfClass:UILabel.class]) {
                    NSString *value = metrics.count ? [metrics componentsJoinedByString:@"   "] :
                        BLT(@"Sin métricas secundarias", @"No secondary metrics");
                    if (![metricLabel.text isEqualToString:value]) metricLabel.text = value;
                }
                UILabel *qualityLabel = (UILabel *)[card viewWithTag:713];
                if ([qualityLabel isKindOfClass:UILabel.class]) {
                    UIColor *qualityColor = BLAnalyzerQualityColor(row);
                    NSString *value = [NSString stringWithFormat:@" %@ ", BLAnalyzerQuality(row)];
                    if (![qualityLabel.text isEqualToString:value]) qualityLabel.text = value;
                    qualityLabel.textColor = qualityColor;
                    qualityLabel.backgroundColor = [qualityColor colorWithAlphaComponent:0.20];
                }
                UILabel *stateLabel = (UILabel *)[card viewWithTag:714];
                if ([stateLabel isKindOfClass:UILabel.class]) {
                    NSDictionary *names = @{@"measured": BLT(@"MEDIDA", @"MEASURED"),
                        @"measured_frequency_unknown": BLT(@"MEDIDA · FREC. DESCONOCIDA", @"MEASURED · FREQ. UNKNOWN"),
                        @"measured_pre_sweep": BLT(@"MEDIDA PREVIA", @"PRE-SWEEP"),
                        @"detected": BLT(@"DETECTADA", @"DETECTED"),
                        @"detected_frequency_unknown": BLT(@"DETECTADA · FREC. DESCONOCIDA", @"DETECTED · FREQ. UNKNOWN"),
                        @"no_signal": BLT(@"SIN SEÑAL", @"NO SIGNAL"),
                        @"query_failed": BLT(@"FALLO", @"FAILED"),
                        @"write_failed": BLT(@"NO FIJADA", @"NOT LOCKED"),
                        @"readback_unverified": BLT(@"NO VERIFICADA", @"UNVERIFIED")};
                    NSString *value = [NSString stringWithFormat:@"  %@  ", names[row[@"status"]] ?: @""];
                    if (![stateLabel.text isEqualToString:value]) stateLabel.text = value;
                }
                UIProgressView *strength = (UIProgressView *)[card viewWithTag:715];
                if ([strength isKindOfClass:UIProgressView.class]) {
                    strength.progress = BLAnalyzerSignalProgress(row);
                    strength.progressTintColor = BLAnalyzerQualityColor(row);
                }
            }
            return;
        }
    }
    [UIView performWithoutAnimation:^{
    for (UIView *view in [stack.arrangedSubviews copy]) { [stack removeArrangedSubview:view]; [view removeFromSuperview]; }
    if (!rows.count) {
        [stack addArrangedSubview:[self text:(scan ? BLT(@"Sin resultados todavía", @"No results yet")
                                                   : BLT(@"No hay celdas con métricas disponibles", @"No cells with metrics available"))
                                      size:13 color:BLAnalyzerMuted() weight:UIFontWeightMedium]];
        return;
    }
    for (NSDictionary *row in rows) if ([row isKindOfClass:NSDictionary.class]) {
        UIView *card = [self measurementCard:row scan:scan];
        card.accessibilityIdentifier = BLAnalyzerCellKey(row);
        [stack addArrangedSubview:card];
    }
    }];
}

- (NSArray<NSDictionary *> *)readHistory {
    id saved = [NSUserDefaults.standardUserDefaults objectForKey:BLAnalyzerHistoryKey];
    if (![saved isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *safe = [NSMutableArray array];
    NSArray *input = (NSArray *)saved;
    NSUInteger start = input.count > BLAnalyzerMaxSamples ? input.count-BLAnalyzerMaxSamples : 0;
    for (NSUInteger i = start; i < input.count; i++) {
        NSDictionary *row = input[i];
        if (![row isKindOfClass:NSDictionary.class]) continue;
        NSNumber *band = row[@"band"], *timestamp = row[@"timestamp"];
        NSString *rat = [row[@"rat"] isKindOfClass:NSString.class] ? row[@"rat"] : @"LTE";
        if (![@[@"2G", @"3G", @"LTE", @"NR"] containsObject:rat] || ![timestamp isKindOfClass:NSNumber.class]) continue;
        if (band && (![band isKindOfClass:NSNumber.class] || band.integerValue < 1 ||
            band.integerValue > ([rat isEqualToString:@"NR"] ? 1024 : 256))) continue;
        NSMutableDictionary *clean = [@{@"timestamp": timestamp, @"rat": rat} mutableCopy];
        if (band) clean[@"band"] = band;
        for (NSString *name in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
            NSNumber *value = BLAnalyzerMetric(row[name], name);
            if (value) clean[name] = value;
        }
        for (NSString *name in @[@"source", @"role", @"scan_id"]) {
            if ([row[name] isKindOfClass:NSString.class]) clean[name] = row[name];
        }
        if (BLAnalyzerPrimaryMetric(clean)) [safe addObject:clean];
    }
    return safe;
}

- (void)appendMeasurement:(NSDictionary *)row source:(NSString *)source scanID:(NSString *)scanID {
    NSNumber *primary = BLAnalyzerPrimaryMetric(row);
    NSString *rat = [row[@"rat"] isKindOfClass:NSString.class] ? row[@"rat"] : nil;
    if (!primary || ![@[@"2G", @"3G", @"LTE", @"NR"] containsObject:rat]) return;
    NSMutableDictionary *saved = [@{@"timestamp": @([NSDate date].timeIntervalSince1970), @"rat": rat} mutableCopy];
    if ([row[@"band"] isKindOfClass:NSNumber.class]) saved[@"band"] = row[@"band"];
    for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr", @"rscp", @"ecno"]) {
        NSNumber *value = BLAnalyzerMetric(row[metric], metric);
        if (value) saved[metric] = value;
    }
    if (source.length) saved[@"source"] = source;
    if ([row[@"role"] isKindOfClass:NSString.class]) saved[@"role"] = row[@"role"];
    if (scanID.length) saved[@"scan_id"] = scanID;
    NSMutableArray *history = [self.history mutableCopy] ?: [NSMutableArray array];
    [history addObject:saved];
    if (history.count > BLAnalyzerMaxSamples) [history removeObjectsInRange:NSMakeRange(0, history.count-BLAnalyzerMaxSamples)];
    self.history = history;
    [NSUserDefaults.standardUserDefaults setObject:history forKey:BLAnalyzerHistoryKey];
}

- (void)updateCurrentFromMeasurement:(NSDictionary *)row {
    NSString *rat = row[@"rat"];
    NSNumber *band = [row[@"band"] isKindOfClass:NSNumber.class] ? row[@"band"] : nil;
    NSString *prefix = BLAnalyzerDisplayRAT(rat);
    if ([rat isEqualToString:@"NR"] && band)
        self.bandLabel.text = [NSString stringWithFormat:@"%@ · n%@", prefix, band];
    else if ([rat isEqualToString:@"LTE"] && band)
        self.bandLabel.text = [NSString stringWithFormat:@"%@ · B%@", prefix, band];
    else
        self.bandLabel.text = prefix;
    self.qualityLabel.text = [NSString stringWithFormat:BLT(@"Calidad %@", @"%@ quality"), BLAnalyzerQuality(row)];
    self.qualityLabel.textColor = BLAnalyzerQualityColor(row);
    NSString *detail = BLAnalyzerBandDetail(rat, band);
    NSNumber *referenceFrequency = BLAnalyzerReferenceFrequencyForRow(row);
    NSNumber *channel = [row[@"channel"] isKindOfClass:NSNumber.class] ? row[@"channel"] : nil;
    if (!detail.length && referenceFrequency) {
        NSString *channelName = [rat isEqualToString:@"2G"] ? @"ARFCN" :
                                ([rat isEqualToString:@"3G"] ? @"UARFCN" : @"Canal");
        detail = channel ? [NSString stringWithFormat:@"%@ MHz · %@ %@", referenceFrequency, channelName, channel]
                         : [NSString stringWithFormat:@"%@ MHz", referenceFrequency];
    }
    self.networkDetailLabel.text = detail.length ? detail : BLT(@"Frecuencia no expuesta por CoreTelephony", @"Frequency not exposed by CoreTelephony");
    BOOL g3 = [rat isEqualToString:@"3G"], g2 = [rat isEqualToString:@"2G"];
    self.rsrpTitleLabel.text = g3 ? @"RSCP · dBm" : (g2 ? @"RSSI · dBm" : @"RSRP · dBm");
    self.rsrqTitleLabel.text = g3 ? @"Ec/No · dB" : @"RSRQ · dB";
    self.rsrpLabel.text = [self displayMetric:row[g3 ? @"rscp" : (g2 ? @"rssi" : @"rsrp")]];
    self.snrLabel.text = [self displayMetric:row[@"snr"]];
    self.rsrqLabel.text = [self displayMetric:row[g3 ? @"ecno" : @"rsrq"]];
    if (g2) {
        self.rssiTitleLabel.text = @"ARFCN";
        self.rssiLabel.text = [row[@"channel"] isKindOfClass:NSNumber.class] ? [row[@"channel"] stringValue] : @"—";
    } else {
        self.rssiTitleLabel.text = @"RSSI · dBm";
        self.rssiLabel.text = [self displayMetric:row[@"rssi"]];
    }
    self.statusLabel.text = @"";
    self.statusLabel.hidden = YES;
}

- (NSDictionary *)preferredServingMeasurement:(NSArray<NSDictionary *> *)rows {
    NSDictionary *best = nil;
    for (NSDictionary *row in rows) {
        if (![row isKindOfClass:NSDictionary.class] || ![row[@"role"] isEqualToString:@"serving"] || !BLAnalyzerPrimaryMetric(row)) continue;
        if ([row[@"rat"] isEqualToString:@"NR"]) return row;
        if ([row[@"rat"] isEqualToString:@"LTE"] && [row[@"source"] isEqualToString:@"typed"]) best = row;
        else if (!best) best = row;
    }
    return best;
}

- (NSString *)carrierAggregationSummaryForMeasurements:(NSArray<NSDictionary *> *)rows {
    NSNumber *primaryBand = nil;
    NSMutableOrderedSet<NSNumber *> *secondaryBands = [NSMutableOrderedSet orderedSet];
    BOOL sawLTE = NO;
    BOOL sawSecondary = NO;
    for (NSDictionary *row in rows) {
        if (![row isKindOfClass:NSDictionary.class] || ![row[@"rat"] isEqualToString:@"LTE"]) continue;
        sawLTE = YES;
        NSNumber *band = [row[@"band"] isKindOfClass:NSNumber.class] ? row[@"band"] : nil;
        if ([row[@"role"] isEqualToString:@"serving"] && !primaryBand && band) primaryBand = band;
        if ([row[@"role"] isEqualToString:@"secondary"]) {
            sawSecondary = YES;
            if (band) [secondaryBands addObject:band];
        }
    }
    if (sawSecondary) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        if (primaryBand) [parts addObject:[NSString stringWithFormat:BLT(@"principal B%@", @"primary B%@"), primaryBand]];
        for (NSNumber *band in secondaryBands)
            [parts addObject:[NSString stringWithFormat:BLT(@"secundaria B%@", @"secondary B%@"), band]];
        NSString *carriers = parts.count ? [parts componentsJoinedByString:@" + "] : BLT(@"celda secundaria LTE", @"LTE secondary cell");
        return [NSString stringWithFormat:BLT(@"Posible CA · CoreTelephony expone %@", @"Possible CA · CoreTelephony exposes %@"), carriers];
    }
    if (sawLTE) return BLT(@"CA: CoreTelephony no expone portadoras secundarias en esta lectura",
                           @"CA: CoreTelephony does not expose secondary carriers in this reading");
    return BLT(@"CA: disponible únicamente durante LTE/4G", @"CA: available only while on LTE/4G");
}

- (void)readTapped:(UIButton *)sender { [self takeReading]; }

- (void)takeReading {
    if (self.requesting || self.manager.busy || self.scanRunning || self.recoveryRequired) return;
    self.requesting = YES;
    self.readButton.enabled = NO;
    if (!self.currentMeasurements.count) {
        self.statusLabel.hidden = NO;
        self.statusLabel.text = BLT(@"Actualizando cobertura…", @"Refreshing coverage…");
    }
    __weak typeof(self) weakSelf = self;
    [self.manager signalProbeWithCompletion:^(NSDictionary *result) {
        BLAnalyzerViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.requesting = NO;
        strongSelf.readButton.enabled = YES;
        if (![result[@"success"] boolValue]) {
            strongSelf.statusLabel.text = BLT(@"Lectura no disponible", @"Reading unavailable");
            return;
        }
        NSArray *rows = [result[@"measurements"] isKindOfClass:NSArray.class] ? result[@"measurements"] : @[];
        strongSelf.currentMeasurements = rows;
        strongSelf.caStatusLabel.text = [strongSelf carrierAggregationSummaryForMeasurements:rows];
        [strongSelf rebuildMeasurementStack:strongSelf.cellsStack rows:rows scan:NO];
        NSDictionary *serving = [strongSelf preferredServingMeasurement:rows];
        if (!serving) {
            strongSelf.statusLabel.hidden = NO;
            strongSelf.statusLabel.text = BLT(@"Sin celda servidora con métricas válidas", @"No serving cell with valid metrics");
            return;
        }
        [strongSelf updateCurrentFromMeasurement:serving];
        [strongSelf appendMeasurement:serving source:@"live" scanID:nil];
        [strongSelf refreshHistoryUI];
    }];
}

- (NSString *)displayMetric:(id)value {
    return [value isKindOfClass:NSNumber.class] ? [NSString stringWithFormat:@"%.1f", [value doubleValue]] : @"—";
}

- (void)monitorTapped:(UIButton *)sender {
    if (self.monitoring) [self stopMonitoring]; else [self startMonitoring];
}

- (void)startMonitoring {
    self.monitoring = YES;
    [self.monitorButton setTitle:BLT(@"Pausar monitor", @"Pause monitor") forState:UIControlStateNormal];
    [self.monitorButton setImage:[UIImage systemImageNamed:@"pause.circle.fill"] forState:UIControlStateNormal];
    if (!self.timer) self.timer = [NSTimer scheduledTimerWithTimeInterval:6.0 target:self selector:@selector(monitorTick:) userInfo:nil repeats:YES];
    [self takeReading];
}

- (void)monitorTick:(NSTimer *)timer { if (self.monitoring && !self.requesting) [self takeReading]; }

- (void)stopMonitoring {
    [self.timer invalidate];
    self.timer = nil;
    self.monitoring = NO;
    [self.monitorButton setTitle:BLT(@"Reanudar monitor", @"Resume monitor") forState:UIControlStateNormal];
    [self.monitorButton setImage:[UIImage systemImageNamed:@"play.circle.fill"] forState:UIControlStateNormal];
}

- (NSString *)selectedScanRAT {
    NSArray *rats = @[@"AUTO", @"2G", @"3G", @"LTE", @"NR"];
    NSInteger index = self.scanTechnology.selectedSegmentIndex;
    return index >= 0 && index < (NSInteger)rats.count ? rats[(NSUInteger)index] : @"AUTO";
}

- (void)selectScanCountry:(UIButton *)sender {
    BLCountriesViewController *picker = [[BLCountriesViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    picker.selectCountryOnly = YES;
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)updateCountryScanSummary {
    NSDictionary *country = BLSelectedCountryRecord();
    NSString *name = country ? BLLocalizedCountryName(country) : BLT(@"Elegir país", @"Choose country");
    [self.scanCountryButton setTitle:[NSString stringWithFormat:BLT(@"País: %@", @"Country: %@"), name]
                           forState:UIControlStateNormal];
    NSString *rat = [self selectedScanRAT];
    if ([rat isEqualToString:@"AUTO"]) {
        self.scanCountryButton.enabled = NO;
        self.scanCountryButton.alpha = 0.45;
        self.scanBandsLabel.text = BLT(
            @"Auto observa la red actual sin forzar 2G/3G/4G/5G ni tocar bandas. Muestra la tecnología que el módem esté usando en ese momento.",
            @"Auto observes the current network without forcing 2G/3G/4G/5G or changing bands. It shows whichever technology the modem is currently using.");
        [self.scanButton setTitle:BLT(@"Observar red en Auto", @"Observe network in Auto") forState:UIControlStateNormal];
        self.scanButton.enabled = !self.scanRunning && !self.recoveryRequired && !self.manager.busy;
        return;
    }
    self.scanCountryButton.alpha = 1.0;
    self.scanCountryButton.enabled = !self.scanRunning && !self.recoveryRequired && !self.manager.busy;
    [self.scanButton setTitle:BLT(@"Iniciar barrido de cobertura", @"Start coverage scan") forState:UIControlStateNormal];
    NSArray *bands = BLCountryBandsForRAT(country, rat);
    NSArray *frequencies = BLCountryFrequenciesForRAT(country, rat);
    NSMutableArray *labels = [NSMutableArray array];
    if ([rat isEqualToString:@"2G"] || [rat isEqualToString:@"3G"]) {
        for (NSNumber *mhz in frequencies) {
            NSString *prefix = [rat isEqualToString:@"2G"] ? @"GSM" : @"UMTS";
            [labels addObject:[NSString stringWithFormat:@"%@ %@ MHz", prefix, mhz]];
        }
    } else {
        for (NSNumber *band in bands) {
            NSString *freq = [rat isEqualToString:@"LTE"] ? BLGFrequencyForBand(band) :
                             ([rat isEqualToString:@"NR"] ? BLGNRFrequencyForBand(band) : @"");
            [labels addObject:[NSString stringWithFormat:@"%@%@%@", [rat isEqualToString:@"NR"] ? @"n" : @"B",
                              band, freq.length ? [NSString stringWithFormat:@" (%@)",freq] : @""]];
        }
        if (!labels.count) for (NSNumber *mhz in frequencies)
            [labels addObject:[NSString stringWithFormat:@"%@ MHz", mhz]];
    }
    BOOL hasReference = bands.count || frequencies.count;
    self.scanBandsLabel.text = hasReference
        ? [NSString stringWithFormat:BLT(@"Frecuencias/bandas de referencia: %@. No implica emisión local.",
                                         @"Reference frequencies/bands: %@. Does not imply local transmission."),
                                     [labels componentsJoinedByString:@" · "]]
        : BLT(@"No hay frecuencias de referencia disponibles para este país y tecnología.",
              @"No reference frequencies are available for this country and technology.");
    self.scanButton.enabled = hasReference && !self.scanRunning && !self.recoveryRequired;
}

- (void)scanTapped:(UIButton *)sender {
    if (self.scanRunning || self.recoveryRequired || self.manager.busy) return;
    NSString *rat = [self selectedScanRAT];
    if ([rat isEqualToString:@"AUTO"]) {
        self.scanStatusLabel.text = BLT(@"Observando la red actual sin cambios de radio…",
                                        @"Observing the current network without radio changes…");
        __weak typeof(self) weakSelf = self;
        [self.manager startPassiveSignalObservationForRAT:@"AUTO" completion:^(NSDictionary *result) {
            BLAnalyzerViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            if (![result[@"success"] boolValue]) {
                [strongSelf showAlert:[result[@"message"] isKindOfClass:NSString.class]
                    ? result[@"message"] : BLT(@"No se pudo iniciar la observación Auto.", @"Could not start Auto observation.")];
                return;
            }
            strongSelf.scanRunning = YES;
            strongSelf.recoveryRequired = NO;
            strongSelf.scanStatusLabel.text = result[@"message"] ?: BLT(@"Observación Auto iniciada", @"Auto observation started");
            [strongSelf updateScanButtons];
            [strongSelf startScanPolling];
        }];
        return;
    }
    NSDictionary *country = BLSelectedCountryRecord();
    NSArray *bands = BLCountryBandsForRAT(country, rat);
    NSArray *frequencies = BLCountryFrequenciesForRAT(country, rat);
    if (!country || (!bands.count && !frequencies.count)) {
        [self showAlert:BLT(@"Elige un país con frecuencias de referencia para esta tecnología.",
                            @"Choose a country with reference frequencies for this technology.")];
        return;
    }
    NSString *countryISO = country[@"iso2"];
    if ([rat isEqualToString:@"NR"] && BLDeviceIsKnownLTEOnly()) {
        [self showAlert:BLT(@"Este iPhone no dispone de módem 5G.", @"This iPhone has no 5G modem.")];
        return;
    }
    NSString *display = BLAnalyzerDisplayRAT(rat);
    NSString *warning = [NSString stringWithFormat:BLT(
        @"El Analizador usará Auto como punto de retorno y limitará el barrido %@ a las frecuencias de referencia de %@. En 2G/3G solo se fijarán bandas si CoreTelephony expone un identificador verificado; si no, se hará observación dirigida sin inventar el mapeo. Puedes perder llamadas o datos mientras mide. ¿Iniciar?",
        @"Analyzer will use Auto as the return point and limit the %@ scan to reference frequencies for %@. On 2G/3G, bands are locked only when CoreTelephony exposes a verified identifier; otherwise it uses directed observation without inventing a mapping. Calls or data may drop. Start?"), display, BLLocalizedCountryName(country)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:BLT(@"Barrido %@", @"%@ scan"), display]
                                                                    message:warning preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Iniciar", @"Start") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        BLAnalyzerViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.scanStatusLabel.text = BLT(@"Preparando Auto como punto de retorno…", @"Preparing Auto as return point…");
        [strongSelf.manager setNetworkModeAutomatic:^(BOOL success, NSString *message) {
            BLAnalyzerViewController *modeSelf = weakSelf;
            if (!modeSelf) return;
            if (!success) { [modeSelf showAlert:message ?: BLT(@"No se pudo preparar Auto.", @"Could not prepare Auto.")]; return; }
            [modeSelf.manager startTechnologySignalScanForRAT:rat country:countryISO
                                                   targetBands:bands targetFrequencies:frequencies
                                                    completion:^(NSDictionary *result) {
                BLAnalyzerViewController *scanSelf = weakSelf;
                if (!scanSelf) return;
                if (![result[@"success"] boolValue]) {
                    [scanSelf showAlert:[result[@"message"] isKindOfClass:NSString.class] ? result[@"message"] : @"Scan did not start"];
                    return;
                }
                scanSelf.scanRunning = YES;
                scanSelf.recoveryRequired = NO;
                scanSelf.scanStatusLabel.text = result[@"message"] ?: @"Scan started";
                [scanSelf updateScanButtons];
                [scanSelf startScanPolling];
            }];
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)scanCancelTapped:(UIButton *)sender {
    if (!self.scanRunning || self.manager.busy) return;
    __weak typeof(self) weakSelf = self;
    [self.manager cancelSignalScanWithCompletion:^(NSDictionary *result) {
        weakSelf.scanStatusLabel.text = result[@"message"] ?: BLT(@"Cancelación solicitada", @"Cancellation requested");
        [weakSelf startScanPolling];
    }];
}

- (void)scanRecoverTapped:(UIButton *)sender {
    if (self.scanRunning || self.manager.busy) return;
    __weak typeof(self) weakSelf = self;
    [self.manager recoverSignalScanWithCompletion:^(NSDictionary *result) {
        weakSelf.scanStatusLabel.text = result[@"message"] ?: BLT(@"Recuperación solicitada", @"Recovery requested");
        [weakSelf startScanPolling];
    }];
}

- (void)startScanPolling {
    if (!self.scanTimer) self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(scanPoll:) userInfo:nil repeats:YES];
    [self scanPoll:nil];
}

- (void)scanPoll:(NSTimer *)timer {
    if (self.manager.busy) return;
    __weak typeof(self) weakSelf = self;
    [self.manager signalScanStatusWithCompletion:^(NSDictionary *status) {
        BLAnalyzerViewController *strongSelf = weakSelf;
        if (!strongSelf || ![status[@"phase"] isKindOfClass:NSString.class]) return;
        strongSelf.scanRunning = [status[@"running"] boolValue];
        strongSelf.recoveryRequired = [status[@"recovery_required"] boolValue];
        NSString *message = [status[@"message"] isKindOfClass:NSString.class] ? status[@"message"] : @"";
        NSNumber *completed = [status[@"completed"] isKindOfClass:NSNumber.class] ? status[@"completed"] : nil;
        NSNumber *total = [status[@"total"] isKindOfClass:NSNumber.class] ? status[@"total"] : nil;
        if (completed && total && total.integerValue > 0) {
            strongSelf.scanStatusLabel.text = [NSString stringWithFormat:@"%@\n%@ %ld/%ld", message,
                BLT(@"Progreso", @"Progress"), (long)completed.integerValue, (long)total.integerValue];
        } else if (message.length) strongSelf.scanStatusLabel.text = message;
        NSArray *rows = [status[@"rows"] isKindOfClass:NSArray.class] ? status[@"rows"] : @[];
        strongSelf.currentScanMeasurements = rows;
        [strongSelf rebuildMeasurementStack:strongSelf.scanRowsStack rows:rows scan:YES];
        if (!rows.count && !strongSelf.scanRunning && !strongSelf.recoveryRequired &&
            strongSelf.scanRowsStack.arrangedSubviews.count == 1 &&
            [strongSelf.scanRowsStack.arrangedSubviews.firstObject isKindOfClass:UILabel.class]) {
            ((UILabel *)strongSelf.scanRowsStack.arrangedSubviews.firstObject).text =
                BLT(@"Sin celdas medibles en este barrido. El motivo aparece en el estado superior.",
                    @"No measurable cells in this scan. See the status above for the reason.");
        }
        [strongSelf persistCompletedScanIfNeeded:status rows:rows];
        [strongSelf updateScanButtons];
        if (!strongSelf.scanRunning && !strongSelf.recoveryRequired) {
            [strongSelf.scanTimer invalidate];
            strongSelf.scanTimer = nil;
            if (strongSelf.monitoring) [strongSelf takeReading];
        }
    }];
}

- (void)persistCompletedScanIfNeeded:(NSDictionary *)status rows:(NSArray<NSDictionary *> *)rows {
    NSString *phase = status[@"phase"];
    NSString *scanID = [status[@"scan_id"] isKindOfClass:NSString.class] ? status[@"scan_id"] : nil;
    if (!scanID.length || [scanID isEqualToString:self.lastPersistedScanID] ||
        !([phase isEqualToString:@"complete"] || [phase isEqualToString:@"observation_complete"])) return;
    BOOL added = NO;
    for (NSDictionary *row in rows) {
        if (![row isKindOfClass:NSDictionary.class] ||
            ![row[@"role"] isEqualToString:@"serving"] ||
            !BLAnalyzerPrimaryMetric(row)) continue;
        [self appendMeasurement:row source:@"scan" scanID:scanID];
        added = YES;
    }
    self.lastPersistedScanID = scanID;
    [NSUserDefaults.standardUserDefaults setObject:scanID forKey:BLAnalyzerLastScanIDKey];
    if (added) [self refreshHistoryUI];
}

- (void)updateScanButtons {
    self.scanTechnology.enabled = !self.scanRunning && !self.recoveryRequired && !self.manager.busy;
    if (BLDeviceIsKnownLTEOnly()) [self.scanTechnology setEnabled:NO forSegmentAtIndex:4];
    NSDictionary *country = BLSelectedCountryRecord();
    NSString *rat = [self selectedScanRAT];
    BOOL autoMode = [rat isEqualToString:@"AUTO"];
    self.scanCountryButton.enabled = !autoMode && !self.scanRunning && !self.recoveryRequired && !self.manager.busy;
    self.scanCountryButton.alpha = autoMode ? 0.45 : 1.0;
    BOOL hasReference = BLCountryBandsForRAT(country, rat).count > 0 ||
                        BLCountryFrequenciesForRAT(country, rat).count > 0;
    self.scanButton.enabled = (autoMode || hasReference) &&
                              !self.scanRunning && !self.recoveryRequired && !self.manager.busy;
    self.scanCancelButton.hidden = !self.scanRunning;
    self.scanCancelButton.enabled = self.scanRunning && !self.manager.busy;
    self.scanRecoverButton.hidden = !self.recoveryRequired;
    self.scanRecoverButton.enabled = self.recoveryRequired && !self.scanRunning && !self.manager.busy;
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock" message:message ?: @"" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshHistoryUI {
    NSUInteger count = self.history.count;
    if (!count) {
        self.historyLabel.text = BLT(@"Sin lecturas", @"No readings");
        self.comparisonLabel.text = BLT(@"Sin datos", @"No data");
        self.graphStatsLabel.text = @"—";
        self.graph.samples = @[];
        return;
    }
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterNoStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSInteger start = MAX((NSInteger)count-10, 0);
    for (NSInteger index = (NSInteger)count-1; index >= start; index--) {
        NSDictionary *item = self.history[(NSUInteger)index];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[item[@"timestamp"] doubleValue]];
        NSNumber *power = BLAnalyzerPrimaryMetric(item);
        NSString *rat = item[@"rat"] ?: @"LTE";
        NSString *bandName = item[@"band"] ? [NSString stringWithFormat:@"%@ %@%@", BLAnalyzerDisplayRAT(rat),
            [rat isEqualToString:@"NR"] ? @"n" : @"B", item[@"band"]] : BLAnalyzerDisplayRAT(rat);
        NSString *source = [item[@"source"] isEqualToString:@"scan"] ? BLT(@"barrido", @"scan") : BLT(@"vivo", @"live");
        [lines addObject:[NSString stringWithFormat:@"%@ · %@ · %.1f dBm · %@ · %@",
            [formatter stringFromDate:date], bandName, power.doubleValue, BLAnalyzerQuality(item), source]];
    }
    self.historyLabel.text = [lines componentsJoinedByString:@"\n"];

    NSUInteger chartStart = count > 61 ? count-61 : 0;
    NSNumber *latestBand = self.history.lastObject[@"band"];
    NSString *latestRAT = self.history.lastObject[@"rat"] ?: @"LTE";
    NSMutableArray *sameBand = [NSMutableArray array];
    for (NSUInteger i = chartStart; i < count; i++) {
        NSDictionary *sample = self.history[i];
        if (latestBand && [sample[@"band"] isEqual:latestBand] && [(sample[@"rat"] ?: @"LTE") isEqual:latestRAT]) [sameBand addObject:sample];
    }
    self.graph.samples = sameBand;
    if (sameBand.count) {
        double minValue = DBL_MAX, maxValue = -DBL_MAX, sum = 0;
        NSUInteger valid = 0;
        for (NSDictionary *sample in sameBand) {
            NSNumber *value = BLAnalyzerPrimaryMetric(sample);
            if (!value) continue;
            minValue = MIN(minValue, value.doubleValue);
            maxValue = MAX(maxValue, value.doubleValue);
            sum += value.doubleValue;
            valid++;
        }
        self.graphStatsLabel.text = valid ? [NSString stringWithFormat:
            BLT(@"Últimas %lu · mín %.1f · media %.1f · máx %.1f dBm",
                @"Last %lu · min %.1f · avg %.1f · max %.1f dBm"),
            (unsigned long)valid, minValue, sum/valid, maxValue] : @"—";
    } else self.graphStatsLabel.text = @"—";

    NSMutableDictionary<NSString *, NSMutableDictionary *> *groups = [NSMutableDictionary dictionary];
    for (NSDictionary *sample in self.history) {
        NSNumber *value = BLAnalyzerPrimaryMetric(sample), *band = sample[@"band"];
        NSString *rat = sample[@"rat"] ?: @"LTE";
        if (!value || !band) continue;
        NSString *key = [NSString stringWithFormat:@"%@:%@", rat, band];
        NSMutableDictionary *group = groups[key];
        if (!group) { group = [@{@"sum": @0.0, @"count": @0} mutableCopy]; groups[key] = group; }
        group[@"sum"] = @([group[@"sum"] doubleValue]+value.doubleValue);
        group[@"count"] = @([group[@"count"] integerValue]+1);
    }
    NSMutableArray *comparison = [NSMutableArray array];
    for (NSString *key in [groups.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *group = groups[key];
        NSInteger n = [group[@"count"] integerValue];
        if (!n) continue;
        NSArray *parts = [key componentsSeparatedByString:@":"];
        NSString *rat = parts.firstObject;
        NSString *display = [NSString stringWithFormat:@"%@ %@%@", BLAnalyzerDisplayRAT(rat),
            [rat isEqualToString:@"NR"] ? @"n" : @"B", parts.lastObject];
        [comparison addObject:[NSString stringWithFormat:@"%@   %.1f dBm · %ld %@", display,
            [group[@"sum"] doubleValue]/n, (long)n, BLT(@"muestras", @"samples")]];
    }
    self.comparisonLabel.text = comparison.count ? [comparison componentsJoinedByString:@"\n"] : BLT(@"Sin datos", @"No data");
}

- (UIStackView *)reportRowsForMeasurements:(NSArray<NSDictionary *> *)rows scan:(BOOL)scan {
    UIStackView *stack = [self columnWithSpace:6];
    if (!rows.count) {
        [stack addArrangedSubview:[self text:BLT(@"Sin mediciones disponibles", @"No measurements available")
                                      size:12 color:BLAnalyzerMuted() weight:UIFontWeightSemibold]];
        return stack;
    }
    for (NSDictionary *row in rows) {
        if (![row isKindOfClass:NSDictionary.class]) continue;
        [stack addArrangedSubview:[self measurementCard:row scan:scan]];
    }
    return stack;
}

- (UIImage *)pngReportImage {
    if (!self.currentMeasurements.count && !self.currentScanMeasurements.count) return nil;

    CGFloat width = 390.0;
    UIView *report = [UIView new];
    report.backgroundColor = BLAnalyzerInk();
    UIStackView *body = [self columnWithSpace:10];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [report addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [body.leadingAnchor constraintEqualToAnchor:report.leadingAnchor constant:14],
        [body.trailingAnchor constraintEqualToAnchor:report.trailingAnchor constant:-14],
        [body.topAnchor constraintEqualToAnchor:report.topAnchor constant:16],
        [body.bottomAnchor constraintEqualToAnchor:report.bottomAnchor constant:-16]
    ]];

    UILabel *title = [self text:@"BandLock · Analizador" size:25 color:UIColor.whiteColor weight:UIFontWeightBold];
    [body addArrangedSubview:title];

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterMediumStyle;
    UILabel *timestamp = [self text:[formatter stringFromDate:NSDate.date]
                                size:11 color:BLAnalyzerMuted() weight:UIFontWeightSemibold];
    [body addArrangedSubview:timestamp];

    NSString *ca = [self carrierAggregationSummaryForMeasurements:self.currentMeasurements ?: @[]];
    if (ca.length) {
        UILabel *caLabel = [self text:ca size:12 color:UIColor.whiteColor weight:UIFontWeightSemibold];
        caLabel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        caLabel.layer.cornerRadius = 8;
        caLabel.layer.masksToBounds = YES;
        [body addArrangedSubview:caLabel];
    }

    if (self.currentMeasurements.count) {
        UIStackView *rows = [self reportRowsForMeasurements:self.currentMeasurements scan:NO];
        [body addArrangedSubview:[self panelWithTitle:BLT(@"MEDICIÓN ACTUAL", @"CURRENT MEASUREMENT")
                                             children:@[rows]]];
    }
    if (self.currentScanMeasurements.count) {
        UIStackView *scanRows = [self reportRowsForMeasurements:self.currentScanMeasurements scan:YES];
        [body addArrangedSubview:[self panelWithTitle:BLT(@"BARRIDO / OBSERVACIÓN", @"SCAN / OBSERVATION")
                                             children:@[scanRows]]];
    }

    [body addArrangedSubview:[self text:BLT(@"Solo se muestran datos realmente expuestos por CoreTelephony.",
                                           @"Only data actually exposed by CoreTelephony is shown.")
                                   size:10 color:BLAnalyzerMuted() weight:UIFontWeightMedium]];

    CGSize fitting = [report systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                            withHorizontalFittingPriority:UILayoutPriorityRequired
                                  verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    CGFloat height = MAX(1.0, ceil(fitting.height));
    report.bounds = CGRectMake(0, 0, width, height);
    [report setNeedsLayout];
    [report layoutIfNeeded];

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = YES;
    format.scale = 3.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:report.bounds.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [report.layer renderInContext:context.CGContext];
    }];
}

- (void)pngTapped:(UIButton *)sender {
    UIImage *image = [self pngReportImage];
    if (!image) {
        [self showAlert:BLT(@"Haz al menos una lectura antes de guardar el PNG.",
                            @"Take at least one reading before saving the PNG.")];
        return;
    }
    NSData *png = UIImagePNGRepresentation(image);
    if (!png.length) {
        [self showAlert:BLT(@"No se pudo generar la imagen PNG.", @"Could not generate the PNG image.")];
        return;
    }
    NSDateFormatter *nameFormatter = [NSDateFormatter new];
    nameFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    nameFormatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *name = [NSString stringWithFormat:@"BandLock-%@.png", [nameFormatter stringFromDate:NSDate.date]];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
    if (![png writeToURL:url atomically:YES]) {
        [self showAlert:BLT(@"No se pudo guardar temporalmente el PNG.", @"Could not save the PNG temporarily.")];
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                           applicationActivities:nil];
    activity.popoverPresentationController.sourceView = sender;
    activity.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)exportTapped:(UIButton *)sender {
    if (!self.history.count) return;
    NSDictionary *safe = @{@"schema": @"bandlock.cell-signal-history.v3", @"measurements": self.history};
    NSData *data = [NSJSONSerialization dataWithJSONObject:safe options:NSJSONWritingPrettyPrinted error:nil];
    if (!data) return;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = sender;
    activity.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)clearTapped:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Borrar historial", @"Clear history")
       message:BLT(@"Se eliminarán todas las mediciones guardadas en este iPhone.",
                   @"All locally stored measurements will be removed from this iPhone.") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Borrar", @"Clear") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:BLAnalyzerHistoryKey];
        weakSelf.history = @[];
        [weakSelf refreshHistoryUI];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
