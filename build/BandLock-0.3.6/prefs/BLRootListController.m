#import "BLRootListController.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const BLLogDirectory = @"/var/mobile/Library/Logs/BandLock";
static NSString * const BLLastLogPath = @"/var/mobile/Library/Logs/BandLock/BandLock-last.txt";

static id BLMsg0(id object, SEL selector) {
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static id BLMsgErr(id object, SEL selector, NSError **error) {
    return ((id (*)(id, SEL, NSError **))objc_msgSend)(object, selector, error);
}

static id BLMsgObjErr(id object, SEL selector, id argument, NSError **error) {
    return ((id (*)(id, SEL, id, NSError **))objc_msgSend)(object, selector, argument, error);
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
    NSString *_blSupported;
    NSString *_blActive;
    NSString *_blDetail;
    NSString *_blLogStatus;
}
- (void)finishReadWithBandInfo:(id)bandInfo context:(id)context ratRaw:(id)ratRaw;
- (NSString *)writeDiagnosticLogWithBandInfo:(id)bandInfo context:(id)context ratRaw:(id)ratRaw error:(NSError **)error;
- (void)clearLogsConfirmed;
@end

@implementation BLRootListController

- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

    if (!_blStatus) {
        _blStatus = @"Sin consultar";
        _blRAT = @"—";
        _blSupported = @"—";
        _blActive = @"—";
        _blDetail = @"Pulsa «Leer bandas».";
        _blLogStatus = [[NSFileManager defaultManager] fileExistsAtPath:BLLastLogPath] ? BLLastLogPath : @"Sin registros";
    }
    return _specifiers;
}

- (NSString *)statusValue { return _blStatus ?: @"Sin consultar"; }
- (NSString *)ratValue { return _blRAT ?: @"—"; }
- (NSString *)supportedBandsValue { return _blSupported ?: @"—"; }
- (NSString *)activeBandsValue { return _blActive ?: @"—"; }
- (NSString *)detailValue { return _blDetail ?: @"—"; }
- (NSString *)logValue { return _blLogStatus ?: @"Sin registros"; }
- (NSString *)versionValue { return @"0.3.6"; }

- (NSString *)writeDiagnosticLogWithBandInfo:(id)bandInfo context:(id)context ratRaw:(id)ratRaw error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *directoryError = nil;
    if (![fm createDirectoryAtPath:BLLogDirectory
       withIntermediateDirectories:YES
                        attributes:nil
                             error:&directoryError]) {
        if (error) *error = directoryError;
        return nil;
    }

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
        @"BandLock-Version: 0.3.6\n"
         "Timestamp: %@\n"
         "Status: %@\n"
         "RAT-UI: %@\n"
         "RAT-Raw: %@\n"
         "Context: %@\n"
         "SupportedBands: %@\n"
         "ActiveBands: %@\n"
         "CTBandInfo-Raw: %@\n"
         "Diagnostic: %@\n",
         [displayFormatter stringFromDate:now],
         _blStatus ?: @"—",
         _blRAT ?: @"—",
         BLCompactDescription(ratRaw),
         BLCompactDescription(context),
         _blSupported ?: @"—",
         _blActive ?: @"—",
         BLCompactDescription(bandInfo),
         _blDetail ?: @"—"];

    NSError *writeError = nil;
    if (![content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        if (error) *error = writeError;
        return nil;
    }

    NSError *lastError = nil;
    if (![content writeToFile:BLLastLogPath atomically:YES encoding:NSUTF8StringEncoding error:&lastError]) {
        if (error) *error = lastError;
        return path;
    }

    return path;
}

- (void)finishReadWithBandInfo:(id)bandInfo context:(id)context ratRaw:(id)ratRaw {
    NSError *logError = nil;
    NSString *path = [self writeDiagnosticLogWithBandInfo:bandInfo context:context ratRaw:ratRaw error:&logError];
    if (path) {
        _blLogStatus = BLLastLogPath;
    } else {
        _blLogStatus = [NSString stringWithFormat:@"Error al guardar: %@", logError.localizedDescription ?: @"desconocido"];
    }
    [self reloadSpecifiers];
}

- (void)reloadBands {
    _blStatus = @"Consultando…";
    _blRAT = @"—";
    _blSupported = @"—";
    _blActive = @"—";
    _blDetail = @"Iniciando CoreTelephony…";
    [self reloadSpecifiers];

    id ratRaw = nil;
    id context = nil;
    id bandInfo = nil;

    @try {
        void *handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_NOW | RTLD_LOCAL);
        if (!handle) {
            const char *err = dlerror();
            _blStatus = @"Error";
            _blDetail = err ? [NSString stringWithUTF8String:err] : @"No se pudo cargar CoreTelephony.";
            [self finishReadWithBandInfo:nil context:nil ratRaw:nil];
            return;
        }

        Class networkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
        if (networkInfoClass) {
            id networkInfo = [[networkInfoClass alloc] init];
            SEL ratSelector = NSSelectorFromString(@"serviceCurrentRadioAccessTechnology");
            if ([networkInfo respondsToSelector:ratSelector]) {
                ratRaw = BLMsg0(networkInfo, ratSelector);
                _blRAT = BLHumanRAT(ratRaw);
            } else {
                _blRAT = @"No disponible";
            }
        } else {
            _blRAT = @"CTTelephonyNetworkInfo no encontrado";
        }

        Class clientClass = NSClassFromString(@"CoreTelephonyClient");
        if (!clientClass) {
            _blStatus = @"Error";
            _blDetail = @"CoreTelephonyClient no está disponible.";
            [self finishReadWithBandInfo:nil context:nil ratRaw:ratRaw];
            return;
        }

        id client = [[clientClass alloc] init];
        if (!client) {
            _blStatus = @"Error";
            _blDetail = @"No se pudo crear CoreTelephonyClient.";
            [self finishReadWithBandInfo:nil context:nil ratRaw:ratRaw];
            return;
        }

        NSError *contextError = nil;
        SEL currentSelector = NSSelectorFromString(@"getCurrentDataSubscriptionContextSync:");
        if ([client respondsToSelector:currentSelector]) {
            context = BLMsgErr(client, currentSelector, &contextError);
        }

        if (!context) {
            contextError = nil;
            SEL preferredSelector = NSSelectorFromString(@"getPreferredDataSubscriptionContextSync:");
            if ([client respondsToSelector:preferredSelector]) {
                context = BLMsgErr(client, preferredSelector, &contextError);
            }
        }

        if (!context) {
            _blStatus = @"Sin contexto de datos";
            _blDetail = contextError ? [contextError description] : @"CoreTelephony no devolvió una suscripción de datos activa/preferida.";
            [self finishReadWithBandInfo:nil context:nil ratRaw:ratRaw];
            return;
        }

        SEL bandSelector = NSSelectorFromString(@"getBandInfo:error:");
        if (![client respondsToSelector:bandSelector]) {
            _blStatus = @"No compatible";
            _blDetail = @"CoreTelephonyClient no implementa getBandInfo:error:.";
            [self finishReadWithBandInfo:nil context:context ratRaw:ratRaw];
            return;
        }

        NSError *bandError = nil;
        bandInfo = BLMsgObjErr(client, bandSelector, context, &bandError);
        if (!bandInfo) {
            _blStatus = @"Lectura fallida";
            _blDetail = bandError ? [bandError description] : @"getBandInfo:error: devolvió nil.";
            [self finishReadWithBandInfo:nil context:context ratRaw:ratRaw];
            return;
        }

        SEL supportedSelector = NSSelectorFromString(@"supportedBands");
        SEL activeSelector = NSSelectorFromString(@"activeBands");
        id supported = [bandInfo respondsToSelector:supportedSelector] ? BLMsg0(bandInfo, supportedSelector) : nil;
        id active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;

        _blSupported = BLCompactDescription(supported);
        _blActive = BLCompactDescription(active);
        _blStatus = @"Lectura correcta";
        _blDetail = [NSString stringWithFormat:@"CTBandInfo: %@", BLCompactDescription(bandInfo)];
        [self finishReadWithBandInfo:bandInfo context:context ratRaw:ratRaw];
    }
    @catch (NSException *exception) {
        _blStatus = @"Excepción";
        _blDetail = [NSString stringWithFormat:@"%@: %@", exception.name ?: @"NSException", exception.reason ?: @"sin detalle"];
        [self finishReadWithBandInfo:bandInfo context:context ratRaw:ratRaw];
    }
}

- (void)clearLogs {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Eliminar registros"
        message:@"Se eliminarán únicamente los registros creados por BandLock."
        preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction
        actionWithTitle:@"Eliminar"
        style:UIAlertActionStyleDestructive
        handler:^(__unused UIAlertAction *action) {
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

    [self reloadSpecifiers];
}

@end
