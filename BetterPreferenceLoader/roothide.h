#pragma once

// Local compatibility shim for the ROOTLESS build used on Dopamine.
// The upstream source imports <roothide.h> for the jbroot() path resolver,
// including when building a rootless .deb. Standalone Theos does not include
// that header. Do not use this shim for a RootHide scheme.
#if !ROOTLESS
#error "This compatibility shim supports only ROOTLESS builds"
#endif

#import <Foundation/Foundation.h>

static inline NSString *jbroot(NSString *path) {
    if (![path isKindOfClass:NSString.class]) return nil;
    return [@"/var/jb" stringByAppendingString:path];
}
