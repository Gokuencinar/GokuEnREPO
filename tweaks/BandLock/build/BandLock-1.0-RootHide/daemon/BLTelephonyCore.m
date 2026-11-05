#import "BLTelephonyManager.h"
#import "../../BLHardwareCapabilities.h"
#include <errno.h>
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import <string.h>

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLNRRAT = @"kCTRegistrationRadioAccessTechnologyNR";
static NSString * const BLUTRANRAT = @"kCTRegistrationRadioAccessTechnologyUTRAN";
static NSString * const BLGSMRAT = @"kCTRegistrationRadioAccessTechnologyGSM";
static NSString * const BLRATAutomatic = @"kCTRegistrationRATSelectionAutomatic";
static NSString * const BLRATGSM = @"kCTRegistrationRATSelectionGSM";
static NSString * const BLRATLTE = @"kCTRegistrationRATSelectionLTE";
static NSString * const BLRATUMTS = @"kCTRegistrationRATSelectionUMTS";
static NSString * const BLRATNR = @"kCTRegistrationRATSelectionNR";
static NSString * const BLRATNRSA = @"kCTRegistrationRATSelectionNRStandAlone";
static NSString * const BLLogDirectory = @"/var/mobile/Library/Logs/BandLockGlobal";
static NSString * const BLLastLogPath = @"/var/mobile/Library/Logs/BandLockGlobal/BandLock-last.txt";
static NSString * const BLStateDefaultsKey = @"BandLockGlobalState";
static const NSTimeInterval BLRatWriteQuietPeriod = 6.0;
static NSTimeInterval BLRatLastWriteStartedAt = 0.0;

static dispatch_semaphore_t BLRatWriteGate(void) {
    static dispatch_semaphore_t gate;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ gate = dispatch_semaphore_create(1); });
    return gate;
}

static id BLMsg0(id object, SEL selector) { return ((id (*)(id, SEL))objc_msgSend)(object, selector); }
static id BLMsgErr(id object, SEL selector, NSError **error) { return ((id (*)(id, SEL, NSError **))objc_msgSend)(object, selector, error); }
static id BLMsgObjErr(id object, SEL selector, id argument, NSError **error) { return ((id (*)(id, SEL, id, NSError **))objc_msgSend)(object, selector, argument, error); }
static id BLMsg2(id object, SEL selector, id arg1, id arg2) { return ((id (*)(id, SEL, id, id))objc_msgSend)(object, selector, arg1, arg2); }
static void BLMsgSetObj(id object, SEL selector, id value) { ((void (*)(id, SEL, id))objc_msgSend)(object, selector, value); }
static void BLMsgSetActiveBandInfo(id object, SEL selector, id context, id bands, NSError **error) { ((void (*)(id, SEL, id, id, NSError **))objc_msgSend)(object, selector, context, bands, error); }
static BOOL BLMsgBoolObj(id object, SEL selector, id value) { return ((BOOL (*)(id, SEL, id))objc_msgSend)(object, selector, value); }
static void BLMsgObjBlock(id object, SEL selector, id value, void (^completion)(id, NSError *)) { ((void (*)(id, SEL, id, id))objc_msgSend)(object, selector, value, completion); }
static void BLMsgGetRatSelection(id object, SEL selector, id context, void (^completion)(NSString *, NSString *, NSError *)) { ((void (*)(id, SEL, id, id))objc_msgSend)(object, selector, context, completion); }
static void BLMsgSetRatSelection(id object, SEL selector, id context, id selection, id preferred, void (^completion)(NSError *)) { ((void (*)(id, SEL, id, id, id, id))objc_msgSend)(object, selector, context, selection, preferred, completion); }

// Classify ONLY known CoreTelephony RAT selection constants; do not turn
// registered LTE, an arbitrary string containing "LTE", or an API success
// into proof that the user's selection is actually LTE-only.
static NSString *BLRHRatSelectionKind(id selection) {
    if (![selection isKindOfClass:NSString.class]) return selection ? @"invalid_type" : @"missing";
    if (![selection length] || [selection isEqualToString:@"—"]) return @"empty";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionLTE"] ||
        [selection isEqualToString:@"LTE"]) return @"lte";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionAutomatic"] ||
        [selection isEqualToString:@"Automatic"]) return @"automatic";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionUMTS"] ||
        [selection isEqualToString:@"UMTS"]) return @"umts";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionGSM"] ||
        [selection isEqualToString:@"GSM"]) return @"gsm";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionNRStandAlone"]) return @"nr_sa";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionNRNonStandAlone"]) return @"nr_nsa";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionNR"]) return @"nr";
    if ([selection isEqualToString:@"kCTRegistrationRATSelectionUnknown"] ||
        [selection isEqualToString:@"Unknown"]) return @"explicit_unknown";
    return @"unrecognized";
}

static NSMutableDictionary *BLReadState(void) {
    NSDictionary *existing = [NSUserDefaults.standardUserDefaults dictionaryForKey:BLStateDefaultsKey];
    return existing ? [existing mutableCopy] : [NSMutableDictionary dictionary];
}

static void BLWriteState(NSDictionary *changes) {
    NSMutableDictionary *state = BLReadState();
    [changes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (obj) state[key] = obj;
        else [state removeObjectForKey:key];
    }];
    [NSUserDefaults.standardUserDefaults setObject:state forKey:BLStateDefaultsKey];
}

static NSString *BLCompactDescription(id object) {
    if (!object || object == [NSNull null]) return @"—";
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id key in [(NSDictionary *)object allKeys]) {
            [parts addObject:[NSString stringWithFormat:@"%@: %@", key, BLCompactDescription(((NSDictionary *)object)[key])]];
        }
        [parts sortUsingSelector:@selector(localizedStandardCompare:)];
        return parts.count ? [parts componentsJoinedByString:@" | "] : @"—";
    }
    if ([object isKindOfClass:[NSSet class]]) object = [(NSSet *)object allObjects];
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id value in (NSArray *)object) [parts addObject:[value description]];
        [parts sortUsingSelector:@selector(localizedStandardCompare:)];
        return parts.count ? [parts componentsJoinedByString:@", "] : @"—";
    }
    return [object description] ?: @"—";
}

static NSString *BLNRBandKey(NSDictionary *dictionary) {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    if ([dictionary[BLNRRAT] isKindOfClass:[NSArray class]] || [dictionary[BLNRRAT] isKindOfClass:[NSSet class]]) return BLNRRAT;
    for (id key in dictionary) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSString *text = (NSString *)key;
        if ([text rangeOfString:@"NR" options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
        id value = dictionary[key];
        if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSSet class]]) return text;
    }
    return nil;
}

static NSArray<NSNumber *> *BLNRBandsFromDictionary(NSDictionary *dictionary) {
    NSString *key = BLNRBandKey(dictionary);
    return key.length ? BLSortedBands(dictionary[key]) : @[];
}

static NSString *BLBandKeyForTargetRAT(NSString *targetRAT, NSDictionary *dictionary) {
    if (![targetRAT isKindOfClass:NSString.class] || ![dictionary isKindOfClass:NSDictionary.class]) return nil;
    NSArray<NSString *> *exact = nil;
    NSArray<NSString *> *tokens = nil;
    if ([targetRAT isEqualToString:@"LTE"]) {
        exact = @[BLLTERAT];
        tokens = @[@"LTE"];
    } else if ([targetRAT isEqualToString:@"NR"]) {
        NSString *nr = BLNRBandKey(dictionary);
        if (nr.length) return nr;
        tokens = @[@"NR"];
    } else if ([targetRAT isEqualToString:@"3G"]) {
        exact = @[BLUTRANRAT];
        tokens = @[@"UTRAN", @"UMTS", @"WCDMA"];
    } else if ([targetRAT isEqualToString:@"2G"]) {
        exact = @[BLGSMRAT];
        tokens = @[@"GSM", @"GERAN"];
    } else {
        return nil;
    }
    for (NSString *key in exact ?: @[]) {
        id value = dictionary[key];
        if ([value isKindOfClass:NSArray.class] || [value isKindOfClass:NSSet.class]) return key;
    }
    NSString *matched = nil;
    for (id rawKey in dictionary) {
        if (![rawKey isKindOfClass:NSString.class]) continue;
        id value = dictionary[rawKey];
        if (![value isKindOfClass:NSArray.class] && ![value isKindOfClass:NSSet.class]) continue;
        NSString *upper = [rawKey uppercaseString];
        for (NSString *token in tokens ?: @[]) {
            if (![upper containsString:token]) continue;
            if (matched && ![matched isEqualToString:rawKey]) return nil;
            matched = rawKey;
            break;
        }
    }
    return matched;
}

static NSDictionary *BLSafeBandDictionary(id raw) {
    if (![raw isKindOfClass:NSDictionary.class]) return nil;
    NSMutableDictionary *safe = [NSMutableDictionary dictionary];
    if ([(NSDictionary *)raw count] > 32) return nil;
    for (id rawKey in (NSDictionary *)raw) {
        if (![rawKey isKindOfClass:NSString.class] || [(NSString *)rawKey length] > 160) return nil;
        id rawBands = ((NSDictionary *)raw)[rawKey];
        if (![rawBands isKindOfClass:NSArray.class] && ![rawBands isKindOfClass:NSSet.class]) return nil;
        NSArray<NSNumber *> *bands = BLSortedBands(rawBands);
        if (bands.count > 256) return nil;
        for (NSNumber *band in bands) {
            if (![band isKindOfClass:NSNumber.class] || band.integerValue <= 0 || band.integerValue > 1024) return nil;
        }
        safe[rawKey] = bands;
    }
    return safe;
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
    if (!cellInfo) return BLT(@"No disponible", @"Unavailable");
    SEL legacySelector = NSSelectorFromString(@"legacyInfo");
    if (![cellInfo respondsToSelector:legacySelector]) return BLT(@"No disponible", @"Unavailable");
    id legacy = BLMsg0(cellInfo, legacySelector);
    if (![legacy isKindOfClass:[NSArray class]] || ![(NSArray *)legacy count]) return BLT(@"No disponible", @"Unavailable");

    NSDictionary *row = nil;
    for (id candidate in (NSArray *)legacy) {
        if (![candidate isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *dict = candidate;
        if ([dict[@"kCTCellMonitorCellType"] isEqual:@"kCTCellMonitorCellTypeServing"]) { row = dict; break; }
    }
    if (!row && [[(NSArray *)legacy firstObject] isKindOfClass:[NSDictionary class]]) row = [(NSArray *)legacy firstObject];
    id band = row[@"kCTCellMonitorBandInfo"];
    if (![band respondsToSelector:@selector(integerValue)] || [band integerValue] <= 0) return BLT(@"No disponible", @"Unavailable");
    NSNumber *bandNumber = @([band integerValue]);
    NSString *rat = row[@"kCTCellMonitorCellRadioAccessTechnology"];
    BOOL isNR = [rat isKindOfClass:[NSString class]] && [rat rangeOfString:@"NR" options:NSCaseInsensitiveSearch].location != NSNotFound;
    NSString *title = isNR ? BLGNRBandTitle(bandNumber) : BLGBandTitle(bandNumber);
    if ([rat isKindOfClass:[NSString class]] && rat.length) return [NSString stringWithFormat:@"%@ · %@", title, ([rat rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound ? @"LTE" : rat)];
    return title;
}

// Resolve only the carrier attached to the current data service. The provider
// dictionary can also contain inactive/disabled eSIM plans, so never pick the
// first carrier and never export the service identifier itself.
static NSString *BLOperatorNameFromNetworkInfo(id networkInfo) {
    if (!networkInfo) return nil;
    SEL dataSelector = NSSelectorFromString(@"dataServiceIdentifier");
    SEL providersSelector = NSSelectorFromString(@"serviceSubscriberCellularProviders");
    if (![networkInfo respondsToSelector:dataSelector] ||
        ![networkInfo respondsToSelector:providersSelector]) return nil;
    id dataService = BLMsg0(networkInfo, dataSelector);
    id rawProviders = BLMsg0(networkInfo, providersSelector);
    if (![dataService isKindOfClass:NSString.class] || ![dataService length] ||
        ![rawProviders isKindOfClass:NSDictionary.class]) return nil;
    id carrier = ((NSDictionary *)rawProviders)[dataService];
    id confirmedDataService = BLMsg0(networkInfo, dataSelector);
    if (![confirmedDataService isKindOfClass:NSString.class] ||
        ![confirmedDataService isEqualToString:dataService]) return nil;
    SEL nameSelector = NSSelectorFromString(@"carrierName");
    if (!carrier || ![carrier respondsToSelector:nameSelector]) return nil;
    id rawName = BLMsg0(carrier, nameSelector);
    if (![rawName isKindOfClass:NSString.class]) return nil;
    NSString *name = [rawName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length || name.length > 96) return nil;
    return name;
}

// RootHide signal diagnostic: never export raw CoreTelephony dictionaries,
// SIM identifiers, subscription UUIDs or other subscriber identity.
// Explicitly allow bounded radio cell identifiers (not subscriber IDs).
// Legacy RSRP/RSRQ/RSSI equal to zero are known placeholder values.
static NSNumber *BLRHSignalNumber(id raw, double lower, double upper, BOOL rejectZero) {
    if (![raw isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)raw) == CFBooleanGetTypeID()) return nil;
    double value = [raw doubleValue];
    if (!isfinite(value) || value < lower || value > upper ||
        (rejectZero && value == 0.0)) return nil;
    return @(value);
}

static NSNumber *BLRHMetric(id container, NSString *key, double lower, double upper, BOOL rejectZero) {
    if (!container || ![container respondsToSelector:NSSelectorFromString(key)]) return nil;
    id raw = BLMsg0(container, NSSelectorFromString(key));
    return BLRHSignalNumber(raw, lower, upper, rejectZero);
}

static NSNumber *BLRHLegacyMetric(NSDictionary *row, NSArray<NSString *> *keys,
                                  double lower, double upper, BOOL rejectZero) {
    for (NSString *key in keys) {
        NSNumber *value = BLRHSignalNumber(row[key], lower, upper, rejectZero);
        if (value) return value; // An invalid earlier alias cannot hide a valid later one.
    }
    return nil;
}

static NSString *BLRHMetricPresence(NSDictionary *row, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = row[key];
        if (!value || value == NSNull.null) continue;
        if ([value isKindOfClass:NSNumber.class]) {
            if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return @"boolean";
            if ([value doubleValue] == 0) return @"zero_placeholder";
            return @"reported";
        }
        return @"unsupported_type";
    }
    return @"missing";
}

// Keep radio-technology classification independent of the availability of
// LTE/NR-specific signal metrics. A UMTS or GSM cell is not an LTE cell.
static NSString *BLRHSignalRAT(NSString *raw) {
    if (![raw isKindOfClass:NSString.class]) return nil;
    NSString *upper = raw.uppercaseString;
    if ([upper containsString:@"NR"]) return @"NR";
    if ([upper containsString:@"LTE"]) return @"LTE";
    for (NSString *token in @[@"WCDMA", @"UMTS", @"UTRAN", @"HSPA", @"HSDPA", @"HSUPA", @"TD-SCDMA"]) {
        if ([upper containsString:token]) return @"3G";
    }
    for (NSString *token in @[@"GSM", @"GPRS", @"EDGE", @"GERAN"]) {
        if ([upper containsString:token]) return @"2G";
    }
    return nil;
}

static NSDictionary *BLRHLegacySignalRow(NSDictionary *row) {
    if (![row isKindOfClass:NSDictionary.class]) return nil;
    NSString *rawRAT = row[@"kCTCellMonitorCellRadioAccessTechnology"];
    NSString *rat = BLRHSignalRAT(rawRAT);
    NSString *type = row[@"kCTCellMonitorCellType"];
    NSString *role = [type isKindOfClass:NSString.class] ?
        ([type rangeOfString:@"Secondary" options:NSCaseInsensitiveSearch].location != NSNotFound ? @"secondary" :
         ([type rangeOfString:@"Serving" options:NSCaseInsensitiveSearch].location != NSNotFound ? @"serving" :
          ([type rangeOfString:@"Neighbor" options:NSCaseInsensitiveSearch].location != NSNotFound ? @"neighbor" : nil))) : nil;
    if (!rat || !role) return nil;
    NSMutableDictionary *item = [@{@"rat": rat, @"role": role, @"source": @"legacy"} mutableCopy];
    // Preserve the private CoreTelephony cell-type token for read-only
    // diagnostics. A "Secondary" token is useful evidence, but is not enough
    // by itself to claim a validated LTE SCC/PCC mapping on every firmware.
    if ([type isKindOfClass:NSString.class] && type.length > 0 && type.length <= 96)
        item[@"cell_type_raw"] = type;
    NSNumber *band = BLRHSignalNumber(row[@"kCTCellMonitorBandInfo"], 1, 1024, YES);
    if (band && floor(band.doubleValue) == band.doubleValue) item[@"band"] = band;
    NSNumber *rsrp = BLRHLegacyMetric(row, @[@"kCTCellMonitorRSRP", @"RSRP", @"rsrp"], -200, -20, YES);
    NSNumber *rsrq = BLRHLegacyMetric(row, @[@"kCTCellMonitorRSRQ", @"RSRQ", @"rsrq"], -60, 0, YES);
    NSNumber *rssi = BLRHLegacyMetric(row, @[@"kCTCellMonitorRSSI", @"RSSI", @"rssi"], -200, -20, YES);
    NSNumber *snr = BLRHLegacyMetric(row, @[@"kCTCellMonitorSNR", @"SNR", @"snr"], -100, 100, NO);
    NSNumber *rscp = [rat isEqualToString:@"3G"] ?
        BLRHLegacyMetric(row, @[@"kCTCellMonitorRSCP", @"RSCP", @"rscp"], -130, -20, YES) : nil;
    NSNumber *ecno = [rat isEqualToString:@"3G"] ?
        BLRHLegacyMetric(row, @[@"kCTCellMonitorEcNo", @"kCTCellMonitorECNO", @"EcNo", @"ECNO", @"ecno"], -40, 0, YES) : nil;
    if (rsrp) item[@"rsrp"] = rsrp;
    if (rsrq) item[@"rsrq"] = rsrq;
    if (rssi) item[@"rssi"] = rssi;
    if (snr) item[@"snr"] = snr;
    if (rscp) item[@"rscp"] = rscp;
    if (ecno) item[@"ecno"] = ecno;
    // These are opt-in radio measurement fields only. A missing or nonnumeric
    // CoreTelephony value stays absent; never derive IDs from band/frequency.
    NSDictionary<NSString *, NSArray<NSString *> *> *aliases = @{
        @"cell_id": @[@"kCTCellMonitorCellId"],
        @"physical_cell_id": @[@"kCTCellMonitorPCI", @"kCTCellMonitorPID"],
        @"psc": @[@"kCTCellMonitorPSC", @"kCTCellMonitorSCN"],
        @"tac": @[@"kCTCellMonitorTAC"],
        @"lac": @[@"kCTCellMonitorLAC"],
        @"channel": [rat isEqualToString:@"NR"]
          ? @[@"kCTCellMonitorNRARFCN", @"kCTCellMonitorChannelNumber"]
          : ([rat isEqualToString:@"3G"]
            ? @[@"kCTCellMonitorUARFCN", @"kCTCellMonitorChannelNumber"]
            : @[@"kCTCellMonitorARFCN", @"kCTCellMonitorChannelNumber"])
    };
    for (NSString *field in aliases) {
        if ([field isEqualToString:@"physical_cell_id"] &&
            ![@[@"LTE", @"NR"] containsObject:rat]) continue;
        if ([field isEqualToString:@"psc"] && ![rat isEqualToString:@"3G"]) continue;
        double upper = [field isEqualToString:@"physical_cell_id"] ? 1007 :
                       ([field isEqualToString:@"psc"] ? 511 :
                        ([field isEqualToString:@"tac"] || [field isEqualToString:@"lac"] ? 65535 :
                         ([field isEqualToString:@"cell_id"] ? 68719476735.0 : 3279165)));
        for (NSString *key in aliases[field]) {
            NSNumber *number = BLRHSignalNumber(row[key], 0, upper, NO);
            if (!number || floor(number.doubleValue) != number.doubleValue) continue;
            item[field] = number;
            item[[field stringByAppendingString:@"_source_key"]] = key;
            break;
        }
    }
    return item;
}

@interface BLTelephonyManager ()
- (NSDictionary *)queryCoreTelephonyWithRatSelection:(BOOL)includeRatSelection;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedNRBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeNRBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingNRBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousNRBands;
@property (nonatomic, assign, readwrite) BOOL supports5G;
@property (nonatomic, copy, readwrite) NSString *radioAccessTechnology;
@property (nonatomic, copy, readwrite) NSString *servingBand;
@property (nonatomic, copy, readwrite) NSString *networkMode;
@property (nonatomic, copy, readwrite) NSString *statusText;
@property (nonatomic, copy, readwrite) NSString *detailText;
@property (nonatomic, assign, readwrite) BOOL hasReadState;
@property (nonatomic, assign, readwrite) BOOL busy;
@property (nonatomic, strong) dispatch_queue_t workerQueue;
@end

@implementation BLTelephonyManager

+ (instancetype)sharedManager {
    static BLTelephonyManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] initPrivate]; });
    return manager;
}

- (instancetype)init { return [BLTelephonyManager sharedManager]; }

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _workerQueue = dispatch_queue_create("com.gokuencinar.bandlock.telephony", DISPATCH_QUEUE_SERIAL);
        NSDictionary *state = BLReadState();
        // Modem capabilities must be read live after each app launch.
        _supportedBands = @[];
        _activeBands = @[];
        _pendingBands = @[];
        _previousBands = BLSortedBands(state[@"previousLTE"]);
        _supportedNRBands = @[];
        _activeNRBands = @[];
        _pendingNRBands = @[];
        _previousNRBands = BLSortedBands(state[@"previousNR"]);
        _supports5G = NO;
        _radioAccessTechnology = @"—";
        _servingBand = @"—";
        _networkMode = BLT(@"Sin consultar", @"Not queried");
        _statusText = BLT(@"Pulsa Actualizar", @"Tap Refresh");
        _detailText = BLT(@"BandLock no modifica el módem al abrirse.", @"BandLock does not change the modem when opened.");
        _hasReadState = NO;
        _busy = NO;
    }
    return self;
}

- (NSDictionary *)readRatSelectionFromClient:(id)client context:(id)context {
    // On iOS 15/16 CoreTelephonyClient can synchronously fetch a
    // CTRatSelection for the exact CTServiceDescriptor of this data
    // subscription. Prefer this to an async callback that may be late
    // during CommCenter re-registration following LTE band changes.
    SEL maskSelector = NSSelectorFromString(@"getRatSelectionMask:error:");
    Class descriptorClass = NSClassFromString(@"CTServiceDescriptor");
    SEL fromContext = NSSelectorFromString(@"descriptorWithSubscriptionContext:");
    NSString *syncStatus = @"unavailable";
    NSString *syncKind = @"missing";
    NSNumber *maskByte = nil;
    if ([client respondsToSelector:maskSelector] &&
        [descriptorClass respondsToSelector:fromContext]) {
        @try {
            id descriptor = ((id (*)(id, SEL, id))objc_msgSend)((id)descriptorClass, fromContext, context);
            if (descriptor) {
                NSError *error = nil;
                id ratMask = BLMsgObjErr(client, maskSelector, descriptor, &error);
                SEL selected = NSSelectorFromString(@"selection");
                SEL preferredSelector = NSSelectorFromString(@"preferred");
                id value = ratMask && [ratMask respondsToSelector:selected]
                    ? BLMsg0(ratMask, selected) : nil;
                id preferredValue = ratMask && [ratMask respondsToSelector:preferredSelector]
                    ? BLMsg0(ratMask, preferredSelector) : nil;
                syncKind = BLRHRatSelectionKind(value);
                SEL rawMaskSelector = NSSelectorFromString(@"mask");
                NSMethodSignature *maskSignature = ratMask && [ratMask respondsToSelector:rawMaskSelector]
                    ? [ratMask methodSignatureForSelector:rawMaskSelector] : nil;
                // CTRatSelection.mask is a scalar unsigned char. Record the
                // number for troubleshooting only; mask bits do NOT prove LTE.
                if (maskSignature && strcmp(maskSignature.methodReturnType, "C") == 0 &&
                    maskSignature.methodReturnLength == sizeof(unsigned char)) {
                    unsigned char rawMask = ((unsigned char (*)(id, SEL))objc_msgSend)(ratMask, rawMaskSelector);
                    maskByte = @(rawMask);
                }
                BOOL knownValue = [@[@"lte", @"automatic", @"umts", @"gsm", @"nr", @"nr_sa", @"nr_nsa"]
                                    containsObject:syncKind];
                if (!error && knownValue) {
                    NSMutableDictionary *answer = [@{@"selection": value,
                        @"preferred": [preferredValue isKindOfClass:NSString.class] ? preferredValue : @"—",
                        @"source": @"mask_sync", @"status": @"ok",
                        @"selection_kind": syncKind, @"sync_kind": syncKind,
                        @"sync_status": @"ok", @"async_status": @"not_needed",
                        @"async_kind": @"not_needed"} mutableCopy];
                    if (maskByte) answer[@"mask_byte"] = maskByte;
                    return answer;
                }
                syncStatus = error ? @"error" : ([syncKind isEqualToString:@"explicit_unknown"]
                    ? @"explicit_unknown" : @"unrecognized_or_missing");
            } else {
                syncStatus = @"descriptor_unavailable";
            }
        } @catch (__unused NSException *exception) {
            syncStatus = @"exception";
        }
    }

    SEL selector = NSSelectorFromString(@"getRatSelection:completion:");
    if (![client respondsToSelector:selector]) {
        return @{@"selection": @"—", @"preferred": @"—",
                 @"source": @"none", @"status": syncStatus,
                 @"selection_kind": @"missing", @"sync_kind": syncKind,
                 @"sync_status": syncStatus, @"async_status": @"unavailable",
                 @"async_kind": @"missing"};
    }
    __block NSString *selection = nil;
    __block NSString *preferred = nil;
    __block NSString *callbackStatus = @"timeout";
    __block NSString *callbackKind = @"missing";
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    BLMsgGetRatSelection(client, selector, context, ^(NSString *currentSelection, NSString *preferredSelection, NSError *error) {
        if (!error) {
            selection = [currentSelection isKindOfClass:NSString.class] ? [currentSelection copy] : nil;
            preferred = [preferredSelection isKindOfClass:NSString.class] ? [preferredSelection copy] : nil;
            callbackKind = BLRHRatSelectionKind(currentSelection);
            callbackStatus = [callbackKind isEqualToString:@"explicit_unknown"]
                ? @"explicit_unknown" : ([callbackKind isEqualToString:@"missing"] ||
                   [callbackKind isEqualToString:@"empty"] ? @"empty" :
                   ([callbackKind isEqualToString:@"unrecognized"] ||
                    [callbackKind isEqualToString:@"invalid_type"] ? @"unrecognized" : @"ok"));
        } else {
            callbackStatus = @"error";
        }
        dispatch_semaphore_signal(semaphore);
    });
    long wait = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    if (wait != 0) {
        // The callback may arrive after the timeout. Do not read its
        // captured variables or misclassify the modem state as changed.
        return @{@"selection": @"—", @"preferred": @"—",
                 @"source": @"async_fallback", @"status": @"timeout",
                 @"mask_status": syncStatus, @"sync_status": syncStatus,
                 @"sync_kind": syncKind, @"async_status": @"timeout",
                 @"async_kind": @"missing", @"selection_kind": @"missing"};
    }
    NSMutableDictionary *answer = [@{@"selection": selection ?: @"—",
             @"preferred": preferred ?: @"—",
             @"source": @"async_fallback", @"status": callbackStatus,
             @"mask_status": syncStatus, @"sync_status": syncStatus,
             @"sync_kind": syncKind, @"async_status": callbackStatus,
             @"async_kind": callbackKind,
             @"selection_kind": callbackKind} mutableCopy];
    if (maskByte) answer[@"mask_byte"] = maskByte;
    return answer;
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
    return [self queryCoreTelephonyWithRatSelection:YES];
}

// Passive observation needs the active data context, band/cell information
// and typed signal, but not the configured RAT selection. On the test iPhone
// both RAT getters report Unknown; calling the async fallback on each sample
// needlessly stalls observation without strengthening its read-only gate.
- (NSDictionary *)queryCoreTelephonyForPassiveObservation {
    return [self queryCoreTelephonyWithRatSelection:NO];
}

// Changing the selected RAT does not require a band-info read or a prior RAT
// getter. The 1.6 iOS18 preflight added these calls on top of the 1.5 path,
// causing failures before the setter was ever reached on busy CommCenter
// instances. Fetch only the context required by the original setter.
- (NSDictionary *)queryContextForRatChange {
    void *handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_NOW | RTLD_LOCAL);
    if (!handle) return @{@"error": @"CoreTelephony no está disponible"};
    Class clientClass = NSClassFromString(@"CoreTelephonyClient");
    id client = clientClass ? [[clientClass alloc] init] : nil;
    if (!client) return @{@"error": @"CoreTelephonyClient no está disponible"};
    NSError *contextError = nil;
    id context = nil;
    SEL current = NSSelectorFromString(@"getCurrentDataSubscriptionContextSync:");
    if ([client respondsToSelector:current]) context = BLMsgErr(client, current, &contextError);
    if (!context) {
        contextError = nil;
        SEL preferred = NSSelectorFromString(@"getPreferredDataSubscriptionContextSync:");
        if ([client respondsToSelector:preferred]) context = BLMsgErr(client, preferred, &contextError);
    }
    if (!context) return @{@"error": contextError.localizedDescription ?: @"No hay línea móvil activa"};
    return @{@"client": client, @"context": context};
}

- (NSDictionary *)queryCoreTelephonyWithRatSelection:(BOOL)includeRatSelection {
    void *handle = dlopen("/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony", RTLD_NOW | RTLD_LOCAL);
    if (!handle) return @{@"error": BLT(@"No se pudo cargar CoreTelephony.", @"Could not load CoreTelephony.")};

    id ratRaw = nil;
    id networkInfo = nil;
    Class networkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    if (networkInfoClass) {
        networkInfo = [[networkInfoClass alloc] init];
        SEL ratSelector = NSSelectorFromString(@"serviceCurrentRadioAccessTechnology");
        if ([networkInfo respondsToSelector:ratSelector]) ratRaw = BLMsg0(networkInfo, ratSelector);
    }

    Class clientClass = NSClassFromString(@"CoreTelephonyClient");
    if (!clientClass) return @{@"error": BLT(@"CoreTelephonyClient no está disponible.", @"CoreTelephonyClient is unavailable.")};
    id client = [[clientClass alloc] init];
    if (!client) return @{@"error": BLT(@"No se pudo crear CoreTelephonyClient.", @"Could not create CoreTelephonyClient.")};

    NSError *contextError = nil;
    id context = nil;
    SEL currentSelector = NSSelectorFromString(@"getCurrentDataSubscriptionContextSync:");
    if ([client respondsToSelector:currentSelector]) context = BLMsgErr(client, currentSelector, &contextError);
    if (!context) {
        contextError = nil;
        SEL preferredSelector = NSSelectorFromString(@"getPreferredDataSubscriptionContextSync:");
        if ([client respondsToSelector:preferredSelector]) context = BLMsgErr(client, preferredSelector, &contextError);
    }
    if (!context) return @{@"error":
        ([contextError.domain isEqualToString:NSPOSIXErrorDomain] && contextError.code == EAGAIN)
            ? @"CommCenter está ocupado temporalmente. Inténtalo de nuevo."
            : (contextError ? contextError.description : BLT(@"No hay contexto de datos activo.", @"No active data subscription context."))};

    BOOL supports5G = NO;
    NSError *supports5GError = nil;
    SEL supports5GSelector = NSSelectorFromString(@"getSupports5G:error:");
    // Do not call a private NR capability getter on known LTE-only hardware.
    if (!BLDeviceIsKnownLTEOnly() && [client respondsToSelector:supports5GSelector]) {
        id supports5GValue = BLMsgObjErr(client, supports5GSelector, context, &supports5GError);
        if (!supports5GError && [supports5GValue respondsToSelector:@selector(boolValue)]) supports5G = [supports5GValue boolValue];
    }

    SEL bandSelector = NSSelectorFromString(@"getBandInfo:error:");
    if (![client respondsToSelector:bandSelector]) return @{@"error": @"getBandInfo:error: unavailable"};
    NSError *bandError = nil;
    id bandInfo = nil;
    // Read-only retries only. EAGAIN (35) means the current modem request is
    // temporarily unavailable, NOT a file permissions failure. Never loop a
    // setter and never repeat a write as part of these read-only attempts.
    for (NSUInteger attempt = 0; attempt < 3; attempt++) {
        bandError = nil;
        bandInfo = BLMsgObjErr(client, bandSelector, context, &bandError);
        if (bandInfo || ![bandError.domain isEqualToString:NSPOSIXErrorDomain] ||
            bandError.code != EAGAIN) break;
        if (attempt < 2) [NSThread sleepForTimeInterval:0.18];
    }
    // Band metadata is mandatory when preparing an actual band write. For
    // passive signal observation on 2G/3G (and during CommCenter EAGAIN),
    // cellular metrics may still be available from copyCellInfo and typed
    // signal APIs. Do not suppress those measurements solely for lack of
    // LTE/NR band capabilities.
    if (!bandInfo && includeRatSelection) return @{@"error":
        ([bandError.domain isEqualToString:NSPOSIXErrorDomain] && bandError.code == EAGAIN)
            ? @"El módem está ocupado temporalmente. Reintenta la consulta."
            : (bandError ? bandError.description : @"getBandInfo:error: returned nil")};

    NSDictionary *ratSelection = includeRatSelection
        ? [self readRatSelectionFromClient:client context:context]
        : @{@"selection": @"—", @"preferred": @"—",
            @"source": @"none", @"status": @"not_needed",
            @"selection_kind": @"missing", @"sync_kind": @"not_needed",
            @"sync_status": @"not_needed", @"async_kind": @"not_needed",
            @"async_status": @"not_needed"};
    id cellInfo = [self copyCellInfoFromClient:client context:context];
    NSString *operatorName = BLOperatorNameFromNetworkInfo(networkInfo);
    return @{@"client": client,
             @"context": context,
             @"bandInfo": bandInfo ?: NSNull.null,
             @"ratRaw": ratRaw ?: NSNull.null,
             @"cellInfo": cellInfo ?: NSNull.null,
             @"operatorName": operatorName ?: NSNull.null,
             @"ratSelection": ratSelection[@"selection"] ?: @"—",
             @"ratPreferred": ratSelection[@"preferred"] ?: @"—",
             @"ratReadSource": ratSelection[@"source"] ?: @"none",
             @"ratReadStatus": ratSelection[@"status"] ?: @"unavailable",
             @"ratMaskStatus": ratSelection[@"mask_status"] ?: @"not_needed",
             @"ratSelectionKind": ratSelection[@"selection_kind"] ?: @"missing",
             @"ratSyncKind": ratSelection[@"sync_kind"] ?: @"missing",
             @"ratSyncStatus": ratSelection[@"sync_status"] ?: @"unavailable",
             @"ratAsyncKind": ratSelection[@"async_kind"] ?: @"missing",
             @"ratAsyncStatus": ratSelection[@"async_status"] ?: @"unavailable",
             @"ratMaskByte": ratSelection[@"mask_byte"] ?: NSNull.null,
             @"supports5G": @(supports5G)};
}

- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    NSDictionary *supported = [bandInfo respondsToSelector:supportedSelector] ? BLMsg0(bandInfo, supportedSelector) : nil;
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;
    NSArray *supportedLTE = BLSortedBands(supported[BLLTERAT]);
    NSArray *activeLTE = BLSortedBands(active[BLLTERAT]);
    NSArray *supportedNR = BLNRBandsFromDictionary(supported);
    NSArray *activeNR = BLNRBandsFromDictionary(active);
    NSString *kind = BLRHRatSelectionKind(query[@"ratSelection"]);
    NSString *preferred = [query[@"ratPreferred"] isKindOfClass:[NSString class]] ? query[@"ratPreferred"] : @"—";
    BOOL supports5G = !BLDeviceIsKnownLTEOnly() &&
        ([query[@"supports5G"] boolValue] || supportedNR.count > 0);
    if (!supports5G) { supportedNR = @[]; activeNR = @[]; }
    NSString *mode = BLT(@"No disponible", @"Unavailable");
    NSString *modeCode = @"unknown";
    if ([kind isEqualToString:@"automatic"] && supports5G &&
        [preferred rangeOfString:@"NR" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        mode = @"5G Auto"; modeCode = @"5g-auto";
    } else if ([kind isEqualToString:@"automatic"]) {
        mode = BLT(@"Automático", @"Automatic"); modeCode = @"automatic";
    } else if (supports5G && [kind isEqualToString:@"nr_sa"]) {
        mode = @"5G Only (SA)"; modeCode = @"5g-only";
    } else if (supports5G && ([kind isEqualToString:@"nr_nsa"] || [kind isEqualToString:@"nr"])) {
        mode = @"5G On"; modeCode = @"5g-on";
    } else if ([kind isEqualToString:@"lte"]) {
        mode = BLT(@"Solo LTE / 4G", @"LTE / 4G only"); modeCode = @"lte";
    } else if ([kind isEqualToString:@"umts"]) {
        mode = BLT(@"Solo 3G", @"3G only"); modeCode = @"3g";
    } else if ([kind isEqualToString:@"gsm"]) {
        mode = BLT(@"Solo 2G", @"2G only"); modeCode = @"2g";
    }
    id ratRaw = query[@"ratRaw"] == NSNull.null ? nil : query[@"ratRaw"];
    id cellInfo = query[@"cellInfo"] == NSNull.null ? nil : query[@"cellInfo"];
    return @{@"supported": supportedLTE,
             @"active": activeLTE,
             @"supported_nr": supportedNR,
             @"active_nr": activeNR,
             @"supports_5g": @(supports5G),
             @"rat": BLHumanRAT(ratRaw) ?: @"—",
             @"serving": BLServingBandFromCellInfo(cellInfo) ?: @"—",
             @"operator_name": [query[@"operatorName"] isKindOfClass:NSString.class] ? query[@"operatorName"] : @"",
             @"mode": mode,
             @"mode_code": modeCode};
}

- (void)consumeSnapshotOnMain:(NSDictionary *)snapshot resetPending:(BOOL)resetPending {
    self.supportedBands = snapshot[@"supported"] ?: @[];
    self.activeBands = snapshot[@"active"] ?: @[];
    self.supportedNRBands = snapshot[@"supported_nr"] ?: @[];
    self.activeNRBands = snapshot[@"active_nr"] ?: @[];
    self.supports5G = [snapshot[@"supports_5g"] boolValue];
    self.radioAccessTechnology = snapshot[@"rat"] ?: @"—";
    self.servingBand = snapshot[@"serving"] ?: @"—";
    self.networkMode = snapshot[@"mode"] ?: BLT(@"No disponible", @"Unavailable");
    self.hasReadState = YES;
    if (resetPending || !self.pendingBands.count) self.pendingBands = self.activeBands;
    if (resetPending || !self.pendingNRBands.count) self.pendingNRBands = self.activeNRBands;
    // supported/active/pending are runtime state; do not persist stale modem data.
}

- (void)finishBusyWithSuccess:(BOOL)success message:(NSString *)message completion:(BLActionCompletion)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.busy = NO;
        self.statusText = success ? BLT(@"Listo", @"Ready") : BLT(@"Error", @"Error");
        self.detailText = message ?: @"";
        if (completion) completion(success, message ?: @"");
    });
}

- (void)refreshWithCompletion:(BLActionCompletion)completion {
    if (self.busy) { if (completion) completion(NO, BLT(@"Hay una operación en curso.", @"An operation is already running.")); return; }
    self.busy = YES;
    self.statusText = BLT(@"Consultando…", @"Refreshing…");
    dispatch_async(self.workerQueue, ^{
        NSDictionary *query = [self queryCoreTelephony];
        NSString *error = query[@"error"];
        if (error) { [self finishBusyWithSuccess:NO message:error completion:completion]; return; }
        NSDictionary *snapshot = [self snapshotFromQuery:query];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self consumeSnapshotOnMain:snapshot resetPending:YES];
            self.busy = NO;
            self.statusText = BLT(@"Actualizado", @"Updated");
            self.detailText = BLT(@"Estado del módem leído correctamente.", @"Modem state read successfully.");
            [self writeLogAction:@"refresh" detail:self.detailText];
            if (completion) completion(YES, self.detailText);
        });
    });
}

- (void)setPendingBands:(NSArray<NSNumber *> *)bands {
    @try {
        self.pendingBands = BLSortedBands(bands);
        self.statusText = BLT(@"Selección preparada", @"Selection prepared");
        self.detailText = BLBandList(self.pendingBands);
    }
    @catch (NSException *exception) {
        self.statusText = BLT(@"Selección no válida", @"Invalid selection");
        self.detailText = exception.reason ?: exception.name ?: @"NSException";
    }
}

- (void)setPendingNRBands:(NSArray<NSNumber *> *)bands {
    @try {
        self.pendingNRBands = BLSortedBands(bands);
        self.statusText = BLT(@"Selección 5G preparada", @"5G selection prepared");
        self.detailText = BLNRBandList(self.pendingNRBands);
    }
    @catch (NSException *exception) {
        self.statusText = BLT(@"Selección no válida", @"Invalid selection");
        self.detailText = exception.reason ?: exception.name ?: @"NSException";
    }
}

- (BOOL)setRatSelectionSync:(NSString *)selection preferred:(NSString *)preferred errorText:(NSString **)errorText {
    dispatch_semaphore_t gate = BLRatWriteGate();
    dispatch_semaphore_wait(gate, DISPATCH_TIME_FOREVER);
    @try {
        // CommCenter rejects back-to-back private RAT writes with EAGAIN/35.
        // Space explicit user/scan/recovery requests BEFORE the next write;
        // this is not a retry of a failed write and never repeats a setter
        // unless a distinct caller requested another mode.
        if (BLRatLastWriteStartedAt > 0) {
            NSTimeInterval elapsed = CFAbsoluteTimeGetCurrent() - BLRatLastWriteStartedAt;
            NSTimeInterval remaining = BLRatWriteQuietPeriod - elapsed;
            if (remaining > 0) [NSThread sleepForTimeInterval:remaining];
        }

        NSDictionary *query = [self queryContextForRatChange];
        if (query[@"error"]) { if (errorText) *errorText = query[@"error"]; return NO; }
        id client = query[@"client"];
        id context = query[@"context"];
        SEL setter = NSSelectorFromString(@"setRatSelection:selection:preferred:completion:");
        if (![client respondsToSelector:setter]) { if (errorText) *errorText = @"setRatSelection unavailable"; return NO; }
        __block NSError *callbackError = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        BLRatLastWriteStartedAt = CFAbsoluteTimeGetCurrent();
        BLMsgSetRatSelection(client, setter, context, selection, preferred, ^(NSError *error) { callbackError = error; dispatch_semaphore_signal(semaphore); });
        long wait = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)));
        if (wait != 0) { if (errorText) *errorText = BLT(@"Tiempo de espera agotado.", @"Operation timed out."); return NO; }
        if (callbackError) {
            if (errorText) *errorText = [callbackError.domain isEqualToString:NSPOSIXErrorDomain] &&
                callbackError.code == EAGAIN
                ? @"CommCenter está ocupado temporalmente (EAGAIN/35). No se repetirá la escritura."
                : callbackError.description;
            return NO;
        }
        return YES;
    } @finally {
        dispatch_semaphore_signal(gate);
    }
}

- (BOOL)setModeCodeSync:(NSString *)mode errorText:(NSString **)errorText {
    if (![mode isKindOfClass:NSString.class]) {
        if (errorText) *errorText = @"Modo de red no válido";
        return NO;
    }
    NSString *selection = BLRATAutomatic;
    NSString *preferred = nil;
    if ([mode isEqualToString:@"automatic"]) {
        selection = BLRATAutomatic;
    } else if ([mode isEqualToString:@"2g"]) {
        selection = BLRATGSM;
        preferred = BLGSMRAT;
    } else if ([mode isEqualToString:@"3g"]) {
        selection = BLRATUMTS;
        preferred = BLUTRANRAT;
    } else if ([mode isEqualToString:@"lte"]) {
        selection = BLRATLTE;
        preferred = BLLTERAT;
    } else if ([mode isEqualToString:@"5g-auto"]) {
        selection = BLRATAutomatic;
        preferred = BLNRRAT;
    } else if ([mode isEqualToString:@"5g-on"]) {
        selection = BLRATNR;
        preferred = BLNRRAT;
    } else if ([mode isEqualToString:@"5g-only"]) {
        selection = BLRATNRSA;
        preferred = BLNRRAT;
    } else {
        if (errorText) *errorText = @"Modo de red no válido";
        return NO;
    }
    return [self setRatSelectionSync:selection preferred:preferred errorText:errorText];
}

- (NSArray<NSNumber *> *)supportedBandsForTargetRAT:(NSString *)targetRAT
                                          fromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL selector = NSSelectorFromString(@"supportedBands");
    NSDictionary *supported = [bandInfo respondsToSelector:selector] ? BLMsg0(bandInfo, selector) : nil;
    NSString *key = BLBandKeyForTargetRAT(targetRAT, supported);
    return key.length ? BLSortedBands(supported[key]) : @[];
}

- (NSArray<NSNumber *> *)activeBandsForTargetRAT:(NSString *)targetRAT
                                       fromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL selector = NSSelectorFromString(@"activeBands");
    NSDictionary *active = [bandInfo respondsToSelector:selector] ? BLMsg0(bandInfo, selector) : nil;
    NSString *key = BLBandKeyForTargetRAT(targetRAT, active);
    return key.length ? BLSortedBands(active[key]) : @[];
}

- (BOOL)writeBands:(NSArray<NSNumber *> *)bands
      forTargetRAT:(NSString *)targetRAT
        usingQuery:(NSDictionary *)query
         errorText:(NSString **)errorText {
    id client = query[@"client"];
    id context = query[@"context"];
    id currentBandInfo = query[@"bandInfo"];
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    NSDictionary *currentActive = [currentBandInfo respondsToSelector:activeSelector]
        ? BLMsg0(currentBandInfo, activeSelector) : nil;
    NSDictionary *currentSupported = [currentBandInfo respondsToSelector:supportedSelector]
        ? BLMsg0(currentBandInfo, supportedSelector) : nil;
    if (![currentActive isKindOfClass:NSDictionary.class] ||
        ![currentSupported isKindOfClass:NSDictionary.class]) {
        if (errorText) *errorText = @"CTBandInfo no expone bandas configurables para este barrido";
        return NO;
    }
    NSString *key = BLBandKeyForTargetRAT(targetRAT, currentSupported);
    if (!key.length || !currentActive[key]) {
        if (errorText) *errorText = @"El módem no expone una máscara configurable para esta tecnología";
        return NO;
    }
    NSArray<NSNumber *> *supported = BLSortedBands(currentSupported[key]);
    if (!bands.count || !supported.count) {
        if (errorText) *errorText = @"Inventario de bandas vacío";
        return NO;
    }
    NSSet *supportedSet = [NSSet setWithArray:supported];
    for (NSNumber *band in bands) {
        if (![band isKindOfClass:NSNumber.class] || band.integerValue <= 0 ||
            band.integerValue > 1024 || ![supportedSet containsObject:band]) {
            if (errorText) *errorText = @"La banda solicitada no está en el inventario del módem";
            return NO;
        }
    }

    NSMutableDictionary *newActive = [currentActive mutableCopy];
    newActive[key] = BLSortedBands(bands);
    id modifiedBandInfo = nil;
    Class bandInfoClass = NSClassFromString(@"CTBandInfo");
    SEL initSelector = NSSelectorFromString(@"initWithSupported:andActiveBands:");
    id allocated = bandInfoClass ? [bandInfoClass alloc] : nil;
    if (allocated && [allocated respondsToSelector:initSelector]) {
        modifiedBandInfo = BLMsg2(allocated, initSelector, currentSupported, newActive);
    }
    if (!modifiedBandInfo) {
        modifiedBandInfo = [currentBandInfo copy];
        SEL setActiveDictionary = NSSelectorFromString(@"setFActiveBands:");
        if (modifiedBandInfo && [modifiedBandInfo respondsToSelector:setActiveDictionary]) {
            BLMsgSetObj(modifiedBandInfo, setActiveDictionary, newActive);
        } else modifiedBandInfo = nil;
    }
    if (!modifiedBandInfo) {
        if (errorText) *errorText = @"No se pudo construir CTBandInfo";
        return NO;
    }
    SEL setter = NSSelectorFromString(@"setActiveBandInfo:bands:error:");
    if (![client respondsToSelector:setter]) {
        if (errorText) *errorText = @"setActiveBandInfo no está disponible";
        return NO;
    }
    NSError *setError = nil;
    BLMsgSetActiveBandInfo(client, setter, context, modifiedBandInfo, &setError);
    if (setError) {
        if (errorText) *errorText = setError.description;
        return NO;
    }
    return YES;
}

- (NSDictionary *)bandConfigurationSnapshotFromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector]
        ? BLSafeBandDictionary(BLMsg0(bandInfo, activeSelector)) : nil;
    NSDictionary *supported = [bandInfo respondsToSelector:supportedSelector]
        ? BLSafeBandDictionary(BLMsg0(bandInfo, supportedSelector)) : nil;
    if (!active || !supported) return nil;
    return @{@"active": active, @"supported": supported};
}

- (BOOL)restoreBandConfiguration:(NSDictionary *)snapshot
                      usingQuery:(NSDictionary *)query
                       errorText:(NSString **)errorText {
    NSDictionary *active = BLSafeBandDictionary(snapshot[@"active"]);
    NSDictionary *supported = BLSafeBandDictionary(snapshot[@"supported"]);
    if (!active || !supported) {
        if (errorText) *errorText = @"Configuración de bandas de recuperación no válida";
        return NO;
    }
    for (NSString *key in active) {
        NSArray *activeBands = active[key];
        NSArray *supportedBands = supported[key];
        if (!supportedBands ||
            ![[NSSet setWithArray:activeBands] isSubsetOfSet:[NSSet setWithArray:supportedBands]]) {
            if (errorText) *errorText = @"La configuración original no es coherente con su inventario guardado";
            return NO;
        }
    }

    id client = query[@"client"];
    id context = query[@"context"];
    Class bandInfoClass = NSClassFromString(@"CTBandInfo");
    SEL initSelector = NSSelectorFromString(@"initWithSupported:andActiveBands:");
    id allocated = bandInfoClass ? [bandInfoClass alloc] : nil;
    id restoredBandInfo = allocated && [allocated respondsToSelector:initSelector]
        ? BLMsg2(allocated, initSelector, supported, active) : nil;
    if (!restoredBandInfo) {
        if (errorText) *errorText = @"No se pudo reconstruir CTBandInfo para recuperación";
        return NO;
    }
    SEL setter = NSSelectorFromString(@"setActiveBandInfo:bands:error:");
    if (![client respondsToSelector:setter]) {
        if (errorText) *errorText = @"setActiveBandInfo no está disponible";
        return NO;
    }
    NSError *setError = nil;
    BLMsgSetActiveBandInfo(client, setter, context, restoredBandInfo, &setError);
    if (setError) {
        if (errorText) *errorText = setError.description;
        return NO;
    }
    return YES;
}

- (void)setNetworkModeSelection:(NSString *)selection preferred:(NSString *)preferred completion:(BLActionCompletion)completion {
    if (self.busy) { if (completion) completion(NO, BLT(@"Hay una operación en curso.", @"An operation is already running.")); return; }
    self.busy = YES;
    dispatch_async(self.workerQueue, ^{
        NSString *error = nil;
        if (![self setRatSelectionSync:selection preferred:preferred errorText:&error]) { [self finishBusyWithSuccess:NO message:error completion:completion]; return; }
        [NSThread sleepForTimeInterval:0.35];
        NSDictionary *verify = [self queryCoreTelephony];
        if (verify[@"error"]) { [self finishBusyWithSuccess:NO message:verify[@"error"] completion:completion]; return; }
        NSDictionary *snapshot = [self snapshotFromQuery:verify];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self consumeSnapshotOnMain:snapshot resetPending:NO];
            self.busy = NO;
            self.statusText = BLT(@"Modo actualizado", @"Mode updated");
            self.detailText = self.networkMode;
            [self writeLogAction:@"network-mode" detail:self.networkMode];
            if (completion) completion(YES, self.networkMode);
        });
    });
}

- (void)setNetworkModeAutomatic:(BLActionCompletion)completion { [self setNetworkModeSelection:BLRATAutomatic preferred:nil completion:completion]; }
- (void)setNetworkModeLTEOnly:(BLActionCompletion)completion { [self setNetworkModeSelection:BLRATLTE preferred:BLLTERAT completion:completion]; }
- (void)setNetworkMode5GAuto:(BLActionCompletion)completion { [self setNetworkModeSelection:BLRATAutomatic preferred:BLNRRAT completion:completion]; }
- (void)setNetworkMode5GOn:(BLActionCompletion)completion { [self setNetworkModeSelection:BLRATNR preferred:BLNRRAT completion:completion]; }
- (void)setNetworkMode5GOnly:(BLActionCompletion)completion { [self setNetworkModeSelection:BLRATNRSA preferred:BLNRRAT completion:completion]; }

- (BOOL)writeLTEBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText {
    id client = query[@"client"];
    id context = query[@"context"];
    id currentBandInfo = query[@"bandInfo"];
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    NSDictionary *currentActive = [currentBandInfo respondsToSelector:activeSelector] ? BLMsg0(currentBandInfo, activeSelector) : nil;
    NSDictionary *currentSupported = [currentBandInfo respondsToSelector:supportedSelector] ? BLMsg0(currentBandInfo, supportedSelector) : nil;
    if (![currentActive isKindOfClass:[NSDictionary class]]) { if (errorText) *errorText = @"Invalid CTBandInfo ActiveBands"; return NO; }
    NSMutableDictionary *newActive = [currentActive mutableCopy];
    newActive[BLLTERAT] = bands;
    // Build a fresh CTBandInfo first. Mutating a copy with setFActiveBands:
    // can widen the active set but, on this iOS 16.3 modem, does not reliably
    // remove bands when narrowing the selection again.
    id modifiedBandInfo = nil;
    Class bandInfoClass = NSClassFromString(@"CTBandInfo");
    SEL initSelector = NSSelectorFromString(@"initWithSupported:andActiveBands:");
    id allocated = bandInfoClass ? [bandInfoClass alloc] : nil;
    if (allocated && [allocated respondsToSelector:initSelector] && [currentSupported isKindOfClass:[NSDictionary class]]) {
        modifiedBandInfo = BLMsg2(allocated, initSelector, currentSupported, newActive);
    }

    // Fallback for devices where the initializer is unavailable.
    if (!modifiedBandInfo) {
        modifiedBandInfo = [currentBandInfo copy];
        SEL setActiveDictionary = NSSelectorFromString(@"setFActiveBands:");
        if (modifiedBandInfo && [modifiedBandInfo respondsToSelector:setActiveDictionary]) {
            BLMsgSetObj(modifiedBandInfo, setActiveDictionary, newActive);
        } else modifiedBandInfo = nil;
    }
    if (!modifiedBandInfo) { if (errorText) *errorText = BLT(@"No se pudo construir CTBandInfo.", @"Could not construct CTBandInfo."); return NO; }
    SEL setter = NSSelectorFromString(@"setActiveBandInfo:bands:error:");
    if (![client respondsToSelector:setter]) { if (errorText) *errorText = @"setActiveBandInfo unavailable"; return NO; }
    NSError *setError = nil;
    BLMsgSetActiveBandInfo(client, setter, context, modifiedBandInfo, &setError);
    if (setError) { if (errorText) *errorText = setError.description; return NO; }
    return YES;
}

- (NSArray<NSNumber *> *)activeLTEFromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;
    return BLSortedBands(active[BLLTERAT]);
}

- (BOOL)writeNRBands:(NSArray<NSNumber *> *)bands usingQuery:(NSDictionary *)query errorText:(NSString **)errorText {
    id client = query[@"client"];
    id context = query[@"context"];
    id currentBandInfo = query[@"bandInfo"];
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    NSDictionary *currentActive = [currentBandInfo respondsToSelector:activeSelector] ? BLMsg0(currentBandInfo, activeSelector) : nil;
    NSDictionary *currentSupported = [currentBandInfo respondsToSelector:supportedSelector] ? BLMsg0(currentBandInfo, supportedSelector) : nil;
    if (![currentActive isKindOfClass:[NSDictionary class]] || ![currentSupported isKindOfClass:[NSDictionary class]]) {
        if (errorText) *errorText = @"Invalid CTBandInfo NR dictionaries";
        return NO;
    }
    NSString *nrKey = BLNRBandKey(currentSupported);
    if (!nrKey.length) {
        if (errorText) *errorText = BLT(@"El módem no reporta un grupo de bandas 5G NR configurable.", @"The modem does not report a configurable 5G NR band group.");
        return NO;
    }
    NSMutableDictionary *newActive = [currentActive mutableCopy];
    newActive[nrKey] = bands;

    id modifiedBandInfo = nil;
    Class bandInfoClass = NSClassFromString(@"CTBandInfo");
    SEL initSelector = NSSelectorFromString(@"initWithSupported:andActiveBands:");
    id allocated = bandInfoClass ? [bandInfoClass alloc] : nil;
    if (allocated && [allocated respondsToSelector:initSelector]) modifiedBandInfo = BLMsg2(allocated, initSelector, currentSupported, newActive);
    if (!modifiedBandInfo) {
        modifiedBandInfo = [currentBandInfo copy];
        SEL setActiveDictionary = NSSelectorFromString(@"setFActiveBands:");
        if (modifiedBandInfo && [modifiedBandInfo respondsToSelector:setActiveDictionary]) BLMsgSetObj(modifiedBandInfo, setActiveDictionary, newActive);
        else modifiedBandInfo = nil;
    }
    if (!modifiedBandInfo) { if (errorText) *errorText = BLT(@"No se pudo construir CTBandInfo.", @"Could not construct CTBandInfo."); return NO; }
    SEL setter = NSSelectorFromString(@"setActiveBandInfo:bands:error:");
    if (![client respondsToSelector:setter]) { if (errorText) *errorText = @"setActiveBandInfo unavailable"; return NO; }
    NSError *setError = nil;
    BLMsgSetActiveBandInfo(client, setter, context, modifiedBandInfo, &setError);
    if (setError) { if (errorText) *errorText = setError.description; return NO; }
    return YES;
}

- (NSArray<NSNumber *> *)activeNRFromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;
    return BLNRBandsFromDictionary(active);
}

- (void)applyBands:(NSArray<NSNumber *> *)requested savePrevious:(BOOL)savePrevious completion:(BLActionCompletion)completion {
    NSArray *bands = BLSortedBands(requested);
    if (!bands.count) { if (completion) completion(NO, BLT(@"Selecciona al menos una banda LTE.", @"Select at least one LTE band.")); return; }
    BOOL allSDL = YES;
    for (NSNumber *band in bands) if (![[BLGDuplexForBand(band) uppercaseString] isEqualToString:@"SDL"]) { allSDL = NO; break; }
    if (allSDL) { if (completion) completion(NO, BLT(@"Una selección compuesta solo por SDL no es válida.", @"An SDL-only selection is not valid.")); return; }
    if (self.busy) { if (completion) completion(NO, BLT(@"Hay una operación en curso.", @"An operation is already running.")); return; }
    self.busy = YES;
    dispatch_async(self.workerQueue, ^{
        NSDictionary *query = [self queryCoreTelephony];
        if (query[@"error"]) { [self finishBusyWithSuccess:NO message:query[@"error"] completion:completion]; return; }
        NSDictionary *fresh = [self snapshotFromQuery:query];
        NSArray *freshSupported = fresh[@"supported"] ?: @[];
        if (![[NSSet setWithArray:bands] isSubsetOfSet:[NSSet setWithArray:freshSupported]]) {
            [self finishBusyWithSuccess:NO message:BLT(@"Las bandas soportadas han cambiado. Actualiza y revisa la selección.", @"Supported bands changed. Refresh and review the selection.") completion:completion];
            return;
        }
        NSArray *current = [self activeLTEFromQuery:query];
        if (savePrevious && current.count) BLWriteState(@{@"previousLTE": current});
        NSString *writeError = nil;
        if (![self writeLTEBands:bands usingQuery:query errorText:&writeError]) { [self finishBusyWithSuccess:NO message:writeError completion:completion]; return; }
        [NSThread sleepForTimeInterval:0.8];
        NSDictionary *verify = [self queryCoreTelephony];
        if (verify[@"error"]) { [self finishBusyWithSuccess:NO message:verify[@"error"] completion:completion]; return; }
        NSArray *readback = [self activeLTEFromQuery:verify];
        if (![[NSSet setWithArray:bands] isEqualToSet:[NSSet setWithArray:readback]]) {
            NSString *retryError = nil;
            if (![self writeLTEBands:bands usingQuery:verify errorText:&retryError]) { [self finishBusyWithSuccess:NO message:retryError completion:completion]; return; }
            [NSThread sleepForTimeInterval:1.0];
            verify = [self queryCoreTelephony];
            if (verify[@"error"]) { [self finishBusyWithSuccess:NO message:verify[@"error"] completion:completion]; return; }
            readback = [self activeLTEFromQuery:verify];
        }
        BOOL matches = [[NSSet setWithArray:bands] isEqualToSet:[NSSet setWithArray:readback]];
        NSDictionary *snapshot = [self snapshotFromQuery:verify];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self consumeSnapshotOnMain:snapshot resetPending:matches];
            self.previousBands = BLSortedBands(BLReadState()[@"previousLTE"]);
            self.busy = NO;
            self.statusText = matches ? BLT(@"Aplicado y verificado", @"Applied and verified") : BLT(@"Resultado distinto", @"Different result");
            self.detailText = matches ? [NSString stringWithFormat:BLT(@"Bandas activas: %@", @"Active bands: %@"), BLBandList(readback)] : [NSString stringWithFormat:BLT(@"Solicitado: %@ · Leído: %@", @"Requested: %@ · Readback: %@"), BLBandList(bands), BLBandList(readback)];
            [self writeLogAction:@"apply-bands" detail:self.detailText];
            if (completion) completion(matches, self.detailText);
        });
    });
}

- (void)applyNRBands:(NSArray<NSNumber *> *)requested savePrevious:(BOOL)savePrevious completion:(BLActionCompletion)completion {
    NSArray *bands = BLSortedBands(requested);
    if (!bands.count) { if (completion) completion(NO, BLT(@"Selecciona al menos una banda 5G NR.", @"Select at least one 5G NR band.")); return; }
    BOOL allSDL = YES;
    for (NSNumber *band in bands) if (![[BLGNRDuplexForBand(band) uppercaseString] hasPrefix:@"SDL"]) { allSDL = NO; break; }
    if (allSDL) { if (completion) completion(NO, BLT(@"Una selección 5G compuesta solo por SDL no es válida.", @"An SDL-only 5G selection is not valid.")); return; }
    if (self.busy) { if (completion) completion(NO, BLT(@"Hay una operación en curso.", @"An operation is already running.")); return; }
    self.busy = YES;
    dispatch_async(self.workerQueue, ^{
        NSDictionary *query = [self queryCoreTelephony];
        if (query[@"error"]) { [self finishBusyWithSuccess:NO message:query[@"error"] completion:completion]; return; }
        NSDictionary *fresh = [self snapshotFromQuery:query];
        NSArray *freshSupported = fresh[@"supported_nr"] ?: @[];
        if (![[NSSet setWithArray:bands] isSubsetOfSet:[NSSet setWithArray:freshSupported]]) {
            [self finishBusyWithSuccess:NO message:BLT(@"Las bandas 5G soportadas han cambiado. Actualiza y revisa la selección.", @"Supported 5G bands changed. Refresh and review the selection.") completion:completion];
            return;
        }
        NSArray *current = [self activeNRFromQuery:query];
        if (savePrevious && current.count) BLWriteState(@{@"previousNR": current});
        NSString *writeError = nil;
        if (![self writeNRBands:bands usingQuery:query errorText:&writeError]) { [self finishBusyWithSuccess:NO message:writeError completion:completion]; return; }
        [NSThread sleepForTimeInterval:0.8];
        NSDictionary *verify = [self queryCoreTelephony];
        if (verify[@"error"]) { [self finishBusyWithSuccess:NO message:verify[@"error"] completion:completion]; return; }
        NSArray *readback = [self activeNRFromQuery:verify];
        if (![[NSSet setWithArray:bands] isEqualToSet:[NSSet setWithArray:readback]]) {
            NSString *retryError = nil;
            if (![self writeNRBands:bands usingQuery:verify errorText:&retryError]) { [self finishBusyWithSuccess:NO message:retryError completion:completion]; return; }
            [NSThread sleepForTimeInterval:1.0];
            verify = [self queryCoreTelephony];
            if (verify[@"error"]) { [self finishBusyWithSuccess:NO message:verify[@"error"] completion:completion]; return; }
            readback = [self activeNRFromQuery:verify];
        }
        BOOL matches = [[NSSet setWithArray:bands] isEqualToSet:[NSSet setWithArray:readback]];
        NSDictionary *snapshot = [self snapshotFromQuery:verify];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self consumeSnapshotOnMain:snapshot resetPending:matches];
            self.previousNRBands = BLSortedBands(BLReadState()[@"previousNR"]);
            self.busy = NO;
            self.statusText = matches ? BLT(@"5G aplicado y verificado", @"5G applied and verified") : BLT(@"Resultado 5G distinto", @"Different 5G result");
            self.detailText = matches ? [NSString stringWithFormat:BLT(@"Bandas 5G activas: %@", @"Active 5G bands: %@"), BLNRBandList(readback)] : [NSString stringWithFormat:BLT(@"5G solicitado: %@ · Leído: %@", @"Requested 5G: %@ · Readback: %@"), BLNRBandList(bands), BLNRBandList(readback)];
            [self writeLogAction:@"apply-nr-bands" detail:self.detailText];
            if (completion) completion(matches, self.detailText);
        });
    });
}

- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion { [self applyBands:self.pendingBands savePrevious:YES completion:completion]; }
- (void)applyPendingNRBandsWithCompletion:(BLActionCompletion)completion { [self applyNRBands:self.pendingNRBands savePrevious:YES completion:completion]; }

- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion {
    NSArray *previous = BLSortedBands(BLReadState()[@"previousLTE"]);
    if (!previous.count) { if (completion) completion(NO, BLT(@"No hay una selección anterior guardada.", @"No previous selection is saved.")); return; }
    [self applyBands:previous savePrevious:NO completion:completion];
}

- (void)restorePreviousNRBandsWithCompletion:(BLActionCompletion)completion {
    NSArray *previous = BLSortedBands(BLReadState()[@"previousNR"]);
    if (!previous.count) { if (completion) completion(NO, BLT(@"No hay una selección 5G anterior guardada.", @"No previous 5G selection is saved.")); return; }
    [self applyNRBands:previous savePrevious:NO completion:completion];
}

- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion {
    NSArray *supported = self.supportedBands;
    if (!supported.count) { if (completion) completion(NO, BLT(@"Actualiza el estado primero.", @"Refresh the modem state first.")); return; }
    [self applyBands:supported savePrevious:YES completion:completion];
}

- (void)restoreAllSupportedNRBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.supportedNRBands.count) {
        if (completion) completion(NO, BLT(@"Este iPhone no reporta bandas 5G NR configurables.", @"This iPhone does not report configurable 5G NR bands."));
        return;
    }
    [self applyNRBands:self.supportedNRBands savePrevious:YES completion:completion];
}

- (void)writeLogAction:(NSString *)action detail:(NSString *)detail {
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:BLLogDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *text = [NSString stringWithFormat:@"BandLock-Version: 1.6\nTimestamp: %@\nAction: %@\nRAT: %@\nServing-Band: %@\nSupported-LTE: %@\nActive-LTE: %@\nPending-LTE: %@\nSupported-NR: %@\nActive-NR: %@\nPending-NR: %@\nDetail: %@\n",
                      NSDate.date, action ?: @"—", self.radioAccessTechnology ?: @"—", self.servingBand ?: @"—", BLBandList(self.supportedBands), BLBandList(self.activeBands), BLBandList(self.pendingBands), BLNRBandList(self.supportedNRBands), BLNRBandList(self.activeNRBands), BLNRBandList(self.pendingNRBands), detail ?: @"—"];
    [text writeToFile:BLLastLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSDictionary *)signalProbeFromQuery:(NSDictionary *)query {
    if (query[@"error"]) return @{@"success": @NO, @"message": [query[@"error"] description] ?: @"CoreTelephony error"};
    // NR metadata alone is not evidence of a 5G modem. Hardware must be
    // capable and the active subscription must report NR support.
    NSDictionary *capabilities = [self snapshotFromQuery:query];
    BOOL supportsNR = !BLDeviceIsKnownLTEOnly() && [capabilities[@"supports_5g"] boolValue];
    id cellInfo = query[@"cellInfo"];
    NSArray *legacyInfo = nil;
    SEL legacySelector = NSSelectorFromString(@"legacyInfo");
    if (cellInfo && cellInfo != NSNull.null && [cellInfo respondsToSelector:legacySelector]) {
        id raw = BLMsg0(cellInfo, legacySelector);
        if ([raw isKindOfClass:NSArray.class]) legacyInfo = raw;
    }

    NSMutableArray *items = [NSMutableArray array];
    NSDictionary *servingLegacy = nil;
    NSMutableOrderedSet<NSString *> *legacyCellTypes = [NSMutableOrderedSet orderedSet];
    for (id raw in legacyInfo) {
        if (![raw isKindOfClass:NSDictionary.class]) continue;
        NSString *rawType = [raw[@"kCTCellMonitorCellType"] isKindOfClass:NSString.class]
            ? raw[@"kCTCellMonitorCellType"] : nil;
        if (rawType.length && rawType.length <= 96) [legacyCellTypes addObject:rawType];
        NSDictionary *legacy = BLRHLegacySignalRow(raw);
        if (!legacy) continue;
        if ([legacy[@"rat"] isEqualToString:@"NR"] && !supportsNR) continue;
        if ([legacy[@"role"] isEqual:@"serving"] && [legacy[@"rat"] isEqual:@"LTE"] && !servingLegacy) {
            servingLegacy = raw;
        }
        [items addObject:legacy];
    }

    NSString *typedStatus = @"api_unavailable";
    id client = query[@"client"];
    id context = query[@"context"];
    id descriptor = nil;
    id typed = nil;
    if (client && context) {
        @try {
            // Bound to the SAME subscription context used to fetch band
            // info. Do not silently use a different data-line descriptor.
            Class descriptorClass = NSClassFromString(@"CTServiceDescriptor");
            SEL fromContext = NSSelectorFromString(@"descriptorWithSubscriptionContext:");
            if ([descriptorClass respondsToSelector:fromContext]) {
                descriptor = ((id (*)(id, SEL, id))objc_msgSend)((id)descriptorClass, fromContext, context);
            }
            SEL signalSelector = NSSelectorFromString(@"getSignalStrengthMeasurements:error:");
            if (descriptor && [client respondsToSelector:signalSelector]) {
                typedStatus = @"queried";
                NSError *signalError = nil;
                typed = BLMsgObjErr(client, signalSelector, descriptor, &signalError);
                if (signalError) typedStatus = @"query_error";
                else if (!typed) typedStatus = @"empty";
            } else {
                typedStatus = descriptor ? @"api_unavailable" : @"descriptor_unavailable";
            }
        } @catch (__unused NSException *exception) {
            typedStatus = @"exception";
            typed = nil;
        }
    }

    if (typed) {
        NSMutableDictionary *serving = nil;
        for (NSMutableDictionary *item in items) {
            if ([item[@"role"] isEqual:@"serving"] &&
                [item[@"rat"] isEqual:(supportsNR && [capabilities[@"rat"] hasPrefix:@"5G"] ? @"NR" : @"LTE")]) {
                serving = item;
                break;
            }
        }
        if (!serving) {
            for (NSMutableDictionary *item in items) {
                if ([item[@"role"] isEqual:@"serving"]) { serving = item; break; }
            }
        }
        NSString *actualRAT = serving[@"rat"];
        if (!actualRAT.length) actualRAT = BLRHSignalRAT(capabilities[@"rat"]);
        if ([actualRAT isEqualToString:@"NR"] && !supportsNR) actualRAT = nil;
        // Typed metrics and legacy band metadata come from distinct APIs.
        // Never overwrite a legacy row and mark its remaining legacy metrics
        // as typed: a missing typed RSRP must not inherit a legacy RSRP.
        // Only label typed metrics as NR when an actual serving NR row is
        // present. NSA LTE-anchor measurements must not masquerade as 5G.
        NSMutableDictionary *typedServing = [@{
            @"rat": actualRAT ?: @"unknown",
            @"role": @"serving", @"source": @"typed"
        } mutableCopy];
        if (serving[@"band"]) typedServing[@"band"] = serving[@"band"];
        for (NSString *field in @[@"cell_id", @"physical_cell_id", @"psc", @"tac", @"lac", @"channel",
                                  @"cell_id_source_key", @"physical_cell_id_source_key",
                                  @"psc_source_key", @"tac_source_key", @"lac_source_key", @"channel_source_key"]) {
            if (serving[field]) typedServing[field] = serving[field];
        }
        NSNumber *rsrp = BLRHMetric(typed, @"rsrp", -200, -20, YES);
        NSNumber *rsrq = BLRHMetric(typed, @"rsrq", -60, 0, YES);
        NSNumber *rssi = BLRHMetric(typed, @"rssi", -200, -20, YES);
        NSNumber *snr = BLRHMetric(typed, @"snr", -100, 100, NO);
        NSNumber *rscp = [typedServing[@"rat"] isEqualToString:@"3G"]
            ? BLRHMetric(typed, @"rscp", -130, -20, YES) : nil;
        NSNumber *ecno = [typedServing[@"rat"] isEqualToString:@"3G"]
            ? BLRHMetric(typed, @"ecno", -40, 0, YES) : nil;
        if (rsrp) typedServing[@"rsrp"] = rsrp;
        if (rsrq) typedServing[@"rsrq"] = rsrq;
        if (rssi) typedServing[@"rssi"] = rssi;
        if (snr) typedServing[@"snr"] = snr;
        if (rscp) typedServing[@"rscp"] = rscp;
        if (ecno) typedServing[@"ecno"] = ecno;
        if (rsrp || rsrq || rssi || snr || rscp || ecno) {
            [items insertObject:typedServing atIndex:0];
            typedStatus = @"values_available";
        } else {
            typedStatus = @"no_valid_values";
        }
    }

    NSMutableArray *available = [NSMutableArray array];
    for (NSDictionary *row in items) {
        if (row[@"rsrp"] || row[@"rsrq"] || row[@"rssi"] ||
            row[@"snr"] || row[@"rscp"] || row[@"ecno"] ||
            row[@"cell_id"] || row[@"physical_cell_id"] ||
            row[@"psc"] || row[@"tac"] || row[@"lac"] || row[@"channel"])
            [available addObject:row];
    }
    NSDictionary *diagnostics = @{
        @"typed_api": typedStatus,
        @"legacy_rows": @(legacyInfo.count),
        @"legacy_cell_types": legacyCellTypes.array ?: @[],
        @"legacy_serving_rsrp": servingLegacy ? BLRHMetricPresence(servingLegacy, @[@"kCTCellMonitorRSRP", @"RSRP", @"rsrp"]) : @"no_serving_row",
        @"legacy_serving_rsrq": servingLegacy ? BLRHMetricPresence(servingLegacy, @[@"kCTCellMonitorRSRQ", @"RSRQ", @"rsrq"]) : @"no_serving_row",
        @"legacy_serving_rssi": servingLegacy ? BLRHMetricPresence(servingLegacy, @[@"kCTCellMonitorRSSI", @"RSSI", @"rssi"]) : @"no_serving_row",
        @"legacy_serving_snr": servingLegacy ? BLRHMetricPresence(servingLegacy, @[@"kCTCellMonitorSNR", @"SNR", @"snr"]) : @"no_serving_row"
    };
    BOOL hasPower = NO;
    for (NSDictionary *item in available) {
        if ([item[@"role"] isEqual:@"serving"] &&
            ([item[@"rat"] isEqual:@"LTE"] || [item[@"rat"] isEqual:@"2G"] ||
             [item[@"rat"] isEqual:@"3G"] || (supportsNR && [item[@"rat"] isEqual:@"NR"])) &&
            (item[@"rsrp"] || item[@"rssi"] || item[@"rscp"])) hasPower = YES;
    }
    return @{
        @"success": @YES,
        @"measurements": available,
        @"diagnostics": diagnostics,
        @"operator_name": [query[@"operatorName"] isKindOfClass:NSString.class] ? query[@"operatorName"] : @"",
        @"supports_nr": @(supportsNR),
        @"supported_nr": supportsNR ? (capabilities[@"supported_nr"] ?: @[]) : @[],
        @"has_serving_power": @(hasPower),
        @"active_scan_available": @NO,
        @"message": hasPower
            ? @"Señal disponible"
            : @"Sin potencia válida de la celda principal"
    };
}

- (BOOL)openFieldTestWithError:(NSString **)errorText {
    NSString *bundleID = @"com.apple.mobilephone";
    BOOL launchRequested = NO;
    @try {
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_NOW | RTLD_LOCAL);
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
        SEL openAppSelector = NSSelectorFromString(@"openApplicationWithBundleID:");
        if (workspaceClass && [workspaceClass respondsToSelector:defaultSelector]) {
            id workspace = BLMsg0((id)workspaceClass, defaultSelector);
            if (workspace && [workspace respondsToSelector:openAppSelector]) {
                launchRequested = BLMsgBoolObj(workspace, openAppSelector, bundleID);
            }
        }

        if (!launchRequested) {
        dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW | RTLD_LOCAL);
        Class serviceClass = NSClassFromString(@"FBSSystemService");
        SEL sharedSelector = NSSelectorFromString(@"sharedService");
        SEL openSelector = NSSelectorFromString(@"openApplication:options:withResult:");
        if (serviceClass && [serviceClass respondsToSelector:sharedSelector]) {
            id service = BLMsg0((id)serviceClass, sharedSelector);
            if (service && [service respondsToSelector:openSelector]) {
                ((void (*)(id, SEL, id, id, id))objc_msgSend)(service, openSelector, bundleID, @{}, nil);
                    launchRequested = YES;
            }
        }
        }
    } @catch (NSException *exception) {
        if (errorText) *errorText = exception.reason ?: exception.name;
        return NO;
    }

    if (!launchRequested) {
        if (errorText) *errorText = BLT(@"No se pudo abrir Teléfono.", @"Could not open Phone.");
        return NO;
    }

    [NSThread sleepForTimeInterval:1.0];
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef notification = CFSTR("com.gokuencinar.bandlock.fieldtest");
    for (NSInteger attempt = 0; attempt < 3; attempt++) {
        CFNotificationCenterPostNotification(center, notification, NULL, NULL, YES);
        [NSThread sleepForTimeInterval:0.35];
    }
    return YES;
}

@end
