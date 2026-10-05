#import "HooksCommon.h"

%group UIKitHooks

%hook UIImage

+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale {
    extern BOOL g_bypassingIconHook;
    if (g_bypassingIconHook) return %orig;

    UIImage *orig = %orig;
    if (!bundleID || !orig) return orig;
    if (isAppExcluded(bundleID)) return orig;

    NSString *style = g_iconStyle ?: @"Default";
    if ([style isEqualToString:@"Default"]) {
        return orig;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_appIconImageCache = [[NSCache alloc] init];
        g_appIconImageCache.countLimit = 120;
    });

    CGFloat targetScale = orig.scale > 0 ? orig.scale : (scale > 0 ? scale : [UIScreen mainScreen].scale);
    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@_%@_%d_%.0fx%.0f_%.0f", bundleID, g_selectedIconPack ?: @"SolidGlass", style, format, orig.size.width, orig.size.height, targetScale];
    UIImage *cached = [g_appIconImageCache objectForKey:cacheKey];
    if (cached) return cached;

    UIImage *baked = Home26RequestStyledIcon(orig, bundleID);
    if (baked) {
        UIImage *finalImage = baked;
        if (orig.size.width > 0 && orig.size.height > 0 && !CGSizeEqualToSize(baked.size, orig.size)) {
            UIGraphicsBeginImageContextWithOptions(orig.size, NO, targetScale);
            [baked drawInRect:CGRectMake(0, 0, orig.size.width, orig.size.height)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resized) finalImage = resized;
        }
        [g_appIconImageCache setObject:finalImage forKey:cacheKey];
        return finalImage;
    }

    return orig;
}

%end

%end

%group PreferencesHooks

static NSString *Home26BundleIDForSpecifier(PSSpecifier *specifier) {
    if (!specifier) return nil;

    NSString *bundleID = [specifier propertyForKey:@"AppBundleID"]
                      ?: [specifier propertyForKey:@"appIDForLazyIcon"]
                      ?: [specifier propertyForKey:@"appBundleIdentifier"]
                      ?: [specifier propertyForKey:@"containerBundleID"]
                      ?: [specifier propertyForKey:@"lazyIconAppID"];

    if (bundleID && [bundleID isKindOfClass:[NSString class]] && bundleID.length > 0) {
        return bundleID;
    }

    NSString *ident = [specifier identifier];
    if (ident && [ident isKindOfClass:[NSString class]] && ident.length > 0) {
        if ([ident containsString:@"."] && ![ident containsString:@" "]) {
            return ident;
        }

        static NSDictionary<NSString *, NSString *> *systemAppMap = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            systemAppMap = @{
                @"SAFARI": @"com.apple.mobilesafari",
                @"Photos": @"com.apple.mobileslideshow",
                @"CAMERA": @"com.apple.camera",
                @"MAIL": @"com.apple.mobilemail",
                @"MESSAGES": @"com.apple.MobileSMS",
                @"MUSIC": @"com.apple.Music",
                @"WEATHER": @"com.apple.weather",
                @"MAPS": @"com.apple.Maps",
                @"NOTES": @"com.apple.mobilenotes",
                @"REMINDERS": @"com.apple.reminders",
                @"CALENDAR": @"com.apple.mobilecal",
                @"CONTACTS": @"com.apple.MobileAddressBook",
                @"Phone": @"com.apple.mobilephone",
                @"FACETIME": @"com.apple.facetime",
                @"STOCKS": @"com.apple.stocks",
                @"HEALTH": @"com.apple.Health",
                @"IBOOKS": @"com.apple.iBooks",
                @"PODCASTS": @"com.apple.podcasts",
                @"TVAPP": @"com.apple.tv",
                @"VOICE_MEMOS": @"com.apple.VoiceMemos",
                @"COMPASS": @"com.apple.compass",
                @"MEASURE": @"com.apple.measure",
                @"SHORTCUTS": @"com.apple.shortcuts",
                @"TRANSLATE": @"com.apple.Translate",
                @"FREEFORM": @"com.apple.freeform",
                @"STORE": @"com.apple.AppStore",
                @"PASSBOOK": @"com.apple.Passbook",
                @"GAMECENTER": @"com.apple.gamecenter",
                @"NEWS": @"com.apple.news",
                @"FITNESS": @"com.apple.Fitness",
                @"TIPS": @"com.apple.tips"
            };
        });

        NSString *mapped = systemAppMap[ident];
        if (mapped) return mapped;
    }

    return nil;
}

static UIImage *Home26ResizeImage(UIImage *image, CGSize targetSize, CGFloat targetScale) {
    if (!image) return nil;
    if (CGSizeEqualToSize(image.size, targetSize) && image.scale == targetScale) {
        return image;
    }
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, targetScale);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resized ?: image;
}

static NSCache *g_preferencesStyledIconCache = nil;
static const char kHome26StyledMarkerKey = 0;

static UIImage *Home26StyledSettingsIcon(UIImage *orig, NSString *bundleID, CGSize targetSize) {
    if (!bundleID || !g_tweakEnabled) return orig;
    if (isAppExcluded(bundleID)) return orig;

    NSString *style = g_iconStyle ?: @"Default";
    CGFloat screenScale = [UIScreen mainScreen].scale;
    CGFloat targetScale = (orig && orig.scale > 0) ? orig.scale : screenScale;
    if (CGSizeEqualToSize(targetSize, CGSizeZero)) {
        targetSize = (orig && orig.size.width > 0) ? orig.size : CGSizeMake(29.0, 29.0);
    }

    if (!g_preferencesStyledIconCache) {
        g_preferencesStyledIconCache = [[NSCache alloc] init];
        g_preferencesStyledIconCache.countLimit = 300;
    }

    NSString *cacheKey = [NSString stringWithFormat:@"%@_%@_%@_%@_%.0fx%.0f_%.0f",
                          bundleID,
                          g_selectedIconPack ?: @"SolidGlass",
                          style,
                          g_themeMode ?: @"Auto",
                          targetSize.width,
                          targetSize.height,
                          targetScale];

    UIImage *cached = [g_preferencesStyledIconCache objectForKey:cacheKey];
    if (cached) {
        return cached;
    }

    UIImage *sourceImage = orig;
    UIImage *cachedOrig = Home26OriginalIconForBundleID(bundleID);
    if (cachedOrig) {
        sourceImage = cachedOrig;
    } else {
        if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
            extern BOOL g_bypassingIconHook;
            g_bypassingIconHook = YES;
            UIImage *large = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:screenScale];
            g_bypassingIconHook = NO;
            if (large) sourceImage = large;
        }
        if (sourceImage) {
            Home26SaveOriginalIcon(sourceImage, bundleID);
        }
    }

    if (!sourceImage) {
        return orig;
    }

    UIImage *styled = Home26RequestStyledIcon(sourceImage, bundleID);
    if (!styled) {
        return orig;
    }

    UIImage *finalImage = Home26ResizeImage(styled, targetSize, targetScale);
    if (finalImage) {
        objc_setAssociatedObject(finalImage, &kHome26StyledMarkerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [g_preferencesStyledIconCache setObject:finalImage forKey:cacheKey];
        return finalImage;
    }

    return orig;
}

%hook PSTableCell

- (UIImage *)getLazyIcon {
    UIImage *orig = %orig;
    if (!g_tweakEnabled) return orig;

    PSSpecifier *spec = nil;
    if ([self respondsToSelector:@selector(specifier)]) {
        spec = [self specifier];
    }
    NSString *bundleID = Home26BundleIDForSpecifier(spec);
    if (!bundleID) return orig;

    CGSize targetSize = (orig && orig.size.width > 0) ? orig.size : CGSizeMake(29.0, 29.0);
    UIImage *styled = Home26StyledSettingsIcon(orig, bundleID, targetSize);
    return styled ?: orig;
}

- (void)setIcon:(UIImage *)icon {
    if (!g_tweakEnabled || !icon) {
        %orig(icon);
        return;
    }

    if (objc_getAssociatedObject(icon, &kHome26StyledMarkerKey)) {
        %orig(icon);
        return;
    }

    if ([self respondsToSelector:@selector(blankIcon)] && icon == [self blankIcon]) {
        %orig(icon);
        return;
    }
    if (icon.size.width <= 1.0 || icon.size.height <= 1.0) {
        %orig(icon);
        return;
    }

    PSSpecifier *spec = nil;
    if ([self respondsToSelector:@selector(specifier)]) {
        spec = [self specifier];
    }
    NSString *bundleID = Home26BundleIDForSpecifier(spec);
    if (!bundleID || isAppExcluded(bundleID)) {
        %orig(icon);
        return;
    }

    CGSize targetSize = icon.size.width > 0 ? icon.size : CGSizeMake(29.0, 29.0);
    UIImage *styled = Home26StyledSettingsIcon(icon, bundleID, targetSize);
    %orig(styled ?: icon);
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    %orig(specifier);

    if (!g_tweakEnabled || !specifier) return;

    UIImage *currentIcon = nil;
    if ([self respondsToSelector:@selector(icon)]) {
        currentIcon = [self icon];
    }
    if (!currentIcon && [self respondsToSelector:@selector(iconImageView)]) {
        UIImageView *iv = [self iconImageView];
        currentIcon = iv.image;
    }

    if (currentIcon && !objc_getAssociatedObject(currentIcon, &kHome26StyledMarkerKey)) {
        if ([self respondsToSelector:@selector(blankIcon)] && currentIcon == [self blankIcon]) {
            return;
        }
        if (currentIcon.size.width <= 1.0 || currentIcon.size.height <= 1.0) {
            return;
        }

        NSString *bundleID = Home26BundleIDForSpecifier(specifier);
        if (bundleID && !isAppExcluded(bundleID)) {
            CGSize targetSize = currentIcon.size.width > 0 ? currentIcon.size : CGSizeMake(29.0, 29.0);
            UIImage *styled = Home26StyledSettingsIcon(currentIcon, bundleID, targetSize);
            if (styled && styled != currentIcon) {
                [self setIcon:styled];
            }
        }
    }
}

%end

void Home26RegisterPreferencesNotifications(void) {
    int token;
    notify_register_dispatch("ngkhoi.26home.UpdateIconStyle", &token, dispatch_get_main_queue(), ^(int t) {
        reload26HomePrefs();
        if (g_preferencesStyledIconCache) {
            [g_preferencesStyledIconCache removeAllObjects];
        }
        Home26ClearGeneratorCache();

        UIWindow *keyWin = Home26GetKeyWindow();
        Home26ReloadAllVisibleTables(keyWin);
    });

    notify_register_dispatch("ngkhoi.26home.reloadPrefs", &token, dispatch_get_main_queue(), ^(int t) {
        reload26HomePrefs();
        if (g_preferencesStyledIconCache) {
            [g_preferencesStyledIconCache removeAllObjects];
        }
    });

    notify_register_dispatch("ngkhoi.26home.clearCache", &token, dispatch_get_main_queue(), ^(int t) {
        reload26HomePrefs();
        if (g_preferencesStyledIconCache) {
            [g_preferencesStyledIconCache removeAllObjects];
        }
        Home26ClearGeneratorCache();

        UIWindow *keyWin = Home26GetKeyWindow();
        Home26ReloadAllVisibleTables(keyWin);
    });
}

%end

void Home26InitPreferencesHooks(void) {
    Home26RegisterPreferencesNotifications();
    %init(UIKitHooks);
    %init(PreferencesHooks);
}
