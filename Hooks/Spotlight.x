#import "HooksCommon.h"

void Home26RegisterSpotlightNotifications(void) {
    int token;
    notify_register_dispatch("ngkhoi.26home.UpdateIconStyle", &token, dispatch_get_main_queue(), ^(int t) {
        reload26HomePrefs();
        Home26ClearGeneratorCache();
        UIWindow *keyWin = Home26GetKeyWindow();
        if (keyWin) {
            Home26ReloadAllVisibleTables(keyWin);
        }
    });

    notify_register_dispatch("ngkhoi.26home.reloadPrefs", &token, dispatch_get_main_queue(), ^(int t) {
        reload26HomePrefs();
        UIWindow *keyWin = Home26GetKeyWindow();
        if (keyWin) {
            Home26ReloadAllVisibleTables(keyWin);
        }
    });

    notify_register_dispatch("ngkhoi.26home.clearCache", &token, dispatch_get_main_queue(), ^(int t) {
        reload26HomePrefs();
        Home26ClearGeneratorCache();
        UIWindow *keyWin = Home26GetKeyWindow();
        if (keyWin) {
            Home26ReloadAllVisibleTables(keyWin);
        }
    });
}

%group SearchUIHooks

%hook SearchUIAppIconImage

- (void)loadImageWithScale:(double)scale isDarkStyle:(BOOL)isDark completionHandler:(void (^)(UIImage *))completionHandler {
    if (!completionHandler) {
        %orig(scale, isDark, completionHandler);
        return;
    }

    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [self bundleIdentifier];
    }

    if (!bundleID || isAppExcluded(bundleID)) {
        %orig(scale, isDark, completionHandler);
        return;
    }

    NSString *capturedBundleID = bundleID;
    void (^completionWrapper)(UIImage *) = ^(UIImage *origImage) {
        if (origImage && [origImage isKindOfClass:[UIImage class]]) {
            UIImage *styled = Home26RequestStyledIcon(origImage, capturedBundleID);
            if (styled) {
                if (origImage.size.width > 0 && origImage.size.height > 0 && !CGSizeEqualToSize(styled.size, origImage.size)) {
                    CGFloat targetScale = origImage.scale > 0 ? origImage.scale : (scale > 0 ? scale : [UIScreen mainScreen].scale);
                    UIGraphicsBeginImageContextWithOptions(origImage.size, NO, targetScale);
                    [styled drawInRect:CGRectMake(0, 0, origImage.size.width, origImage.size.height)];
                    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    if (resized) {
                        completionHandler(resized);
                        return;
                    }
                }
                completionHandler(styled);
                return;
            }
        }
        completionHandler(origImage);
    };
    %orig(scale, isDark, completionWrapper);
}

- (id)loadImageWithScale:(double)scale isDarkStyle:(BOOL)isDarkStyle {
    UIImage *orig = %orig;
    if (!orig || ![orig isKindOfClass:[UIImage class]]) return orig;

    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [self bundleIdentifier];
    }

    if (!bundleID || isAppExcluded(bundleID)) {
        return orig;
    }

    UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
    if (styled) {
        if (orig.size.width > 0 && orig.size.height > 0 && !CGSizeEqualToSize(styled.size, orig.size)) {
            CGFloat targetScale = orig.scale > 0 ? orig.scale : (scale > 0 ? scale : [UIScreen mainScreen].scale);
            UIGraphicsBeginImageContextWithOptions(orig.size, NO, targetScale);
            [styled drawInRect:CGRectMake(0, 0, orig.size.width, orig.size.height)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resized) return resized;
        }
        return styled;
    }
    return orig;
}

- (id)generateImageWithFormat:(int)format scale:(double)scale {
    UIImage *orig = %orig;
    if (!orig || ![orig isKindOfClass:[UIImage class]]) return orig;

    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [self bundleIdentifier];
    }

    if (!bundleID || isAppExcluded(bundleID)) {
        return orig;
    }

    UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
    if (styled) {
        if (orig.size.width > 0 && orig.size.height > 0 && !CGSizeEqualToSize(styled.size, orig.size)) {
            CGFloat targetScale = orig.scale > 0 ? orig.scale : (scale > 0 ? scale : [UIScreen mainScreen].scale);
            UIGraphicsBeginImageContextWithOptions(orig.size, NO, targetScale);
            [styled drawInRect:CGRectMake(0, 0, orig.size.width, orig.size.height)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resized) return resized;
        }
        return styled;
    }
    return orig;
}

%end

%hook SearchUIImage

- (UIImage *)uiImage {
    UIImage *orig = %orig;
    if (!orig || ![orig isKindOfClass:[UIImage class]]) return orig;

    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [(id)self performSelector:@selector(bundleIdentifier)];
    }

    if (bundleID && !isAppExcluded(bundleID)) {
        UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
        if (styled) {
            if (orig.size.width > 0 && orig.size.height > 0 && !CGSizeEqualToSize(styled.size, orig.size)) {
                CGFloat targetScale = orig.scale > 0 ? orig.scale : [UIScreen mainScreen].scale;
                UIGraphicsBeginImageContextWithOptions(orig.size, NO, targetScale);
                [styled drawInRect:CGRectMake(0, 0, orig.size.width, orig.size.height)];
                UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                if (resized) return resized;
            }
            return styled;
        }
    }
    return orig;
}

- (id)loadImageWithScale:(double)scale isDarkStyle:(BOOL)isDarkStyle {
    UIImage *orig = %orig;
    if (!orig || ![orig isKindOfClass:[UIImage class]]) return orig;

    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [(id)self performSelector:@selector(bundleIdentifier)];
    }

    if (!bundleID || isAppExcluded(bundleID)) {
        return orig;
    }

    UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
    if (styled) {
        if (orig.size.width > 0 && orig.size.height > 0 && !CGSizeEqualToSize(styled.size, orig.size)) {
            CGFloat targetScale = orig.scale > 0 ? orig.scale : (scale > 0 ? scale : [UIScreen mainScreen].scale);
            UIGraphicsBeginImageContextWithOptions(orig.size, NO, targetScale);
            [styled drawInRect:CGRectMake(0, 0, orig.size.width, orig.size.height)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resized) return resized;
        }
        return styled;
    }
    return orig;
}

%end

%end

void Home26InitSpotlightHooks(void) {
    Home26RegisterSpotlightNotifications();
    if (objc_getClass("SearchUIAppIconImage") || objc_getClass("SearchUIImage")) {
        %init(SearchUIHooks);
    }
}
