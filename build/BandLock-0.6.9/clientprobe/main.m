#import <Foundation/Foundation.h>
#import "../app/BLTelephonyManager.h"

@interface BLTelephonyManager (Probe)
- (NSDictionary *)sendRequestSynchronously:(NSDictionary *)request;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        fprintf(stderr, "client-probe begin\n");
        BLTelephonyManager *manager = BLTelephonyManager.sharedManager;
        fprintf(stderr, "client-probe manager ready\n");
        NSDictionary *result = [manager sendRequestSynchronously:@{@"cmd": @"status"}];
        fprintf(stderr, "client-probe request returned\n");
        if (!result) {
            fprintf(stderr, "client-probe nil result\n");
            return 2;
        }
        NSError *error = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
        if (!json) {
            fprintf(stderr, "client-probe JSON error: %s\n", error.localizedDescription.UTF8String ?: "unknown");
            return 3;
        }
        fwrite(json.bytes, 1, json.length, stdout);
        fputc('\n', stdout);
        BOOL success = [result[@"success"] boolValue];
        fprintf(stderr, "client-probe success=%d\n", success ? 1 : 0);
        return success ? 0 : 4;
    }
}