#import "BLAnalyzerViewController.h"
#import "BLTelephonyManager.h"
#import "BLLocalization.h"
#import <math.h>

// This page intentionally does not expose any band/mode changing command.
// The persisted schema allows only timestamp, band and physical signal metrics.
static NSString *const BLAnalyzerHistoryKey = @"BLAnalyzerTypedLTEHistory.v1";
static NSUInteger const BLAnalyzerMaxSamples = 300;

static UIColor *BLAnalyzerInk(void) { return [UIColor colorWithRed:0.06 green:0.10 blue:0.19 alpha:1]; }
static UIColor *BLAnalyzerTeal(void) { return [UIColor colorWithRed:0.05 green:0.74 blue:0.66 alpha:1]; }
static UIColor *BLAnalyzerMuted(void) { return [UIColor colorWithRed:0.59 green:0.65 blue:0.73 alpha:1]; }

static NSNumber *BLAnalyzerMetric(id candidate, NSString *name) {
    if (![candidate isKindOfClass:NSNumber.class]) return nil;
    double value = [candidate doubleValue];
    if (!isfinite(value)) return nil;
    if ([name isEqualToString:@"rsrp"] && (value < -160 || value > -40)) return nil;
    if ([name isEqualToString:@"rssi"] && (value < -160 || value > -20)) return nil;
    if ([name isEqualToString:@"rsrq"] && (value < -40 || value > 10)) return nil;
    if ([name isEqualToString:@"snr"] && (value < -50 || value > 50)) return nil;
    return @(value);
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
    CGFloat x0 = 14, x1 = CGRectGetWidth(rect) - 14, y0 = 14, y1 = CGRectGetHeight(rect) - 14;
    if (x1 <= x0 || y1 <= y0) return;
    CGContextSetLineWidth(context, 1);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1 alpha:0.13].CGColor);
    for (NSUInteger i = 0; i <= 3; i++) {
        CGFloat y = y0 + (y1-y0)*i/3.0;
        CGContextMoveToPoint(context, x0, y);
        CGContextAddLineToPoint(context, x1, y);
    }
    CGContextStrokePath(context);
    NSMutableArray<NSNumber *> *values = [NSMutableArray array];
    for (NSDictionary *sample in self.samples) {
        NSNumber *v = BLAnalyzerMetric(sample[@"rsrp"], @"rsrp");
        if (v) [values addObject:v];
    }
    if (!values.count) return;
    double lowest = -135, highest = -75;
    for (NSNumber *v in values) {
        lowest = MIN(lowest, floor(v.doubleValue / 10.0) * 10.0);
        highest = MAX(highest, ceil(v.doubleValue / 10.0) * 10.0);
    }
    CGContextSetLineWidth(context, 2.5);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetStrokeColorWithColor(context, BLAnalyzerTeal().CGColor);
    for (NSUInteger i = 0; i < values.count; i++) {
        CGFloat x = values.count == 1 ? (x0 + x1)/2.0 : x0 + (x1-x0) * i/(values.count-1.0);
        CGFloat y = y1 - (y1-y0)*(values[i].doubleValue-lowest)/(highest-lowest);
        if (i == 0) CGContextMoveToPoint(context, x, y);
        else CGContextAddLineToPoint(context, x, y);
    }
    CGContextStrokePath(context);
    CGFloat lastX = values.count == 1 ? (x0+x1)/2.0 : x1;
    CGFloat lastY = y1-(y1-y0)*(values.lastObject.doubleValue-lowest)/(highest-lowest);
    CGContextSetFillColorWithColor(context, BLAnalyzerTeal().CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(lastX-4, lastY-4, 8, 8));
}
@end

@interface BLAnalyzerViewController ()
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *bandLabel;
@property (nonatomic, strong) UILabel *rsrpLabel;
@property (nonatomic, strong) UILabel *snrLabel;
@property (nonatomic, strong) UILabel *rsrqLabel;
@property (nonatomic, strong) UILabel *rssiLabel;
@property (nonatomic, strong) UILabel *historyLabel;
@property (nonatomic, strong) UILabel *comparisonLabel;
@property (nonatomic, strong) BLAnalyzerGraph *graph;
@property (nonatomic, strong) UIButton *monitorButton;
@property (nonatomic, strong) UIButton *readButton;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL monitoring;
@property (nonatomic, assign) BOOL requesting;
@property (nonatomic, copy) NSArray<NSDictionary *> *history;
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

- (UIStackView *)metricWithTitle:(NSString *)title valueLabel:(UILabel * __strong *)outLabel {
    UIStackView *item = [self columnWithSpace:5];
    [item addArrangedSubview:[self text:title size:12 color:BLAnalyzerMuted() weight:UIFontWeightMedium]];
    UILabel *value = [self text:@"—" size:22 color:UIColor.whiteColor weight:UIFontWeightBold];
    [item addArrangedSubview:value];
    if (outLabel) *outLabel = value;
    return item;
}

- (UIView *)panelWithTitle:(NSString *)title children:(NSArray<UIView *> *)children {
    UIView *panel = [UIView new];
    panel.backgroundColor = [UIColor colorWithRed:0.10 green:0.16 blue:0.27 alpha:1];
    panel.layer.cornerRadius = 20;
    UIStackView *body = [self columnWithSpace:12];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [body addArrangedSubview:[self text:title size:13 color:BLAnalyzerMuted() weight:UIFontWeightBold]];
    for (UIView *child in children) [body addArrangedSubview:child];
    [panel addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [body.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:18],
        [body.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-18],
        [body.topAnchor constraintEqualToAnchor:panel.topAnchor constant:18],
        [body.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-18]
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
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 10, 12, 10);
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Analizador", @"Analyzer");
    self.view.backgroundColor = BLAnalyzerInk();
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationController.navigationBar.tintColor = BLAnalyzerTeal();
    self.navigationController.navigationBar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    self.history = [self readHistory];

    self.scroll = [UIScrollView new];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scroll];
    self.stack = [self columnWithSpace:16];
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.stack.topAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.topAnchor constant:16],
        [self.stack.bottomAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.bottomAnchor constant:-30],
        [self.stack.leadingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.leadingAnchor constant:16],
        [self.stack.trailingAnchor constraintEqualToAnchor:self.scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [self.stack.widthAnchor constraintEqualToAnchor:self.scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    UIStackView *header = [self columnWithSpace:6];
    [header addArrangedSubview:[self text:BLT(@"TU RED, EN DETALLE", @"YOUR NETWORK, IN DETAIL")
        size:12 color:BLAnalyzerTeal() weight:UIFontWeightBold]];
    [header addArrangedSubview:[self text:BLT(@"Observa. Compara. Entiende.", @"Observe. Compare. Understand.")
        size:25 color:UIColor.whiteColor weight:UIFontWeightBold]];
    [header addArrangedSubview:[self text:BLT(@"Mediciones LTE pasivas · Sin modificar bandas ni modos de red",
        @"Passive LTE measurements · No band or network mode changes")
        size:13 color:BLAnalyzerMuted() weight:UIFontWeightRegular]];
    [self.stack addArrangedSubview:header];

    self.bandLabel = [self text:@"LTE · —" size:31 color:UIColor.whiteColor weight:UIFontWeightBold];
    self.statusLabel = [self text:BLT(@"Sin lectura todavía", @"No reading yet")
        size:12 color:BLAnalyzerTeal() weight:UIFontWeightMedium];
    UIStackView *metricRow = [UIStackView new];
    metricRow.axis = UILayoutConstraintAxisHorizontal;
    metricRow.distribution = UIStackViewDistributionFillEqually;
    metricRow.spacing = 12;
    [metricRow addArrangedSubview:[self metricWithTitle:@"RSRP · dBm" valueLabel:&_rsrpLabel]];
    [metricRow addArrangedSubview:[self metricWithTitle:@"SNR · dB" valueLabel:&_snrLabel]];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"SEÑAL ACTUAL", @"CURRENT SIGNAL")
                                          children:@[self.bandLabel, self.statusLabel, metricRow]]];

    UIStackView *minorRow = [UIStackView new];
    minorRow.axis = UILayoutConstraintAxisHorizontal;
    minorRow.spacing = 12;
    minorRow.distribution = UIStackViewDistributionFillEqually;
    [minorRow addArrangedSubview:[self metricWithTitle:@"RSRQ · dB" valueLabel:&_rsrqLabel]];
    [minorRow addArrangedSubview:[self metricWithTitle:@"RSSI · dBm" valueLabel:&_rssiLabel]];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"MÉTRICAS ADICIONALES", @"ADDITIONAL METRICS") children:@[minorRow]]];

    self.readButton = [self action:BLT(@"Tomar lectura", @"Take reading") icon:@"waveform.path.ecg"
                         selector:@selector(readTapped:) strong:YES];
    self.monitorButton = [self action:BLT(@"Iniciar monitor", @"Start monitor") icon:@"play.circle.fill"
                         selector:@selector(monitorTapped:) strong:NO];
    UIStackView *actions = [self columnWithSpace:9];
    [actions addArrangedSubview:self.readButton];
    [actions addArrangedSubview:self.monitorButton];
    [self.stack addArrangedSubview:actions];

    self.graph = [BLAnalyzerGraph new];
    self.graph.backgroundColor = UIColor.clearColor;
    self.graph.translatesAutoresizingMaskIntoConstraints = NO;
    [self.graph.heightAnchor constraintEqualToConstant:148].active = YES;
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"EVOLUCIÓN RSRP · ÚLTIMAS LECTURAS", @"RSRP TREND · RECENT READINGS")
        children:@[self.graph, [self text:BLT(@"Gráfica de muestras válidas, no un escaneo de bandas.",
                                             @"Graph of valid samples, not a band scan.")
                                         size:11 color:BLAnalyzerMuted() weight:UIFontWeightRegular]]]];

    self.comparisonLabel = [self text:@"—" size:14 color:UIColor.whiteColor weight:UIFontWeightMedium];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"COMPARAR BANDAS OBSERVADAS", @"COMPARE OBSERVED BANDS") children:@[self.comparisonLabel]]];
    self.historyLabel = [self text:@"—" size:13 color:UIColor.whiteColor weight:UIFontWeightRegular];
    [self.stack addArrangedSubview:[self panelWithTitle:BLT(@"HISTORIAL LOCAL", @"LOCAL HISTORY") children:@[self.historyLabel]]];

    UIButton *export = [self action:BLT(@"Compartir lecturas", @"Share readings") icon:@"square.and.arrow.up"
                             selector:@selector(exportTapped:) strong:NO];
    UIButton *clear = [self action:BLT(@"Borrar historial", @"Clear history") icon:@"trash"
                            selector:@selector(clearTapped:) strong:NO];
    [self.stack addArrangedSubview:export];
    [self.stack addArrangedSubview:clear];
    [self.stack addArrangedSubview:[self text:BLT(@"Solo se guardan fecha, banda y RSRP/RSRQ/RSSI/SNR válidos. Nunca IMSI, IMEI, identificación de celda ni ubicación. El monitor se detiene al salir de esta pantalla.",
        @"Only time, band and valid RSRP/RSRQ/RSSI/SNR are saved. Never IMSI, IMEI, cell IDs or location. Monitoring stops when you leave this screen.")
        size:12 color:BLAnalyzerMuted() weight:UIFontWeightRegular]];
    [self refreshHistoryUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopMonitoring];
}

- (void)dealloc { [self.timer invalidate]; }

- (NSArray<NSDictionary *> *)readHistory {
    id saved = [NSUserDefaults.standardUserDefaults objectForKey:BLAnalyzerHistoryKey];
    if (![saved isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *safe = [NSMutableArray array];
    NSArray *input = (NSArray *)saved;
    NSUInteger start = input.count > BLAnalyzerMaxSamples ? input.count - BLAnalyzerMaxSamples : 0;
    for (NSUInteger i = start; i < input.count; i++) {
        NSDictionary *row = input[i];
        if (![row isKindOfClass:NSDictionary.class]) continue;
        NSNumber *band = row[@"band"], *timestamp = row[@"timestamp"];
        if (![band isKindOfClass:NSNumber.class] || band.integerValue < 1 || band.integerValue > 256 ||
            ![timestamp isKindOfClass:NSNumber.class]) continue;
        NSMutableDictionary *clean = [@{@"timestamp": timestamp, @"band": band} mutableCopy];
        for (NSString *name in @[@"rsrp", @"rsrq", @"rssi", @"snr"]) {
            NSNumber *value = BLAnalyzerMetric(row[name], name);
            if (value) clean[name] = value;
        }
        if (clean[@"rsrp"] || clean[@"rssi"]) [safe addObject:clean];
    }
    return safe;
}

- (void)readTapped:(UIButton *)sender { [self takeReading]; }

- (void)takeReading {
    if (self.requesting || BLTelephonyManager.sharedManager.busy) return;
    self.requesting = YES;
    self.readButton.enabled = NO;
    self.statusLabel.text = BLT(@"Consultando señal LTE…", @"Reading LTE signal…");
    __weak typeof(self) weakSelf = self;
    [BLTelephonyManager.sharedManager signalProbeWithCompletion:^(NSDictionary *result) {
        BLAnalyzerViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.requesting = NO;
        strongSelf.readButton.enabled = YES;
        if (![result[@"success"] boolValue]) {
            strongSelf.statusLabel.text = BLT(@"Lectura no disponible. Prueba más tarde.", @"Reading unavailable. Try later.");
            return;
        }
        NSArray *rows = [result[@"measurements"] isKindOfClass:NSArray.class] ? result[@"measurements"] : @[];
        NSDictionary *typed = nil;
        for (id candidate in rows) {
            if (![candidate isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *row = candidate;
            NSNumber *band = row[@"band"];
            if (![row[@"source"] isEqual:@"typed"] || ![row[@"role"] isEqual:@"serving"] ||
                ![row[@"rat"] isEqual:@"LTE"] || ![band isKindOfClass:NSNumber.class] ||
                band.integerValue < 1 || band.integerValue > 256) continue;
            if (BLAnalyzerMetric(row[@"rsrp"], @"rsrp") || BLAnalyzerMetric(row[@"rssi"], @"rssi")) {
                typed = row;
                break;
            }
        }
        if (!typed) {
            strongSelf.statusLabel.text = BLT(@"No hay lectura LTE tipada válida", @"No valid typed LTE reading available");
            return;
        }
        NSMutableDictionary *saved = [@{@"timestamp": @([NSDate date].timeIntervalSince1970),
                                          @"band": typed[@"band"]} mutableCopy];
        for (NSString *metric in @[@"rsrp", @"rsrq", @"rssi", @"snr"]) {
            NSNumber *value = BLAnalyzerMetric(typed[metric], metric);
            if (value) saved[metric] = value;
        }
        NSMutableArray *history = [strongSelf.history mutableCopy];
        [history addObject:saved];
        if (history.count > BLAnalyzerMaxSamples)
            [history removeObjectsInRange:NSMakeRange(0, history.count-BLAnalyzerMaxSamples)];
        strongSelf.history = history;
        [NSUserDefaults.standardUserDefaults setObject:history forKey:BLAnalyzerHistoryKey];
        strongSelf.bandLabel.text = [NSString stringWithFormat:@"LTE · B%@", saved[@"band"]];
        strongSelf.rsrpLabel.text = [strongSelf displayMetric:saved[@"rsrp"]];
        strongSelf.snrLabel.text = [strongSelf displayMetric:saved[@"snr"]];
        strongSelf.rsrqLabel.text = [strongSelf displayMetric:saved[@"rsrq"]];
        strongSelf.rssiLabel.text = [strongSelf displayMetric:saved[@"rssi"]];
        strongSelf.statusLabel.text = BLT(@"CoreTelephony · Tipado · Lectura pasiva", @"CoreTelephony · Typed · Passive reading");
        [strongSelf refreshHistoryUI];
    }];
}

- (NSString *)displayMetric:(id)value {
    return [value isKindOfClass:NSNumber.class] ? [NSString stringWithFormat:@"%.1f", [value doubleValue]] : @"—";
}

- (void)monitorTapped:(UIButton *)sender {
    if (self.monitoring) { [self stopMonitoring]; return; }
    self.monitoring = YES;
    [self.monitorButton setTitle:BLT(@"Detener monitor", @"Stop monitor") forState:UIControlStateNormal];
    [self.monitorButton setImage:[UIImage systemImageNamed:@"stop.circle.fill"] forState:UIControlStateNormal];
    [self takeReading];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:12 target:self selector:@selector(monitorTick:)
                                               userInfo:nil repeats:YES];
}

- (void)monitorTick:(NSTimer *)timer { if (!self.requesting) [self takeReading]; }

- (void)stopMonitoring {
    [self.timer invalidate];
    self.timer = nil;
    self.monitoring = NO;
    [self.monitorButton setTitle:BLT(@"Iniciar monitor", @"Start monitor") forState:UIControlStateNormal];
    [self.monitorButton setImage:[UIImage systemImageNamed:@"play.circle.fill"] forState:UIControlStateNormal];
}

- (void)refreshHistoryUI {
    NSUInteger count = self.history.count;
    if (!count) {
        self.historyLabel.text = BLT(@"Todavía no hay muestras. Inicia una lectura.", @"No samples yet. Start a reading.");
        self.comparisonLabel.text = BLT(@"Aparecerán únicamente las bandas medidas realmente.",
                                           @"Only genuinely measured bands will appear.");
        self.graph.samples = @[];
        return;
    }
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterNoStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSInteger start = MAX((NSInteger)count-8, 0);
    for (NSInteger index = (NSInteger)count-1; index >= start; index--) {
        NSDictionary *item = self.history[(NSUInteger)index];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[item[@"timestamp"] doubleValue]];
        NSString *power = item[@"rsrp"] ? [NSString stringWithFormat:@"%@ dBm", [self displayMetric:item[@"rsrp"]]] : @"—";
        [lines addObject:[NSString stringWithFormat:@"%@  ·  B%@  ·  %@",
            [formatter stringFromDate:date], item[@"band"], power]];
    }
    self.historyLabel.text = [lines componentsJoinedByString:@"\n"];
    NSUInteger chartStart = count > 40 ? count-40 : 0;
    // A single trace is for the last naturally observed band only: do not join
    // unrelated serving-cell/band measurements into a fabricated signal trend.
    NSNumber *latestBand = self.history.lastObject[@"band"];
    NSMutableArray *sameBand = [NSMutableArray array];
    for (NSUInteger i = chartStart; i < count; i++) {
        NSDictionary *sample = self.history[i];
        if ([sample[@"band"] isEqual:latestBand]) [sameBand addObject:sample];
    }
    self.graph.samples = sameBand;

    NSMutableDictionary<NSNumber *, NSMutableDictionary *> *groups = [NSMutableDictionary dictionary];
    for (NSDictionary *sample in self.history) {
        NSNumber *value = BLAnalyzerMetric(sample[@"rsrp"], @"rsrp");
        if (!value) continue;
        NSNumber *band = sample[@"band"];
        NSMutableDictionary *group = groups[band];
        if (!group) { group = [@{@"sum": @0.0, @"count": @0} mutableCopy]; groups[band] = group; }
        group[@"sum"] = @([group[@"sum"] doubleValue]+value.doubleValue);
        group[@"count"] = @([group[@"count"] integerValue]+1);
    }
    NSMutableArray *comparison = [NSMutableArray array];
    NSArray *sorted = [groups.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *band in sorted) {
        NSDictionary *group = groups[band];
        NSInteger n = [group[@"count"] integerValue];
        if (!n) continue;
        [comparison addObject:[NSString stringWithFormat:@"B%@   %.1f dBm   ·   %ld %@",
            band, [group[@"sum"] doubleValue]/n, (long)n, BLT(@"muestras", @"samples")]];
    }
    self.comparisonLabel.text = comparison.count ? [comparison componentsJoinedByString:@"\n"] :
        BLT(@"Sin RSRP tipado para comparar.", @"No typed RSRP to compare.");
}

- (void)exportTapped:(UIButton *)sender {
    if (!self.history.count) return;
    NSDictionary *safe = @{@"schema": @"bandlock.typed-lte-history.v1", @"measurements": self.history};
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Borrar historial LTE", @"Clear LTE history")
       message:BLT(@"Se eliminarán todas las muestras guardadas en este iPhone.",
                   @"All locally stored samples will be removed from this iPhone.") preferredStyle:UIAlertControllerStyleAlert];
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
