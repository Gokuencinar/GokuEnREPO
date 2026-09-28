#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

static inline void BLProbeLog(const char *message) {
    int fd = open("/var/mobile/BandLock-0.6.11-ipc.log", O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) return;
    if (message) write(fd, message, strlen(message));
    close(fd);
}

static inline void BLProbeLogf(const char *format, ...) {
    if (!format) return;
    char buffer[1024];
    va_list args;
    va_start(args, format);
    int count = vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    if (count <= 0) return;
    buffer[sizeof(buffer) - 1] = '\0';
    BLProbeLog(buffer);
}
