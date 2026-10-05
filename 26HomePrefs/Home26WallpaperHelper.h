#import <UIKit/UIKit.h>

@interface Home26WallpaperHelper : NSObject

+ (UIImage *)currentDeviceWallpaper;
+ (UIImage *)rawDeviceWallpaper;
+ (void)requestWallpaperExport;
+ (void)fetchCurrentWallpaperAsync:(void(^)(UIImage *image))completion;

@end
