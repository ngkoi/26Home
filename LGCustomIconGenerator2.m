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

#define kDarkClearRimTopOpacity 1
#define kDarkClearRimBottomOpacity 1

#define kLightClearTopOpacity 0.25
#define kLightClearBottomOpacity 0.03
#define kLightClearStrokeOpacity 0.2

#define kLightClearRimTopOpacity 1
#define kLightClearRimBottomOpacity 1

// Dedicated configuration for Tinted Dark
#define kDarkTintedTopOpacity 0.55
#define kDarkTintedBottomOpacity 0.03
#define kDarkTintedStrokeOpacity 0.2
#define kDarkTintedRimTopOpacity 1.0
#define kDarkTintedRimBottomOpacity 1.0

@interface LGCustomIconGenerator2 ()
@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, strong) NSMutableDictionary *originalImages;
@property (nonatomic, strong) NSString *cacheDirectory;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) NSMutableSet *processingIdentifiers;
@property (nonatomic, strong) NSDictionary<NSString *, NSSet<NSString *> *> *directoryIndexCache;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *themePathsCache;
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
        self.originalImages = [[NSMutableDictionary alloc] init];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *basePath = paths.firstObject;
        self.cacheDirectory = [basePath stringByAppendingPathComponent:@"ngkhoi.26home.icons"];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.cacheDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDirectory 
                                      withIntermediateDirectories:YES 
                                                       attributes:nil 
                                                            error:nil];
        }
        
        self.processingQueue = dispatch_queue_create("ngkhoi.26home.processingQueue", DISPATCH_QUEUE_CONCURRENT);
        self.processingIdentifiers = [NSMutableSet set];
        
        NSMutableDictionary *indexCache = [NSMutableDictionary dictionary];
        NSMutableDictionary *pathsCache = [NSMutableDictionary dictionary];
        NSArray *themes = @[@"Light", @"Dark", @"ClearLight", @"ClearDark"];
        for (NSString *theme in themes) {
            NSString *basePath1 = [NSString stringWithFormat:@"/var/jb/Library/Application Support/26Home/SolidGlass/%@", theme];
            NSString *basePath2 = [NSString stringWithFormat:@"/Library/Application Support/26Home/SolidGlass/%@", theme];
            NSString *basePath = [[NSFileManager defaultManager] fileExistsAtPath:basePath1] ? basePath1 : basePath2;
            
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:nil];
            if (contents) {
                [indexCache setObject:[NSSet setWithArray:contents] forKey:theme];
                [pathsCache setObject:basePath forKey:theme];
            }
        }
        self.directoryIndexCache = indexCache;
        self.themePathsCache = pathsCache;
        
        // Listen to Settings app cache clear notification
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

- (void)saveOriginalImage:(UIImage *)image forBundleID:(NSString *)bundleID {
    if ([bundleID isEqualToString:@"com.apple.mobiletimer"] || [bundleID isEqualToString:@"com.apple.mobilecal"]) {
        return; // NEVER cache dynamic icons
    }
    if (image && bundleID) {
        @synchronized (self.originalImages) {
            [self.originalImages setObject:image forKey:bundleID];
        }
    }
}

- (UIImage *)originalImageForBundleID:(NSString *)bundleID {
    if ([bundleID isEqualToString:@"com.apple.mobiletimer"] || [bundleID isEqualToString:@"com.apple.mobilecal"]) {
        return nil; // NEVER return cached snapshot for dynamic icons
    }
    if (!bundleID) return nil;
    @synchronized (self.originalImages) {
        return [self.originalImages objectForKey:bundleID];
    }
}

- (void)clearCache {
    [self.memoryCache removeAllObjects];
    @synchronized (self.originalImages) {
        [self.originalImages removeAllObjects];
    }
}

- (void)clearDiskCache {
    [self.memoryCache removeAllObjects];
    @synchronized (self.originalImages) {
        [self.originalImages removeAllObjects];
    }
    dispatch_async(self.processingQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:self.cacheDirectory error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:self.cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    });
}

- (UIImage *)applySpecularHighlightToImage:(UIImage *)image {
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, image.size.width, image.size.height) cornerRadius:image.size.width * 0.225];
    [path addClip];
    [image drawAtPoint:CGPointZero];
    
    [path setLineWidth:3.0];
    [[UIColor colorWithWhite:1.0 alpha:0.15] setStroke];
    [path stroke];
    
    CGContextSaveGState(context);
    CGContextSetLineWidth(context, 3.0);
    CGContextAddPath(context, path.CGPath);
    CGContextReplacePathWithStrokedPath(context);
    CGContextClip(context);

    CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.75].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.35].CGColor];
    
    CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
    CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);
    
    CGPoint rimStart = CGPointMake(0, 0);
    CGPoint rimEnd = CGPointMake(image.size.width, image.size.height);
    
    CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);
    
    CGGradientRelease(rimGradient);
    CGColorSpaceRelease(rimColorSpace);
    CGContextRestoreGState(context);
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (UIImage *)applySquircleMaskToImage:(UIImage *)image {
    if (!image) return nil;
    CGSize targetSize = CGSizeMake(180, 180);
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, [UIScreen mainScreen].scale);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, targetSize.width, targetSize.height) cornerRadius:targetSize.width * 0.225];
    [path addClip];
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *masked = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return masked;
}

- (UIImage *)_premadeIconForBundleID:(NSString *)bundleID style:(NSString *)style {
    if (!bundleID || !style) return nil;
    
    NSString *themeSubdir = nil;
    if ([style isEqualToString:@"Light"]) {
        themeSubdir = @"Light";
    } else if ([style isEqualToString:@"Dark"]) {
        themeSubdir = @"Dark";
    } else if ([style isEqualToString:@"ClearLight"]) {
        themeSubdir = @"ClearLight";
    } else if ([style isEqualToString:@"ClearDark"]) {
        themeSubdir = @"ClearDark";
    }
    
    if (!themeSubdir) return nil;
    
    NSString *basePath = self.themePathsCache[themeSubdir];
    NSSet *dirContents = self.directoryIndexCache[themeSubdir];
    if (!basePath || !dirContents) return nil;
    
    NSArray *suffixes = @[@"-large.png", @".png"];
    
    // Special case for Clock: ALWAYS load ClockIconBackgroundSquare (dial background without hands),
    // NEVER load com.apple.mobiletimer-large.png (which contains static baked-in hands).
        if ([bundleID isEqualToString:@"com.apple.mobiletimer"]) {
        for (NSString *suffix in suffixes) {
            NSString *filename = [@"ClockIconBackgroundSquare" stringByAppendingString:suffix];
            if ([dirContents containsObject:filename]) {
                NSString *fullPath = [basePath stringByAppendingPathComponent:filename];
                UIImage *img = [UIImage imageWithContentsOfFile:fullPath];
                if (img) return img;
            }
        }
        return nil;
    }
    
    for (NSString *suffix in suffixes) {
        NSString *filename = [bundleID stringByAppendingString:suffix];
        if ([dirContents containsObject:filename]) {
            NSString *fullPath = [basePath stringByAppendingPathComponent:filename];
            UIImage *img = [UIImage imageWithContentsOfFile:fullPath];
            if (img) return img;
        }
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
    
    // Tame saturation so icons are refined and never harsh / pure neon
    s = s * 0.70;
    
    // Control brightness based on theme mode to prevent washout and ensure strong readability
    if (isDarkTheme) {
        b = MIN(b * 0.85, 0.85);
        b = MAX(b, 0.20);
    } else {
        // Light mode: clamp brightness to 0.70 so white glyphs pop and white tint becomes a sleek silver/slate
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
        } else { // "Auto"
            isDarkTheme = isSystemDark;
            // Dark Auto: In light mode -> use Default (light) icons theme; in dark mode -> use Dark theme design
            effectiveStyle = isSystemDark ? @"Dark" : @"Default";
        }
    } else if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
        NSString *themeMode = g_themeMode ?: @"Auto";
        if ([themeMode isEqualToString:@"Dark"]) {
            isDarkTheme = YES;
        } else if ([themeMode isEqualToString:@"Light"]) {
            isDarkTheme = NO;
        } else { // "Auto"
            isDarkTheme = isSystemDark;
        }
        effectiveStyle = style;
    } else { // "Default"
        isDarkTheme = NO;
        effectiveStyle = @"Default";
    }
    
    if (outEffectiveStyle) *outEffectiveStyle = effectiveStyle;
    if (outIsDarkTheme) *outIsDarkTheme = isDarkTheme;
}

- (UIImage *)generateDynamicIconForBundleID:(NSString *)bundleID style:(NSString *)style isDarkTheme:(BOOL)isDarkTheme {
    // 1. Resolve theme directory name
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
    
    // 2. Fetch premade asset
    UIImage *baseImage = [self _premadeIconForBundleID:bundleID style:themeName];
    if (!baseImage) {
        // Fallback to Light or Dark if specific asset is missing
        baseImage = [self _premadeIconForBundleID:bundleID style:isDarkTheme ? @"Dark" : @"Light"];
    }
    if (!baseImage) return nil;
    
    // 3. If Calendar, draw Day of Week and Date Number
    UIImage *renderedImage = baseImage;
    if ([bundleID isEqualToString:@"com.apple.mobilecal"]) {
        UIGraphicsBeginImageContextWithOptions(baseImage.size, NO, baseImage.scale);
        [baseImage drawAtPoint:CGPointZero];
        
        NSDate *date = [NSDate date];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        
        // Draw Day of Week (e.g., FRIDAY)
        [formatter setDateFormat:@"EEEE"];
        NSString *dayString = [[formatter stringFromDate:date] uppercaseString];
        UIColor *dayColor = [UIColor systemRedColor];
        UIFont *dayFont = [UIFont systemFontOfSize:baseImage.size.width * 0.15 weight:UIFontWeightSemibold];
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        [dayString drawInRect:CGRectMake(0, baseImage.size.height * 0.15, baseImage.size.width, baseImage.size.height * 0.2)
               withAttributes:@{NSFontAttributeName: dayFont, NSForegroundColorAttributeName: dayColor, NSParagraphStyleAttributeName: paragraphStyle}];
        
        // Draw Date (e.g., 14)
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
    
    // 4. Return directly for Default & Dark, but apply specular overlay
    if ([style isEqualToString:@"Default"] || [style isEqualToString:@"Dark"]) {
        return [self applySpecularHighlightToImage:renderedImage];
    }
    
    // 5. For Clear or Tinted: apply glass refraction/specular shimmer
    UIColor *tintColor = [self adjustedTintColorFromHex:g_tintColor isDarkTheme:isDarkTheme];
    UIImage *styled = [self compositeGlyph:renderedImage withBackgroundStyle:style isDarkTheme:isDarkTheme tintColor:tintColor isAutoGenerated:YES];
    if (!styled) styled = renderedImage;
    
    // 6. For Tinted Dark only: apply color tint overlay
    if ([style isEqualToString:@"Tinted"] && isDarkTheme && styled) {
        UIGraphicsBeginImageContextWithOptions(styled.size, NO, styled.scale);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, styled.size.width, styled.size.height) cornerRadius:styled.size.width * 0.225];
        [path addClip];
        
        [tintColor setFill];
        UIRectFill(CGRectMake(0, 0, styled.size.width, styled.size.height));
        
        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeLuminosity alpha:1.0];
        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0];
        
        styled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    return styled;
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
    
    // 1. Direct premade icon check for Clear style
    if ([style isEqualToString:@"Clear"]) {
        UIImage *premade = [self _premadeIconForBundleID:bundleID style:isDarkTheme ? @"ClearDark" : @"ClearLight"];
        if (premade) return premade;
    }
    
    // Base image setup based on style
    UIImage *baseOrig = orig;
    if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
        UIImage *premadeDark = [self _premadeIconForBundleID:bundleID style:@"Dark"];
        if (premadeDark) {
            baseOrig = premadeDark;
        }
    }
    
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@_v8", bundleID, style];
    
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
            // Guarantee rounded corners for all icons to fix live icons (like Clock) spilling out
            UIGraphicsBeginImageContextWithOptions(styled.size, NO, styled.scale);
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, styled.size.width, styled.size.height) cornerRadius:styled.size.width * 0.225];
            [path addClip];
            [styled drawAtPoint:CGPointZero];
            
            if ([style isEqualToString:@"Default"] || [style isEqualToString:@"Dark"]) {
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                [path setLineWidth:3.0];
                [[UIColor colorWithWhite:1.0 alpha:0.15] setStroke];
                [path stroke];
                
                CGContextSaveGState(context);
                CGContextSetLineWidth(context, 3.0);
                CGContextAddPath(context, path.CGPath);
                CGContextReplacePathWithStrokedPath(context);
                CGContextClip(context);

                CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
                NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.75].CGColor,
                                       (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                       (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                       (id)[UIColor colorWithWhite:1.0 alpha:0.35].CGColor];
                
                CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
                CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);
                
                CGPoint rimStart = CGPointMake(0, 0);
                CGPoint rimEnd = CGPointMake(styled.size.width, styled.size.height);
                
                CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);
                
                CGGradientRelease(rimGradient);
                CGColorSpaceRelease(rimColorSpace);
                CGContextRestoreGState(context);
            }
            
            styled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
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
    return [self compositeGlyph:glyph withBackgroundStyle:style isDarkTheme:isDarkTheme tintColor:nil isAutoGenerated:YES];
}

- (UIImage *)compositeGlyph:(UIImage *)glyph withBackgroundStyle:(NSString *)style isDarkTheme:(BOOL)isDarkTheme tintColor:(UIColor *)tintColor isAutoGenerated:(BOOL)isAutoGenerated {
    if (!glyph) return nil;
    
    if (!tintColor && [style isEqualToString:@"Tinted"]) {
        tintColor = [self adjustedTintColorFromHex:g_tintColor isDarkTheme:isDarkTheme];
    }
    
    UIGraphicsBeginImageContextWithOptions(glyph.size, NO, glyph.scale);
    
    // Draw background
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, glyph.size.width, glyph.size.height) cornerRadius:glyph.size.width * 0.225]; // Apple's continuous corner radius ratio
    [path addClip];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if ([style isEqualToString:@"Tinted"] && !isDarkTheme) {
        // --- TINTED LIGHT: Clear translucent dark glass base (0.16 alpha) + light colored glass gradient ---
        [[UIColor colorWithWhite:0.0 alpha:0.16] setFill];
        [path fill];
        
        CGFloat topOpacity = 0.20;
        CGFloat botOpacity = 0.04;
        CGFloat strokeOpacity = 0.22;
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(id)[tintColor colorWithAlphaComponent:topOpacity].CGColor,
                            (id)[tintColor colorWithAlphaComponent:botOpacity].CGColor];
        
        CGFloat locations[] = {0.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
        
        CGPoint startPoint = CGPointMake(glyph.size.width/2, 0);
        CGPoint endPoint = CGPointMake(glyph.size.width/2, glyph.size.height);
        
        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        
        // Glass border with tint
        [path setLineWidth:1.2];
        [[tintColor colorWithAlphaComponent:strokeOpacity] setStroke];
        [path stroke];
        
        // Specular white rims on top-left and bottom-right
        CGContextSaveGState(context);
        [path setLineWidth:1.2];
        CGContextAddPath(context, path.CGPath);
        CGContextReplacePathWithStrokedPath(context);
        CGContextClip(context);

        CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.9].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.7].CGColor];
        
        CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
        CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);
        
        CGPoint rimStart = CGPointMake(0, 0);
        CGPoint rimEnd = CGPointMake(glyph.size.width, glyph.size.height);
        
        CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);
        CGGradientRelease(rimGradient);
        CGColorSpaceRelease(rimColorSpace);
        CGContextRestoreGState(context);
        
    } else if ([style isEqualToString:@"Clear"] || ([style isEqualToString:@"Tinted"] && isDarkTheme)) {
        if ([style isEqualToString:@"Tinted"] && isDarkTheme) {
            [[UIColor colorWithWhite:0.06 alpha:1.0] setFill];
            [path fill];
        }
        
        CGFloat topOpacity = 0.2;
        CGFloat botOpacity = 0.03;
        CGFloat strokeOpacity = 0.2;
        CGFloat rimTopOpacity = 1.0;
        CGFloat rimBotOpacity = 1.0;
        
        if ([style isEqualToString:@"Tinted"] && isDarkTheme) {
            BOOL disableGrad = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] boolForKey:@"ngkhoi.26home.disableDarkTintGradient"];
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
        
        // Draw glassy gradient
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(id)[UIColor colorWithWhite:1.0 alpha:topOpacity].CGColor,
                            (id)[UIColor colorWithWhite:1.0 alpha:botOpacity].CGColor];
        
        CGFloat locations[] = {0.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
        
        CGPoint startPoint = CGPointMake(glyph.size.width/2, 0);
        CGPoint endPoint = CGPointMake(glyph.size.width/2, glyph.size.height);
        
        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
        
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        
        // Add a subtle glass border
        [path setLineWidth:1.5];
        [[UIColor colorWithWhite:1.0 alpha:strokeOpacity] setStroke];
        [path stroke];
        
        if (![g_menuAppearance isEqualToString:@"iOS18"] && isAutoGenerated) {
            // Add specular rims (highlighted top-left & bottom-right border)
            CGContextSaveGState(context);
            [path setLineWidth:1.5];
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
            
            CGPoint rimStart = CGPointMake(0, 0);
            CGPoint rimEnd = CGPointMake(glyph.size.width, glyph.size.height);
            
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
    
    // Apply dimming layer specifically to the background only before the glyph is drawn on top for Tinted Dark
    if ([style isEqualToString:@"Tinted"] && isDarkTheme) {
        [[UIColor colorWithWhite:0.0 alpha:0.40] setFill];
        [path fill];
    }
    
    // Draw glyph with subtle drop shadow for depth (glyph stays pure white in Tinted Light!)
    CGContextSaveGState(context);
    if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
        CGContextSetShadowWithColor(context, CGSizeMake(0, 2), 4.0, [UIColor colorWithWhite:0.0 alpha:0.3].CGColor);
    }
    [glyph drawInRect:CGRectMake(0, 0, glyph.size.width, glyph.size.height)];
    CGContextRestoreGState(context);
    
    // Draw specular rims ON TOP for Default and Dark (since their glyphs are opaque and would cover background rims)
    if (![g_menuAppearance isEqualToString:@"iOS18"] && ([style isEqualToString:@"Default"] || [style isEqualToString:@"Dark"]) && isAutoGenerated) {
        CGContextSaveGState(context);
        [path setLineWidth:1.5];
        [[UIColor colorWithWhite:1.0 alpha:0.15] setStroke];
        [path stroke];
        
        CGContextSetLineWidth(context, 1.5);
        CGContextAddPath(context, path.CGPath);
        CGContextReplacePathWithStrokedPath(context);
        CGContextClip(context);

        CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.75].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                               (id)[UIColor colorWithWhite:1.0 alpha:0.35].CGColor];
        
        CGFloat rimLocations[] = {0.0, 0.35, 0.65, 1.0};
        CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);
        
        CGPoint rimStart = CGPointMake(0, 0);
        CGPoint rimEnd = CGPointMake(glyph.size.width, glyph.size.height);
        
        CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);
        
        CGGradientRelease(rimGradient);
        CGColorSpaceRelease(rimColorSpace);
        
        CGContextRestoreGState(context);
    }
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
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
    
    // 1. Direct premade icon check for Clear style
    if ([effectiveStyle isEqualToString:@"Clear"]) {
        UIImage *premade = [self _premadeIconForBundleID:bundleID style:@"ClearLight"];
        if (premade) return premade;
    }
    
    NSString *tintHex = @"";
    if ([effectiveStyle isEqualToString:@"Tinted"]) {
        tintHex = g_tintColor ?: @"#00FFFF";
    }
    
    BOOL disableGrad = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] boolForKey:@"ngkhoi.26home.disableDarkTintGradient"];
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@_v41_bg_%@_%@_%@_%d", bundleID, effectiveStyle, isDarkTheme ? @"dark" : @"light", tintHex, g_menuAppearance, disableGrad];
    
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
    
    BOOL isAutoGenerated = NO;
    UIImage *glyph = nil;
    if ([effectiveStyle isEqualToString:@"Tinted"]) {
        UIImage *premadeClear = [self _premadeIconForBundleID:bundleID style:@"ClearLight"];
        if (premadeClear) {
            glyph = premadeClear;
            isAutoGenerated = NO;
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
        UIImage *premadeClear = [self _premadeIconForBundleID:bundleID style:@"ClearLight"];
        if (premadeClear) {
            glyph = premadeClear;
            isAutoGenerated = NO;
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
        UIImage *premadeDark = [self _premadeIconForBundleID:bundleID style:@"Dark"];
        if (premadeDark) {
            return premadeDark; // Premade dark icon is already fully rendered and complete
        } else {
            glyph = [self generateDarkIconForImage:orig bundleID:bundleID];
            isAutoGenerated = YES;
        }
    } else { // "Default"
        UIImage *premadeLight = [self _premadeIconForBundleID:bundleID style:@"Light"];
        if (premadeLight) {
            return premadeLight; // Premade light icon is already fully rendered and complete
        } else {
            glyph = orig;
            isAutoGenerated = YES;
        }
    }
    
    UIColor *tintColor = [self adjustedTintColorFromHex:tintHex isDarkTheme:isDarkTheme];
    UIImage *styled = [self compositeGlyph:glyph withBackgroundStyle:effectiveStyle isDarkTheme:isDarkTheme tintColor:tintColor isAutoGenerated:isAutoGenerated];
    
    // Tint overlay is ONLY applied to Tinted Dark (Tinted Light background is already tinted glass and glyph stays white)
    if ([effectiveStyle isEqualToString:@"Tinted"] && isDarkTheme && styled) {
        UIGraphicsBeginImageContextWithOptions(styled.size, NO, styled.scale);
        
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, styled.size.width, styled.size.height) cornerRadius:styled.size.width * 0.225];
        [path addClip];
        
        // 1. Fill solid tint color
        [tintColor setFill];
        UIRectFill(CGRectMake(0, 0, styled.size.width, styled.size.height));
        
        // 2. Apply luminosity (details) from original styled image
        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeLuminosity alpha:1.0];
        
        // 3. Mask out the original alpha channel (so transparent backgrounds stay transparent)
        [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0];
        
        styled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    if (styled) {
        [self.memoryCache setObject:styled forKey:cacheKey];
        dispatch_async(self.processingQueue, ^{
            NSData *pngData = UIImagePNGRepresentation(styled);
            [pngData writeToFile:diskPath atomically:YES];
        });
    }
    
    return styled;
}

// ---------------------------------------------------------
// IMAGE PROCESSING LOGIC
// ---------------------------------------------------------

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

- (unsigned char *)loadRawData:(UIImage *)image 
                          width:(size_t *)outWidth 
                         height:(size_t *)outHeight 
                   bytesPerRow:(NSUInteger *)outBytesPerRow {
    CGImageRef cgImage = image.CGImage;
    *outWidth = CGImageGetWidth(cgImage);
    *outHeight = CGImageGetHeight(cgImage);
    *outBytesPerRow = 4 * (*outWidth);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char *)calloc((*outHeight) * (*outWidth) * 4, sizeof(unsigned char));
    
    CGContextRef context = CGBitmapContextCreate(rawData, *outWidth, *outHeight, 8, *outBytesPerRow, colorSpace,
                                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, *outWidth, *outHeight), cgImage);
    CGContextRelease(context);
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
            
            // Smart gradient boundary box
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
            
            // Smooth anti-aliased distance calculation
            CGFloat t0 = 0.03;
            CGFloat t1 = 0.18;
            CGFloat factor = 0.0;
            if (dist > t0) {
                CGFloat t = (dist - t0) / (t1 - t0);
                if (t > 1.0) t = 1.0;
                factor = t * t * (3.0 - 2.0 * t); // Smoothstep curve for smooth anti-aliased edge
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
    
    // 3x3 anti-aliasing filter to eliminate jagged staircase artifacts on high-DPI displays
    unsigned char *smoothMask = (unsigned char *)malloc(height * width);
    for (int y = 0; y < (int)height; y++) {
        for (int x = 0; x < (int)width; x++) {
            int sum = 0;
            int weight = 0;
            for (int dy = -1; dy <= 1; dy++) {
                int ny = y + dy;
                if (ny < 0 || ny >= (int)height) continue;
                for (int dx = -1; dx <= 1; dx++) {
                    int nx = x + dx;
                    if (nx < 0 || nx >= (int)width) continue;
                    int w = (dx == 0 && dy == 0) ? 4 : 1;
                    sum += maskData[ny * width + nx] * w;
                    weight += w;
                }
            }
            smoothMask[y * width + x] = (unsigned char)(sum / weight);
        }
    }
    free(maskData);
    maskData = smoothMask;

    CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
    CGContextRef maskCtx = CGBitmapContextCreate(maskData, width, height, 8, width, graySpace, kCGImageAlphaNone);
    CGImageRef maskImage = CGBitmapContextCreateImage(maskCtx);
    CGContextRelease(maskCtx);
    CGColorSpaceRelease(graySpace);
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
    
    UIBezierPath *squircle = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height)
                                                        cornerRadius:size.width * 0.225];
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
    return result;
}

- (UIImage *)generateDarkIconForImage:(UIImage *)image bundleID:(NSString *)bundleID {
    // Explicitly skip complex stock apps that cannot be procedurally processed
    NSSet *skipApps = [NSSet setWithObjects:
                       @"com.apple.camera",
                       @"com.apple.mobilenotes",
                       @"com.apple.Preferences",
                       @"com.apple.Maps",
                       @"com.apple.weather",
                       nil];
                       
    if (bundleID && [skipApps containsObject:bundleID]) {
        return image;
    }

    size_t width, height;
    NSUInteger bytesPerRow;
    unsigned char *rawData = [self loadRawData:image width:&width height:&height bytesPerRow:&bytesPerRow];
    
    LGBGInfo bg = [self sampleBackgroundFromRawData:rawData width:width height:height bytesPerRow:bytesPerRow];
    
    if (bg.isDark) {
        free(rawData);
        return image;
    }
    
    BOOL fgIsColorful = NO;
    CGImageRef mask = [self createMaskFromRawData:rawData width:width height:height
                                     bytesPerRow:bytesPerRow bgInfo:bg outFgIsColorful:&fgIsColorful];
    free(rawData);
    
    UIImage *glyphImage;
    
    if (bg.isWhite || bg.saturation < 0.1) {
        // ALWAYS invert black text on white backgrounds, regardless of whether the foreground is colorful (like Calendar red SUN)
        glyphImage = [self invertDarkGrayscaleInImage:image];
    } else if (fgIsColorful) {
        glyphImage = image;
    } else {
        UIColor *topC = [UIColor colorWithRed:bg.tR green:bg.tG blue:bg.tB alpha:1.0];
        UIColor *botC = [UIColor colorWithRed:bg.bR green:bg.bG blue:bg.bB alpha:1.0];
        glyphImage = [self synthesizeGradientImageWithSize:image.size topColor:topC bottomColor:botC];
    }
    
    CGSize size = image.size;
    UIImage *result = [self compositeWithMask:mask glyphImage:glyphImage darkBg:YES size:size scale:image.scale];
    CGImageRelease(mask);
    return result;
}

- (UIImage *)generateClearIconForImage:(UIImage *)image bundleID:(NSString *)bundleID {
    size_t width, height;
    NSUInteger bytesPerRow;
    unsigned char *rawData = [self loadRawData:image width:&width height:&height bytesPerRow:&bytesPerRow];
    
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
        glyphImage = [self synthesizeGradientImageWithSize:image.size topColor:topC bottomColor:botC];
    }
    
    CGSize size = image.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, 0, size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    // 1. Clip to the extracted object mask
    CGContextClipToMask(ctx, CGRectMake(0, 0, size.width, size.height), mask);
    
    // 2. Draw the object image to retain its details and 3D depth
    CGContextSetAlpha(ctx, 0.95);
    CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), glyphImage.CGImage);
    
    CGContextSetAlpha(ctx, 1.0);
    
    // 3. Desaturate the object completely
    [[UIColor blackColor] setFill];
    CGContextSetBlendMode(ctx, kCGBlendModeSaturation);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    
    // 4. Tint to frosted white/gray while preserving 3D depth
    // The user requested to ALWAYS keep the object light/frosted, even in Dark mode,
    // so it contrasts well against the dark glass background.
    [[UIColor colorWithWhite:0.75 alpha:1.0] setFill];
    CGContextSetBlendMode(ctx, kCGBlendModeScreen);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    
    CGContextRestoreGState(ctx);
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRelease(mask);
    
    return result;
}

@end
