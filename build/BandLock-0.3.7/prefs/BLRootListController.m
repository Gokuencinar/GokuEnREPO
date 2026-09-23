#import "BLRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLLogDirectory = @"/var/mobile/Library/Logs/BandLock";
static NSString * const BLLastLogPath = @"/var/mobile/Library/Logs/BandLock/BandLock-last.txt";
static NSString * const BLSSHLastLogPath = @"/rootfs/private/var/mobile/Library/Logs/BandLock/BandLock-last.txt";

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
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:bands.count];
    for (NSNumber *band in bands) [parts addObject:[NSString stringWithFormat:@"B%@", band]];
    return [parts componentsJoinedByString:@", "];
}

static NSString *BLCompactDescription(id object) {
    if (!object || object == [NSNull null]) return @"—";
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)object;
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

@interface BLRootListController () {
    NSString *_blStatus;
    NSString *_blRAT;
    NSString *_blDetail;
    NSString *_blLogStatus;
    NSArray<NSNumber *> *_blSupportedLTE;
    NSArray<NSNumber *> *_blActiveLTE;
    NSMutableSet<NSNumber *> *_blSelectedLTE;
    BOOL _blHasRead;
}
@end

@implementation BLRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!_blStatus) {
        _blStatus = @"Sin consultar";
        _blRAT = @"—";
        _blDetail = @"Pulsa «Leer bandas» antes de modificar la selección.";
        _blLogStatus = [[NSFileManager defaultManager] fileExistsAtPath:BLLastLogPath] ? BLSSHLastLogPath : @"Sin registros";
        _blSupportedLTE = @[];
        _blActiveLTE = @[];
        _blSelectedLTE = [NSMutableSet set];
    }
}

- (NSMutableArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *items = [NSMutableArray array];

    PSSpecifier *readGroup = [PSSpecifier emptyGroupSpecifier];
    readGroup.name = @"Estado";
    [readGroup setProperty:@"La lectura y los cambios solo se ejecutan mediante los botones de esta pantalla. BandLock no usa procesos en segundo plano." forKey:@"footerText"];
    [items addObject:readGroup];

    PSSpecifier *readButton = [PSSpecifier preferenceSpecifierNamed:@"Leer bandas"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    readButton.buttonAction = @selector(reloadBands);
    [readButton setProperty:@YES forKey:@"enabled"];
    [items addObject:readButton];

    PSSpecifier *status = [PSSpecifier preferenceSpecifierNamed:@"Estado"
        target:self set:nil get:@selector(statusValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:status];

    PSSpecifier *rat = [PSSpecifier preferenceSpecifierNamed:@"RAT actual"
        target:self set:nil get:@selector(ratValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:rat];

    PSSpecifier *mode = [PSSpecifier preferenceSpecifierNamed:@"Modo LTE"
        target:self set:nil get:@selector(modeValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:mode];

    PSSpecifier *supported = [PSSpecifier preferenceSpecifierNamed:@"LTE soportadas"
        target:self set:nil get:@selector(supportedLTEValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:supported];

    PSSpecifier *active = [PSSpecifier preferenceSpecifierNamed:@"LTE permitidas"
        target:self set:nil get:@selector(activeLTEValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:active];

    PSSpecifier *selectionGroup = [PSSpecifier emptyGroupSpecifier];
    selectionGroup.name = @"Selección LTE";
    [selectionGroup setProperty:(_blHasRead
        ? @"Los interruptores cambian solo la selección pendiente. Nada se escribe hasta pulsar «Aplicar selección LTE»."
        : @"Pulsa primero «Leer bandas». Después aparecerán aquí las bandas LTE soportadas por el dispositivo.")
        forKey:@"footerText"];
    [items addObject:selectionGroup];

    if (_blSupportedLTE.count) {
        NSSet *supportedSet = [NSSet setWithArray:_blSupportedLTE];
        for (NSNumber *band in _blSupportedLTE) {
            PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"B%@", band]
                target:self
                set:@selector(setBandSwitchValue:specifier:)
                get:@selector(bandSwitchValue:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];
            [toggle setProperty:band forKey:@"band"];
            [toggle setProperty:@YES forKey:@"enabled"];
            [toggle setProperty:@([supportedSet containsObject:band]) forKey:@"default"];
            [items addObject:toggle];
        }
    } else {
        PSSpecifier *none = [PSSpecifier preferenceSpecifierNamed:@"Sin datos LTE todavía"
            target:self set:nil get:nil detail:nil cell:PSStaticTextCell edit:nil];
        [none setProperty:@NO forKey:@"enabled"];
        [items addObject:none];
    }

    PSSpecifier *actionsGroup = [PSSpecifier emptyGroupSpecifier];
    actionsGroup.name = @"Aplicar";
    [actionsGroup setProperty:@"Aplicar puede provocar una pérdida temporal de cobertura. BandLock vuelve a leer CTBandInfo después de cada escritura y muestra lo que el módem aceptó realmente." forKey:@"footerText"];
    [items addObject:actionsGroup];

    PSSpecifier *apply = [PSSpecifier preferenceSpecifierNamed:@"Aplicar selección LTE"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    apply.buttonAction = @selector(confirmApplySelection);
    [apply setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:apply];

    PSSpecifier *restore = [PSSpecifier preferenceSpecifierNamed:@"Restaurar todas las LTE"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    restore.buttonAction = @selector(restoreAllLTE);
    [restore setProperty:@(_blHasRead) forKey:@"enabled"];
    [items addObject:restore];

    PSSpecifier *diagnosticGroup = [PSSpecifier emptyGroupSpecifier];
    diagnosticGroup.name = @"Diagnóstico";
    [diagnosticGroup setProperty:@"Los registros ya no incluyen la descripción del contexto de suscripción, evitando guardar el número de teléfono. Ruta visible por SSH: /rootfs/private/var/mobile/Library/Logs/BandLock/BandLock-last.txt" forKey:@"footerText"];
    [items addObject:diagnosticGroup];

    PSSpecifier *detail = [PSSpecifier preferenceSpecifierNamed:@"Resultado"
        target:self set:nil get:@selector(detailValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:detail];

    PSSpecifier *log = [PSSpecifier preferenceSpecifierNamed:@"Último registro"
        target:self set:nil get:@selector(logValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:log];

    PSSpecifier *clear = [PSSpecifier preferenceSpecifierNamed:@"Eliminar todos los registros"
        target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    clear.buttonAction = @selector(clearLogs);
    [items addObject:clear];

    PSSpecifier *infoGroup = [PSSpecifier emptyGroupSpecifier];
    infoGroup.name = @"Información";
    [items addObject:infoGroup];

    PSSpecifier *version = [PSSpecifier preferenceSpecifierNamed:@"Versión"
        target:self set:nil get:@selector(versionValue) detail:nil cell:PSTitleValueCell edit:nil];
    [items addObject:version];

    _specifiers = items;
    return _specifiers;
}

- (NSString *)statusValue { return _blStatus ?: @"Sin consultar"; }
- (NSString *)ratValue { return _blRAT ?: @"—"; }
- (NSString *)supportedLTEValue { return BLBandList(_blSupportedLTE); }
- (NSString *)activeLTEValue { return BLBandList(_blActiveLTE); }
- (NSString *)detailValue { return _blDetail ?: @"—"; }
- (NSString *)logValue { return _blLogStatus ?: @"Sin registros"; }
- (NSString *)versionValue { return @"0.3.7"; }

- (NSString *)modeValue {
    if (!_blHasRead) return @"Sin consultar";
    NSSet *supported = [NSSet setWithArray:_blSupportedLTE];
    NSSet *active = [NSSet setWithArray:_blActiveLTE];
    if ([supported isEqualToSet:active]) return @"Automático / todas";
    return BLBandList(_blActiveLTE);
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

    if (!context) {
        return @{@"error": contextError ? [contextError description] : @"No hay contexto de datos activo/preferido."};
    }

    SEL bandSelector = NSSelectorFromString(@"getBandInfo:error:");
    if (![client respondsToSelector:bandSelector]) return @{@"error": @"getBandInfo:error: no está disponible."};

    NSError *bandError = nil;
    id bandInfo = BLMsgObjErr(client, bandSelector, context, &bandError);
    if (!bandInfo) return @{@"error": bandError ? [bandError description] : @"getBandInfo:error: devolvió nil."};

    return @{
        @"client": client,
        @"context": context,
        @"bandInfo": bandInfo,
        @"ratRaw": ratRaw ?: [NSNull null]
    };
}

- (void)consumeQuery:(NSDictionary *)query resetSelection:(BOOL)resetSelection {
    id bandInfo = query[@"bandInfo"];
    id ratRaw = query[@"ratRaw"];
    if (ratRaw == [NSNull null]) ratRaw = nil;

    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    NSDictionary *supported = [bandInfo respondsToSelector:supportedSelector] ? BLMsg0(bandInfo, supportedSelector) : nil;
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;

    _blSupportedLTE = BLSortedBands(supported[BLLTERAT]);
    _blActiveLTE = BLSortedBands(active[BLLTERAT]);
    if (resetSelection || !_blSelectedLTE) _blSelectedLTE = [NSMutableSet setWithArray:_blActiveLTE];

    _blRAT = BLHumanRAT(ratRaw);
    _blHasRead = YES;
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

    NSString *filename = [NSString stringWithFormat:@"BandLock-%@.txt", [fileFormatter stringFromDate:now]];
    NSString *path = [BLLogDirectory stringByAppendingPathComponent:filename];

    NSString *content = [NSString stringWithFormat:
        @"BandLock-Version: 0.3.7\n"
         "Timestamp: %@\n"
         "Action: %@\n"
         "Status: %@\n"
         "RAT-UI: %@\n"
         "RAT-Raw: %@\n"
         "SubscriptionContext: acquired (details redacted)\n"
         "Requested-LTE: %@\n"
         "Supported-LTE: %@\n"
         "Active-LTE: %@\n"
         "SupportedBands: %@\n"
         "ActiveBands: %@\n"
         "CTBandInfo-Raw: %@\n"
         "Diagnostic: %@\n",
         [displayFormatter stringFromDate:now],
         action ?: @"—",
         _blStatus ?: @"—",
         _blRAT ?: @"—",
         BLCompactDescription(ratRaw),
         requestedLTE ? BLBandList(requestedLTE) : @"—",
         BLBandList(_blSupportedLTE),
         BLBandList(_blActiveLTE),
         BLCompactDescription(supported),
         BLCompactDescription(active),
         BLCompactDescription(bandInfo),
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

- (void)reloadBands {
    _blStatus = @"Consultando…";
    _blDetail = @"Leyendo CTBandInfo…";
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
        _blDetail = @"Bandas LTE leídas correctamente. Los interruptores reflejan las LTE permitidas actualmente.";
        [self updateLogForAction:@"Lectura" query:query requestedLTE:nil];
    }
    @catch (NSException *exception) {
        _blStatus = @"Excepción";
        _blDetail = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: @"sin detalle"];
    }

    [self rebuildUI];
}

- (void)confirmApplySelection {
    if (!_blHasRead) {
        _blStatus = @"Lee las bandas primero";
        _blDetail = @"Pulsa «Leer bandas» antes de aplicar una selección.";
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

    NSString *message = [NSString stringWithFormat:@"Se permitirán únicamente estas bandas LTE:\n\n%@\n\nPuede haber una pérdida temporal de cobertura.", BLBandList(bands)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Aplicar selección LTE" message:message preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aplicar" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf applyLTEBands:bands action:@"Aplicar selección"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)restoreAllLTE {
    if (!_blHasRead || !_blSupportedLTE.count) {
        _blStatus = @"Lee las bandas primero";
        _blDetail = @"No hay una lista de bandas LTE soportadas disponible.";
        [self rebuildUI];
        return;
    }
    [self applyLTEBands:_blSupportedLTE action:@"Restaurar todas"];
}

- (void)applyLTEBands:(NSArray<NSNumber *> *)requested action:(NSString *)action {
    NSArray<NSNumber *> *bands = BLSortedBands(requested);
    if (!bands.count) {
        _blStatus = @"Selección no válida";
        _blDetail = @"No se puede aplicar una lista LTE vacía.";
        [self rebuildUI];
        return;
    }

    NSSet *supportedSet = [NSSet setWithArray:_blSupportedLTE];
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
            _blDetail = @"CTBandInfo no devolvió el diccionario ActiveBands esperado.";
            [self rebuildUI];
            return;
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
