#import <Foundation/Foundation.h>
#import <roothide.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/time.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

static NSDictionary *BLStatusRequest(void) {
    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:@{@"cmd": @"status"} options:0 error:&error];
    if (!body) return @{@"success": @NO, @"message": error.localizedDescription ?: @"json serialize failed"};

    NSMutableData *wire = [body mutableCopy];
    [wire appendBytes:"\n" length:1];

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return @{@"success": @NO, @"message": [NSString stringWithFormat:@"socket errno=%d", errno]};

    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
    struct timeval timeout = {.tv_sec = 5, .tv_usec = 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    NSString *resolvedPath = jbroot(@"/tmp/com.gokuencinar.bandlockd.sock");
    const char *path = resolvedPath.fileSystemRepresentation;
    if (!path) {
        close(fd);
        return @{@"success": @NO, @"message": @"jbroot path resolution failed"};
    }
    strlcpy(address.sun_path, path, sizeof(address.sun_path));

    fprintf(stderr, "client-probe resolved %s\n", path);
    fprintf(stderr, "client-probe connect %s\n", path);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        int saved = errno;
        close(fd);
        return @{@"success": @NO, @"message": [NSString stringWithFormat:@"connect errno=%d", saved]};
    }

    const uint8_t *bytes = wire.bytes;
    NSUInteger remaining = wire.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written <= 0) {
            int saved = errno;
            close(fd);
            return @{@"success": @NO, @"message": [NSString stringWithFormat:@"write errno=%d", saved]};
        }
        bytes += written;
        remaining -= (NSUInteger)written;
    }

    NSMutableData *response = [NSMutableData data];
    uint8_t buffer[4096];
    while (response.length < 131072) {
        ssize_t count = read(fd, buffer, sizeof(buffer));
        if (count < 0) {
            int saved = errno;
            close(fd);
            return @{@"success": @NO, @"message": [NSString stringWithFormat:@"read errno=%d", saved]};
        }
        if (count == 0) break;
        [response appendBytes:buffer length:(NSUInteger)count];
        if (memchr(buffer, '\n', (size_t)count)) break;
    }
    close(fd);

    NSRange newline = [response rangeOfData:[NSData dataWithBytes:"\n" length:1]
                                    options:0
                                      range:NSMakeRange(0, response.length)];
    if (newline.location != NSNotFound) response.length = newline.location;
    id result = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
    if (![result isKindOfClass:[NSDictionary class]]) {
        return @{@"success": @NO, @"message": error.localizedDescription ?: @"invalid response"};
    }
    return result;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        fprintf(stderr, "client-probe standalone begin\n");
        NSDictionary *result = BLStatusRequest();
        fprintf(stderr, "client-probe request returned\n");
        NSError *error = nil;
        NSData *json = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
        if (!json) return 3;
        fwrite(json.bytes, 1, json.length, stdout);
        fputc('\n', stdout);
        BOOL success = [result[@"success"] boolValue];
        fprintf(stderr, "client-probe success=%d\n", success ? 1 : 0);
        return success ? 0 : 4;
    }
}
