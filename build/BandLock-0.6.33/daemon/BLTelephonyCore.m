#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const BLLTERAT = @"kCTRegistrationRadioAccessTechnologyLTE";
static NSString * const BLRATAutomatic = @"kCTRegistrationRATSelectionAutomatic";
static NSString * const BLRATLTE = @"kCTRegistrationRATSelectionLTE";
static NSString * const BLLogDirectory = @"/var/mobile/Library/Logs/BandLockGlobal";
static NSString * const BLLastLogPath = @"/var/mobile/Library/Logs/BandLockGlobal/BandLock-last.txt";
static NSString * const BLStateDefaultsKey = @"BandLockGlobalState";

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
    NSString *title = BLGBandTitle(bandNumber);
    if ([rat isKindOfClass:[NSString class]] && rat.length) return [NSString stringWithFormat:@"%@ · %@", title, ([rat rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound ? @"LTE" : rat)];
    return title;
}

@interface BLTelephonyManager ()
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *supportedBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *activeBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *pendingBands;
@property (nonatomic, copy, readwrite) NSArray<NSNumber *> *previousBands;
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
    SEL selector = NSSelectorFromString(@"getRatSelection:completion:");
    if (![client respondsToSelector:selector]) return @{@"selection": @"—", @"preferred": @"—"};
    __block NSString *selection = nil;
    __block NSString *preferred = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    BLMsgGetRatSelection(client, selector, context, ^(NSString *currentSelection, NSString *preferredSelection, NSError *error) {
        if (!error) { selection = [currentSelection copy]; preferred = [preferredSelection copy]; }
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    return @{@"selection": selection ?: @"—", @"preferred": preferred ?: @"—"};
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
    if (!handle) return @{@"error": BLT(@"No se pudo cargar CoreTelephony.", @"Could not load CoreTelephony.")};

    id ratRaw = nil;
    Class networkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    if (networkInfoClass) {
        id networkInfo = [[networkInfoClass alloc] init];
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
    if (!context) return @{@"error": contextError ? contextError.description : BLT(@"No hay contexto de datos activo.", @"No active data subscription context.")};

    SEL bandSelector = NSSelectorFromString(@"getBandInfo:error:");
    if (![client respondsToSelector:bandSelector]) return @{@"error": @"getBandInfo:error: unavailable"};
    NSError *bandError = nil;
    id bandInfo = BLMsgObjErr(client, bandSelector, context, &bandError);
    if (!bandInfo) return @{@"error": bandError ? bandError.description : @"getBandInfo:error: returned nil"};

    NSDictionary *ratSelection = [self readRatSelectionFromClient:client context:context];
    id cellInfo = [self copyCellInfoFromClient:client context:context];
    return @{@"client": client,
             @"context": context,
             @"bandInfo": bandInfo,
             @"ratRaw": ratRaw ?: NSNull.null,
             @"cellInfo": cellInfo ?: NSNull.null,
             @"ratSelection": ratSelection[@"selection"] ?: @"—",
             @"ratPreferred": ratSelection[@"preferred"] ?: @"—"};
}

- (NSDictionary *)snapshotFromQuery:(NSDictionary *)query {
    id bandInfo = query[@"bandInfo"];
    SEL supportedSelector = NSSelectorFromString(@"supportedBands");
    SEL activeSelector = NSSelectorFromString(@"activeBands");
    NSDictionary *supported = [bandInfo respondsToSelector:supportedSelector] ? BLMsg0(bandInfo, supportedSelector) : nil;
    NSDictionary *active = [bandInfo respondsToSelector:activeSelector] ? BLMsg0(bandInfo, activeSelector) : nil;
    NSArray *supportedLTE = BLSortedBands(supported[BLLTERAT]);
    NSArray *activeLTE = BLSortedBands(active[BLLTERAT]);
    NSString *selection = [query[@"ratSelection"] isKindOfClass:[NSString class]] ? query[@"ratSelection"] : @"—";
    NSString *mode = BLT(@"No disponible", @"Unavailable");
    NSString *modeCode = @"unknown";
    if ([selection rangeOfString:@"Unknown" options:NSCaseInsensitiveSearch].location != NSNotFound) { mode = BLT(@"No disponible", @"Unavailable"); modeCode = @"unknown"; }
    else if ([selection rangeOfString:@"Automatic" options:NSCaseInsensitiveSearch].location != NSNotFound) { mode = BLT(@"Automático", @"Automatic"); modeCode = @"automatic"; }
    else if ([selection rangeOfString:@"LTE" options:NSCaseInsensitiveSearch].location != NSNotFound) { mode = BLT(@"Solo LTE / 4G", @"LTE / 4G only"); modeCode = @"lte"; }
    else if (![selection isEqualToString:@"—"]) { mode = selection; modeCode = @"other"; }
    id ratRaw = query[@"ratRaw"] == NSNull.null ? nil : query[@"ratRaw"];
    id cellInfo = query[@"cellInfo"] == NSNull.null ? nil : query[@"cellInfo"];
    return @{@"supported": supportedLTE,
             @"active": activeLTE,
             @"rat": BLHumanRAT(ratRaw) ?: @"—",
             @"serving": BLServingBandFromCellInfo(cellInfo) ?: @"—",
             @"mode": mode,
             @"mode_code": modeCode};
}

- (void)consumeSnapshotOnMain:(NSDictionary *)snapshot resetPending:(BOOL)resetPending {
    self.supportedBands = snapshot[@"supported"] ?: @[];
    self.activeBands = snapshot[@"active"] ?: @[];
    self.radioAccessTechnology = snapshot[@"rat"] ?: @"—";
    self.servingBand = snapshot[@"serving"] ?: @"—";
    self.networkMode = snapshot[@"mode"] ?: BLT(@"No disponible", @"Unavailable");
    self.hasReadState = YES;
    if (resetPending || !self.pendingBands.count) self.pendingBands = self.activeBands;
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

- (BOOL)setRatSelectionSync:(NSString *)selection preferred:(NSString *)preferred errorText:(NSString **)errorText {
    NSDictionary *query = [self queryCoreTelephony];
    if (query[@"error"]) { if (errorText) *errorText = query[@"error"]; return NO; }
    id client = query[@"client"];
    id context = query[@"context"];
    SEL setter = NSSelectorFromString(@"setRatSelection:selection:preferred:completion:");
    if (![client respondsToSelector:setter]) { if (errorText) *errorText = @"setRatSelection unavailable"; return NO; }
    __block NSError *callbackError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    BLMsgSetRatSelection(client, setter, context, selection, preferred, ^(NSError *error) { callbackError = error; dispatch_semaphore_signal(semaphore); });
    long wait = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)));
    if (wait != 0) { if (errorText) *errorText = BLT(@"Tiempo de espera agotado.", @"Operation timed out."); return NO; }
    if (callbackError) { if (errorText) *errorText = callbackError.description; return NO; }
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
        }
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

- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion { [self applyBands:self.pendingBands savePrevious:YES completion:completion]; }

- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion {
    NSArray *previous = BLSortedBands(BLReadState()[@"previousLTE"]);
    if (!previous.count) { if (completion) completion(NO, BLT(@"No hay una selección anterior guardada.", @"No previous selection is saved.")); return; }
    [self applyBands:previous savePrevious:NO completion:completion];
}

- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion {
    NSArray *supported = self.supportedBands;
    if (!supported.count) { if (completion) completion(NO, BLT(@"Actualiza el estado primero.", @"Refresh the modem state first.")); return; }
    [self applyBands:supported savePrevious:YES completion:completion];
}

- (void)writeLogAction:(NSString *)action detail:(NSString *)detail {
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:BLLogDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *text = [NSString stringWithFormat:@"BandLock-Version: 0.6.33\nTimestamp: %@\nAction: %@\nRAT: %@\nServing-Band: %@\nSupported-LTE: %@\nActive-LTE: %@\nPending-LTE: %@\nDetail: %@\n",
                      NSDate.date, action ?: @"—", self.radioAccessTechnology ?: @"—", self.servingBand ?: @"—", BLBandList(self.supportedBands), BLBandList(self.activeBands), BLBandList(self.pendingBands), detail ?: @"—"];
    [text writeToFile:BLLastLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
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
