#import "Home26WallpaperHelper.h"
#import <dlfcn.h>
#import <CoreGraphics/CoreGraphics.h>
#import <notify.h>

@implementation Home26WallpaperHelper

+ (UIImage *)cropWallpaperImage:(UIImage *)image {
    if (!image) return nil;

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width <= 0 || screenSize.height <= 0) screenSize = CGSizeMake(390, 844);
    CGFloat screenAspect = screenSize.width / screenSize.height;

    CGFloat imgWidth = image.size.width;
    CGFloat imgHeight = image.size.height;
    if (imgWidth <= 0 || imgHeight <= 0) return image;
    CGFloat imgAspect = imgWidth / imgHeight;

    CGRect cropRect;
    if (imgAspect > screenAspect) {
        CGFloat targetWidth = imgHeight * screenAspect;
        CGFloat x = (imgWidth - targetWidth) / 2.0;
        cropRect = CGRectMake(x, 0, targetWidth, imgHeight);
    } else {
        CGFloat targetHeight = imgWidth / screenAspect;
        CGFloat y = (imgHeight - targetHeight) * 0.20;
        if (y < 0) y = 0;
        cropRect = CGRectMake(0, y, imgWidth, targetHeight);
    }

    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
    if (!imageRef) return image;

    UIImage *cropped = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imageRef);
    return cropped ?: image;
}

+ (void)requestWallpaperExport {
    notify_post("ngkhoi.26home.ExportWallpaper");
}

+ (UIImage *)rawDeviceWallpaper {
    NSString *spPath = @"/var/mobile/Library/SpringBoard/26HomeCurrentWallpaper.jpg";
    if ([[NSFileManager defaultManager] fileExistsAtPath:spPath]) {
        UIImage *img = [UIImage imageWithContentsOfFile:spPath];
        if (img && img.size.width > 100 && img.size.height > 100) {
            return img;
        }
    }

    NSArray *searchDirs = @[
        @"/var/mobile/Library/PosterBoard",
        @"/var/mobile/Library/Wallpaper",
        @"/var/mobile/Library/CoverSheet"
    ];

    NSString *newestPath = nil;
    NSDate *newestDate = [NSDate distantPast];

    for (NSString *dir in searchDirs) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dir];
            NSString *relPath;
            while ((relPath = [enumerator nextObject])) {
                NSString *ext = relPath.pathExtension.lowercaseString;
                if ([ext isEqualToString:@"png"] || [ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) {
                    NSString *fullPath = [dir stringByAppendingPathComponent:relPath];
                    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
                    NSDate *modDate = attrs[NSFileModificationDate];
                    unsigned long long fsize = [attrs[NSFileSize] unsignedLongLongValue];

                    if (fsize > 40000 && modDate && [modDate compare:newestDate] == NSOrderedDescending) {
                        UIImage *candidate = [UIImage imageWithContentsOfFile:fullPath];
                        if (candidate && candidate.size.width > 200 && candidate.size.height > 200) {
                            newestDate = modDate;
                            newestPath = fullPath;
                        }
                    }
                }
            }
        }
    }

    if (newestPath) {
        UIImage *img = [UIImage imageWithContentsOfFile:newestPath];
        if (img) return img;
    }

    CGSize size = CGSizeMake(390, 844);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 0.35, 0.70, 1.0 };

    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)@[
        (id)[UIColor colorWithRed:0.10 green:0.20 blue:0.42 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.25 green:0.42 blue:0.75 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.52 green:0.32 blue:0.68 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.85 green:0.42 blue:0.52 alpha:1.0].CGColor
    ], locations);

    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0), CGPointMake(size.width, size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    UIImage *gradientImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return gradientImg;
}

+ (UIImage *)currentDeviceWallpaper {
    [self requestWallpaperExport];
    UIImage *raw = [self rawDeviceWallpaper];
    return [self cropWallpaperImage:raw];
}

+ (void)fetchCurrentWallpaperAsync:(void(^)(UIImage *image))completion {
    if (!completion) return;

    UIImage *cached = [self rawDeviceWallpaper];
    if (cached) {
        completion([self cropWallpaperImage:cached]);
    }

    [self requestWallpaperExport];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 6; i++) {
            [NSThread sleepForTimeInterval:0.12];
            NSString *spPath = @"/var/mobile/Library/SpringBoard/26HomeCurrentWallpaper.jpg";
            if ([[NSFileManager defaultManager] fileExistsAtPath:spPath]) {
                UIImage *img = [UIImage imageWithContentsOfFile:spPath];
                if (img && img.size.width > 100 && img.size.height > 100) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion([self cropWallpaperImage:img]);
                    });
                    break;
                }
            }
        }
    });
}

@end
