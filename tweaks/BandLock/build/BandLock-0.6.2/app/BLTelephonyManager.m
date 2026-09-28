#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSString * const BLPreviousBandsDefaultsKey = @"BandLockPreviousBands";

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
@property (nonatomic, strong) dispatch_queue_t helperQueue;
@end

@implementation BLTelephonyManager

+ (instancetype)sharedManager {
    static BLTelephonyManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] initPrivate]; });
    return manager;
}

- (instancetype)init { return BLTelephonyManager.sharedManager; }

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _helperQueue = dispatch_queue_create("com.gokuencinar.bandlock.helper", DISPATCH_QUEUE_SERIAL);
        _supportedBands = @[];
        _activeBands = @[];
        _pendingBands = @[];
        _previousBands = BLSortedBands([NSUserDefaults.standardUserDefaults arrayForKey:BLPreviousBandsDefaultsKey]);
        _radioAccessTechnology = @"—";
        _servingBand = @"—";
        _networkMode = BLT(@"Sin consultar", @"Not queried");
        _statusText = BLT(@"Pulsa Actualizar", @"Tap Refresh");
        _detailText = BLT(@"La interfaz está aislada de CoreTelephony. Las operaciones del módem se ejecutan en un helper independiente.", @"The UI is isolated from CoreTelephony. Modem operations run in a separate helper process.");
        _hasReadState = NO;
        _busy = NO;
    }
    return self;
}

- (NSString *)helperPath {
    return [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"BandLockHelper"];
}

- (NSDictionary *)decodeHelperData:(NSData *)data exitStatus:(int)exitStatus {
    if (!data.length) {
        return @{@"success": @NO,
                 @"message": [NSString stringWithFormat:BLT(@"El helper terminó sin respuesta (estado %d).", @"The helper exited without a response (status %d)."), exitStatus]};
    }
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if ([json isKindOfClass:[NSDictionary class]]) return json;

    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    NSRange first = [text rangeOfString:@"{"];
    NSRange last = [text rangeOfString:@"}" options:NSBackwardsSearch];
    if (first.location != NSNotFound && last.location != NSNotFound && last.location >= first.location) {
        NSString *slice = [text substringWithRange:NSMakeRange(first.location, NSMaxRange(last) - first.location)];
        NSData *sliceData = [slice dataUsingEncoding:NSUTF8StringEncoding];
        json = [NSJSONSerialization JSONObjectWithData:sliceData options:0 error:nil];
        if ([json isKindOfClass:[NSDictionary class]]) return json;
    }
    return @{@"success": @NO,
             @"message": [NSString stringWithFormat:BLT(@"Respuesta no válida del helper (estado %d): %@", @"Invalid helper response (status %d): %@"), exitStatus, text.length ? text : (jsonError.localizedDescription ?: @"—")]};
}

- (NSDictionary *)runHelperSynchronouslyWithArguments:(NSArray<NSString *> *)arguments {
    NSString *path = [self helperPath];
    if (![NSFileManager.defaultManager isExecutableFileAtPath:path]) {
        return @{@"success": @NO,
                 @"message": BLT(@"BandLockHelper no está instalado o no es ejecutable. Reinstala BandLock 0.6.2 desde Sileo.", @"BandLockHelper is missing or not executable. Reinstall BandLock 0.6.2 from Sileo.")};
    }

    int outputPipe[2] = {-1, -1};
    if (pipe(outputPipe) != 0) {
        return @{@"success": @NO, @"message": BLT(@"No se pudo crear el canal con el helper.", @"Could not create the helper pipe.")};
    }

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, outputPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&actions, outputPipe[0]);
    posix_spawn_file_actions_addclose(&actions, outputPipe[1]);

    NSUInteger argc = arguments.count + 2;
    char **argv = calloc(argc, sizeof(char *));
    argv[0] = strdup(path.fileSystemRepresentation);
    for (NSUInteger index = 0; index < arguments.count; index++) argv[index + 1] = strdup(arguments[index].UTF8String ?: "");
    argv[arguments.count + 1] = NULL;

    pid_t pid = 0;
    int spawnResult = posix_spawn(&pid, path.fileSystemRepresentation, &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(outputPipe[1]);
    for (NSUInteger index = 0; index < arguments.count + 1; index++) free(argv[index]);
    free(argv);

    if (spawnResult != 0) {
        close(outputPipe[0]);
        return @{@"success": @NO,
                 @"message": [NSString stringWithFormat:BLT(@"No se pudo iniciar BandLockHelper (errno %d).", @"Could not start BandLockHelper (errno %d)."), spawnResult]};
    }

    NSMutableData *output = [NSMutableData data];
    uint8_t buffer[4096];
    ssize_t count = 0;
    while ((count = read(outputPipe[0], buffer, sizeof(buffer))) > 0) [output appendBytes:buffer length:(NSUInteger)count];
    close(outputPipe[0]);

    int status = 0;
    waitpid(pid, &status, 0);
    int exitStatus = WIFEXITED(status) ? WEXITSTATUS(status) : (WIFSIGNALED(status) ? 128 + WTERMSIG(status) : status);
    NSMutableDictionary *result = [[self decodeHelperData:output exitStatus:exitStatus] mutableCopy];
    if (exitStatus != 0 && [result[@"success"] boolValue]) result[@"success"] = @NO;
    if (exitStatus >= 128 && ![result[@"message"] length]) {
        result[@"message"] = [NSString stringWithFormat:BLT(@"BandLockHelper fue terminado por la señal %d. La app principal sigue abierta.", @"BandLockHelper was terminated by signal %d. The main app remains open."), exitStatus - 128];
    }
    return result;
}

- (void)runHelper:(NSArray<NSString *> *)arguments completion:(void (^)(NSDictionary *result))completion {
    if (self.busy) {
        if (completion) completion(@{@"success": @NO, @"message": BLT(@"Hay una operación en curso.", @"An operation is already running.")});
        return;
    }
    self.busy = YES;
    dispatch_async(self.helperQueue, ^{
        NSDictionary *result = [self runHelperSynchronouslyWithArguments:arguments];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            if (completion) completion(result ?: @{@"success": @NO, @"message": @"No result"});
        });
    });
}

- (void)consumeStatusResult:(NSDictionary *)result resetPending:(BOOL)resetPending {
    self.supportedBands = BLSortedBands(result[@"supported"]);
    self.activeBands = BLSortedBands(result[@"active"]);
    self.radioAccessTechnology = [result[@"rat"] isKindOfClass:[NSString class]] ? result[@"rat"] : @"—";
    self.servingBand = [result[@"serving"] isKindOfClass:[NSString class]] ? result[@"serving"] : @"—";
    self.networkMode = [result[@"mode"] isKindOfClass:[NSString class]] ? result[@"mode"] : BLT(@"No disponible", @"Unavailable");
    self.hasReadState = YES;
    if (resetPending || !self.pendingBands.count) self.pendingBands = self.activeBands;
}

- (void)finishResult:(NSDictionary *)result successMessage:(NSString *)successMessage completion:(BLActionCompletion)completion {
    BOOL success = [result[@"success"] boolValue];
    NSString *message = [result[@"message"] isKindOfClass:[NSString class]] ? result[@"message"] : (success ? successMessage : BLT(@"Operación fallida.", @"Operation failed."));
    self.statusText = success ? BLT(@"Listo", @"Ready") : BLT(@"Error del helper", @"Helper error");
    self.detailText = message ?: @"";
    if (completion) completion(success, self.detailText);
}

- (void)refreshWithCompletion:(BLActionCompletion)completion {
    self.statusText = BLT(@"Consultando helper…", @"Querying helper…");
    [self runHelper:@[@"status"] completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) [self consumeStatusResult:result resetPending:YES];
        [self finishResult:result successMessage:BLT(@"Estado del módem actualizado.", @"Modem state updated.") completion:completion];
    }];
}

- (void)setPendingBands:(NSArray<NSNumber *> *)bands {
    self.pendingBands = BLSortedBands(bands);
    self.statusText = BLT(@"Selección preparada", @"Selection prepared");
    self.detailText = BLBandList(self.pendingBands);
}

- (void)setNetworkMode:(NSString *)mode completion:(BLActionCompletion)completion {
    [self runHelper:@[@"rat", mode] completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) [self consumeStatusResult:result resetPending:NO];
        [self finishResult:result successMessage:BLT(@"Modo de red actualizado.", @"Network mode updated.") completion:completion];
    }];
}

- (void)setNetworkModeAutomatic:(BLActionCompletion)completion { [self setNetworkMode:@"automatic" completion:completion]; }
- (void)setNetworkModeLTEOnly:(BLActionCompletion)completion { [self setNetworkMode:@"lte" completion:completion]; }

- (NSString *)csvForBands:(NSArray<NSNumber *> *)bands {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSNumber *band in BLSortedBands(bands)) [parts addObject:band.stringValue];
    return [parts componentsJoinedByString:@","];
}

- (void)applyBands:(NSArray<NSNumber *> *)bands savePrevious:(BOOL)savePrevious completion:(BLActionCompletion)completion {
    NSArray<NSNumber *> *clean = BLSortedBands(bands);
    if (!clean.count) {
        if (completion) completion(NO, BLT(@"Selecciona al menos una banda LTE.", @"Select at least one LTE band."));
        return;
    }
    if (savePrevious && self.activeBands.count) {
        self.previousBands = self.activeBands;
        [NSUserDefaults.standardUserDefaults setObject:self.previousBands forKey:BLPreviousBandsDefaultsKey];
    }
    [self runHelper:@[@"apply", [self csvForBands:clean]] completion:^(NSDictionary *result) {
        if ([result[@"success"] boolValue]) {
            if (savePrevious) {
                NSArray *previous = BLSortedBands(result[@"previous"]);
                if (previous.count) {
                    self.previousBands = previous;
                    [NSUserDefaults.standardUserDefaults setObject:previous forKey:BLPreviousBandsDefaultsKey];
                }
            }
            [self consumeStatusResult:result resetPending:YES];
        }
        [self finishResult:result successMessage:BLT(@"Selección LTE aplicada.", @"LTE selection applied.") completion:completion];
    }];
}

- (void)applyPendingBandsWithCompletion:(BLActionCompletion)completion { [self applyBands:self.pendingBands savePrevious:YES completion:completion]; }

- (void)restorePreviousBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.previousBands.count) {
        if (completion) completion(NO, BLT(@"No hay una selección anterior guardada.", @"No previous selection is saved."));
        return;
    }
    [self applyBands:self.previousBands savePrevious:NO completion:completion];
}

- (void)restoreAllSupportedBandsWithCompletion:(BLActionCompletion)completion {
    if (!self.supportedBands.count) {
        if (completion) completion(NO, BLT(@"Pulsa Actualizar estado primero.", @"Tap Refresh status first."));
        return;
    }
    [self applyBands:self.supportedBands savePrevious:YES completion:completion];
}

- (void)openFieldTestWithCompletion:(BLActionCompletion)completion {
    [self runHelper:@[@"fieldtest"] completion:^(NSDictionary *result) {
        [self finishResult:result successMessage:BLT(@"Field Test solicitado.", @"Field Test requested.") completion:completion];
    }];
}

@end
