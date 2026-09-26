#include "BLBreadcrumb.h"

#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <sys/time.h>
#include <unistd.h>

static const char *BLBreadcrumbPath = "/var/mobile/BandLock-client.log";

static void BLBreadcrumbWriteLine(const char *stage) {
    int fd = open(BLBreadcrumbPath, O_WRONLY | O_CREAT | O_APPEND, 0644);
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
    int fd = open(BLBreadcrumbPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
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
