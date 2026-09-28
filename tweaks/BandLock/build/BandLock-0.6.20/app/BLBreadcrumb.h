#pragma once

#ifdef __cplusplus
extern "C" {
#endif

void BLBreadcrumbReset(void);
void BLBreadcrumb(const char *stage);
void BLBreadcrumbf(const char *format, ...);

#ifdef __cplusplus
}
#endif
