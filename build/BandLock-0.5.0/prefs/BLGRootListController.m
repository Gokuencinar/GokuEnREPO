#import "BLGRootListController.h"
#import "BLGBandMetadata.h"
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLRATAutomatic = @"kCTRegistrationRATSelectionAutomatic";
static NSString * const BLRATLTE = @"kCTRegistrationRATSelectionLTE";
static NSString * const BLLogDirectory = @"/var/mobile/Library/Logs/BandLockGlobal";
static NSString * const BLLastLogPath = @"/var/mobile/Library/Logs/BandLockGlobal/BandLock-last.txt";
static NSString * const BLSSHLastLogPath = @"/rootfs/private/var/mobile/Library/Logs/BandLockGlobal/BandLock-last.txt";
static NSString * const BLStatePath = @"/var/mobile/Library/Preferences/com.gokuencinar.bandlock.state.plist";

static BOOL BLGUsesSpanish(void) {
    NSString *language = NSLocale.preferredLanguages.firstObject.lowercaseString ?: @"";
    return [language hasPrefix:@"es"];
}

static NSString *BLGT(NSString *es, NSString *en) {
    return BLGUsesSpanish() ? es : en;
}

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
    return BLGBandTitle(band);
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
    if (!cellInfo) return BLGT(@"No disponible", @"Unavailable");
    SEL legacySelector = NSSelectorFromString(@"legacyInfo");
    if (![cellInfo respondsToSelector:legacySelector]) return BLGT(@"No disponible", @"Unavailable");

    id legacy = BLMsg0(cellInfo, legacySelector);
    if (![legacy isKindOfClass:[NSArray class]] || ![(NSArray *)legacy count]) return BLGT(@"No disponible", @"Unavailable");

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
    if (!row) return BLGT(@"No disponible", @"Unavailable");

    id band = row[@"kCTCellMonitorBandInfo"];
    if (![band respondsToSelector:@selector(integerValue)] || [band integerValue] <= 0) return BLGT(@"No disponible", @"Unavailable");

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

@interface BLGRootListController () {
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
- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText;
- (NSArray<NSNumber *> *)allActiveLTEFromQuery:(NSDictionary *)query;
- (void)verifyLTEBands:(NSArray<NSNumber *> *)bands action:(NSString *)action retryCount:(NSInteger)retryCount;
- (void)savePreviousLTE:(NSArray<NSNumber *> *)bands;
- (void)clearLogsConfirmed;
- (NSDictionary *)readRatSelectionFromClient:(id)client context:(id)context;
- (void)applyNetworkModeSelection:(NSString *)selection preferred:(NSString *)preferred label:(NSString *)label stateValue:(NSString *)stateValue;
@end

@implementation BLGRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"BandLock";

    if (!_blStatus) {
        _blStatus = BLGT(@"Sin consultar", @"Not queried");
        _blRAT = @"—";
        _blServingBand = @"—";
        _blDetail = BLGT(@"Pulsa «Actualizar estado» para leer la configuración del módem.", @"Tap “Refresh status” to read the modem configuration.");
        _blLogStatus = [[NSFileManager defaultManager] fileExistsAtPath:BLLastLogPath] ? BLSSHLastLogPath : BLGT(@"Sin registros", @"No logs");
        _blConfiguredRATMode = BLGT(@"Sin consultar", @"Not queried");
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
            subtitle.text = @"Global · LTE / 4G";
            subtitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            subtitle.textColor = UIColor.secondaryLabelColor;
            [card addSubview:subtitle];

            UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 73, width - 68, 18)];
            caption.text = BLGT(@"Control LTE manual · estado verificado por el módem", @"Manual LTE control · modem-verified state");
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
    connectionGroup.name = BLGT(@"Estado de red", @"Network status");
    [connectionGroup setProperty:BLGT(@"La lectura es manual. «Banda conectada» intenta identificar la celda servidora; «Bandas permitidas» muestra el bloqueo LTE actual.", @"Status is read on demand. “Serving band” attempts to identify the serving cell; “Allowed bands” shows the current LTE restriction.") forKey:@"footerText"];
    [items addObject:connectionGroup];

    PSSpecifier *readButton = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Actualizar estado", @"Refresh status")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    readButton.buttonAction = @selector(reloadBands);
    [readButton setProperty:@YES forKey:@"enabled"];
    [items addObject:readButton];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Estado", @"Status") target:self set:nil get:@selector(statusValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Red actual", @"Current network") target:self set:nil get:@selector(ratValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Banda conectada", @"Serving band") target:self set:nil get:@selector(servingBandValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Modo LTE", @"LTE mode") target:self set:nil get:@selector(modeValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Bandas permitidas", @"Allowed bands") target:self set:nil get:@selector(activeLTEValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *networkGroup = [PSSpecifier emptyGroupSpecifier];
    networkGroup.name = BLGT(@"Modo de red", @"Network mode");
    [networkGroup setProperty:BLGT(@"Pulsa directamente el modo que quieras usar. Automático mantiene el comportamiento normal de iOS; Solo LTE / 4G evita el fallback a 3G/EDGE mientras esté activo.", @"Choose the network mode directly. Automatic keeps normal iOS behavior; LTE / 4G only prevents fallback to 3G/EDGE while enabled.") forKey:@"footerText"];
    [items addObject:networkGroup];

    BOOL ratIsLTE = [_blConfiguredRATMode isEqualToString:BLGT(@"Solo LTE / 4G", @"LTE / 4G only")];
    BOOL ratIsAutomatic = [_blConfiguredRATMode isEqualToString:BLGT(@"Automático", @"Automatic")];

    PSSpecifier *automaticMode = [PSSpecifier preferenceSpecifierNamed:(ratIsAutomatic ? BLGT(@"✓ Automático", @"✓ Automatic") : BLGT(@"Automático", @"Automatic"))
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    automaticMode.buttonAction = @selector(selectAutomaticNetworkMode);
    [automaticMode setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:automaticMode];

    PSSpecifier *lteMode = [PSSpecifier preferenceSpecifierNamed:(ratIsLTE ? BLGT(@"✓ Solo LTE / 4G", @"✓ LTE / 4G only") : BLGT(@"Solo LTE / 4G", @"LTE / 4G only"))
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    lteMode.buttonAction = @selector(confirmLTENetworkMode);
    [lteMode setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:lteMode];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Configuración RAT", @"RAT configuration")
        target:self set:nil get:@selector(networkModeStatusValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *controlGroup = [PSSpecifier emptyGroupSpecifier];
    controlGroup.name = BLGT(@"Control LTE", @"LTE control");
    [controlGroup setProperty:BLGT(@"La selección se genera con todas las bandas LTE que reporta el módem de este iPhone. No se aplica ningún filtro por país u operador.", @"The selector is generated from every LTE band reported by this iPhone modem. No country or carrier filter is applied.") forKey:@"footerText"];
    [items addObject:controlGroup];

    Class selectionClass = NSClassFromString(@"BLGBandSelectionController");
    PSSpecifier *selection = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Seleccionar bandas", @"Select bands")
        target:self set:nil get:nil detail:selectionClass cell:PSLinkCell edit:nil];
    [selection setProperty:@(_blHasRead && selectionClass != Nil) forKey:@"enabled"];
    [selection setProperty:@"antenna.radiowaves.left.and.right" forKey:@"iconImageSystem"];
    [items addObject:selection];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Selección pendiente", @"Pending selection") target:self set:nil get:@selector(pendingSelectionValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *apply = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Aplicar selección LTE", @"Apply LTE selection")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    apply.buttonAction = @selector(confirmApplySelection);
    [apply setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:apply];

    PSSpecifier *previous = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Restaurar selección anterior", @"Restore previous selection")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    previous.buttonAction = @selector(restorePreviousLTE);
    [previous setProperty:@(_blHasRead && _blPreviousLTE.count > 0) forKey:@"enabled"];
    [items addObject:previous];

    PSSpecifier *automatic = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Restaurar modo automático", @"Restore automatic mode")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    automatic.buttonAction = @selector(restoreAllLTE);
    [automatic setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:automatic];

    PSSpecifier *toolsGroup = [PSSpecifier emptyGroupSpecifier];
    toolsGroup.name = BLGT(@"Herramientas", @"Tools");
    [toolsGroup setProperty:BLGT(@"FTMInternal-4 es la aplicación interna de Apple utilizada para Field Test Mode.", @"FTMInternal-4 is Apple's internal Field Test Mode application.") forKey:@"footerText"];
    [items addObject:toolsGroup];

    PSSpecifier *fieldTest = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Abrir FTMInternal-4", @"Open FTMInternal-4")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    fieldTest.buttonAction = @selector(openFieldTestMode);
    [fieldTest setProperty:@YES forKey:@"enabled"];
    [items addObject:fieldTest];

    PSSpecifier *diagGroup = [PSSpecifier emptyGroupSpecifier];
    diagGroup.name = BLGT(@"Diagnóstico", @"Diagnostics");
    [diagGroup setProperty:@"Último registro por SSH: /rootfs/private/var/mobile/Library/Logs/BandLockGlobal/BandLock-last.txt" forKey:@"footerText"];
    [items addObject:diagGroup];

    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Resultado", @"Result") target:self set:nil get:@selector(detailValue) detail:nil cell:PSTitleValueCell edit:nil]];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Último registro", @"Latest log") target:self set:nil get:@selector(logValue) detail:nil cell:PSTitleValueCell edit:nil]];

    PSSpecifier *clear = [PSSpecifier preferenceSpecifierNamed:BLGT(@"Eliminar registros de BandLock", @"Delete BandLock logs")
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    clear.buttonAction = @selector(clearLogs);
    [items addObject:clear];

    PSSpecifier *infoGroup = [PSSpecifier emptyGroupSpecifier];
    infoGroup.name = BLGT(@"Información", @"Information");
    [items addObject:infoGroup];
    [items addObject:[PSSpecifier preferenceSpecifierNamed:BLGT(@"Versión", @"Version") target:self set:nil get:@selector(versionValue) detail:nil cell:PSTitleValueCell edit:nil]];

    _specifiers = items;
    return _specifiers;
}

- (NSString *)statusValue { return _blStatus ?: BLGT(@"Sin consultar", @"Not queried"); }
- (NSString *)ratValue { return _blRAT ?: @"—"; }
- (NSString *)servingBandValue { return _blServingBand ?: @"—"; }
- (NSString *)supportedLTEValue { return BLBandList(_blSupportedLTE); }
- (NSString *)activeLTEValue { return BLBandList(_blActiveLTE); }
- (NSString *)detailValue { return _blDetail ?: @"—"; }
- (NSString *)logValue { return _blLogStatus ?: BLGT(@"Sin registros", @"No logs"); }
- (NSString *)versionValue { return @"0.5.0 Global"; }
- (NSString *)networkModeStatusValue {
    return _blConfiguredRATMode ?: BLGT(@"Sin consultar", @"Not queried");
}

- (void)selectAutomaticNetworkMode {
    [self applyNetworkModeSelection:BLRATAutomatic
                          preferred:BLRATAutomatic
                          label:BLGT(@"Automático", @"Automatic")
                         stateValue:@"automatic"];
}

- (void)confirmLTENetworkMode {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:BLGT(@"Solo LTE / 4G", @"LTE / 4G only")
        message:BLGT(@"El módem no podrá bajar a 3G o EDGE mientras este modo esté activo. Si no hay LTE disponible, puedes quedarte temporalmente sin servicio. Las llamadas también pueden verse afectadas si VoLTE no está disponible.", @"The modem will not fall back to 3G or EDGE while this mode is active. If LTE is unavailable, you may temporarily lose service. Calls can also be affected when VoLTE is unavailable.")
        preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Cancelar", @"Cancel")
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Activar", @"Enable")
                                             style:UIAlertActionStyleDestructive
                                           handler:^(__unused UIAlertAction *action) {
        [weakSelf applyNetworkModeSelection:BLRATLTE
                                  preferred:BLRATLTE
                                      label:BLGT(@"Solo LTE / 4G", @"LTE / 4G only")
                                 stateValue:@"lte"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}



- (NSString *)pendingSelectionValue {
    NSArray *bands = [[_blSelectedLTE allObjects] sortedArrayUsingSelector:@selector(compare:)];
    return bands.count ? BLBandList(bands) : BLGT(@"Ninguna", @"None");
}

- (NSString *)modeValue {
    if (!_blHasRead) return BLGT(@"Sin consultar", @"Not queried");
    NSSet *allSupported = [NSSet setWithArray:_blAllSupportedLTE ?: @[]];
    NSSet *allActive = [NSSet setWithArray:_blAllActiveLTE ?: @[]];
    if (allSupported.count && [allSupported isEqualToSet:allActive]) return BLGT(@"Automático", @"Automatic");

    return _blActiveLTE.count ? BLBandList(_blActiveLTE) : BLGT(@"Personalizado", @"Custom");
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
    // Global edition: the modem is the source of truth. Never hide a supported
    // LTE band because of a country/operator allow-list.
    _blSupportedLTE = _blAllSupportedLTE;
    _blActiveLTE = _blAllActiveLTE;

    if (resetSelection || !_blSelectedLTE) {
        _blSelectedLTE = [NSMutableSet setWithArray:_blActiveLTE];
    }

    _blRAT = BLHumanRAT(ratRaw);
    _blServingBand = BLServingBandFromCellInfo(cellInfo);
    _blRatSelectionRaw = [query[@"ratSelection"] isKindOfClass:[NSString class]] ? query[@"ratSelection"] : @"—";
    _blRatPreferredRaw = [query[@"ratPreferred"] isKindOfClass:[NSString class]] ? query[@"ratPreferred"] : @"—";

    if ([_blRatSelectionRaw rangeOfString:@"Automatic" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        _blConfiguredRATMode = BLGT(@"Automático", @"Automatic");
    } else if ([_blRatSelectionRaw rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        _blConfiguredRATMode = BLGT(@"Solo LTE / 4G", @"LTE / 4G only");
    } else if (![_blRatSelectionRaw isEqualToString:@"—"]) {
        _blConfiguredRATMode = _blRatSelectionRaw;
    } else {
        _blConfiguredRATMode = BLGT(@"No disponible", @"Unavailable");
    }
    _blHasRead = YES;

    NSArray *pending = [[_blSelectedLTE allObjects] sortedArrayUsingSelector:@selector(compare:)];
    BLWriteState(@{
        @"supportedLTE": _blSupportedLTE ?: @[],
        @"activeLTE": _blActiveLTE ?: @[],
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
        @"BandLock-Version: 0.5.0-global\n"
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
    _blLogStatus = path ? BLSSHLastLogPath : [NSString stringWithFormat:BLGT(@"Error al guardar: %@", @"Save error: %@"), error.localizedDescription ?: BLGT(@"desconocido", @"unknown")];
}

- (void)applyNetworkModeSelection:(NSString *)selection preferred:(NSString *)preferred label:(NSString *)label stateValue:(NSString *)stateValue {
    _blStatus = BLGT(@"Cambiando modo de red…", @"Changing network mode…");
    _blDetail = [NSString stringWithFormat:BLGT(@"Solicitando %@", @"Requesting %@"), label];
    [self rebuildUI];

    @try {
        NSDictionary *query = [self queryCoreTelephony];
        NSString *queryError = query[@"error"];
        if (queryError) {
            _blStatus = BLGT(@"No se pudo cambiar", @"Could not change");
            _blDetail = queryError;
            [self rebuildUI];
            return;
        }

        id client = query[@"client"];
        id context = query[@"context"];
        SEL setter = NSSelectorFromString(@"setRatSelection:selection:preferred:completion:");
        if (![client respondsToSelector:setter]) {
            _blStatus = BLGT(@"No compatible", @"Unsupported");
            _blDetail = BLGT(@"CoreTelephonyClient no implementa setRatSelection:selection:preferred:completion:.", @"CoreTelephonyClient does not implement setRatSelection:selection:preferred:completion:.");
            [self rebuildUI];
            return;
        }

        __weak typeof(self) weakSelf = self;
        BLMsgSetRatSelection(client, setter, context, selection, preferred, ^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;

                if (error) {
                    self->_blStatus = BLGT(@"Cambio RAT rechazado", @"RAT change rejected");
                    self->_blDetail = [error description];
                    [self rebuildUI];
                    return;
                }

                BLWriteState(@{@"networkModeRequested": stateValue ?: @"automatic"});

                NSDictionary *verify = [self queryCoreTelephony];
                NSString *verifyError = verify[@"error"];
                if (verifyError) {
                    self->_blStatus = BLGT(@"Aplicado; verificación fallida", @"Applied; verification failed");
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

                self->_blStatus = matches ? BLGT(@"Modo de red verificado", @"Network mode verified") : BLGT(@"Modo aplicado", @"Mode applied");
                self->_blDetail = matches
                    ? [NSString stringWithFormat:BLGT(@"Configuración RAT: %@", @"RAT configuration: %@"), label]
                    : [NSString stringWithFormat:BLGT(@"Solicitado %@. Lectura: %@", @"Requested %@. Readback: %@"), label, self->_blRatSelectionRaw ?: @"—"];

                [self updateLogForAction:[NSString stringWithFormat:BLGT(@"Modo de red: %@", @"Network mode: %@"), label]
                                   query:verify
                            requestedLTE:nil];
                [self rebuildUI];
            });
        });
    }
    @catch (NSException *exception) {
        _blStatus = BLGT(@"Excepción", @"Exception");
        _blDetail = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: BLGT(@"sin detalle", @"no details")];
        [self rebuildUI];
    }
}

- (void)reloadBands {
    _blStatus = BLGT(@"Consultando…", @"Querying…");
    _blDetail = BLGT(@"Leyendo CoreTelephony…", @"Reading CoreTelephony…");
    [self rebuildUI];

    @try {
        NSDictionary *query = [self queryCoreTelephony];
        NSString *errorText = query[@"error"];
        if (errorText) {
            _blStatus = BLGT(@"Lectura fallida", @"Read failed");
            _blDetail = errorText;
            [self rebuildUI];
            return;
        }

        [self consumeQuery:query resetSelection:YES];
        _blStatus = BLGT(@"Lectura correcta", @"Read successful");
        _blDetail = BLGT(@"Bandas LTE leídas. Los interruptores reflejan las bandas permitidas actuales.", @"LTE bands read successfully. The switches reflect the currently allowed bands.");
        [self updateLogForAction:BLGT(@"Lectura", @"Read") query:query requestedLTE:nil];
    }
    @catch (NSException *exception) {
        _blStatus = BLGT(@"Excepción", @"Exception");
        _blDetail = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: BLGT(@"sin detalle", @"no details")];
    }

    [self rebuildUI];
}

- (void)selectAllBands {
    if (!_blHasRead) return;
    _blSelectedLTE = [NSMutableSet setWithArray:_blSupportedLTE];
    _blStatus = BLGT(@"Selección preparada", @"Selection ready");
    _blDetail = BLGT(@"Todas las bandas LTE soportadas están seleccionadas.", @"All supported LTE bands are selected.");
    [self rebuildUI];
}

- (void)deselectAllBands {
    if (!_blHasRead) return;
    [_blSelectedLTE removeAllObjects];
    _blStatus = BLGT(@"Selección preparada", @"Selection ready");
    _blDetail = BLGT(@"Todas las bandas están desmarcadas. No podrás aplicar hasta seleccionar al menos una.", @"All bands are cleared. You cannot apply until at least one LTE band is selected.");
    [self rebuildUI];
}

- (void)confirmApplySelection {
    if (!_blHasRead) {
        _blStatus = BLGT(@"Lee las bandas primero", @"Read bands first");
        _blDetail = BLGT(@"Pulsa «Actualizar estado» antes de aplicar una selección.", @"Tap “Refresh status” before applying a selection.");
        [self rebuildUI];
        return;
    }

    NSArray<NSNumber *> *bands = [[_blSelectedLTE allObjects] sortedArrayUsingSelector:@selector(compare:)];
    if (!bands.count) {
        _blStatus = BLGT(@"Selección no válida", @"Invalid selection");
        _blDetail = BLGT(@"Debes mantener al menos una banda LTE seleccionada.", @"At least one LTE band must remain selected.");
        [self rebuildUI];
        return;
    }

    NSString *message = [NSString stringWithFormat:BLGT(@"Se permitirán únicamente estas bandas LTE:\n\n%@\n\nSe guardará la selección actual para poder restaurarla.", @"Only these LTE bands will be allowed:\n\n%@\n\nThe current selection will be saved so it can be restored."), BLBandList(bands)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLGT(@"Aplicar selección LTE", @"Apply LTE selection") message:message preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Aplicar", @"Apply") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf applyLTEBands:bands action:BLGT(@"Aplicar selección", @"Apply selection") savePrevious:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)restorePreviousLTE {
    if (!_blPreviousLTE.count) {
        _blStatus = BLGT(@"Sin selección anterior", @"No previous selection");
        _blDetail = BLGT(@"Todavía no hay una selección anterior guardada.", @"There is no saved previous selection yet.");
        [self rebuildUI];
        return;
    }
    [self applyLTEBands:_blPreviousLTE action:BLGT(@"Restaurar selección anterior", @"Restore previous selection") savePrevious:NO];
}

- (void)restoreAllLTE {
    if (!_blHasRead || !_blAllSupportedLTE.count) {
        _blStatus = BLGT(@"Lee las bandas primero", @"Read bands first");
        _blDetail = BLGT(@"No hay una lista LTE soportada disponible.", @"No supported LTE band list is available.");
        [self rebuildUI];
        return;
    }
    [self applyLTEBands:_blAllSupportedLTE action:BLGT(@"Restaurar modo automático", @"Restore automatic mode") savePrevious:YES];
}

- (NSArray<NSNumber *> *)allActiveLTEFromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;
    return BLSortedBands(active[BLLTERAT]);
}

- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText {
    id client = query[@"client"];
    id context = query[@"context"];
    id currentBandInfo = query[@"bandInfo"];

    SEL activeSelector = NSSelectorFromString(@"activeBands");
    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    NSDictionary *currentActive = [currentBandInfo respondsToSelector:activeSelector] ? BLMsg0(currentBandInfo, activeSelector) : nil;
    NSDictionary *currentSupported = [currentBandInfo respondsToSelector:supportedSelector] ? BLMsg0(currentBandInfo, supportedSelector) : nil;

    if (![currentActive isKindOfClass:[NSDictionary class]]) {
        if (errorText) *errorText = BLGT(@"CTBandInfo no devolvió ActiveBands en el formato esperado.", @"CTBandInfo did not return ActiveBands in the expected format.");
        return NO;
    }

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
        if (errorText) *errorText = BLGT(@"No se pudo construir CTBandInfo para la nueva selección.", @"Could not construct CTBandInfo for the new selection.");
        return NO;
    }

    SEL setter = NSSelectorFromString(@"setActiveBandInfo:bands:error:");
    if (![client respondsToSelector:setter]) {
        if (errorText) *errorText = BLGT(@"CoreTelephonyClient no implementa setActiveBandInfo:bands:error:.", @"CoreTelephonyClient does not implement setActiveBandInfo:bands:error:.");
        return NO;
    }

    NSError *setError = nil;
    BLMsgSetActiveBandInfo(client, setter, context, modifiedBandInfo, &setError);
    if (setError) {
        if (errorText) *errorText = [setError description];
        return NO;
    }

    return YES;
}

- (void)verifyLTEBands:(NSArray<NSNumber *> *)bands action:(NSString *)action retryCount:(NSInteger)retryCount {
    @try {
        NSDictionary *verify = [self queryCoreTelephony];
        NSString *verifyError = verify[@"error"];
        if (verifyError) {
            _blStatus = BLGT(@"Verificación fallida", @"Verification failed");
            _blDetail = verifyError;
            [self rebuildUI];
            return;
        }

        NSArray<NSNumber *> *readbackAllLTE = [self allActiveLTEFromQuery:verify];
        NSSet *requestedSet = [NSSet setWithArray:bands];
        NSSet *readbackSet = [NSSet setWithArray:readbackAllLTE];

        if ([requestedSet isEqualToSet:readbackSet]) {
            [self consumeQuery:verify resetSelection:YES];
            _blStatus = retryCount > 0 ? BLGT(@"Aplicado tras reintento", @"Applied after retry") : BLGT(@"Aplicado y verificado", @"Applied and verified");
            _blDetail = [NSString stringWithFormat:BLGT(@"El módem informa ahora: %@", @"The modem now reports: %@"), BLBandList(readbackAllLTE)];
            [self updateLogForAction:action query:verify requestedLTE:bands];
            [self rebuildUI];
            return;
        }

        // CommCenter puede tardar unas décimas en consolidar el nuevo conjunto de bandas.
        // Si la primera lectura devuelve la configuración anterior, reescribimos una sola vez
        // automáticamente sin perder la selección pendiente del usuario.
        if (retryCount < 1) {
            [self consumeQuery:verify resetSelection:NO];
            _blStatus = BLGT(@"Confirmando cambio…", @"Confirming change…");
            _blDetail = [NSString stringWithFormat:BLGT(@"Primera lectura: %@. Reintentando automáticamente…", @"First readback: %@. Retrying automatically…"),
                         BLBandList(readbackAllLTE)];
            [self rebuildUI];

            NSString *retryError = nil;
            BOOL wroteAgain = [self writeLTEBands:bands usingQuery:verify errorText:&retryError];
            if (!wroteAgain) {
                _blStatus = BLGT(@"Reintento fallido", @"Retry failed");
                _blDetail = retryError ?: BLGT(@"No se pudo repetir la escritura LTE.", @"The LTE write could not be retried.");
                [self updateLogForAction:[action stringByAppendingString:BLGT(@" (reintento fallido)", @" (retry failed)")]
                                   query:verify
                            requestedLTE:bands];
                [self rebuildUI];
                return;
            }

            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [weakSelf verifyLTEBands:bands action:action retryCount:retryCount + 1];
            });
            return;
        }

        [self consumeQuery:verify resetSelection:NO];
        _blStatus = BLGT(@"Resultado distinto", @"Different result");
        _blDetail = [NSString stringWithFormat:BLGT(@"Solicitado: %@ | Leído: %@", @"Requested: %@ | Readback: %@"),
                     BLBandList(bands), BLBandList(readbackAllLTE)];
        [self updateLogForAction:[action stringByAppendingString:BLGT(@" (resultado distinto)", @" (different result)")]
                           query:verify
                    requestedLTE:bands];
    }
    @catch (NSException *exception) {
        _blStatus = BLGT(@"Excepción", @"Exception");
        _blDetail = [NSString stringWithFormat:@"%@: %@",
                     exception.name ?: @"NSException",
                     exception.reason ?: BLGT(@"sin detalle", @"no details")];
    }

    [self rebuildUI];
}

- (void)applyLTEBands:(NSArray<NSNumber *> *)requested action:(NSString *)action savePrevious:(BOOL)savePrevious {
    NSArray<NSNumber *> *bands = BLSortedBands(requested);
    if (!bands.count) {
        _blStatus = BLGT(@"Selección no válida", @"Invalid selection");
        _blDetail = BLGT(@"No se puede aplicar una lista LTE vacía.", @"An empty LTE band list cannot be applied.");
        [self rebuildUI];
        return;
    }

    NSSet *supportedSet = [NSSet setWithArray:_blAllSupportedLTE.count ? _blAllSupportedLTE : _blSupportedLTE];
    for (NSNumber *band in bands) {
        if (![supportedSet containsObject:band]) {
            _blStatus = BLGT(@"Selección no válida", @"Invalid selection");
            _blDetail = [NSString stringWithFormat:BLGT(@"B%@ no figura entre las bandas LTE soportadas.", @"B%@ is not reported among the supported LTE bands."), band];
            [self rebuildUI];
            return;
        }
    }

    _blStatus = BLGT(@"Aplicando…", @"Applying…");
    _blDetail = BLBandList(bands);
    [self rebuildUI];

    @try {
        NSDictionary *query = [self queryCoreTelephony];
        NSString *queryError = query[@"error"];
        if (queryError) {
            _blStatus = BLGT(@"No se pudo aplicar", @"Could not apply");
            _blDetail = queryError;
            [self rebuildUI];
            return;
        }

        NSArray<NSNumber *> *currentLTE = [self allActiveLTEFromQuery:query];
        if (savePrevious && currentLTE.count) [self savePreviousLTE:currentLTE];

        // Conserva la selección solicitada mientras CommCenter realiza el cambio.
        _blSelectedLTE = [NSMutableSet setWithArray:BLIntersectBands(bands, _blSupportedLTE)];
        BLWriteState(@{@"pendingLTE": [[_blSelectedLTE allObjects] sortedArrayUsingSelector:@selector(compare:)]});

        NSString *writeError = nil;
        if (![self writeLTEBands:bands usingQuery:query errorText:&writeError]) {
            _blStatus = BLGT(@"Escritura rechazada", @"Write rejected");
            _blDetail = writeError ?: BLGT(@"CoreTelephony rechazó la selección.", @"CoreTelephony rejected the selection.");
            [self rebuildUI];
            return;
        }

        _blStatus = BLGT(@"Esperando al módem…", @"Waiting for modem…");
        _blDetail = BLGT(@"La escritura fue aceptada. Verificando cuando CommCenter haya consolidado el cambio.", @"The write was accepted. Verifying after CommCenter commits the change.");
        [self rebuildUI];

        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [weakSelf verifyLTEBands:bands action:action retryCount:0];
        });
    }
    @catch (NSException *exception) {
        _blStatus = BLGT(@"Excepción", @"Exception");
        _blDetail = [NSString stringWithFormat:@"%@: %@",
                     exception.name ?: @"NSException",
                     exception.reason ?: BLGT(@"sin detalle", @"no details")];
        [self rebuildUI];
    }
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
                                    message:[NSString stringWithFormat:BLGT(@"FrontBoard rechazó el lanzamiento: %@", @"FrontBoard rejected the launch: %@"), error.localizedDescription ?: [error description]]
                                    preferredStyle:UIAlertControllerStyleAlert];
                                [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
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
        message:(attempted ? BLGT(@"iOS rechazó el lanzamiento directo de com.apple.FTMInternal.", @"iOS rejected the direct launch of com.apple.FTMInternal.") : BLGT(@"No se encontró una API disponible para lanzar com.apple.FTMInternal.", @"No available API was found to launch com.apple.FTMInternal."))
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearLogs {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:BLGT(@"Eliminar registros", @"Delete logs")
        message:BLGT(@"Se eliminarán únicamente los registros creados por BandLock.", @"Only logs created by BandLock will be deleted.")
        preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:BLGT(@"Eliminar", @"Delete") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf clearLogsConfirmed];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearLogsConfirmed {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fm fileExistsAtPath:BLLogDirectory] && ![fm removeItemAtPath:BLLogDirectory error:&error]) {
        _blLogStatus = [NSString stringWithFormat:BLGT(@"Error al eliminar: %@", @"Delete error: %@"), error.localizedDescription ?: BLGT(@"desconocido", @"unknown")];
    } else {
        _blLogStatus = BLGT(@"Registros eliminados", @"Logs deleted");
    }
    [self rebuildUI];
}

@end
