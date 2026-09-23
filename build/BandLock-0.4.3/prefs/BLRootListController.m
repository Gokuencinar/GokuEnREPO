#import "BLRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLRATAutomatic = @"kCTRegistrationRATSelectionAutomatic";
static NSString * const BLRATLTE = @"kCTRegistrationRATSelectionLTE";
static NSString * const BLLogDirectory = @"/var/mobile/Library/Logs/BandLock";
static NSString * const BLLastLogPath = @"/var/mobile/Library/Logs/BandLock/BandLock-last.txt";
static NSString * const BLSSHLastLogPath = @"/rootfs/private/var/mobile/Library/Logs/BandLock/BandLock-last.txt";
static NSString * const BLStatePath = @"/var/mobile/Library/Preferences/com.local.bandlock.state.plist";

static id BLMsg0(id object, SEL selector) {
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}
static id BLMsgErr(id object, SEL selector, NSError **error) {
    return ((id (*)(id, SEL, NSError **))objc_msgSend)(object, selector, error);
}
static id BLMsgObjErr(id object, SEL selector, id argument, NSError **error) {
    return ((id (*)(id, SEL, id, NSError **))objc_msgSend)(object, selector, argument, error);
}
static id BLMsg2(id object, SEL selector, id arg1, id arg2) {
    return ((id (*)(id, SEL, id, id))objc_msgSend)(object, selector, arg1, arg2);
}
static void BLMsgSetObj(id object, SEL selector, id value) {
    ((void (*)(id, SEL, id))objc_msgSend)(object, selector, value);
}
static void BLMsgSetActiveBandInfo(id object, SEL selector, id context, id bands, NSError **error) {
    ((void (*)(id, SEL, id, id, NSError **))objc_msgSend)(object, selector, context, bands, error);
}
static BOOL BLMsgBoolObj(id object, SEL selector, id value) {
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(object, selector, value);
}
static void BLMsgObjBlock(id object, SEL selector, id value, void (^completion)(id, NSError *)) {
    ((void (*)(id, SEL, id, id))objc_msgSend)(object, selector, value, completion);
}
static void BLMsgGetRatSelection(id object, SEL selector, id context, void (^completion)(NSString *, NSString *, NSError *)) {
    ((void (*)(id, SEL, id, id))objc_msgSend)(object, selector, context, completion);
}
static void BLMsgSetRatSelection(id object, SEL selector, id context, id selection, id preferred, void (^completion)(NSError *)) {
    ((void (*)(id, SEL, id, id, id, id))objc_msgSend)(object, selector, context, selection, preferred, completion);
}

static NSDictionary<NSNumber *, NSString *> *BLBandFrequencies(void) {
    static NSDictionary<NSNumber *, NSString *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @1: @"2100 MHz",
            @2: @"1900 MHz PCS",
            @3: @"1800 MHz",
            @4: @"AWS 1700/2100 MHz",
            @5: @"850 MHz",
            @7: @"2600 MHz",
            @8: @"900 MHz",
            @12: @"700 MHz",
            @13: @"700 MHz",
            @14: @"700 MHz",
            @17: @"700 MHz",
            @18: @"850 MHz",
            @19: @"850 MHz",
            @20: @"800 MHz",
            @25: @"1900 MHz PCS",
            @26: @"850 MHz",
            @28: @"700 MHz",
            @29: @"700 MHz SDL",
            @30: @"2300 MHz",
            @34: @"2000 MHz TDD",
            @38: @"2600 MHz TDD",
            @39: @"1900 MHz TDD",
            @40: @"2300 MHz TDD",
            @41: @"2500 MHz TDD",
            @66: @"AWS 1700/2100 MHz"
        };
    });
    return map;
}

static NSArray<NSNumber *> *BLSpainBands(void) {
    return @[@28, @20, @8, @3, @1, @7, @38];
}

static NSArray<NSNumber *> *BLIntersectBands(NSArray<NSNumber *> *source, NSArray<NSNumber *> *wanted) {
    NSSet *sourceSet = [NSSet setWithArray:source ?: @[]];
    NSMutableArray *result = [NSMutableArray array];
    for (NSNumber *band in wanted ?: @[]) {
        if ([sourceSet containsObject:band]) [result addObject:band];
    }
    return result;
}


static NSMutableDictionary *BLReadState(void) {
    NSDictionary *existing = [NSDictionary dictionaryWithContentsOfFile:BLStatePath];
    return existing ? [existing mutableCopy] : [NSMutableDictionary dictionary];
}

static void BLWriteState(NSDictionary *changes) {
    NSMutableDictionary *state = BLReadState();
    [changes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj) state[key] = obj;
        else [state removeObjectForKey:key];
    }];
    [state writeToFile:BLStatePath atomically:YES];
}

static NSString *BLBandTitle(NSNumber *band) {
    NSString *frequency = BLBandFrequencies()[band];
    return frequency.length
        ? [NSString stringWithFormat:@"B%@ · %@", band, frequency]
        : [NSString stringWithFormat:@"B%@", band];
}

static NSArray<NSNumber *> *BLSortedBands(id bands) {
    if (![bands isKindOfClass:[NSArray class]] && ![bands isKindOfClass:[NSSet class]]) return @[];
    NSArray *input = [bands isKindOfClass:[NSSet class]] ? [(NSSet *)bands allObjects] : (NSArray *)bands;
    NSMutableOrderedSet<NSNumber *> *normalized = [NSMutableOrderedSet orderedSet];
    for (id item in input) {
        if ([item respondsToSelector:@selector(integerValue)]) {
            NSInteger value = [item integerValue];
            if (value > 0) [normalized addObject:@(value)];
        }
    }
    return [[normalized array] sortedArrayUsingSelector:@selector(compare:)];
}

static NSString *BLBandList(NSArray<NSNumber *> *bands) {
    if (!bands.count) return @"—";
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:bands.count];
    for (NSNumber *band in bands) [parts addObject:[NSString stringWithFormat:@"B%@", band]];
    return [parts componentsJoinedByString:@", "];
}

static NSString *BLCompactDescription(id object) {
    if (!object || object == [NSNull null]) return @"—";
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = object;
        NSArray *keys = [[dictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            return [[a description] compare:[b description] options:NSNumericSearch];
        }];
        NSMutableArray *parts = [NSMutableArray array];
        for (id key in keys) {
            [parts addObject:[NSString stringWithFormat:@"%@: %@", [key description], BLCompactDescription(dictionary[key])]];
        }
        return parts.count ? [parts componentsJoinedByString:@" | "] : @"(vacío)";
    }
    if ([object isKindOfClass:[NSSet class]]) object = [(NSSet *)object allObjects];
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id value in (NSArray *)object) [parts addObject:[value description]];
        [parts sortUsingSelector:@selector(localizedStandardCompare:)];
        return parts.count ? [parts componentsJoinedByString:@", "] : @"(vacío)";
    }
    return [object description] ?: @"—";
}

static NSString *BLHumanRAT(id ratObject) {
    NSString *raw = BLCompactDescription(ratObject);
    if ([raw rangeOfString:@"NRNSA" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"5G NSA";
    if ([raw rangeOfString:@"NR" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"5G NR";
    if ([raw rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"LTE / 4G";
    if ([raw rangeOfString:@"HSDPA" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"HSDPA / 3G";
    if ([raw rangeOfString:@"HSUPA" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"HSUPA / 3G";
    if ([raw rangeOfString:@"WCDMA" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"WCDMA / 3G";
    if ([raw rangeOfString:@"Edge" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"EDGE / 2G";
    if ([raw rangeOfString:@"GPRS" options:NSCaseInsensitiveSearch].location != NSNotFound) return @"GPRS / 2G";
    return raw;
}

static NSString *BLServingBandFromCellInfo(id cellInfo) {
    if (!cellInfo) return @"No disponible";
    SEL legacySelector = NSSelectorFromString(@"legacyInfo");
    if (![cellInfo respondsToSelector:legacySelector]) return @"No disponible";

    id legacy = BLMsg0(cellInfo, legacySelector);
    if (![legacy isKindOfClass:[NSArray class]] || ![(NSArray *)legacy count]) return @"No disponible";

    NSDictionary *row = nil;
    for (id candidate in (NSArray *)legacy) {
        if (![candidate isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *dict = (NSDictionary *)candidate;
        if ([dict[@"kCTCellMonitorCellType"] isEqual:@"kCTCellMonitorCellTypeServing"]) {
            row = dict;
            break;
        }
    }
    if (!row) {
        id first = [(NSArray *)legacy firstObject];
        if ([first isKindOfClass:[NSDictionary class]]) row = first;
    }
    if (!row) return @"No disponible";

    id band = row[@"kCTCellMonitorBandInfo"];
    if (![band respondsToSelector:@selector(integerValue)] || [band integerValue] <= 0) return @"No disponible";

    NSNumber *bandNumber = @([band integerValue]);
    NSString *rat = row[@"kCTCellMonitorCellRadioAccessTechnology"];
    NSString *title = BLBandTitle(bandNumber);
    if ([rat isKindOfClass:[NSString class]] && [rat length]) {
        if ([rat rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return [NSString stringWithFormat:@"%@ · LTE", title];
        }
        return [NSString stringWithFormat:@"%@ · %@", title, rat];
    }
    return title;
}

@interface BLRootListController () {
    NSString *_blStatus;
    NSString *_blRAT;
    NSString *_blServingBand;
    NSString *_blDetail;
    NSString *_blLogStatus;
    NSString *_blConfiguredRATMode;
    NSString *_blRatSelectionRaw;
    NSString *_blRatPreferredRaw;
    NSArray<NSNumber *> *_blSupportedLTE;
    NSArray<NSNumber *> *_blActiveLTE;
    NSArray<NSNumber *> *_blAllSupportedLTE;
    NSArray<NSNumber *> *_blAllActiveLTE;
    NSArray<NSNumber *> *_blPreviousLTE;
    NSMutableSet<NSNumber *> *_blSelectedLTE;
    BOOL _blHasRead;
}
- (void)rebuildUI;
- (NSDictionary *)queryCoreTelephony;
- (void)consumeQuery:(NSDictionary *)query resetSelection:(BOOL)resetSelection;
- (void)applyLTEBands:(NSArray<NSNumber *> *)requested action:(NSString *)action savePrevious:(BOOL)savePrevious;
- (void)savePreviousLTE:(NSArray<NSNumber *> *)bands;
- (void)clearLogsConfirmed;
- (NSDictionary *)readRatSelectionFromClient:(id)client context:(id)context;
- (void)applyNetworkModeSelection:(NSString *)selection preferred:(NSString *)preferred label:(NSString *)label stateValue:(NSString *)stateValue;
@end

@implementation BLRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"BandLock";

    if (!_blStatus) {
        _blStatus = @"Sin consultar";
        _blRAT = @"—";
        _blServingBand = @"—";
        _blDetail = @"Pulsa «Actualizar estado» para leer la configuración del módem.";
        _blLogStatus = [[NSFileManager defaultManager] fileExistsAtPath:BLLastLogPath] ? BLSSHLastLogPath : @"Sin registros";
        _blConfiguredRATMode = @"Sin consultar";
        _blRatSelectionRaw = @"—";
        _blRatPreferredRaw = @"—";
        _blSupportedLTE = @[];
        _blActiveLTE = @[];
        _blAllSupportedLTE = @[];
        _blAllActiveLTE = @[];
        _blSelectedLTE = [NSMutableSet set];
        NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:BLStatePath];
        _blPreviousLTE = BLSortedBands(state[@"previousLTE"]);
    }

    @try {
        UITableView *table = [self valueForKey:@"table"];
        if ([table isKindOfClass:[UITableView class]] && !table.tableHeaderView) {
            CGFloat width = CGRectGetWidth(UIScreen.mainScreen.bounds);
            UIView *outer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 126)];
            outer.backgroundColor = UIColor.clearColor;

            UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 12, width - 32, 102)];
            card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
            card.layer.cornerRadius = 16.0;
            card.layer.masksToBounds = YES;
            [outer addSubview:card];

            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"]];
            icon.frame = CGRectMake(18, 20, 34, 34);
            icon.contentMode = UIViewContentModeScaleAspectFit;
            icon.tintColor = UIColor.systemOrangeColor;
            [card addSubview:icon];

            UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(66, 14, width - 130, 30)];
            title.text = @"BandLock";
            title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
            title.textColor = UIColor.labelColor;
            [card addSubview:title];

            UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(66, 44, width - 130, 22)];
            subtitle.text = @"España · Orange · LTE";
            subtitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            subtitle.textColor = UIColor.secondaryLabelColor;
            [card addSubview:subtitle];

            UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 73, width - 68, 18)];
            caption.text = @"Control LTE manual · estado verificado por el módem";
            caption.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
            caption.textColor = UIColor.tertiaryLabelColor;
            [card addSubview:caption];

            table.tableHeaderView = outer;
        }
    } @catch (__unused NSException *exception) {}
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSMutableDictionary *state = BLReadState();
    NSArray *pending = BLSortedBands(state[@"pendingLTE"]);
    NSArray *previous = BLSortedBands(state[@"previousLTE"]);
    if (pending.count) _blSelectedLTE = [NSMutableSet setWithArray:pending];
    if (previous.count) _blPreviousLTE = previous;

    if (_blHasRead) {
        _specifiers = nil;
        [self reloadSpecifiers];
    }
}

- (NSMutableArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];

    PSSpecifier *connectionGroup = [PSSpecifier emptyGroupSpecifier];
    connectionGroup.name = @"Estado de red";
    [connectionGroup setProperty:@"La lectura es manual. «Banda conectada» intenta identificar la celda servidora; «Bandas permitidas» muestra el bloqueo LTE actual." forKey:@"footerText"];
    [items addObject:connectionGroup];

    PSSpecifier *readButton = [PSSpecifier preferenceSpecifierNamed:@"Actualizar estado"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    readButton.buttonAction = @selector(reloadBands);
    [readButton setProperty:@YES forKey:@"enabled"];
    [items addObject:readButton];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Estado" target:self set:nil get:@selector(statusValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Red actual" target:self set:nil get:@selector(ratValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Banda conectada" target:self set:nil get:@selector(servingBandValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Modo LTE" target:self set:nil get:@selector(modeValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Bandas permitidas" target:self set:nil get:@selector(activeLTEValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *networkGroup = [PSSpecifier emptyGroupSpecifier];
    networkGroup.name = @"Modo de red";
    [networkGroup setProperty:@"Pulsa directamente el modo que quieras usar. Automático mantiene el comportamiento normal de iOS; Solo LTE / 4G evita el fallback a 3G/EDGE mientras esté activo." forKey:@"footerText"];
    [items addObject:networkGroup];

    BOOL ratIsLTE = [_blConfiguredRATMode isEqualToString:@"Solo LTE / 4G"];
    BOOL ratIsAutomatic = [_blConfiguredRATMode isEqualToString:@"Automático"];

    PSSpecifier *automaticMode = [PSSpecifier preferenceSpecifierNamed:(ratIsAutomatic ? @"✓ Automático" : @"Automático")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    automaticMode.buttonAction = @selector(selectAutomaticNetworkMode);
    [automaticMode setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:automaticMode];

    PSSpecifier *lteMode = [PSSpecifier preferenceSpecifierNamed:(ratIsLTE ? @"✓ Solo LTE / 4G" : @"Solo LTE / 4G")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    lteMode.buttonAction = @selector(confirmLTENetworkMode);
    [lteMode setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:lteMode];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Configuración RAT"
        target:self set:nil get:@selector(networkModeStatusValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *controlGroup = [PSSpecifier emptyGroupSpecifier];
    controlGroup.name = @"Control LTE";
    [controlGroup setProperty:@"La selección de bandas está separada en una pantalla propia. Solo aparecen bandas LTE utilizadas en España y compatibles con este iPhone." forKey:@"footerText"];
    [items addObject:controlGroup];

    Class selectionClass = NSClassFromString(@"BLBandSelectionController");
    PSSpecifier *selection = [PSSpecifier preferenceSpecifierNamed:@"Seleccionar bandas"
        target:self set:nil get:nil detail:selectionClass cell:PSLinkCell edit:nil];
    [selection setProperty:@(_blHasRead && selectionClass != Nil) forKey:@"enabled"];
    [selection setProperty:@"antenna.radiowaves.left.and.right" forKey:@"iconImageSystem"];
    [items addObject:selection];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Selección pendiente" target:self set:nil get:@selector(pendingSelectionValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *apply = [PSSpecifier preferenceSpecifierNamed:@"Aplicar selección LTE"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    apply.buttonAction = @selector(confirmApplySelection);
    [apply setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:apply];

    PSSpecifier *previous = [PSSpecifier preferenceSpecifierNamed:@"Restaurar selección anterior"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    previous.buttonAction = @selector(restorePreviousLTE);
    [previous setProperty:@(_blHasRead && _blPreviousLTE.count > 0) forKey:@"enabled"];
    [items addObject:previous];

    PSSpecifier *automatic = [PSSpecifier preferenceSpecifierNamed:@"Restaurar modo automático"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    automatic.buttonAction = @selector(restoreAllLTE);
    [automatic setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:automatic];

    PSSpecifier *toolsGroup = [PSSpecifier emptyGroupSpecifier];
    toolsGroup.name = @"Herramientas";
    [toolsGroup setProperty:@"FTMInternal-4 es la aplicación interna de Apple utilizada para Field Test Mode." forKey:@"footerText"];
    [items addObject:toolsGroup];

    PSSpecifier *fieldTest = [PSSpecifier preferenceSpecifierNamed:@"Abrir FTMInternal-4"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    fieldTest.buttonAction = @selector(openFieldTestMode);
    [fieldTest setProperty:@YES forKey:@"enabled"];
    [items addObject:fieldTest];

    PSSpecifier *diagGroup = [PSSpecifier emptyGroupSpecifier];
    diagGroup.name = @"Diagnóstico";
    [diagGroup setProperty:@"Último registro por SSH: /rootfs/private/var/mobile/Library/Logs/BandLock/BandLock-last.txt" forKey:@"footerText"];
    [items addObject:diagGroup];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Resultado" target:self set:nil get:@selector(detailValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Último registro" target:self set:nil get:@selector(logValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *clear = [PSSpecifier preferenceSpecifierNamed:@"Eliminar registros de BandLock"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    clear.buttonAction = @selector(clearLogs);
    [items addObject:clear];

    PSSpecifier *infoGroup = [PSSpecifier emptyGroupSpecifier];
    infoGroup.name = @"Información";
    [items addObject:infoGroup];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:@"Versión" target:self set:nil get:@selector(versionValue) detail:nil cell:PSTitleValueCell edit:nil]];

    _specifiers = items;
    return _specifiers;
}

- (NSString *)statusValue { return _blStatus ?: @"Sin consultar"; }
- (NSString *)ratValue { return _blRAT ?: @"—"; }
- (NSString *)servingBandValue { return _blServingBand ?: @"—"; }
- (NSString *)supportedLTEValue { return BLBandList(_blSupportedLTE); }
- (NSString *)activeLTEValue { return BLBandList(_blActiveLTE); }
- (NSString *)detailValue { return _blDetail ?: @"—"; }
- (NSString *)logValue { return _blLogStatus ?: @"Sin registros"; }
- (NSString *)versionValue { return @"0.4.3"; }
- (NSString *)networkModeStatusValue {
    return _blConfiguredRATMode ?: @"Sin consultar";
}

- (void)selectAutomaticNetworkMode {
    [self applyNetworkModeSelection:BLRATAutomatic
                          preferred:BLRATAutomatic
                              label:@"Automático"
                         stateValue:@"automatic"];
}

- (void)confirmLTENetworkMode {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Solo LTE / 4G"
        message:@"El módem no podrá bajar a 3G o EDGE mientras este modo esté activo. Si no hay LTE disponible, puedes quedarte temporalmente sin servicio. Las llamadas también pueden verse afectadas si VoLTE no está disponible."
        preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Activar"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(__unused UIAlertAction *action) {
        [weakSelf applyNetworkModeSelection:BLRATLTE
                                  preferred:BLRATLTE
                                      label:@"Solo LTE / 4G"
                                 stateValue:@"lte"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}



- (NSString *)pendingSelectionValue {
    NSArray *bands = [[_blSelectedLTE allObjects] sortedArrayUsingSelector:@selector(compare:)];
    return bands.count ? BLBandList(bands) : @"Ninguna";
}

- (NSString *)modeValue {
    if (!_blHasRead) return @"Sin consultar";
    NSSet *allSupported = [NSSet setWithArray:_blAllSupportedLTE ?: @[]];
    NSSet *allActive = [NSSet setWithArray:_blAllActiveLTE ?: @[]];
    if (allSupported.count && [allSupported isEqualToSet:allActive]) return @"Automático";

    NSSet *spainSupported = [NSSet setWithArray:_blSupportedLTE ?: @[]];
    NSSet *spainActive = [NSSet setWithArray:_blActiveLTE ?: @[]];
    if (spainSupported.count && [spainSupported isEqualToSet:spainActive] &&
        _blAllActiveLTE.count == _blActiveLTE.count) return @"España completa";

    return _blActiveLTE.count ? BLBandList(_blActiveLTE) : @"Personalizado";
}

- (id)bandSwitchValue:(PSSpecifier *)specifier {
    NSNumber *band = [specifier propertyForKey:@"band"];
    return @([_blSelectedLTE containsObject:band]);
}

- (void)setBandSwitchValue:(id)value specifier:(PSSpecifier *)specifier {
    NSNumber *band = [specifier propertyForKey:@"band"];
    if (!band) return;
    if ([value boolValue]) [_blSelectedLTE addObject:band];
    else [_blSelectedLTE removeObject:band];
}

- (void)rebuildUI {
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSDictionary *)readRatSelectionFromClient:(id)client context:(id)context {
    SEL selector = NSSelectorFromString(@"getRatSelection:completion:");
    if (![client respondsToSelector:selector]) {
        return @{@"selection": @"—", @"preferred": @"—", @"error": @"getRatSelection:completion: no disponible"};
    }

    __block NSString *selection = nil;
    __block NSString *preferred = nil;
    __block NSError *callbackError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    BLMsgGetRatSelection(client, selector, context, ^(NSString *currentSelection, NSString *preferredSelection, NSError *error) {
        selection = [currentSelection copy];
        preferred = [preferredSelection copy];
        callbackError = error;
        dispatch_semaphore_signal(semaphore);
    });

    long wait = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    if (wait != 0) {
        return @{@"selection": @"—", @"preferred": @"—", @"error": @"timeout"};
    }

    return @{
        @"selection": selection ?: @"—",
        @"preferred": preferred ?: @"—",
        @"error": callbackError ? [callbackError description] : @""
    };
}

- (id)copyCellInfoFromClient:(id)client context:(id)context {
    SEL selector = NSSelectorFromString(@"copyCellInfo:completion:");
    if (![client respondsToSelector:selector]) return nil;

    __block id result = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    BLMsgObjBlock(client, selector, context, ^(id info, NSError *error) {
        if (!error && info) result = info;
        dispatch_semaphore_signal(semaphore);
    });

    long wait = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)));
    return wait == 0 ? result : nil;
}

- (NSDictionary *)queryCoreTelephony {
    void *handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        const char *err = dlerror();
        return @{@"error": err ? [NSString stringWithUTF8String:err] : @"No se pudo cargar CoreTelephony."};
    }

    id ratRaw = nil;
    Class networkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    if (networkInfoClass) {
        id networkInfo = [[networkInfoClass alloc] init];
        SEL ratSelector = NSSelectorFromString(@"serviceCurrentRadioAccessTechnology");
        if ([networkInfo respondsToSelector:ratSelector]) ratRaw = BLMsg0(networkInfo, ratSelector);
    }

    Class clientClass = NSClassFromString(@"CoreTelephonyClient");
    if (!clientClass) return @{@"error": @"CoreTelephonyClient no está disponible."};
    id client = [[clientClass alloc] init];
    if (!client) return @{@"error": @"No se pudo crear CoreTelephonyClient."};

    NSError *contextError = nil;
    id context = nil;
    SEL currentSelector = NSSelectorFromString(@"getCurrentDataSubscriptionContextSync:");
    if ([client respondsToSelector:currentSelector]) context = BLMsgErr(client, currentSelector, &contextError);

    if (!context) {
        contextError = nil;
        SEL preferredSelector = NSSelectorFromString(@"getPreferredDataSubscriptionContextSync:");
        if ([client respondsToSelector:preferredSelector]) context = BLMsgErr(client, preferredSelector, &contextError);
    }
    if (!context) return @{@"error": contextError ? [contextError description] : @"No hay contexto de datos activo/preferido."};

    SEL bandSelector = NSSelectorFromString(@"getBandInfo:error:");
    if (![client respondsToSelector:bandSelector]) return @{@"error": @"getBandInfo:error: no está disponible."};

    NSError *bandError = nil;
    id bandInfo = BLMsgObjErr(client, bandSelector, context, &bandError);
    if (!bandInfo) return @{@"error": bandError ? [bandError description] : @"getBandInfo:error: devolvió nil."};

    id cellInfo = [self copyCellInfoFromClient:client context:context];
    NSDictionary *ratSelectionInfo = [self readRatSelectionFromClient:client context:context];

    return @{
        @"client": client,
        @"context": context,
        @"bandInfo": bandInfo,
        @"ratRaw": ratRaw ?: [NSNull null],
        @"cellInfo": cellInfo ?: [NSNull null],
        @"ratSelection": ratSelectionInfo[@"selection"] ?: @"—",
        @"ratPreferred": ratSelectionInfo[@"preferred"] ?: @"—",
        @"ratSelectionError": ratSelectionInfo[@"error"] ?: @""
    };
}

- (void)consumeQuery:(NSDictionary *)query resetSelection:(BOOL)resetSelection {
    id bandInfo = query[@"bandInfo"];
    id ratRaw = query[@"ratRaw"];
    id cellInfo = query[@"cellInfo"];
    if (ratRaw == [NSNull null]) ratRaw = nil;
    if (cellInfo == [NSNull null]) cellInfo = nil;

    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    NSDictionary *supported = [bandInfo respondsToSelector:supportedSelector] ? BLMsg0(bandInfo, supportedSelector) : nil;
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;

    _blAllSupportedLTE = BLSortedBands(supported[BLLTERAT]);
    _blAllActiveLTE = BLSortedBands(active[BLLTERAT]);
    _blSupportedLTE = BLIntersectBands(_blAllSupportedLTE, BLSpainBands());
    _blActiveLTE = BLIntersectBands(_blAllActiveLTE, BLSpainBands());

    if (resetSelection || !_blSelectedLTE) {
        _blSelectedLTE = [NSMutableSet setWithArray:_blActiveLTE];
    }

    _blRAT = BLHumanRAT(ratRaw);
    _blServingBand = BLServingBandFromCellInfo(cellInfo);
    _blRatSelectionRaw = [query[@"ratSelection"] isKindOfClass:[NSString class]] ? query[@"ratSelection"] : @"—";
    _blRatPreferredRaw = [query[@"ratPreferred"] isKindOfClass:[NSString class]] ? query[@"ratPreferred"] : @"—";

    if ([_blRatSelectionRaw rangeOfString:@"Automatic" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        _blConfiguredRATMode = @"Automático";
    } else if ([_blRatSelectionRaw rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        _blConfiguredRATMode = @"Solo LTE / 4G";
    } else if (![_blRatSelectionRaw isEqualToString:@"—"]) {
        _blConfiguredRATMode = _blRatSelectionRaw;
    } else {
        _blConfiguredRATMode = @"No disponible";
    }
    _blHasRead = YES;

    NSArray *pending = [[_blSelectedLTE allObjects] sortedArrayUsingSelector:@selector(compare:)];
    BLWriteState(@{
        @"supportedSpain": _blSupportedLTE ?: @[],
        @"activeSpain": _blActiveLTE ?: @[],
        @"allSupportedLTE": _blAllSupportedLTE ?: @[],
        @"allActiveLTE": _blAllActiveLTE ?: @[],
        @"pendingLTE": pending ?: @[],
        @"ratSelectionRaw": _blRatSelectionRaw ?: @"—",
        @"ratPreferredRaw": _blRatPreferredRaw ?: @"—"
    });
}

- (void)savePreviousLTE:(NSArray<NSNumber *> *)bands {
    NSArray *clean = BLSortedBands(bands);
    if (!clean.count) return;
    _blPreviousLTE = clean;
    BLWriteState(@{@"previousLTE": clean});
}

- (NSString *)writeLogForAction:(NSString *)action
                          query:(NSDictionary *)query
                   requestedLTE:(NSArray<NSNumber *> *)requestedLTE
                          error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *dirError = nil;
    if (![fm createDirectoryAtPath:BLLogDirectory withIntermediateDirectories:YES attributes:nil error:&dirError]) {
        if (error) *error = dirError;
        return nil;
    }

    id bandInfo = query[@"bandInfo"];
    id ratRaw = query[@"ratRaw"];
    if (ratRaw == [NSNull null]) ratRaw = nil;

    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    id supported = [bandInfo respondsToSelector:supportedSelector] ? BLMsg0(bandInfo, supportedSelector) : nil;
    id active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;

    NSDate *now = [NSDate date];
    NSDateFormatter *fileFormatter = [[NSDateFormatter alloc] init];
    fileFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    fileFormatter.dateFormat = @"yyyyMMdd-HHmmss-SSS";

    NSDateFormatter *displayFormatter = [[NSDateFormatter alloc] init];
    displayFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    displayFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";

    NSString *path = [BLLogDirectory stringByAppendingPathComponent:
        [NSString stringWithFormat:@"BandLock-%@.txt", [fileFormatter stringFromDate:now]]];

    NSString *content = [NSString stringWithFormat:
        @"BandLock-Version: 0.4.3\n"
         "Timestamp: %@\n"
         "Action: %@\n"
         "Status: %@\n"
         "RAT-UI: %@\n"
         "RAT-Raw: %@\n"
         "RAT-Selection: %@\n"
         "RAT-Preferred: %@\n"
         "Serving-Band: %@\n"
         "SubscriptionContext: acquired (details redacted)\n"
         "Requested-LTE: %@\n"
         "Previous-LTE: %@\n"
         "Supported-LTE: %@\n"
         "Active-LTE: %@\n"
         "SupportedBands: %@\n"
         "ActiveBands: %@\n"
         "Diagnostic: %@\n",
         [displayFormatter stringFromDate:now],
         action ?: @"—",
         _blStatus ?: @"—",
         _blRAT ?: @"—",
         BLCompactDescription(ratRaw),
         _blRatSelectionRaw ?: @"—",
         _blRatPreferredRaw ?: @"—",
         _blServingBand ?: @"—",
         requestedLTE ? BLBandList(requestedLTE) : @"—",
         BLBandList(_blPreviousLTE),
         BLBandList(_blSupportedLTE),
         BLBandList(_blActiveLTE),
         BLCompactDescription(supported),
         BLCompactDescription(active),
         _blDetail ?: @"—"];

    NSError *writeError = nil;
    if (![content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        if (error) *error = writeError;
        return nil;
    }
    if (![content writeToFile:BLLastLogPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        if (error) *error = writeError;
        return path;
    }
    return path;
}

- (void)updateLogForAction:(NSString *)action query:(NSDictionary *)query requestedLTE:(NSArray<NSNumber *> *)requestedLTE {
    NSError *error = nil;
    NSString *path = [self writeLogForAction:action query:query requestedLTE:requestedLTE error:&error];
    _blLogStatus = path ? BLSSHLastLogPath : [NSString stringWithFormat:@"Error al guardar: %@", error.localizedDescription ?: @"desconocido"];
}

- (void)applyNetworkModeSelection:(NSString *)selection preferred:(NSString *)preferred label:(NSString *)label stateValue:(NSString *)stateValue {
    _blStatus = @"Cambiando modo de red…";
    _blDetail = [NSString stringWithFormat:@"Solicitando %@", label];
    [self rebuildUI];

    @try {
        NSDictionary *query = [self queryCoreTelephony];
        NSString *queryError = query[@"error"];
        if (queryError) {
            _blStatus = @"No se pudo cambiar";
            _blDetail = queryError;
            [self rebuildUI];
            return;
        }

        id client = query[@"client"];
        id context = query[@"context"];
        SEL setter = NSSelectorFromString(@"setRatSelection:selection:preferred:completion:");
        if (![client respondsToSelector:setter]) {
            _blStatus = @"No compatible";
            _blDetail = @"CoreTelephonyClient no implementa setRatSelection:selection:preferred:completion:.";
            [self rebuildUI];
            return;
        }

        __weak typeof(self) weakSelf = self;
        BLMsgSetRatSelection(client, setter, context, selection, preferred, ^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                if (error) {
                    self->_blStatus = @"Cambio RAT rechazado";
                    self->_blDetail = [error description];
                    [self rebuildUI];
                    return;
                }

                BLWriteState(@{@"networkModeRequested": stateValue ?: @"automatic"});

                NSDictionary *verify = [self queryCoreTelephony];
                NSString *verifyError = verify[@"error"];
                if (verifyError) {
                    self->_blStatus = @"Aplicado; verificación fallida";
                    self->_blDetail = verifyError;
                    [self rebuildUI];
                    return;
                }

                [self consumeQuery:verify resetSelection:NO];

                BOOL matches = NO;
                if ([stateValue isEqualToString:@"lte"]) {
                    matches = [self->_blRatSelectionRaw rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound &&
                              [self->_blRatSelectionRaw rangeOfString:@"Automatic" options:NSCaseInsensitiveSearch].location == NSNotFound;
                } else {
                    matches = [self->_blRatSelectionRaw rangeOfString:@"Automatic" options:NSCaseInsensitiveSearch].location != NSNotFound;
                }

                self->_blStatus = matches ? @"Modo de red verificado" : @"Modo aplicado";
                self->_blDetail = matches
                    ? [NSString stringWithFormat:@"Configuración RAT: %@", label]
                    : [NSString stringWithFormat:@"Solicitado %@. Lectura: %@", label, self->_blRatSelectionRaw ?: @"—"];

                [self updateLogForAction:[NSString stringWithFormat:@"Modo de red: %@", label]
                                   query:verify
                            requestedLTE:nil];
                [self rebuildUI];
            });
        });
    }
    @catch (NSException *exception) {
        _blStatus = @"Excepción";
        _blDetail = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: @"sin detalle"];
        [self rebuildUI];
    }
}

- (void)reloadBands {
    _blStatus = @"Consultando…";
    _blDetail = @"Leyendo CoreTelephony…";
    [self rebuildUI];

    @try {
        NSDictionary *query = [self queryCoreTelephony];
        NSString *errorText = query[@"error"];
        if (errorText) {
            _blStatus = @"Lectura fallida";
            _blDetail = errorText;
            [self rebuildUI];
            return;
        }

        [self consumeQuery:query resetSelection:YES];
        _blStatus = @"Lectura correcta";
        _blDetail = @"Bandas LTE leídas. Los interruptores reflejan las bandas permitidas actuales.";
        [self updateLogForAction:@"Lectura" query:query requestedLTE:nil];
    }
    @catch (NSException *exception) {
        _blStatus = @"Excepción";
        _blDetail = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: @"sin detalle"];
    }

    [self rebuildUI];
}

- (void)selectOrangeSpain {
    if (!_blHasRead) return;
    _blSelectedLTE = [NSMutableSet setWithArray:_blSupportedLTE];
    _blStatus = @"Perfil preparado";
    _blDetail = [NSString stringWithFormat:@"Orange España: %@. Pulsa «Aplicar selección LTE».", BLBandList(_blSupportedLTE)];
    [self rebuildUI];
}

- (void)selectCoverageBands {
    if (!_blHasRead) return;
    NSArray *available = BLIntersectBands(_blSupportedLTE, @[@28, @20, @8]);
    _blSelectedLTE = [NSMutableSet setWithArray:available];
    _blStatus = @"Perfil preparado";
    _blDetail = [NSString stringWithFormat:@"Cobertura: %@.", BLBandList(available)];
    [self rebuildUI];
}

- (void)selectCapacityBands {
    if (!_blHasRead) return;
    NSArray *available = BLIntersectBands(_blSupportedLTE, @[@3, @1, @7]);
    _blSelectedLTE = [NSMutableSet setWithArray:available];
    _blStatus = @"Perfil preparado";
    _blDetail = [NSString stringWithFormat:@"Capacidad: %@.", BLBandList(available)];
    [self rebuildUI];
}

- (void)selectB3B7 {
    if (!_blHasRead) return;
    NSArray *available = BLIntersectBands(_blSupportedLTE, @[@3, @7]);
    _blSelectedLTE = [NSMutableSet setWithArray:available];
    _blStatus = @"Perfil preparado";
    _blDetail = [NSString stringWithFormat:@"B3 + B7: %@.", BLBandList(available)];
    [self rebuildUI];
}

- (void)selectAllBands {
    if (!_blHasRead) return;
    _blSelectedLTE = [NSMutableSet setWithArray:_blSupportedLTE];
    _blStatus = @"Selección preparada";
    _blDetail = @"Todas las bandas LTE soportadas están seleccionadas.";
    [self rebuildUI];
}

- (void)deselectAllBands {
    if (!_blHasRead) return;
    [_blSelectedLTE removeAllObjects];
    _blStatus = @"Selección preparada";
    _blDetail = @"Todas las bandas están desmarcadas. No podrás aplicar hasta seleccionar al menos una.";
    [self rebuildUI];
}

- (void)confirmApplySelection {
    if (!_blHasRead) {
        _blStatus = @"Lee las bandas primero";
        _blDetail = @"Pulsa «Actualizar estado» antes de aplicar una selección.";
        [self rebuildUI];
        return;
    }

    NSArray<NSNumber *> *bands = [[_blSelectedLTE allObjects] sortedArrayUsingSelector:@selector(compare:)];
    if (!bands.count) {
        _blStatus = @"Selección no válida";
        _blDetail = @"Debes mantener al menos una banda LTE seleccionada.";
        [self rebuildUI];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"Se permitirán únicamente estas bandas LTE:\n\n%@\n\nSe guardará la selección actual para poder restaurarla.", BLBandList(bands)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Aplicar selección LTE" message:message preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aplicar" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf applyLTEBands:bands action:@"Aplicar selección" savePrevious:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)restorePreviousLTE {
    if (!_blPreviousLTE.count) {
        _blStatus = @"Sin selección anterior";
        _blDetail = @"Todavía no hay una selección anterior guardada.";
        [self rebuildUI];
        return;
    }
    [self applyLTEBands:_blPreviousLTE action:@"Restaurar selección anterior" savePrevious:NO];
}

- (void)restoreAllLTE {
    if (!_blHasRead || !_blAllSupportedLTE.count) {
        _blStatus = @"Lee las bandas primero";
        _blDetail = @"No hay una lista LTE soportada disponible.";
        [self rebuildUI];
        return;
    }
    [self applyLTEBands:_blAllSupportedLTE action:@"Restaurar modo automático" savePrevious:YES];
}

- (void)applyLTEBands:(NSArray<NSNumber *> *)requested action:(NSString *)action savePrevious:(BOOL)savePrevious {
    NSArray<NSNumber *> *bands = BLSortedBands(requested);
    if (!bands.count) {
        _blStatus = @"Selección no válida";
        _blDetail = @"No se puede aplicar una lista LTE vacía.";
        [self rebuildUI];
        return;
    }

    NSSet *supportedSet = [NSSet setWithArray:_blAllSupportedLTE.count ? _blAllSupportedLTE : _blSupportedLTE];
    for (NSNumber *band in bands) {
        if (![supportedSet containsObject:band]) {
            _blStatus = @"Selección no válida";
            _blDetail = [NSString stringWithFormat:@"B%@ no figura entre las bandas LTE soportadas.", band];
            [self rebuildUI];
            return;
        }
    }

    _blStatus = @"Aplicando…";
    _blDetail = BLBandList(bands);
    [self rebuildUI];

    @try {
        NSDictionary *query = [self queryCoreTelephony];
        NSString *queryError = query[@"error"];
        if (queryError) {
            _blStatus = @"No se pudo aplicar";
            _blDetail = queryError;
            [self rebuildUI];
            return;
        }

        id client = query[@"client"];
        id context = query[@"context"];
        id currentBandInfo = query[@"bandInfo"];

        SEL activeSelector = NSSelectorFromString(@"activeBands");
        SEL supportedSelector = NSSelectorFromString(@"supportedBands");
        NSDictionary *currentActive = [currentBandInfo respondsToSelector:activeSelector] ? BLMsg0(currentBandInfo, activeSelector) : nil;
        NSDictionary *currentSupported = [currentBandInfo respondsToSelector:supportedSelector] ? BLMsg0(currentBandInfo, supportedSelector) : nil;

        if (![currentActive isKindOfClass:[NSDictionary class]]) {
            _blStatus = @"No se pudo aplicar";
            _blDetail = @"CTBandInfo no devolvió ActiveBands en el formato esperado.";
            [self rebuildUI];
            return;
        }

        NSArray *currentLTE = BLSortedBands(currentActive[BLLTERAT]);
        if (savePrevious && currentLTE.count) [self savePreviousLTE:currentLTE];

        NSMutableDictionary *newActive = [currentActive mutableCopy];
        newActive[BLLTERAT] = bands;

        id modifiedBandInfo = [currentBandInfo copy];
        SEL setActiveDictionary = NSSelectorFromString(@"setFActiveBands:");
        if (modifiedBandInfo && [modifiedBandInfo respondsToSelector:setActiveDictionary]) {
            BLMsgSetObj(modifiedBandInfo, setActiveDictionary, newActive);
        } else {
            Class bandInfoClass = NSClassFromString(@"CTBandInfo");
            SEL initSelector = NSSelectorFromString(@"initWithSupported:andActiveBands:");
            id allocated = bandInfoClass ? [bandInfoClass alloc] : nil;
            if (allocated && [allocated respondsToSelector:initSelector]) {
                modifiedBandInfo = BLMsg2(allocated, initSelector, currentSupported, newActive);
            }
        }

        if (!modifiedBandInfo) {
            _blStatus = @"No se pudo aplicar";
            _blDetail = @"No se pudo construir CTBandInfo para la nueva selección.";
            [self rebuildUI];
            return;
        }

        SEL setter = NSSelectorFromString(@"setActiveBandInfo:bands:error:");
        if (![client respondsToSelector:setter]) {
            _blStatus = @"No compatible";
            _blDetail = @"CoreTelephonyClient no implementa setActiveBandInfo:bands:error:.";
            [self rebuildUI];
            return;
        }

        NSError *setError = nil;
        BLMsgSetActiveBandInfo(client, setter, context, modifiedBandInfo, &setError);
        if (setError) {
            _blStatus = @"Escritura rechazada";
            _blDetail = [setError description];
            [self rebuildUI];
            return;
        }

        NSDictionary *verify = [self queryCoreTelephony];
        NSString *verifyError = verify[@"error"];
        if (verifyError) {
            _blStatus = @"Escrito, verificación fallida";
            _blDetail = verifyError;
            [self rebuildUI];
            return;
        }

        [self consumeQuery:verify resetSelection:YES];
        NSSet *requestedSet = [NSSet setWithArray:bands];
        NSSet *readbackSet = [NSSet setWithArray:_blActiveLTE];

        if ([requestedSet isEqualToSet:readbackSet]) {
            _blStatus = @"Aplicado y verificado";
            _blDetail = [NSString stringWithFormat:@"El módem informa ahora: %@", BLBandList(_blActiveLTE)];
        } else {
            _blStatus = @"Resultado distinto";
            _blDetail = [NSString stringWithFormat:@"Solicitado: %@ | Leído: %@", BLBandList(bands), BLBandList(_blActiveLTE)];
        }

        [self updateLogForAction:action query:verify requestedLTE:bands];
    }
    @catch (NSException *exception) {
        _blStatus = @"Excepción";
        _blDetail = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: @"sin detalle"];
    }

    [self rebuildUI];
}

- (void)openFieldTestMode {
    NSString *bundleID = @"com.apple.FTMInternal";
    __block BOOL attempted = NO;

    @try {
        void *fbs = dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW | RTLD_LOCAL);
        if (fbs) {
            Class serviceClass = NSClassFromString(@"FBSSystemService");
            SEL sharedSelector = NSSelectorFromString(@"sharedService");
            SEL openSelector = NSSelectorFromString(@"openApplication:options:withResult:");
            if (serviceClass && [serviceClass respondsToSelector:sharedSelector]) {
                id service = BLMsg0((id)serviceClass, sharedSelector);
                if (service && [service respondsToSelector:openSelector]) {
                    attempted = YES;
                    void (^resultBlock)(NSError *) = ^(NSError *error) {
                        if (error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle:@"FTMInternal-4"
                                    message:[NSString stringWithFormat:@"FrontBoard rechazó el lanzamiento: %@", error.localizedDescription ?: [error description]]
                                    preferredStyle:UIAlertControllerStyleAlert];
                                [alert addAction:[UIAlertAction actionWithTitle:@"Aceptar" style:UIAlertActionStyleDefault handler:nil]];
                                [self presentViewController:alert animated:YES completion:nil];
                            });
                        }
                    };
                    ((void (*)(id, SEL, id, id, id))objc_msgSend)(service, openSelector, bundleID, @{}, resultBlock);
                    return;
                }
            }
        }
    } @catch (__unused NSException *exception) {}

    @try {
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_NOW | RTLD_LOCAL);
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!workspaceClass) {
            dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_NOW | RTLD_LOCAL);
            workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        }
        SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
        SEL openSelector = NSSelectorFromString(@"openApplicationWithBundleID:");
        if (workspaceClass && [workspaceClass respondsToSelector:defaultSelector]) {
            id workspace = BLMsg0((id)workspaceClass, defaultSelector);
            if (workspace && [workspace respondsToSelector:openSelector]) {
                attempted = YES;
                if (BLMsgBoolObj(workspace, openSelector, bundleID)) return;
            }
        }
    } @catch (__unused NSException *exception) {}

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"FTMInternal-4"
        message:(attempted ? @"iOS rechazó el lanzamiento directo de com.apple.FTMInternal." : @"No se encontró una API disponible para lanzar com.apple.FTMInternal.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aceptar" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearLogs {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Eliminar registros"
        message:@"Se eliminarán únicamente los registros creados por BandLock."
        preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Eliminar" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf clearLogsConfirmed];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearLogsConfirmed {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fm fileExistsAtPath:BLLogDirectory] && ![fm removeItemAtPath:BLLogDirectory error:&error]) {
        _blLogStatus = [NSString stringWithFormat:@"Error al eliminar: %@", error.localizedDescription ?: @"desconocido"];
    } else {
        _blLogStatus = @"Registros eliminados";
    }
    [self rebuildUI];
}

@end
