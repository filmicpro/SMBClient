#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "bdsm.h"
#import "libtasn1.h"
#import "netbios_defs.h"
#import "netbios_ns.h"
#import "smb_defs.h"
#import "smb_dir.h"
#import "smb_file.h"
#import "smb_session.h"
#import "smb_share.h"
#import "smb_stat.h"
#import "smb_types.h"

FOUNDATION_EXPORT double SMBClientVersionNumber;
FOUNDATION_EXPORT const unsigned char SMBClientVersionString[];

