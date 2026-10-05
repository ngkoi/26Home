#import "Headers.h"
#import "LGCustomIconGenerator2.h"
#import <CoreImage/CoreImage.h>
#import <notify.h>

extern NSString *g_iconStyle;
extern NSString *g_themeMode;
extern NSString *g_darkIconMode;
extern NSString *g_tintColor;
extern NSString *g_menuAppearance;

#define kDarkClearTopOpacity 0.2
#define kDarkClearBottomOpacity 0.03
#define kDarkClearStrokeOpacity 0.2

#define kDarkClearRimTopOpacity 0.65
#define kDarkClearRimBottomOpacity 0.30

#define kLightClearTopOpacity 0.25
#define kLightClearBottomOpacity 0.03
#define kLightClearStrokeOpacity 0.2

#define kLightClearRimTopOpacity 0.70
#define kLightClearRimBottomOpacity 0.30

#define kDarkTintedTopOpacity 0.55
#define kDarkTintedBottomOpacity 0.03
#define kDarkTintedStrokeOpacity 0.2
#define kDarkTintedRimTopOpacity 0.55
#define kDarkTintedRimBottomOpacity 0.25

#define kDarkIconRimTopOpacity 0.45
#define kDarkIconRimBottomOpacity 0.20

@interface LGCustomIconGenerator2 ()
@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, strong) NSCache *skeletonCache;
@property (nonatomic, strong) NSMutableDictionary *originalImages;
@property (nonatomic, strong) NSString *cacheDirectory;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) NSMutableSet *processingIdentifiers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *pendingCallbacks;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *themeIconsCache;
- (UIImage *)_applySpecularHighlightToImage:(UIImage *)image topAlpha:(CGFloat)topAlpha bottomAlpha:(CGFloat)bottomAlpha perimeterAlpha:(CGFloat)perimeterAlpha;
@end

@implementation LGCustomIconGenerator2

+ (instancetype)sharedGenerator {
    static LGCustomIconGenerator2 *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.memoryCache = [[NSCache alloc] init];
        self.memoryCache.countLimit = 100;
        self.skeletonCache = [[NSCache alloc] init];
        self.skeletonCache.countLimit = 30;
        self.originalImages = [[NSMutableDictionary alloc] init];
        self.pendingCallbacks = [[NSMutableDictionary alloc] init];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *basePath = paths.firstObject;
        self.cacheDirectory = [basePath stringByAppendingPathComponent:@"ngkhoi.26home.icons"];

        if (![[NSFileManager defaultManager] fileExistsAtPath:self.cacheDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDirectory
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }

        dispatch_queue_attr_t qosAttr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        self.processingQueue = dispatch_queue_create("ngkhoi.26home.processingQueue", qosAttr);
        self.processingIdentifiers = [NSMutableSet set];

        [self reloadDirectoryIndex];

        int out_token;
        notify_register_dispatch("ngkhoi.26home.clearCache", &out_token, dispatch_get_main_queue(), ^(int token) {
            [self clearDiskCache];
        });

        notify_register_dispatch("ngkhoi.26home.UpdateIconStyle", &out_token, dispatch_get_main_queue(), ^(int token) {
            [self clearCache];
        });
    }
    return self;
}

static NSString *ExtractBundleIDFromIconFilename(NSString *filename) {
    if (![filename hasSuffix:@".png"]) return nil;
    NSString *name = [filename stringByDeletingPathExtension];
    if ([name hasSuffix:@"-large"]) {
        name = [name substringToIndex:name.length - 6];
    }
    if ([name isEqualToString:@"ClockIconBackgroundSquare"]) {
        return @"com.apple.mobiletimer";
    }

    if (name.length > 11 && [name characterAtIndex:10] == '.') {
        NSString *prefix = [name substringToIndex:10];
        NSCharacterSet *alphanumeric = [NSCharacterSet alphanumericCharacterSet];
        if ([[prefix stringByTrimmingCharactersInSet:alphanumeric] length] == 0) {
            name = [name substringFromIndex:11];
        }
    }
    return [name lowercaseString];
}

- (NSString *)activePackId {
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));
    CFPropertyListRef packVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.selectedIconPack"), CFSTR("com.ngkhoi.26home"));
    NSString *selectedPack = nil;
    if (packVal && [(__bridge id)packVal isKindOfClass:[NSString class]]) {
        selectedPack = [(__bridge NSString *)packVal copy];
        CFRelease(packVal);
    }
    if (!selectedPack || selectedPack.length == 0) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        selectedPack = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: @"SolidGlass";
    }
    return selectedPack ?: @"SolidGlass";
}

- (NSString *)specularStyle {
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));
    CFPropertyListRef val = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.icongen.specularStyle"), CFSTR("com.ngkhoi.26home"));
    if (val && [(__bridge id)val isKindOfClass:[NSString class]]) {
        NSString *s = [(__bridge NSString *)val copy];
        CFRelease(val);
        return s;
    }
    Boolean exists = false;
    Boolean enabled = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.icongen.specularEnabled"), CFSTR("com.ngkhoi.26home"), &exists);
    if (exists && !enabled) {
        return @"none";
    }
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    CGFloat angle = [prefs floatForKey:@"ngkhoi.26home.icongen.specularAngle"];
    if (angle == 90.0) {
        return @"27";
    }
    return @"26";
}

- (BOOL)isSpecularEnabled {
    return ![[self specularStyle] isEqualToString:@"none"];
}

- (void)getSpecularStart:(CGPoint *)outStart end:(CGPoint *)outEnd forSize:(CGSize)size {
    NSString *style = [self specularStyle];
    if ([style isEqualToString:@"27"]) {
        if (outStart) *outStart = CGPointMake(size.width / 2.0, 0);
        if (outEnd)   *outEnd   = CGPointMake(size.width / 2.0, size.height);
    } else {
        if (outStart) *outStart = CGPointMake(0, 0);
        if (outEnd)   *outEnd   = CGPointMake(size.width, size.height);
    }
}

- (NSString *)packDirectoryForId:(NSString *)packId {
    if (!packId || packId.length == 0) packId = @"SolidGlass";

    NSString *p1 = jbroot([NSString stringWithFormat:@"/Library/Application Support/26Home/IconPacks/%@", packId]);
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;

    NSString *p2 = [NSString stringWithFormat:@"/Library/Application Support/26Home/IconPacks/%@", packId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:p2]) return p2;

    NSString *l1 = jbroot([NSString stringWithFormat:@"/Library/Application Support/26Home/%@", packId]);
    if ([[NSFileManager defaultManager] fileExistsAtPath:l1]) return l1;

    NSString *l2 = [NSString stringWithFormat:@"/Library/Application Support/26Home/%@", packId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:l2]) return l2;

    return p1;
}

- (NSString *)activePackDirectory {
    return [self packDirectoryForId:[self activePackId]];
}

- (NSArray<NSString *> *)orderedPacksList {
    NSString *primaryPack = [self activePackId];
    if (!primaryPack || primaryPack.length == 0) primaryPack = @"SolidGlass";

    Boolean multiFallbackExists = false;
    Boolean multiFallback = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.multiPackFallbackEnabled"), CFSTR("com.ngkhoi.26home"), &multiFallbackExists);
    if (multiFallbackExists && !multiFallback) {
        return @[primaryPack];
    }
    if (!multiFallbackExists) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        if ([prefs objectForKey:@"ngkhoi.26home.multiPackFallbackEnabled"]) {
            if (![prefs boolForKey:@"ngkhoi.26home.multiPackFallbackEnabled"]) {
                return @[primaryPack];
            }
        } else {
            return @[primaryPack];
        }
    }

    NSMutableArray<NSString *> *result = [NSMutableArray array];
    [result addObject:primaryPack];

    CFPropertyListRef listVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.enabledPacksPriority"), CFSTR("com.ngkhoi.26home"));
    NSArray *userList = nil;
    if (listVal && [(__bridge id)listVal isKindOfClass:[NSArray class]]) {
        userList = [(__bridge NSArray *)listVal copy];
        CFRelease(listVal);
    }
    if (!userList) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        userList = [prefs arrayForKey:@"ngkhoi.26home.enabledPacksPriority"];
    }
    if (userList) {
        for (id item in userList) {
            if ([item isKindOfClass:[NSString class]] && ![result containsObject:item]) {
                [result addObject:item];
            }
        }
    }

    NSString *iconPacksDir = jbroot(@"/Library/Application Support/26Home/IconPacks");
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:iconPacksDir error:nil];
    for (NSString *packName in contents) {
        if ([packName hasPrefix:@"."]) continue;
        NSString *full = [iconPacksDir stringByAppendingPathComponent:packName];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir] && isDir) {
            if (![result containsObject:packName]) {
                [result addObject:packName];
            }
        }
    }

    if (![result containsObject:@"SolidGlass"]) {
        [result addObject:@"SolidGlass"];
    }

    return [result copy];
}

- (void)reloadDirectoryIndex {
    NSArray<NSString *> *packs = [self orderedPacksList];
    NSArray<NSString *> *themes = @[@"Light", @"LightNS", @"Dark", @"DarkNS", @"ClearLight", @"ClearDark"];

    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSString *> *> *buildingCache = [NSMutableDictionary dictionary];
    for (NSString *theme in themes) {
        buildingCache[theme] = [NSMutableDictionary dictionary];
    }

    for (NSString *packId in packs) {
        NSString *packDir = [self packDirectoryForId:packId];
        if (![[NSFileManager defaultManager] fileExistsAtPath:packDir]) continue;

        for (NSString *theme in themes) {
            NSString *themePath = [packDir stringByAppendingPathComponent:theme];
            if (![[NSFileManager defaultManager] fileExistsAtPath:themePath]) {

                if ([theme isEqualToString:@"LightNS"]) {
                    NSString *alt = [packDir stringByAppendingPathComponent:@"DefaultNS"];
                    if ([[NSFileManager defaultManager] fileExistsAtPath:alt]) {
                        themePath = alt;
                    }
                }
            }
            if (![[NSFileManager defaultManager] fileExistsAtPath:themePath]) continue;

            NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:themePath error:nil];
            if (!files || files.count == 0) continue;

            NSMutableDictionary<NSString *, NSString *> *packIcons = [NSMutableDictionary dictionary];
            for (NSString *filename in files) {
                NSString *bID = ExtractBundleIDFromIconFilename(filename);
                if (!bID) continue;

                NSString *fullPath = [themePath stringByAppendingPathComponent:filename];
                BOOL isLarge = [filename containsString:@"-large"];
                BOOL isClockBg = [filename containsString:@"ClockIconBackgroundSquare"];
                NSString *existing = packIcons[bID];
                if (!existing) {
                    packIcons[bID] = fullPath;
                } else if ([bID isEqualToString:@"com.apple.mobiletimer"]) {
                    BOOL isExactClockBg = [filename isEqualToString:@"ClockIconBackgroundSquare.png"];
                    BOOL existingIsExact = [[existing lastPathComponent] isEqualToString:@"ClockIconBackgroundSquare.png"];
                    if (isExactClockBg) {
                        packIcons[bID] = fullPath;
                    } else if (!existingIsExact) {
                        BOOL existingIsClockBg = [existing containsString:@"ClockIconBackgroundSquare"];
                        if (isClockBg && !existingIsClockBg) {
                            packIcons[bID] = fullPath;
                        } else if (isClockBg && existingIsClockBg && isLarge) {
                            packIcons[bID] = fullPath;
                        } else if (!isClockBg && !existingIsClockBg && isLarge) {
                            packIcons[bID] = fullPath;
                        }
                    }
                } else if (isLarge) {
                    packIcons[bID] = fullPath;
                }
            }

            NSMutableDictionary<NSString *, NSString *> *themeDict = buildingCache[theme];
            for (NSString *bID in packIcons) {
                if (!themeDict[bID]) {
                    themeDict[bID] = packIcons[bID];
                }
            }
        }
    }

    @synchronized (self) {
        self.themeIconsCache = buildingCache;
    }
}

- (void)saveOriginalImage:(UIImage *)image forBundleID:(NSString *)bundleID {
    if ([bundleID isEqualToString:@"com.apple.mobiletimer"] || [bundleID isEqualToString:@"com.apple.mobilecal"]) {
        return;
    }
    if (image && bundleID && image.size.width >= 50 && image.size.height >= 50) {
        @synchronized (self.originalImages) {
            [self.originalImages setObject:image forKey:bundleID];
        }
    }
}

- (UIImage *)originalImageForBundleID:(NSString *)bundleID {
    if ([bundleID isEqualToString:@"com.apple.mobiletimer"] || [bundleID isEqualToString:@"com.apple.mobilecal"]) {
        return nil;
    }
    if (!bundleID) return nil;
    @synchronized (self.originalImages) {
        return [self.originalImages objectForKey:bundleID];
    }
}

- (void)clearCache {
    [self.memoryCache removeAllObjects];
    [self.skeletonCache removeAllObjects];
    @synchronized (self.originalImages) {
        [self.originalImages removeAllObjects];
    }
    [self reloadDirectoryIndex];
}

- (void)clearDiskCache {
    [self.memoryCache removeAllObjects];
    [self.skeletonCache removeAllObjects];
    @synchronized (self.originalImages) {
        [self.originalImages removeAllObjects];
    }
    [self reloadDirectoryIndex];
    [[NSFileManager defaultManager] removeItemAtPath:self.cacheDirectory error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
}

- (UIImage *)applySpecularHighlightToImage:(UIImage *)image {
    return [self _applySpecularHighlightToImage:image topAlpha:0.75 bottomAlpha:0.35 perimeterAlpha:0.18];
}

- (UIImage *)_applySpecularHighlightToImage:(UIImage *)image topAlpha:(CGFloat)topAlpha bottomAlpha:(CGFloat)bottomAlpha perimeterAlpha:(CGFloat)perimeterAlpha {
    if (!image) return nil;
    if (![self isSpecularEnabled]) return image;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGFloat radius = image.size.width * 0.256;
    UIBezierPath *path = Home26CreateSquirclePath(CGRectMake(0, 0, image.size.width, image.size.height), radius);
    [path addClip];
    [image drawAtPoint:CGPointZero];

    CGFloat rimWidth = MAX(3.0, image.size.width * 0.024);
    [path setLineWidth:rimWidth];
    [[UIColor colorWithWhite:1.0 alpha:perimeterAlpha] setStroke];
    [path stroke];

    CGContextSaveGState(context);
    CGContextSetLineWidth(context, rimWidth);
    CGContextAddPath(context, path.CGPath);
    CGContextReplacePathWithStrokedPath(context);
    CGContextClip(context);

    CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:topAlpha].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:bottomAlpha].CGColor];

    CGFloat rimLocations[] = {0.0, 0.38, 0.62, 1.0};
    CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);

    CGPoint rimStart, rimEnd;
    [self getSpecularStart:&rimStart end:&rimEnd forSize:image.size];

    CGContextSetBlendMode(context, kCGBlendModePlusLighter);
    CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);

    CGGradientRelease(rimGradient);
    CGColorSpaceRelease(rimColorSpace);
    CGContextRestoreGState(context);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (UIImage *)_makeMonochromeImage:(UIImage *)image {
    if (!image) return nil;
    CGImageRef cgImg = image.CGImage;
    if (!cgImg) return image;

    size_t w = CGImageGetWidth(cgImg);
    size_t h = CGImageGetHeight(cgImg);
    if (w == 0 || h == 0) return image;

    CGColorSpaceRef grayCS = CGColorSpaceCreateDeviceGray();
    CGContextRef grayCtx = CGBitmapContextCreate(NULL, w, h, 8, w, grayCS,
                                                  kCGImageAlphaNone | kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(grayCS);
    if (!grayCtx) return image;

    CGContextDrawImage(grayCtx, CGRectMake(0, 0, w, h), cgImg);
    CGImageRef grayImg = CGBitmapContextCreateImage(grayCtx);
    CGContextRelease(grayCtx);

    CGColorSpaceRef rgbCS = CGColorSpaceCreateDeviceRGB();
    size_t bpr = w * 4;
    unsigned char *buf = (unsigned char *)calloc(h * bpr, 1);
    if (!buf) { CGImageRelease(grayImg); CGColorSpaceRelease(rgbCS); return image; }
    CGContextRef rgbaCtx = CGBitmapContextCreate(buf, w, h, 8, bpr, rgbCS,
                                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(rgbCS);
    if (!rgbaCtx) { free(buf); CGImageRelease(grayImg); return image; }

    CGContextDrawImage(rgbaCtx, CGRectMake(0, 0, w, h), cgImg);

    CGContextSetBlendMode(rgbaCtx, kCGBlendModeSaturation);
    CGContextDrawImage(rgbaCtx, CGRectMake(0, 0, w, h), grayImg);
    CGContextSetBlendMode(rgbaCtx, kCGBlendModeNormal);

    CGImageRef resultImg = CGBitmapContextCreateImage(rgbaCtx);
    CGContextRelease(rgbaCtx);
    free(buf);
    CGImageRelease(grayImg);

    if (!resultImg) return image;
    UIImage *result = [UIImage imageWithCGImage:resultImg scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(resultImg);
    return result ?: image;
}

- (UIImage *)applySquircleMaskToImage:(UIImage *)image {
    if (!image || image.size.width <= 0 || image.size.height <= 0) return image;
    CGSize size = image.size;
    CGFloat scale = image.scale > 0 ? image.scale : [UIScreen mainScreen].scale;
    CGFloat radius = size.width * 0.256;

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        UIGraphicsEndImageContext();
        return image;
    }

    UIBezierPath *path = Home26CreateSquirclePath(CGRectMake(0, 0, size.width, size.height), radius);
    [path addClip];
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *masked = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return masked ?: image;
}

- (UIImage *)_premadeIconForBundleID:(NSString *)bundleID style:(NSString *)style {
    if (!bundleID || !style) return nil;

    NSString *targetTheme = nil;
    NSString *fallbackTheme = nil;

    if ([style isEqualToString:@"Light"]) {
        targetTheme = @"Light";
        fallbackTheme = @"LightNS";
    } else if ([style isEqualToString:@"LightNS"] || [style isEqualToString:@"DefaultNS"]) {
        targetTheme = @"LightNS";
        fallbackTheme = nil;
    } else if ([style isEqualToString:@"Dark"]) {
        targetTheme = @"Dark";
        fallbackTheme = @"DarkNS";
    } else if ([style isEqualToString:@"DarkNS"]) {
        targetTheme = @"DarkNS";
        fallbackTheme = nil;
    } else if ([style isEqualToString:@"ClearLight"]) {
        targetTheme = @"ClearLight";
    } else if ([style isEqualToString:@"ClearDark"]) {
        targetTheme = @"ClearDark";
        fallbackTheme = @"ClearLight";
    }

    if (!targetTheme) return nil;

    NSString *bID = [bundleID lowercaseString];

    NSString *filePath = nil;
    @synchronized (self) {
        filePath = self.themeIconsCache[targetTheme][bID];
        if (!filePath && fallbackTheme) {
            filePath = self.themeIconsCache[fallbackTheme][bID];
        }
    }

    if (filePath) {
        return [UIImage imageWithContentsOfFile:filePath];
    }

    return nil;
}

- (UIColor *)adjustedTintColorFromHex:(NSString *)hex isDarkTheme:(BOOL)isDarkTheme {
    NSString *tintHex = hex ?: @"#00FFFF";
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:tintHex];
    if ([tintHex hasPrefix:@"#"]) {
        [scanner setScanLocation:1];
    }
    [scanner scanHexInt:&rgbValue];

    UIColor *rawColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0
                                        green:((rgbValue & 0xFF00) >> 8)/255.0
                                         blue:((rgbValue & 0xFF)/255.0)
                                        alpha:1.0];

    CGFloat h, s, b, a;
    [rawColor getHue:&h saturation:&s brightness:&b alpha:&a];

    s = s * 0.70;

    if (isDarkTheme) {
        b = MIN(b * 0.85, 0.85);
        b = MAX(b, 0.20);
    } else {

        b = MIN(b * 0.70, 0.70);
        b = MAX(b, 0.20);
    }

    return [UIColor colorWithHue:h saturation:s brightness:b alpha:1.0];
}

- (void)_resolveEffectiveStyle:(NSString **)outEffectiveStyle isDarkTheme:(BOOL *)outIsDarkTheme {
    NSString *style = g_iconStyle ?: @"Default";
    BOOL isSystemDark = NO;
    if (@available(iOS 13.0, *)) {
        isSystemDark = ([UIScreen mainScreen].traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    BOOL isDarkTheme = NO;
    NSString *effectiveStyle = style;

    if ([style isEqualToString:@"Dark"]) {
        NSString *darkIconMode = g_darkIconMode ?: @"Always";
        if ([darkIconMode isEqualToString:@"Always"]) {
            isDarkTheme = YES;
            effectiveStyle = @"Dark";
        } else {
            isDarkTheme = isSystemDark;
            effectiveStyle = isSystemDark ? @"Dark" : @"Default";
        }
    } else if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
        NSString *themeMode = g_themeMode ?: @"Auto";
        if ([themeMode isEqualToString:@"Dark"]) {
            isDarkTheme = YES;
        } else if ([themeMode isEqualToString:@"Light"]) {
            isDarkTheme = NO;
        } else {
            isDarkTheme = isSystemDark;
        }
        effectiveStyle = style;
    } else {
        isDarkTheme = NO;
        effectiveStyle = @"Default";
    }

    if (outEffectiveStyle) *outEffectiveStyle = effectiveStyle;
    if (outIsDarkTheme) *outIsDarkTheme = isDarkTheme;
}

- (UIImage *)generateDynamicIconForBundleID:(NSString *)bundleID style:(NSString *)style isDarkTheme:(BOOL)isDarkTheme {

    NSString *themeName = @"Light";
    if ([style isEqualToString:@"Dark"]) {
        themeName = isDarkTheme ? @"Dark" : @"Light";
    } else if ([style isEqualToString:@"Clear"]) {
        themeName = isDarkTheme ? @"ClearDark" : @"ClearLight";
    } else if ([style isEqualToString:@"Tinted"]) {
        if (isDarkTheme) {
            UIImage *premadeClearDark = [self _premadeIconForBundleID:bundleID style:@"ClearDark"];
            themeName = premadeClearDark ? @"ClearDark" : @"Dark";
        } else {
            UIImage *premadeClearLight = [self _premadeIconForBundleID:bundleID style:@"ClearLight"];
            themeName = premadeClearLight ? @"ClearLight" : @"Light";
        }
    }

    UIImage *baseImage = [self _premadeIconForBundleID:bundleID style:themeName];
    if (!baseImage) {

        baseImage = [self _premadeIconForBundleID:bundleID style:isDarkTheme ? @"Dark" : @"Light"];
    }
    if (!baseImage) return nil;

    UIImage *renderedImage = baseImage;
    if ([bundleID isEqualToString:@"com.apple.mobilecal"]) {
        UIGraphicsBeginImageContextWithOptions(baseImage.size, NO, baseImage.scale);
        [baseImage drawAtPoint:CGPointZero];

        NSDate *date = [NSDate date];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

        [formatter setDateFormat:@"EEEE"];
        NSString *dayString = [[formatter stringFromDate:date] uppercaseString];
        UIColor *dayColor = [UIColor systemRedColor];
        UIFont *dayFont = [UIFont systemFontOfSize:baseImage.size.width * 0.15 weight:UIFontWeightSemibold];
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        [dayString drawInRect:CGRectMake(0, baseImage.size.height * 0.15, baseImage.size.width, baseImage.size.height * 0.2)
               withAttributes:@{NSFontAttributeName: dayFont, NSForegroundColorAttributeName: dayColor, NSParagraphStyleAttributeName: paragraphStyle}];

        [formatter setDateFormat:@"d"];
        NSString *dateString = [formatter stringFromDate:date];
        UIColor *dateColor = [UIColor blackColor];
        if ([style isEqualToString:@"Dark"] || [style isEqualToString:@"Tinted"] || ([style isEqualToString:@"Clear"] && isDarkTheme)) {
            dateColor = [UIColor whiteColor];
        }
        UIFont *dateFont = [UIFont systemFontOfSize:baseImage.size.width * 0.4 weight:UIFontWeightLight];
        [dateString drawInRect:CGRectMake(0, baseImage.size.height * 0.35, baseImage.size.width, baseImage.size.height * 0.5)
                withAttributes:@{NSFontAttributeName: dateFont, NSForegroundColorAttributeName: dateColor, NSParagraphStyleAttributeName: paragraphStyle}];

        renderedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    if ([style isEqualToString:@"Default"] || [style isEqualToString:@"Dark"]) {

        if ([bundleID isEqualToString:@"com.apple.mobilecal"] || [bundleID isEqualToString:@"com.apple.mobiletimer"]) {
            return [self applySquircleMaskToImage:renderedImage];
        }
        CGFloat topAlpha = [style isEqualToString:@"Dark"] ? kDarkIconRimTopOpacity : 0.92;
        CGFloat bottomAlpha = [style isEqualToString:@"Dark"] ? kDarkIconRimBottomOpacity : 0.48;
        CGFloat perimeterAlpha = [style isEqualToString:@"Dark"] ? 0.16 : 0.28;
        UIImage *highlighted = [self _applySpecularHighlightToImage:renderedImage topAlpha:topAlpha bottomAlpha:bottomAlpha perimeterAlpha:perimeterAlpha];
        return [self applySquircleMaskToImage:highlighted];
    }

    if ([bundleID isEqualToString:@"com.apple.mobiletimer"]) {
        if ([style isEqualToString:@"Clear"]) {
            return [self applySquircleMaskToImage:renderedImage];
        }
    }

    UIColor *tintColor = [self adjustedTintColorFromHex:g_tintColor isDarkTheme:isDarkTheme];
    BOOL isTimer = [bundleID isEqualToString:@"com.apple.mobiletimer"];
    UIImage *styled = [self compositeGlyph:renderedImage withBackgroundStyle:style isDarkTheme:isDarkTheme tintColor:tintColor isAutoGenerated:!isTimer drawSpecular:NO];
    if (!styled) styled = renderedImage;

    if ([style isEqualToString:@"Tinted"] && isDarkTheme && styled) {
        UIGraphicsBeginImageContextWithOptions(styled.size, NO, styled.scale);
        CGFloat radius = styled.size.width * 0.256;
        UIBezierPath *path = Home26CreateSquirclePath(CGRectMake(0, 0, styled.size.width, styled.size.height), radius);
        [path addClip];

        [tintColor setFill];
        UIRectFill(CGRectMake(0, 0, styled.size.width, styled.size.height));

        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeLuminosity alpha:1.0];
        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0];

        styled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    return [self applySquircleMaskToImage:styled];
}

- (UIImage *)requestStyledImageForImage:(UIImage *)orig bundleID:(NSString *)bundleID {
    if (!orig || !bundleID) return nil;

    NSString *style = g_iconStyle;
    if (!style) style = @"Default";

    NSString *themeMode = g_themeMode;
    BOOL isDarkTheme = NO;
    if ([themeMode isEqualToString:@"Dark"]) {
        isDarkTheme = YES;
    } else if ([themeMode isEqualToString:@"Light"]) {
        isDarkTheme = NO;
    } else {
        isDarkTheme = ([UIScreen mainScreen].traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    BOOL isDynamicIcon = ([bundleID isEqualToString:@"com.apple.mobiletimer"] || [bundleID isEqualToString:@"com.apple.mobilecal"]);
    if (isDynamicIcon) {
        return [self generateDynamicIconForBundleID:bundleID style:style isDarkTheme:isDarkTheme];
    }

    if ([style isEqualToString:@"Clear"]) {
        UIImage *premade = [self _premadeIconForBundleID:bundleID style:isDarkTheme ? @"ClearDark" : @"ClearLight"];
        if (premade) return premade;
    }

    UIImage *baseOrig = orig;
    if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
        UIImage *premadeDark = [self _premadeIconForBundleID:bundleID style:@"Dark"];
        if (premadeDark) {
            baseOrig = premadeDark;
        }
    }

    NSString *packId = [self activePackId];
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@_%@_v11_spec_%@", bundleID, packId, style, [self specularStyle]];

    UIImage *memCached = [self.memoryCache objectForKey:cacheKey];
    if (memCached) return memCached;

    NSString *diskPath = [self.cacheDirectory stringByAppendingPathComponent:[cacheKey stringByAppendingString:@".png"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        UIImage *diskCached = [UIImage imageWithContentsOfFile:diskPath];
        if (diskCached) {
            [self.memoryCache setObject:diskCached forKey:cacheKey];
            return diskCached;
        }
    }

    @synchronized (self.processingIdentifiers) {
        if ([self.processingIdentifiers containsObject:cacheKey]) return nil;
        [self.processingIdentifiers addObject:cacheKey];
    }

    dispatch_async(self.processingQueue, ^{
        UIImage *styled = nil;
        if ([style isEqualToString:@"Dark"]) {
            styled = [self generateDarkIconForImage:baseOrig bundleID:bundleID];
        } else if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
            styled = [self generateClearIconForImage:baseOrig bundleID:bundleID];
        } else {
            styled = baseOrig;
        }

        if (styled) {

            UIGraphicsBeginImageContextWithOptions(styled.size, NO, styled.scale);
            CGFloat radius = styled.size.width * 0.256;
            UIBezierPath *path = Home26CreateSquirclePath(CGRectMake(0, 0, styled.size.width, styled.size.height), radius);
            [path addClip];
            [styled drawAtPoint:CGPointZero];

            if (([style isEqualToString:@"Default"] || [style isEqualToString:@"Dark"]) && [self isSpecularEnabled]) {
                CGContextRef context = UIGraphicsGetCurrentContext();

                [path setLineWidth:3.0];
                CGFloat perimeterAlpha = [style isEqualToString:@"Dark"] ? 0.10 : 0.15;
                [[UIColor colorWithWhite:1.0 alpha:perimeterAlpha] setStroke];
                [path stroke];

                CGContextSaveGState(context);
                CGContextSetLineWidth(context, 3.0);
                CGContextAddPath(context, path.CGPath);
                CGContextReplacePathWithStrokedPath(context);
                CGContextClip(context);

                CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
                CGFloat rimTopAlpha = [style isEqualToString:@"Dark"] ? kDarkIconRimTopOpacity : 0.75;
                CGFloat rimBottomAlpha = [style isEqualToString:@"Dark"] ? kDarkIconRimBottomOpacity : 0.35;
                NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:rimTopAlpha].CGColor,
                                       (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                       (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                       (id)[UIColor colorWithWhite:1.0 alpha:rimBottomAlpha].CGColor];

                CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
                CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);

                CGPoint rimStart, rimEnd;
                [self getSpecularStart:&rimStart end:&rimEnd forSize:styled.size];

                CGContextSetBlendMode(context, kCGBlendModePlusLighter);
        CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);

                CGGradientRelease(rimGradient);
                CGColorSpaceRelease(rimColorSpace);
                CGContextRestoreGState(context);
            }

            styled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            styled = [self applySquircleMaskToImage:styled];

            [self.memoryCache setObject:styled forKey:cacheKey];
            NSData *pngData = UIImagePNGRepresentation(styled);
            [pngData writeToFile:diskPath atomically:YES];
        }

        @synchronized (self.processingIdentifiers) {
            [self.processingIdentifiers removeObject:cacheKey];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.IconReady"
                                                                object:nil
                                                              userInfo:@{@"bundleID": bundleID}];
        });
    });

    return nil;
}

- (UIImage *)compositeGlyph:(UIImage *)glyph withBackgroundStyle:(NSString *)style isDarkTheme:(BOOL)isDarkTheme {
    return [self compositeGlyph:glyph withBackgroundStyle:style isDarkTheme:isDarkTheme tintColor:nil isAutoGenerated:YES drawSpecular:YES];
}
- (UIImage *)compositeGlyph:(UIImage *)glyph withBackgroundStyle:(NSString *)style isDarkTheme:(BOOL)isDarkTheme tintColor:(UIColor *)tintColor isAutoGenerated:(BOOL)isAutoGenerated drawSpecular:(BOOL)drawSpecular {
    return [self compositeGlyph:glyph withBackgroundStyle:style isDarkTheme:isDarkTheme tintColor:tintColor isAutoGenerated:isAutoGenerated drawSpecular:drawSpecular isStockArtwork:NO];
}
- (UIImage *)skeletonBackgroundForStyle:(NSString *)style isDarkTheme:(BOOL)isDarkTheme tintColor:(UIColor *)tintColor size:(CGSize)size scale:(CGFloat)scale {
    CGFloat targetW = MAX(256.0, size.width * (scale > 0 ? scale : 1.0));
    CGFloat targetH = MAX(256.0, size.height * (scale > 0 ? scale : 1.0));
    CGSize canvasSize = CGSizeMake(targetW, targetH);
    CGFloat canvasScale = 1.0;

    NSString *tintHex = @"";
    if ([style isEqualToString:@"Tinted"]) {
        tintHex = g_tintColor ?: @"#00FFFF";
    }
    BOOL disableGrad = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] boolForKey:@"ngkhoi.26home.disableDarkTintGradient"];
    NSString *skelKey = [NSString stringWithFormat:@"skel_%@_%@_%@_%@_%d_%.0fx%.0f", style ?: @"Default", isDarkTheme ? @"dark" : @"light", tintHex, [self specularStyle], disableGrad, canvasSize.width, canvasSize.height];

    UIImage *cached = [self.skeletonCache objectForKey:skelKey];
    if (cached) return cached;

    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, canvasScale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetAllowsAntialiasing(context, YES);
    CGContextSetShouldAntialias(context, YES);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

    CGFloat radius = canvasSize.width * 0.256;
    UIBezierPath *path = Home26CreateSquirclePath(CGRectMake(0, 0, canvasSize.width, canvasSize.height), radius);
    [path addClip];

    if ([style isEqualToString:@"Tinted"] && !isDarkTheme) {
        [[UIColor colorWithWhite:0.0 alpha:0.16] setFill];
        [path fill];

        CGFloat topOpacity = 0.20;
        CGFloat botOpacity = 0.04;
        CGFloat strokeOpacity = 0.22;

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(id)[(tintColor ?: [UIColor cyanColor]) colorWithAlphaComponent:topOpacity].CGColor,
                            (id)[(tintColor ?: [UIColor cyanColor]) colorWithAlphaComponent:botOpacity].CGColor];

        CGFloat locations[] = {0.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);

        CGPoint startPoint = CGPointMake(canvasSize.width/2, 0);
        CGPoint endPoint = CGPointMake(canvasSize.width/2, canvasSize.height);

        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);

        CGFloat strokeWidth = MAX(1.5, canvasSize.width * 0.008);
        CGFloat rimWidth = MAX(3.0, canvasSize.width * 0.024);
        [path setLineWidth:strokeWidth];
        [[(tintColor ?: [UIColor cyanColor]) colorWithAlphaComponent:strokeOpacity] setStroke];
        [path stroke];

        if ([self isSpecularEnabled]) {
            CGContextSaveGState(context);
            [path setLineWidth:rimWidth];
            CGContextAddPath(context, path.CGPath);
            CGContextReplacePathWithStrokedPath(context);
            CGContextClip(context);

            CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
            NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.55].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:0.25].CGColor];

            CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
            CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);

            CGPoint rimStart, rimEnd;
            [self getSpecularStart:&rimStart end:&rimEnd forSize:canvasSize];

            CGContextSetBlendMode(context, kCGBlendModePlusLighter);
            CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);
            CGGradientRelease(rimGradient);
            CGColorSpaceRelease(rimColorSpace);
            CGContextRestoreGState(context);
        }
    } else if ([style isEqualToString:@"Clear"] || ([style isEqualToString:@"Tinted"] && isDarkTheme)) {
        if ([style isEqualToString:@"Tinted"] && isDarkTheme) {
            [[UIColor colorWithWhite:0.06 alpha:1.0] setFill];
            [path fill];
            [[UIColor colorWithWhite:0.0 alpha:0.40] setFill];
            [path fill];
        }

        CGFloat topOpacity = 0.2;
        CGFloat botOpacity = 0.03;
        CGFloat strokeOpacity = 0.2;
        CGFloat rimTopOpacity = 1.0;
        CGFloat rimBotOpacity = 1.0;

        if ([style isEqualToString:@"Tinted"] && isDarkTheme) {
            if (disableGrad) {
                topOpacity = 0.0;
                botOpacity = 0.0;
                strokeOpacity = 0.0;
                rimTopOpacity = 0.0;
                rimBotOpacity = 0.0;
            } else {
                topOpacity = kDarkTintedTopOpacity;
                botOpacity = kDarkTintedBottomOpacity;
                strokeOpacity = kDarkTintedStrokeOpacity;
                rimTopOpacity = kDarkTintedRimTopOpacity;
                rimBotOpacity = kDarkTintedRimBottomOpacity;
            }
        } else if (isDarkTheme) {
            topOpacity = kDarkClearTopOpacity;
            botOpacity = kDarkClearBottomOpacity;
            strokeOpacity = kDarkClearStrokeOpacity;
            rimTopOpacity = kDarkClearRimTopOpacity;
            rimBotOpacity = kDarkClearRimBottomOpacity;
        } else {
            topOpacity = kLightClearTopOpacity;
            botOpacity = kLightClearBottomOpacity;
            strokeOpacity = kLightClearStrokeOpacity;
            rimTopOpacity = kLightClearRimTopOpacity;
            rimBotOpacity = kLightClearRimBottomOpacity;
        }

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(id)[UIColor colorWithWhite:1.0 alpha:topOpacity].CGColor,
                            (id)[UIColor colorWithWhite:1.0 alpha:botOpacity].CGColor];

        CGFloat locations[] = {0.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);

        CGPoint startPoint = CGPointMake(canvasSize.width/2, 0);
        CGPoint endPoint = CGPointMake(canvasSize.width/2, canvasSize.height);

        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);

        CGFloat strokeWidth = MAX(1.5, canvasSize.width * 0.008);
        CGFloat rimWidth = MAX(3.0, canvasSize.width * 0.024);
        [path setLineWidth:strokeWidth];
        [[UIColor colorWithWhite:1.0 alpha:strokeOpacity] setStroke];
        [path stroke];

        if ([self isSpecularEnabled] && ![g_menuAppearance isEqualToString:@"iOS18"]) {
            CGContextSaveGState(context);
            [path setLineWidth:rimWidth];
            CGContextAddPath(context, path.CGPath);
            CGContextReplacePathWithStrokedPath(context);
            CGContextClip(context);

            CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
            NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:rimTopOpacity].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                   (id)[UIColor colorWithWhite:1.0 alpha:rimBotOpacity].CGColor];

            CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
            CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);

            CGPoint rimStart, rimEnd;
            [self getSpecularStart:&rimStart end:&rimEnd forSize:canvasSize];

            CGContextSetBlendMode(context, kCGBlendModePlusLighter);
            CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);
            CGGradientRelease(rimGradient);
            CGColorSpaceRelease(rimColorSpace);
            CGContextRestoreGState(context);
        }
    } else {
        UIColor *bgColor = [UIColor clearColor];
        if ([style isEqualToString:@"Dark"]) {
            bgColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        }
        [bgColor setFill];
        [path fill];
    }

    UIImage *skeleton = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (skeleton) {
        skeleton = [self applySquircleMaskToImage:skeleton];
        [self.skeletonCache setObject:skeleton forKey:skelKey];
    }
    return skeleton;
}

- (UIImage *)skeletonBackgroundForBundleID:(NSString *)bundleID size:(CGSize)size scale:(CGFloat)scale {
    NSString *effectiveStyle = @"Default";
    BOOL isDarkTheme = NO;
    [self _resolveEffectiveStyle:&effectiveStyle isDarkTheme:&isDarkTheme];

    UIColor *tintColor = nil;
    if ([effectiveStyle isEqualToString:@"Tinted"]) {
        NSString *tintHex = g_tintColor ?: @"#00FFFF";
        tintColor = [self adjustedTintColorFromHex:tintHex isDarkTheme:isDarkTheme];
    }

    return [self skeletonBackgroundForStyle:effectiveStyle isDarkTheme:isDarkTheme tintColor:tintColor size:size scale:scale];
}

- (UIImage *)compositeGlyph:(UIImage *)glyph withBackgroundStyle:(NSString *)style isDarkTheme:(BOOL)isDarkTheme tintColor:(UIColor *)tintColor isAutoGenerated:(BOOL)isAutoGenerated drawSpecular:(BOOL)drawSpecular isStockArtwork:(BOOL)isStockArtwork {
    if (!glyph) return nil;

    if (!tintColor && [style isEqualToString:@"Tinted"]) {
        tintColor = [self adjustedTintColorFromHex:g_tintColor isDarkTheme:isDarkTheme];
    }

    CGFloat targetW = MAX(256.0, glyph.size.width * glyph.scale);
    CGFloat targetH = MAX(256.0, glyph.size.height * glyph.scale);
    CGSize canvasSize = CGSizeMake(targetW, targetH);
    CGFloat canvasScale = 1.0;

    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, canvasScale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetAllowsAntialiasing(context, YES);
    CGContextSetShouldAntialias(context, YES);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

    UIImage *bg = [self skeletonBackgroundForStyle:style isDarkTheme:isDarkTheme tintColor:tintColor size:canvasSize scale:canvasScale];
    if (bg) {
        [bg drawInRect:CGRectMake(0, 0, canvasSize.width, canvasSize.height)];
    }

    CGFloat radius = canvasSize.width * 0.256;
    UIBezierPath *path = Home26CreateSquirclePath(CGRectMake(0, 0, canvasSize.width, canvasSize.height), radius);
    [path addClip];

    CGContextSaveGState(context);
    if (([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) && isAutoGenerated && !isStockArtwork) {
        CGContextSetShadowWithColor(context, CGSizeMake(0, 1.5), 3.5, [UIColor colorWithWhite:0.0 alpha:0.35].CGColor);
    }

    CGRect glyphRect = CGRectMake(0, 0, canvasSize.width, canvasSize.height);
    if (isStockArtwork) {
        if ([style isEqualToString:@"Tinted"]) {
            if (!isDarkTheme) {

                UIGraphicsBeginImageContextWithOptions(canvasSize, NO, canvasScale);
                CGContextRef ctx = UIGraphicsGetCurrentContext();
                CGContextSetAllowsAntialiasing(ctx, YES);
                CGContextSetShouldAntialias(ctx, YES);
                CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
                [glyph drawInRect:glyphRect];
                if (tintColor) {
                    [tintColor setFill];
                    UIRectFillUsingBlendMode(glyphRect, kCGBlendModeColor);
                }

                [[UIColor colorWithWhite:1.0 alpha:0.25] setFill];
                CGContextSetBlendMode(ctx, kCGBlendModeScreen);
                CGContextFillRect(ctx, glyphRect);
                UIImage *tintedGlyph = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();

                CGFloat tintedAlpha = 0.85;
                [(tintedGlyph ?: glyph) drawInRect:glyphRect blendMode:kCGBlendModeNormal alpha:tintedAlpha];
            } else {
                [glyph drawInRect:glyphRect];
                if (tintColor) {
                    [tintColor setFill];
                    UIRectFillUsingBlendMode(glyphRect, kCGBlendModeColor);
                }
            }
        } else if ([style isEqualToString:@"Clear"]) {

            CGFloat stockAlpha = isDarkTheme ? 0.80 : 0.85;
            UIImage *monoGlyph = [self _makeMonochromeImage:glyph];
            UIImage *srcGlyph = monoGlyph ?: glyph;

            UIGraphicsBeginImageContextWithOptions(canvasSize, NO, canvasScale);
            CGContextRef monoCtx = UIGraphicsGetCurrentContext();
            CGContextSetAllowsAntialiasing(monoCtx, YES);
            CGContextSetShouldAntialias(monoCtx, YES);
            CGContextSetInterpolationQuality(monoCtx, kCGInterpolationHigh);
            [srcGlyph drawInRect:glyphRect];
            if (!isDarkTheme) {

                [[UIColor colorWithWhite:1.0 alpha:0.35] setFill];
                CGContextSetBlendMode(monoCtx, kCGBlendModeScreen);
                CGContextFillRect(monoCtx, glyphRect);
            } else {

                [[UIColor colorWithWhite:1.0 alpha:0.45] setFill];
                CGContextSetBlendMode(monoCtx, kCGBlendModeScreen);
                CGContextFillRect(monoCtx, glyphRect);
            }
            CGContextSetBlendMode(monoCtx, kCGBlendModeNormal);
            UIImage *liftedGlyph = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            srcGlyph = liftedGlyph ?: srcGlyph;

            [srcGlyph drawInRect:glyphRect blendMode:kCGBlendModeNormal alpha:stockAlpha];
        } else {
            [glyph drawInRect:glyphRect];
        }
    } else {
        [glyph drawInRect:glyphRect];
    }
    CGContextRestoreGState(context);

    if (drawSpecular && [self isSpecularEnabled] && ![g_menuAppearance isEqualToString:@"iOS18"] && (([style isEqualToString:@"Default"] || [style isEqualToString:@"Dark"]) || isStockArtwork)) {
        CGContextSaveGState(context);
        [path setLineWidth:1.5];
        [[UIColor colorWithWhite:1.0 alpha:0.15] setStroke];
        [path stroke];

        CGContextSetLineWidth(context, 1.5);
        CGContextAddPath(context, path.CGPath);
        CGContextReplacePathWithStrokedPath(context);
        CGContextClip(context);

        CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat rimTopAlpha = [style isEqualToString:@"Dark"] ? kDarkIconRimTopOpacity : 0.75;
        CGFloat rimBottomAlpha = [style isEqualToString:@"Dark"] ? kDarkIconRimBottomOpacity : 0.35;
        NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:rimTopAlpha].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:rimBottomAlpha].CGColor];

        CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
        CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);

        CGPoint rimStart, rimEnd;
        [self getSpecularStart:&rimStart end:&rimEnd forSize:canvasSize];

        CGContextSetBlendMode(context, kCGBlendModePlusLighter);
        CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);

        CGGradientRelease(rimGradient);
        CGColorSpaceRelease(rimColorSpace);

        CGContextRestoreGState(context);
    }

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return [self applySquircleMaskToImage:result];
}

- (NSString *)_cacheKeyForBundleID:(NSString *)bundleID effectiveStyle:(NSString *)effectiveStyle isDarkTheme:(BOOL)isDarkTheme nsPremade:(UIImage *)nsPremade {
    NSString *tintHex = @"";
    if ([effectiveStyle isEqualToString:@"Tinted"]) {
        tintHex = g_tintColor ?: @"#00FFFF";
    }
    BOOL disableGrad = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] boolForKey:@"ngkhoi.26home.disableDarkTintGradient"];
    NSString *packId = [self activePackId];
    BOOL isException = isAppInExceptionList(bundleID);
    BOOL skipIconGen = isException && g_exceptionsNoIconProcessing;
    return [NSString stringWithFormat:@"%@_%@_%@_v54_bg_%@_%@_%@_%d%@%@_spec_%@", bundleID, packId, effectiveStyle, isDarkTheme ? @"dark" : @"light", tintHex, g_menuAppearance, disableGrad, nsPremade ? @"_ns4" : @"", skipIconGen ? @"_noGen2" : @"", [self specularStyle]];
}

- (UIImage *)fastCachedIconForBundleID:(NSString *)bundleID {
    if (!bundleID) return nil;

    NSString *effectiveStyle = @"Default";
    BOOL isDarkTheme = NO;
    [self _resolveEffectiveStyle:&effectiveStyle isDarkTheme:&isDarkTheme];

    BOOL isDynamicIcon = ([bundleID isEqualToString:@"com.apple.mobiletimer"] || [bundleID isEqualToString:@"com.apple.mobilecal"]);
    if (isDynamicIcon) {
        return [self generateDynamicIconForBundleID:bundleID style:effectiveStyle isDarkTheme:isDarkTheme];
    }

    if ([effectiveStyle isEqualToString:@"Clear"]) {
        NSString *clearStyle = isDarkTheme ? @"ClearDark" : @"ClearLight";
        UIImage *premade = [self _premadeIconForBundleID:bundleID style:clearStyle];
        if (premade) return premade;
    }

    UIImage *nsPremade = nil;
    if ([effectiveStyle isEqualToString:@"Dark"]) {
        nsPremade = [self _premadeIconForBundleID:bundleID style:@"DarkNS"];
        if (!nsPremade) {
            UIImage *premadeDark = [self _premadeIconForBundleID:bundleID style:@"Dark"];
            if (premadeDark) return [self applySquircleMaskToImage:premadeDark];
        }
    } else if ([effectiveStyle isEqualToString:@"Default"]) {
        nsPremade = [self _premadeIconForBundleID:bundleID style:@"LightNS"];
        if (!nsPremade) {
            UIImage *premadeLight = [self _premadeIconForBundleID:bundleID style:@"Light"];
            if (premadeLight) return [self applySquircleMaskToImage:premadeLight];
        }
    }

    NSString *cacheKey = [self _cacheKeyForBundleID:bundleID effectiveStyle:effectiveStyle isDarkTheme:isDarkTheme nsPremade:nsPremade];
    UIImage *memCached = [self.memoryCache objectForKey:cacheKey];
    if (memCached) {
        return memCached;
    }

    NSString *diskPath = [self.cacheDirectory stringByAppendingPathComponent:[cacheKey stringByAppendingString:@".png"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        UIImage *diskCached = [UIImage imageWithContentsOfFile:diskPath];
        if (diskCached) {
            [self.memoryCache setObject:diskCached forKey:cacheKey];
            return diskCached;
        }
    }

    return nil;
}

- (void)requestIconAsyncForImage:(UIImage *)orig bundleID:(NSString *)bundleID completion:(void (^)(UIImage *styled))completion {
    if (!bundleID) {
        if (completion) completion(nil);
        return;
    }

    UIImage *cached = [self fastCachedIconForBundleID:bundleID];
    if (cached) {
        if (completion) {
            if ([NSThread isMainThread]) {
                completion(cached);
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(cached);
                });
            }
        }
        return;
    }

    @synchronized (self.processingIdentifiers) {
        if (completion) {
            NSMutableArray *cbs = self.pendingCallbacks[bundleID];
            if (!cbs) {
                cbs = [NSMutableArray array];
                self.pendingCallbacks[bundleID] = cbs;
            }
            [cbs addObject:[completion copy]];
        }

        if ([self.processingIdentifiers containsObject:bundleID]) {
            return;
        }
        [self.processingIdentifiers addObject:bundleID];
    }

    dispatch_async(self.processingQueue, ^{
        UIImage *styled = [self requestIconImageWithBackgroundForImage:orig bundleID:bundleID];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *callbacksToCall = nil;
            @synchronized (self.processingIdentifiers) {
                [self.processingIdentifiers removeObject:bundleID];
                callbacksToCall = [self.pendingCallbacks[bundleID] copy];
                [self.pendingCallbacks removeObjectForKey:bundleID];
            }

            for (void (^cb)(UIImage *) in callbacksToCall) {
                cb(styled);
            }

            if (styled) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.IconDidGenerate"
                                                                    object:nil
                                                                  userInfo:@{@"bundleID": bundleID, @"image": styled}];
            }
        });
    });
}

- (UIImage *)requestIconImageWithBackgroundForImage:(UIImage *)orig bundleID:(NSString *)bundleID {
    if (!orig || !bundleID) return nil;

    NSString *effectiveStyle = @"Default";
    BOOL isDarkTheme = NO;
    [self _resolveEffectiveStyle:&effectiveStyle isDarkTheme:&isDarkTheme];

    BOOL isDynamicIcon = ([bundleID isEqualToString:@"com.apple.mobiletimer"] || [bundleID isEqualToString:@"com.apple.mobilecal"]);
    if (isDynamicIcon) {
        return [self generateDynamicIconForBundleID:bundleID style:effectiveStyle isDarkTheme:isDarkTheme];
    }

    if ([effectiveStyle isEqualToString:@"Clear"]) {
        NSString *clearStyle = isDarkTheme ? @"ClearDark" : @"ClearLight";
        UIImage *premade = [self _premadeIconForBundleID:bundleID style:clearStyle];
        if (premade) return premade;
    }

    UIImage *nsPremade = nil;
    if ([effectiveStyle isEqualToString:@"Dark"]) {
        nsPremade = [self _premadeIconForBundleID:bundleID style:@"DarkNS"];
    } else if ([effectiveStyle isEqualToString:@"Default"]) {
        nsPremade = [self _premadeIconForBundleID:bundleID style:@"LightNS"];
    }

    NSString *cacheKey = [self _cacheKeyForBundleID:bundleID effectiveStyle:effectiveStyle isDarkTheme:isDarkTheme nsPremade:nsPremade];
    UIImage *memCached = [self.memoryCache objectForKey:cacheKey];
    if (memCached) {
        return memCached;
    }

    NSString *diskPath = [self.cacheDirectory stringByAppendingPathComponent:[cacheKey stringByAppendingString:@".png"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        UIImage *diskCached = [UIImage imageWithContentsOfFile:diskPath];
        if (diskCached) {
            [self.memoryCache setObject:diskCached forKey:cacheKey];
            return diskCached;
        }
    }

    BOOL isException = isAppInExceptionList(bundleID);
    BOOL skipIconGen = isException && g_exceptionsNoIconProcessing;
    NSString *tintHex = @"";
    if ([effectiveStyle isEqualToString:@"Tinted"]) {
        tintHex = g_tintColor ?: @"#00FFFF";
    }

    BOOL isAutoGenerated = NO;
    BOOL isStockArtwork = NO;
    UIImage *glyph = nil;
    if ([effectiveStyle isEqualToString:@"Tinted"]) {
        NSString *clearStyle = isDarkTheme ? @"ClearDark" : @"ClearLight";
        UIImage *premadeClear = [self _premadeIconForBundleID:bundleID style:clearStyle];
        if (premadeClear) {
            glyph = premadeClear;
            isAutoGenerated = NO;
        } else if (skipIconGen) {
            glyph = orig;
            isAutoGenerated = YES;
            isStockArtwork = YES;
        } else {
            UIImage *premadeLight = [self _premadeIconForBundleID:bundleID style:@"Light"];
            if (premadeLight) {
                glyph = [self generateClearIconForImage:premadeLight bundleID:bundleID];
            } else {
                glyph = [self generateClearIconForImage:orig bundleID:bundleID];
            }
            isAutoGenerated = YES;
        }
    } else if ([effectiveStyle isEqualToString:@"Clear"]) {
        NSString *clearStyle = isDarkTheme ? @"ClearDark" : @"ClearLight";
        UIImage *premadeClear = [self _premadeIconForBundleID:bundleID style:clearStyle];
        if (premadeClear) {
            glyph = premadeClear;
            isAutoGenerated = NO;
        } else if (skipIconGen) {
            glyph = orig;
            isAutoGenerated = YES;
            isStockArtwork = YES;
        } else {
            UIImage *premadeLight = [self _premadeIconForBundleID:bundleID style:@"Light"];
            if (premadeLight) {
                glyph = [self generateClearIconForImage:premadeLight bundleID:bundleID];
            } else {
                glyph = [self generateClearIconForImage:orig bundleID:bundleID];
            }
            isAutoGenerated = YES;
        }
    } else if ([effectiveStyle isEqualToString:@"Dark"]) {
        if (nsPremade) {
            glyph = nsPremade;
            isAutoGenerated = NO;
        } else {
            UIImage *premadeDark = [self _premadeIconForBundleID:bundleID style:@"Dark"];
            if (premadeDark) {
                return [self applySquircleMaskToImage:premadeDark];
            } else {
                glyph = [self generateDarkIconForImage:orig bundleID:bundleID];
                isAutoGenerated = YES;
            }
        }
    } else {
        if (nsPremade) {
            glyph = nsPremade;
            isAutoGenerated = NO;
        } else {
            UIImage *premadeLight = [self _premadeIconForBundleID:bundleID style:@"Light"];
            if (premadeLight) {
                return [self applySquircleMaskToImage:premadeLight];
            } else {
                glyph = orig;
                isAutoGenerated = YES;
            }
        }
    }

    UIColor *tintColor = [self adjustedTintColorFromHex:tintHex isDarkTheme:isDarkTheme];

    UIImage *styled = [self compositeGlyph:glyph withBackgroundStyle:effectiveStyle isDarkTheme:isDarkTheme tintColor:tintColor isAutoGenerated:isAutoGenerated drawSpecular:YES isStockArtwork:isStockArtwork];

    if ([effectiveStyle isEqualToString:@"Tinted"] && isDarkTheme && styled) {
        UIGraphicsBeginImageContextWithOptions(styled.size, NO, styled.scale);
        CGFloat radius = styled.size.width * 0.256;
        UIBezierPath *path = Home26CreateSquirclePath(CGRectMake(0, 0, styled.size.width, styled.size.height), radius);
        [path addClip];

        [tintColor setFill];
        UIRectFill(CGRectMake(0, 0, styled.size.width, styled.size.height));

        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeLuminosity alpha:1.0];

        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0];

        styled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    if (styled && [self isSpecularEnabled] && ![g_menuAppearance isEqualToString:@"iOS18"]) {
        BOOL isDark = isDarkTheme || [effectiveStyle isEqualToString:@"Dark"];
        CGFloat topA = isDark ? kDarkIconRimTopOpacity : 0.75;
        CGFloat botA = isDark ? kDarkIconRimBottomOpacity : 0.35;
        CGFloat perimA = isDark ? 0.16 : 0.20;
        styled = [self _applySpecularHighlightToImage:styled topAlpha:topA bottomAlpha:botA perimeterAlpha:perimA];
    }

    if (styled) {
        styled = [self applySquircleMaskToImage:styled];
        [self.memoryCache setObject:styled forKey:cacheKey];
        dispatch_async(self.processingQueue, ^{
            NSData *pngData = UIImagePNGRepresentation(styled);
            [pngData writeToFile:diskPath atomically:YES];
        });
    }

    return [self applySquircleMaskToImage:styled];
}

typedef struct {
    CGFloat r, g, b, brightness, saturation;
    BOOL isDark;
    BOOL isWhite;
    CGFloat tR, tG, tB;
    CGFloat bR, bG, bB;
} LGBGInfo;

- (LGBGInfo)sampleBackgroundFromRawData:(unsigned char *)rawData
                                  width:(size_t)width
                                 height:(size_t)height
                           bytesPerRow:(NSUInteger)bytesPerRow {
    int patchSize = MAX(4, (int)(width * 0.08));
    int offset = MAX(2, (int)(width * 0.05));

    long rSum = 0, gSum = 0, bSum = 0;
    long tRSum = 0, tGSum = 0, tBSum = 0;
    long bRSum = 0, bGSum = 0, bBSum = 0;
    int count = 0, tCount = 0, bCount = 0;

    int corners[4][2] = {
        {offset, offset},
        {(int)width - offset - patchSize, offset},
        {offset, (int)height - offset - patchSize},
        {(int)width - offset - patchSize, (int)height - offset - patchSize}
    };

    for (int c = 0; c < 4; c++) {
        int startX = corners[c][0];
        int startY = corners[c][1];
        for (int y = startY; y < startY + patchSize && y < (int)height; y++) {
            for (int x = startX; x < startX + patchSize && x < (int)width; x++) {
                int idx = (int)(bytesPerRow * y) + x * 4;
                if (rawData[idx + 3] > 200) {
                    if (c < 2) {
                        tRSum += rawData[idx]; tGSum += rawData[idx+1]; tBSum += rawData[idx+2];
                        tCount++;
                    } else {
                        bRSum += rawData[idx]; bGSum += rawData[idx+1]; bBSum += rawData[idx+2];
                        bCount++;
                    }
                    rSum += rawData[idx]; gSum += rawData[idx+1]; bSum += rawData[idx+2];
                    count++;
                }
            }
        }
    }

    if (count == 0) count = 1;
    if (tCount == 0) tCount = 1;
    if (bCount == 0) bCount = 1;

    LGBGInfo info;
    info.r = (CGFloat)rSum / count / 255.0;
    info.g = (CGFloat)gSum / count / 255.0;
    info.b = (CGFloat)bSum / count / 255.0;
    info.tR = (CGFloat)tRSum / tCount / 255.0;
    info.tG = (CGFloat)tGSum / tCount / 255.0;
    info.tB = (CGFloat)tBSum / tCount / 255.0;
    info.bR = (CGFloat)bRSum / bCount / 255.0;
    info.bG = (CGFloat)bGSum / bCount / 255.0;
    info.bB = (CGFloat)bBSum / bCount / 255.0;

    UIColor *avgColor = [UIColor colorWithRed:info.r green:info.g blue:info.b alpha:1.0];
    CGFloat hue, sat, br, alpha;
    [avgColor getHue:&hue saturation:&sat brightness:&br alpha:&alpha];

    info.brightness = br;
    info.saturation = sat;
    info.isDark = (br < 0.25);
    info.isWhite = (info.r > 0.80 && info.g > 0.80 && info.b > 0.80);

    return info;
}

- (UIImage *)_upscaleImageIfNeeded:(UIImage *)image toSize:(CGSize)targetSize {
    if (!image) return nil;
    CGImageRef cgImage = image.CGImage;
    if (cgImage) {
        size_t w = CGImageGetWidth(cgImage);
        size_t h = CGImageGetHeight(cgImage);
        if (w >= (size_t)targetSize.width && h >= (size_t)targetSize.height) {
            return image;
        }
    }
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextSetAllowsAntialiasing(ctx, YES);
    CGContextSetShouldAntialias(ctx, YES);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *upscaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return upscaled ?: image;
}

- (unsigned char *)loadRawData:(UIImage *)image
                          width:(size_t *)outWidth
                         height:(size_t *)outHeight
                   bytesPerRow:(NSUInteger *)outBytesPerRow {
    if (!image) {
        if (outWidth) *outWidth = 0;
        if (outHeight) *outHeight = 0;
        if (outBytesPerRow) *outBytesPerRow = 0;
        return NULL;
    }

    image = [self _upscaleImageIfNeeded:image toSize:CGSizeMake(256, 256)];

    CGImageRef cgImage = image.CGImage;
    BOOL mustReleaseCGImage = NO;
    if (!cgImage && image.size.width > 0 && image.size.height > 0) {
        CGFloat scale = image.scale > 0 ? image.scale : 1.0;
        UIGraphicsBeginImageContextWithOptions(image.size, NO, scale);
        [image drawAtPoint:CGPointZero];
        UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (rendered && rendered.CGImage) {
            cgImage = CGImageRetain(rendered.CGImage);
            mustReleaseCGImage = YES;
        }
    }

    if (!cgImage) {
        if (outWidth) *outWidth = 0;
        if (outHeight) *outHeight = 0;
        if (outBytesPerRow) *outBytesPerRow = 0;
        return NULL;
    }

    *outWidth = CGImageGetWidth(cgImage);
    *outHeight = CGImageGetHeight(cgImage);
    if (*outWidth == 0 || *outHeight == 0) {
        if (mustReleaseCGImage) CGImageRelease(cgImage);
        if (outBytesPerRow) *outBytesPerRow = 0;
        return NULL;
    }

    *outBytesPerRow = 4 * (*outWidth);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char *)calloc((*outHeight) * (*outWidth) * 4, sizeof(unsigned char));
    if (!rawData) {
        CGColorSpaceRelease(colorSpace);
        if (mustReleaseCGImage) CGImageRelease(cgImage);
        return NULL;
    }

    CGContextRef context = CGBitmapContextCreate(rawData, *outWidth, *outHeight, 8, *outBytesPerRow, colorSpace,
                                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        free(rawData);
        if (mustReleaseCGImage) CGImageRelease(cgImage);
        return NULL;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, *outWidth, *outHeight), cgImage);
    CGContextRelease(context);
    if (mustReleaseCGImage) CGImageRelease(cgImage);
    return rawData;
}

- (CGImageRef)createMaskFromRawData:(unsigned char *)rawData
                               width:(size_t)width
                              height:(size_t)height
                        bytesPerRow:(NSUInteger)bytesPerRow
                               bgInfo:(LGBGInfo)bg
                     outFgIsColorful:(BOOL *)outFgIsColorful {
    unsigned char *maskData = (unsigned char *)calloc(height * width, sizeof(unsigned char));

    int fgCount = 0;
    int colorfulCount = 0;

    for (int y = 0; y < (int)height; y++) {
        for (int x = 0; x < (int)width; x++) {
            int idx = (int)(bytesPerRow * y) + x * 4;
            CGFloat a = rawData[idx + 3] / 255.0;

            if (a < 0.1) {
                maskData[y * width + x] = 0;
                continue;
            }

            CGFloat r = (a > 0) ? (rawData[idx]   / 255.0) / a : 0;
            CGFloat g = (a > 0) ? (rawData[idx+1] / 255.0) / a : 0;
            CGFloat b = (a > 0) ? (rawData[idx+2] / 255.0) / a : 0;

            CGFloat dr = 0, dg = 0, db = 0;
            CGFloat minR = MIN(bg.tR, bg.bR) - 0.1;
            CGFloat maxR = MAX(bg.tR, bg.bR) + 0.1;
            CGFloat minG = MIN(bg.tG, bg.bG) - 0.1;
            CGFloat maxG = MAX(bg.tG, bg.bG) + 0.1;
            CGFloat minB = MIN(bg.tB, bg.bB) - 0.1;
            CGFloat maxB = MAX(bg.tB, bg.bB) + 0.1;

            if (r < minR) dr = minR - r; else if (r > maxR) dr = r - maxR;
            if (g < minG) dg = minG - g; else if (g > maxG) dg = g - maxG;
            if (b < minB) db = minB - b; else if (b > maxB) db = b - maxB;

            CGFloat dist = sqrt(dr*dr + dg*dg + db*db);

            CGFloat t0 = 0.03;
            CGFloat t1 = 0.18;
            CGFloat factor = 0.0;
            if (dist > t0) {
                CGFloat t = (dist - t0) / (t1 - t0);
                if (t > 1.0) t = 1.0;
                factor = t * t * (3.0 - 2.0 * t);
            }

            if (!bg.isWhite) {
                CGFloat whiteness = MIN(MIN(r, g), b);
                if (whiteness > 0.70) {
                    CGFloat wFactor = (whiteness - 0.70) / 0.20;
                    if (wFactor > 1.0) wFactor = 1.0;
                    CGFloat wSmooth = wFactor * wFactor * (3.0 - 2.0 * wFactor);
                    factor = MAX(factor, wSmooth);
                }
            } else if (bg.brightness > 0.30) {
                CGFloat blackness = 1.0 - MAX(MAX(r, g), b);
                if (blackness > 0.70) {
                    CGFloat bFactor = (blackness - 0.70) / 0.20;
                    if (bFactor > 1.0) bFactor = 1.0;
                    CGFloat bSmooth = bFactor * bFactor * (3.0 - 2.0 * bFactor);
                    factor = MAX(factor, bSmooth);
                }
            }

            CGFloat finalAlpha = factor * a * 255.0;
            if (finalAlpha > 255.0) finalAlpha = 255.0;
            if (finalAlpha < 0.0) finalAlpha = 0.0;
            maskData[y * width + x] = (unsigned char)finalAlpha;

            if (finalAlpha > 180) {
                fgCount++;
                CGFloat maxChanDiff = MAX(MAX(fabs(r-g), fabs(r-b)), fabs(g-b));
                if (maxChanDiff > 0.12) colorfulCount++;
            }
        }
    }

    if (outFgIsColorful) {
        *outFgIsColorful = (fgCount > 0) && ((CGFloat)colorfulCount / fgCount) > 0.08;
    }

    unsigned char *tempMask = (unsigned char *)malloc(height * width);
    if (tempMask) {

        for (int y = 0; y < (int)height; y++) {
            int rowOffset = y * (int)width;
            for (int x = 0; x < (int)width; x++) {
                int x_m2 = (x >= 2) ? x - 2 : 0;
                int x_m1 = (x >= 1) ? x - 1 : 0;
                int x_p1 = (x + 1 < (int)width) ? x + 1 : (int)width - 1;
                int x_p2 = (x + 2 < (int)width) ? x + 2 : (int)width - 1;

                int val = (int)maskData[rowOffset + x_m2] * 1 +
                          (int)maskData[rowOffset + x_m1] * 4 +
                          (int)maskData[rowOffset + x]    * 6 +
                          (int)maskData[rowOffset + x_p1] * 4 +
                          (int)maskData[rowOffset + x_p2] * 1;
                tempMask[rowOffset + x] = (unsigned char)(val / 16);
            }
        }

        for (int y = 0; y < (int)height; y++) {
            int y_m2 = (y >= 2) ? y - 2 : 0;
            int y_m1 = (y >= 1) ? y - 1 : 0;
            int y_p1 = (y + 1 < (int)height) ? y + 1 : (int)height - 1;
            int y_p2 = (y + 2 < (int)height) ? y + 2 : (int)height - 1;

            int row_m2 = y_m2 * (int)width;
            int row_m1 = y_m1 * (int)width;
            int row_0  = y    * (int)width;
            int row_p1 = y_p1 * (int)width;
            int row_p2 = y_p2 * (int)width;

            for (int x = 0; x < (int)width; x++) {
                int val = (int)tempMask[row_m2 + x] * 1 +
                          (int)tempMask[row_m1 + x] * 4 +
                          (int)tempMask[row_0  + x] * 6 +
                          (int)tempMask[row_p1 + x] * 4 +
                          (int)tempMask[row_p2 + x] * 1;
                maskData[row_0 + x] = (unsigned char)(val / 16);
            }
        }
        free(tempMask);
    }

    CGContextRef maskCtx = CGBitmapContextCreate(maskData, width, height, 8, width, NULL, kCGImageAlphaOnly);
    CGImageRef maskImage = CGBitmapContextCreateImage(maskCtx);
    CGContextRelease(maskCtx);
    free(maskData);

    return maskImage;
}

- (UIImage *)synthesizeGradientImageWithSize:(CGSize)size topColor:(UIColor *)topColor bottomColor:(UIColor *)bottomColor {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(id)topColor.CGColor, (id)bottomColor.CGColor];
    CGFloat locations[] = {0.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (UIImage *)invertDarkGrayscaleInImage:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    NSUInteger bytesPerRow = 4 * width;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char *)calloc(height * width * 4, sizeof(unsigned char));
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, 8, bytesPerRow, colorSpace,
                                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);

    for (int y = 0; y < (int)height; y++) {
        for (int x = 0; x < (int)width; x++) {
            int idx = (int)(bytesPerRow * y) + x * 4;
            CGFloat a = rawData[idx + 3] / 255.0;
            if (a > 0.1) {
                CGFloat r = (rawData[idx]   / 255.0) / a;
                CGFloat g = (rawData[idx+1] / 255.0) / a;
                CGFloat b = (rawData[idx+2] / 255.0) / a;

                if (r < 0.5 && g < 0.5 && b < 0.5) {
                    CGFloat maxDiff = MAX(MAX(fabs(r-g), fabs(r-b)), fabs(g-b));
                    if (maxDiff < 0.18) {
                        r = 1.0 - r;
                        g = 1.0 - g;
                        b = 1.0 - b;
                        rawData[idx]   = (unsigned char)(r * a * 255.0);
                        rawData[idx+1] = (unsigned char)(g * a * 255.0);
                        rawData[idx+2] = (unsigned char)(b * a * 255.0);
                    }
                }
            }
        }
    }

    CGImageRef invertedCg = CGBitmapContextCreateImage(context);
    UIImage *inverted = [UIImage imageWithCGImage:invertedCg scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(invertedCg);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(rawData);
    return inverted;
}

- (UIImage *)compositeWithMask:(CGImageRef)mask
                     glyphImage:(UIImage *)glyphImage
                       darkBg:(BOOL)darkBg
                          size:(CGSize)size
                         scale:(CGFloat)scale {
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetAllowsAntialiasing(ctx, YES);
    CGContextSetShouldAntialias(ctx, YES);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);

    CGFloat radius = size.width * 0.256;
    UIBezierPath *squircle = nil;
    squircle = Home26CreateSquirclePath(CGRectMake(0, 0, size.width, size.height), radius);
    [squircle addClip];

    if (darkBg) {
        [[UIColor colorWithWhite:0.12 alpha:1.0] setFill];
        CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    }

    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, 0, size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    CGContextClipToMask(ctx, CGRectMake(0, 0, size.width, size.height), mask);
    CGContextTranslateCTM(ctx, 0, size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    [glyphImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
    CGContextRestoreGState(ctx);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [self applySquircleMaskToImage:result];
}

- (UIImage *)generateDarkIconForImage:(UIImage *)image bundleID:(NSString *)bundleID {
    if (!image) return nil;

    NSSet *skipApps = [NSSet setWithObjects:
                       @"com.apple.camera",
                       @"com.apple.mobilenotes",
                       @"com.apple.Preferences",
                       @"com.apple.Maps",
                       @"com.apple.weather",
                       nil];

    if (bundleID && [skipApps containsObject:bundleID]) {
        return [self applySquircleMaskToImage:image];
    }

    CGSize targetSize = CGSizeMake(256, 256);
    image = [self _upscaleImageIfNeeded:image toSize:targetSize];

    size_t width, height;
    NSUInteger bytesPerRow;
    unsigned char *rawData = [self loadRawData:image width:&width height:&height bytesPerRow:&bytesPerRow];
    if (!rawData) return [self applySquircleMaskToImage:image];

    LGBGInfo bg = [self sampleBackgroundFromRawData:rawData width:width height:height bytesPerRow:bytesPerRow];

    if (bg.isDark) {
        free(rawData);
        return [self applySquircleMaskToImage:image];
    }

    BOOL fgIsColorful = NO;
    CGImageRef mask = [self createMaskFromRawData:rawData width:width height:height
                                     bytesPerRow:bytesPerRow bgInfo:bg outFgIsColorful:&fgIsColorful];
    free(rawData);

    UIImage *glyphImage;
    if (bg.isWhite || bg.saturation < 0.1) {
        glyphImage = [self invertDarkGrayscaleInImage:image];
    } else if (fgIsColorful) {
        glyphImage = image;
    } else {
        UIColor *topC = [UIColor colorWithRed:bg.tR green:bg.tG blue:bg.tB alpha:1.0];
        UIColor *botC = [UIColor colorWithRed:bg.bR green:bg.bG blue:bg.bB alpha:1.0];
        glyphImage = [self synthesizeGradientImageWithSize:targetSize topColor:topC bottomColor:botC];
    }

    UIImage *result = [self compositeWithMask:mask glyphImage:glyphImage darkBg:YES size:targetSize scale:1.0];
    CGImageRelease(mask);
    return [self applySquircleMaskToImage:result];
}

- (UIImage *)generateClearIconForImage:(UIImage *)image bundleID:(NSString *)bundleID {
    if (!image) return nil;

    CGSize targetSize = CGSizeMake(256, 256);
    image = [self _upscaleImageIfNeeded:image toSize:targetSize];

    size_t width, height;
    NSUInteger bytesPerRow;
    unsigned char *rawData = [self loadRawData:image width:&width height:&height bytesPerRow:&bytesPerRow];
    if (!rawData) return image;

    LGBGInfo bg = [self sampleBackgroundFromRawData:rawData width:width height:height bytesPerRow:bytesPerRow];

    BOOL fgIsColorful = NO;
    CGImageRef mask = [self createMaskFromRawData:rawData width:width height:height
                                     bytesPerRow:bytesPerRow bgInfo:bg outFgIsColorful:&fgIsColorful];
    free(rawData);

    UIImage *glyphImage;
    if (bg.isWhite || bg.saturation < 0.1) {
        glyphImage = [self invertDarkGrayscaleInImage:image];
    } else if (fgIsColorful) {
        glyphImage = image;
    } else {
        UIColor *topC = [UIColor colorWithRed:bg.tR green:bg.tG blue:bg.tB alpha:1.0];
        UIColor *botC = [UIColor colorWithRed:bg.bR green:bg.bG blue:bg.bB alpha:1.0];
        glyphImage = [self synthesizeGradientImageWithSize:targetSize topColor:topC bottomColor:botC];
    }

    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetAllowsAntialiasing(ctx, YES);
    CGContextSetShouldAntialias(ctx, YES);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);

    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, 0, targetSize.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);

    CGContextClipToMask(ctx, CGRectMake(0, 0, targetSize.width, targetSize.height), mask);

    CGContextSetAlpha(ctx, 0.95);
    CGContextDrawImage(ctx, CGRectMake(0, 0, targetSize.width, targetSize.height), glyphImage.CGImage);

    CGContextSetAlpha(ctx, 1.0);

    [[UIColor blackColor] setFill];
    CGContextSetBlendMode(ctx, kCGBlendModeSaturation);
    CGContextFillRect(ctx, CGRectMake(0, 0, targetSize.width, targetSize.height));

    [[UIColor colorWithWhite:0.75 alpha:1.0] setFill];
    CGContextSetBlendMode(ctx, kCGBlendModeScreen);
    CGContextFillRect(ctx, CGRectMake(0, 0, targetSize.width, targetSize.height));

    CGContextRestoreGState(ctx);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRelease(mask);

    return result;
}

@end
