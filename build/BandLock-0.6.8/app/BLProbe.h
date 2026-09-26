#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

static inline void BLProbeLog(const char *message) {
    int fd = open("/var/mobile/BandLock-0.6.8-ui-stub.log", O_CREAT | O_WRONLY | O_APPEND, 0644);
    if (fd < 0) return;
    if (message) write(fd, message, strlen(message));
    close(fd);
}
