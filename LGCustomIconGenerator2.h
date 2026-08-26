#import <UIKit/UIKit.h>

@interface LGCustomIconGenerator2 : NSObject

+ (instancetype)sharedGenerator;

// main entry for icon hooks (returns cached or dispatches async)
- (UIImage *)requestStyledImageForImage:(UIImage *)orig bundleID:(NSString *)bundleID;

// baked bg for folders, spotlight, prefs
- (UIImage *)requestIconImageWithBackgroundForImage:(UIImage *)orig bundleID:(NSString *)bundleID;

// orig icon cache
- (void)saveOriginalImage:(UIImage *)image forBundleID:(NSString *)bundleID;
- (UIImage *)originalImageForBundleID:(NSString *)bundleID;

// clear mem cache
- (void)clearCache;

// clear disk cache
- (void)clearDiskCache;

@end
