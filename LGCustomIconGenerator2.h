#import <UIKit/UIKit.h>

@interface LGCustomIconGenerator2 : NSObject

+ (instancetype)sharedGenerator;

// Main entry point for hooked image views.
// Returns the styled image immediately if cached.
// If not, returns nil, processes in the background, and posts a notification when done.
- (UIImage *)requestStyledImageForImage:(UIImage *)orig bundleID:(NSString *)bundleID;

// Request styled image with baked-in background (for folders, spotlight, etc.)
- (UIImage *)requestIconImageWithBackgroundForImage:(UIImage *)orig bundleID:(NSString *)bundleID;

// Original image storage
- (void)saveOriginalImage:(UIImage *)image forBundleID:(NSString *)bundleID;
- (UIImage *)originalImageForBundleID:(NSString *)bundleID;

// Clears the memory cache
- (void)clearCache;

// Clears the disk cache
- (void)clearDiskCache;

@end
