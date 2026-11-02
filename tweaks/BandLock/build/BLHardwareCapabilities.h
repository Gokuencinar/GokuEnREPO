// CoreTelephony's NR metadata can describe synthetic capabilities rather than
// the radio actually installed.  Known LTE-only iPhones must never show 5G.
#pragma once
#include <sys/sysctl.h>
#include <stdio.h>

static inline BOOL BLDeviceIsKnownLTEOnly(void) {
    char model[96] = {0};
    size_t length = sizeof(model);
    if (sysctlbyname("hw.machine", model, &length, NULL, 0) != 0) return NO;
    int major = 0, minor = 0;
    // iPhone12,x includes iPhone 11 Pro (12,3) and iPhone SE 2020.
    // iPhone13,x and later must still have positive modem evidence for NR.
    return sscanf(model, "iPhone%d,%d", &major, &minor) == 2 && major > 0 && major < 13;
}
