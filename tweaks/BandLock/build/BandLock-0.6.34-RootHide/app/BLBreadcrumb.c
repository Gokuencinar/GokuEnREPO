#include "BLBreadcrumb.h"

#include <fcntl.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

static int BLBreadcrumbPath(char *outPath, size_t outSize) {
    const char *suffix = "/var/mobile";
    const char *home = getenv("CFFIXED_USER_HOME");
    if (!home || !*home) home = getenv("HOME");
    if (home && *home) {
        size_t homeLength = strlen(home);
        size_t suffixLength = strlen(suffix);
        if (homeLength > suffixLength &&
            strcmp(home + homeLength - suffixLength, suffix) == 0) {
            size_t rootLength = homeLength - suffixLength;
            int written = snprintf(outPath,
                                   outSize,
                                   "%.*s/tmp/BandLock-client.log",
                                   (int)rootLength,
                                   home);
            return written > 0 && (size_t)written < outSize;
        }
    }
    int written = snprintf(outPath, outSize, "/tmp/BandLock-client.log");
    return written > 0 && (size_t)written < outSize;
}

static void BLBreadcrumbWriteLine(const char *stage) {
    char path[1024];
    if (!BLBreadcrumbPath(path, sizeof(path))) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;

    struct timeval tv;
    gettimeofday(&tv, NULL);

    char line[1400];
    int length = snprintf(line,
                          sizeof(line),
                          "%lld.%03d pid=%d %s\n",
                          (long long)tv.tv_sec,
                          (int)(tv.tv_usec / 1000),
                          (int)getpid(),
                          stage ? stage : "(null)");
    if (length > 0) {
        size_t count = (size_t)length;
        if (count >= sizeof(line)) count = sizeof(line) - 1;
        (void)write(fd, line, count);
    }
    close(fd);
}

void BLBreadcrumbReset(void) {
    char path[1024];
    if (!BLBreadcrumbPath(path, sizeof(path))) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
        close(fd);
    }
    BLBreadcrumbWriteLine("log reset");
}

void BLBreadcrumb(const char *stage) {
    BLBreadcrumbWriteLine(stage);
}

void BLBreadcrumbf(const char *format, ...) {
    char message[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(message, sizeof(message), format ? format : "(null)", args);
    va_end(args);
    BLBreadcrumbWriteLine(message);
}
