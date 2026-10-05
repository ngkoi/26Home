#import "HooksCommon.h"

BOOL g_tweakEnabled = YES;
BOOL g_bypassingIconHook = NO;
NSString *g_engineVersion = @"IconGen2";
NSString *g_selectedIconPack = @"SolidGlass";
NSString *g_iconStyle = @"Default";
NSString *g_themeMode = @"Auto";
NSString *g_darkIconMode = @"Always";
NSString *g_tintColor = @"#00FFFF";
BOOL g_largeIconsEnabled = NO;
BOOL g_disableLiquidGlassIcons = NO;
BOOL g_keepAppIconBlur = YES;
NSDictionary *g_excludedApps = nil;
BOOL g_exceptionsApplyOnlyToSolid = YES;
BOOL g_exceptionsNoIconProcessing = YES;
CGFloat g_appIconBlurRadius = 1.0;
CGFloat g_appIconGlassQuality = 0.35;
BOOL g_hideGlassWhenUnfocused = YES;
NSString *g_menuAppearance = @"iOS26";

BOOL g_isAppOpening = NO;
BOOL g_isFolderOpen = NO;
BOOL g_isHomeScreenVisible = YES;
BOOL g_isSwitcherOpen = NO;
BOOL g_isCoverSheetVisible = NO;
BOOL g_isEditingMode = NO;
BOOL g_isAnimatingScale = NO;
BOOL g_eyedropperActive = NO;
double g_coverSheetProgress = 0.0;
BOOL g_isWallpaperDimmed = NO;
UIView *g_dimView = nil;

BOOL Home26IsViewInFolder(UIView *view) {
    if (!view) return NO;
    UIView *v = view;
    while (v) {
        if ([v isKindOfClass:NSClassFromString(@"SBFolderView")] ||
            [v isKindOfClass:NSClassFromString(@"SBFloatyFolderView")] ||
            [v isKindOfClass:NSClassFromString(@"SBFolderControllerBackgroundView")] ||
            [v isKindOfClass:NSClassFromString(@"SBFolderIconImageView")]) {
            return YES;
        }
        v = v.superview;
    }
    return NO;
}

void ForceLayoutAllIconViews(UIView *view) {
    if ([view isKindOfClass:NSClassFromString(@"SBIconView")]) {
        if ([view respondsToSelector:@selector(_26home_updateCustomScale)]) {
            [view performSelector:@selector(_26home_updateCustomScale)];
        }
        [view setNeedsLayout];
        [UIView animateWithDuration:0.3 animations:^{
            [view layoutIfNeeded];
        }];
    }
    for (UIView *sub in view.subviews) {
        ForceLayoutAllIconViews(sub);
    }
}

void updateTintViews(UIView *view, UIColor *tintColor) {
    if ([view isKindOfClass:NSClassFromString(@"SBIconView")]) {
        UIView *tintView = [view viewWithTag:9003];
        if (tintView) tintView.backgroundColor = tintColor;

        id icon = [view respondsToSelector:@selector(icon)] ? [view performSelector:@selector(icon)] : nil;
        if ([icon isKindOfClass:NSClassFromString(@"SBWidgetIcon")]) {
            _26home_recursivelyApplyWidgetTint(view);
        }
    }
    for (UIView *sub in view.subviews) {
        updateTintViews(sub, tintColor);
    }
}

NSCache *g_appIconImageCache = nil;
NSCache *g_notificationIconsCache = nil;

__weak id g_editingDoneTarget = nil;
SEL g_editingDoneAction = NULL;

id GetIconGenerator(void) {
    return [LGCustomIconGenerator2 sharedGenerator];
}

BOOL isAppInExceptionList(NSString *bundleID) {
    if (!bundleID || !g_excludedApps) return NO;
    NSNumber *val = g_excludedApps[bundleID];
    return val ? [val boolValue] : NO;
}

BOOL isAppExcluded(NSString *bundleID) {
    if (!bundleID || !isAppInExceptionList(bundleID)) return NO;

    if (g_exceptionsApplyOnlyToSolid) {
        NSString *style = g_iconStyle ?: @"Default";
        if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
            return NO;
        }
    }
    return YES;
}

BOOL isAppExcludedFromEffects(NSString *bundleID) {
    return isAppExcluded(bundleID);
}

BOOL Home26IsCoverSheetActive(void) {
    Class csManagerCls = NSClassFromString(@"SBCoverSheetPresentationManager");
    if (csManagerCls && [csManagerCls respondsToSelector:@selector(sharedInstanceIfExists)]) {
        id manager = [csManagerCls performSelector:@selector(sharedInstanceIfExists)];
        if (manager && [manager respondsToSelector:@selector(isPresented)]) {
            return ((BOOL (*)(id, SEL))[manager methodForSelector:@selector(isPresented)])(manager, @selector(isPresented));
        }
    }
    return g_isCoverSheetVisible || g_coverSheetProgress > 0.001;
}

UIWindow *GetWallpaperWindow(void) {
    id wc = [NSClassFromString(@"SBWallpaperController") sharedInstance];
    if (wc) {
        @try {
            UIWindow *ww = [wc valueForKey:@"wallpaperWindow"] ?: [wc valueForKey:@"_wallpaperWindow"];
            if (ww && [ww isKindOfClass:[UIWindow class]]) {
                return ww;
            }
        } @catch (id e) {}
    }
    return nil;
}

UIWindow *Home26GetKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) return w;
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

void EnsureWallpaperDimView(void) {
    if (g_dimView && g_dimView.superview) return;

    UIWindow *ww = GetWallpaperWindow();
    if (!ww) return;

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    g_dimView = [ww viewWithTag:99926];

    if (!g_dimView) {
        g_dimView = [[UIView alloc] initWithFrame:CGRectMake(-500.0, -500.0, screenBounds.size.width + 1000.0, screenBounds.size.height + 1000.0)];
        g_dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        g_dimView.backgroundColor = [UIColor blackColor];
        g_dimView.userInteractionEnabled = NO;
        g_dimView.layer.masksToBounds = NO;
        g_dimView.clipsToBounds = NO;
        g_dimView.alpha = 0.0;
        g_dimView.tag = 99926;
        [ww addSubview:g_dimView];
    }
}

void UpdateWallpaperDimState(BOOL dimmed, BOOL animated) {
    g_isWallpaperDimmed = dimmed;
    if (dimmed) EnsureWallpaperDimView();
    if (!g_dimView) return;

    if (g_dimView.superview) {
        [g_dimView.superview bringSubviewToFront:g_dimView];
    }

    Class csManagerCls = NSClassFromString(@"SBCoverSheetPresentationManager");
    if (csManagerCls && [csManagerCls respondsToSelector:@selector(sharedInstanceIfExists)]) {
        id csManager = [csManagerCls performSelector:@selector(sharedInstanceIfExists)];
        if (csManager && [csManager respondsToSelector:@selector(isPresented)]) {
            BOOL presented = ((BOOL (*)(id, SEL))[csManager methodForSelector:@selector(isPresented)])(csManager, @selector(isPresented));
            if (presented && g_coverSheetProgress == 0.0) {
                g_coverSheetProgress = 1.0;
            } else if (!presented && g_coverSheetProgress == 1.0) {
                g_coverSheetProgress = 0.0;
            }
        }
    }

    CGFloat baseAlpha = dimmed ? 0.35 : 0.0;
    CGFloat targetAlpha = baseAlpha * (1.0 - g_coverSheetProgress);

    if (animated) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            g_dimView.alpha = targetAlpha;
        } completion:nil];
    } else {
        g_dimView.alpha = targetAlpha;
    }
}

void reload26HomePrefs(void) {
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));

    Boolean enableKeyExists = false;
    Boolean enabled = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.enabled"), CFSTR("com.ngkhoi.26home"), &enableKeyExists);
    g_tweakEnabled = enableKeyExists ? enabled : YES;

    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    CFPropertyListRef engineVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.icongen.engineVersion"), CFSTR("com.ngkhoi.26home"));
    if (engineVal && [(__bridge id)engineVal isKindOfClass:[NSString class]]) {
        g_engineVersion = [(__bridge NSString *)engineVal copy];
        CFRelease(engineVal);
    } else {
        g_engineVersion = [prefs stringForKey:@"ngkhoi.26home.icongen.engineVersion"] ?: @"IconGen3";
    }

    CFPropertyListRef packVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.selectedIconPack"), CFSTR("com.ngkhoi.26home"));
    if (packVal && [(__bridge id)packVal isKindOfClass:[NSString class]]) {
        g_selectedIconPack = [(__bridge NSString *)packVal copy];
        CFRelease(packVal);
    } else {
        g_selectedIconPack = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: @"SolidGlass";
    }

    g_iconStyle = [prefs stringForKey:@"ngkhoi.26home.iconStyle"] ?: @"Default";
    g_themeMode = [prefs stringForKey:@"ngkhoi.26home.themeMode"] ?: @"Auto";
    g_darkIconMode = [prefs stringForKey:@"ngkhoi.26home.darkIconMode"] ?: @"Always";
    g_tintColor = [prefs stringForKey:@"ngkhoi.26home.tintColor"] ?: @"#00FFFF";
    g_largeIconsEnabled = [prefs boolForKey:@"ngkhoi.26home.largeIcons"];
    g_disableLiquidGlassIcons = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.disableLiquidGlassIcons"), CFSTR("com.ngkhoi.26home"), NULL);

    CFPropertyListRef excludedVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.excludedApps"), CFSTR("com.ngkhoi.26home"));
    if (excludedVal && [(__bridge id)excludedVal isKindOfClass:[NSDictionary class]]) {
        g_excludedApps = [(__bridge NSDictionary *)excludedVal copy];
        CFRelease(excludedVal);
    } else {
        g_excludedApps = [prefs dictionaryForKey:@"ngkhoi.26home.excludedApps"] ?: @{};
    }

    Boolean solidKeyExists = false;
    Boolean solidVal = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.exceptionsApplyOnlyToSolid"), CFSTR("com.ngkhoi.26home"), &solidKeyExists);
    g_exceptionsApplyOnlyToSolid = solidKeyExists ? solidVal : YES;

    Boolean noProcKeyExists = false;
    Boolean noProcVal = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.exceptionsNoIconProcessing"), CFSTR("com.ngkhoi.26home"), &noProcKeyExists);
    g_exceptionsNoIconProcessing = noProcKeyExists ? noProcVal : YES;

    Home26Log(@"[Prefs Reload] exceptionsApplyOnlyToSolid: %d, exceptionsNoIconProcessing: %d, excludedApps: %lu",
              g_exceptionsApplyOnlyToSolid, g_exceptionsNoIconProcessing, (unsigned long)g_excludedApps.count);

    if ([prefs objectForKey:@"ngkhoi.26home.hideGlassWhenUnfocused"]) {
        g_hideGlassWhenUnfocused = [prefs boolForKey:@"ngkhoi.26home.hideGlassWhenUnfocused"];
    } else {
        g_hideGlassWhenUnfocused = YES;
    }

    g_menuAppearance = @"iOS26";

    Boolean keyExists = false;
    Boolean keepBlur = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.keepAppIconBlur"), CFSTR("com.ngkhoi.26home"), &keyExists);
    g_keepAppIconBlur = keyExists ? keepBlur : YES;

    CFPropertyListRef blurVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.appIconBlurRadius"), CFSTR("com.ngkhoi.26home"));
    if (blurVal && [(__bridge id)blurVal isKindOfClass:[NSNumber class]]) {
        g_appIconBlurRadius = [(__bridge NSNumber *)blurVal floatValue];
        CFRelease(blurVal);
    } else {
        g_appIconBlurRadius = 1.0;
    }

    CFPropertyListRef qualityVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.appIconGlassQuality"), CFSTR("com.ngkhoi.26home"));
    if (qualityVal && [(__bridge id)qualityVal isKindOfClass:[NSNumber class]]) {
        g_appIconGlassQuality = [(__bridge NSNumber *)qualityVal floatValue];
        CFRelease(qualityVal);
    } else {
        g_appIconGlassQuality = 0.35;
    }
    if (g_appIconGlassQuality < 0.10) g_appIconGlassQuality = 0.10;
    if (g_appIconGlassQuality > 1.0) g_appIconGlassQuality = 1.0;
}

void notifyAllIconsVisibilityChanged(void) {
    Class iconCtrlCls = NSClassFromString(@"SBIconController");
    id iconController = nil;
    if ([iconCtrlCls respondsToSelector:@selector(sharedInstance)]) {
        iconController = [iconCtrlCls performSelector:@selector(sharedInstance)];
    }
    if (iconController) {
        id iconManager = nil;
        if ([iconController respondsToSelector:@selector(iconManager)]) {
            iconManager = [iconController performSelector:@selector(iconManager)];
        } else {
            iconManager = iconController;
        }
        if (iconManager && [iconManager respondsToSelector:@selector(enumerateKnownIconViewsUsingBlock:)]) {
            void (*enumerate)(id, SEL, void (^)(id)) = (void (*)(id, SEL, void (^)(id)))[iconManager methodForSelector:@selector(enumerateKnownIconViewsUsingBlock:)];
            enumerate(iconManager, @selector(enumerateKnownIconViewsUsingBlock:), ^(UIView *iconView) {
                if ([iconView respondsToSelector:@selector(_26home_updateGlassVisibility)]) {
                    [iconView performSelector:@selector(_26home_updateGlassVisibility)];
                }
            });
        }
    }
}

void Home26RefreshAllFolderIcons(void) {
    Class iconCtrlCls = NSClassFromString(@"SBIconController");
    id iconController = nil;
    if ([iconCtrlCls respondsToSelector:@selector(sharedInstance)]) {
        iconController = [iconCtrlCls performSelector:@selector(sharedInstance)];
    }
    if (!iconController) return;

    id iconManager = [iconController respondsToSelector:@selector(iconManager)] ?
                     [iconController performSelector:@selector(iconManager)] : iconController;
    if (!iconManager) return;

    if ([iconManager respondsToSelector:@selector(iconImageCache)]) {
        id iconCache = [iconManager performSelector:@selector(iconImageCache)];
        if ([iconCache respondsToSelector:@selector(purgeAllCachedImages)]) {
            [iconCache performSelector:@selector(purgeAllCachedImages)];
        }
    }

    if ([iconManager respondsToSelector:@selector(folderIconImageCache)]) {
        id folderCache = [iconManager performSelector:@selector(folderIconImageCache)];
        if (folderCache) {
            id iconImageCache = [folderCache respondsToSelector:@selector(iconImageCache)] ?
                                [folderCache performSelector:@selector(iconImageCache)] : nil;
            if (iconImageCache && [iconImageCache respondsToSelector:@selector(purgeAllCachedImages)]) {
                [iconImageCache performSelector:@selector(purgeAllCachedImages)];
            }
            @try {
                id cachedMiniGridImages = [folderCache valueForKey:@"_cachedMiniGridImages"];
                if ([cachedMiniGridImages respondsToSelector:@selector(removeAllObjects)]) {
                    [cachedMiniGridImages removeAllObjects];
                }
            } @catch (NSException *e) {}

            void (^rebuildFolderIconBlock)(id) = ^(id icon) {
                if (!icon) return;
                BOOL isFolder = NO;
                if ([icon respondsToSelector:@selector(isFolderIcon)]) {
                    isFolder = ((BOOL (*)(id, SEL))[icon methodForSelector:@selector(isFolderIcon)])(icon, @selector(isFolderIcon));
                }
                Class folderIconCls = NSClassFromString(@"SBFolderIcon");
                if (isFolder || (folderIconCls && [icon isKindOfClass:folderIconCls])) {
                    if (folderCache) {
                        if ([folderCache respondsToSelector:@selector(rebuildImagesForFolderIcon:)]) {
                            [folderCache performSelector:@selector(rebuildImagesForFolderIcon:) withObject:icon];
                        }
                        if ([folderCache respondsToSelector:@selector(informObserversOfUpdateForFolderIcon:)]) {
                            [folderCache performSelector:@selector(informObserversOfUpdateForFolderIcon:) withObject:icon];
                        }
                    }
                    if ([icon respondsToSelector:@selector(iconImageDidUpdate:)]) {
                        [icon performSelector:@selector(iconImageDidUpdate:) withObject:icon];
                    }
                }
            };

            id rootFolder = [iconManager respondsToSelector:@selector(rootFolder)] ?
                            [iconManager performSelector:@selector(rootFolder)] : nil;
            if (!rootFolder && [iconController respondsToSelector:@selector(rootFolder)]) {
                rootFolder = [iconController performSelector:@selector(rootFolder)];
            }
            if (rootFolder) {
                if ([rootFolder respondsToSelector:@selector(folderIcons)]) {
                    NSArray *fIcons = [rootFolder performSelector:@selector(folderIcons)];
                    if ([fIcons isKindOfClass:[NSArray class]]) {
                        for (id fIcon in fIcons) {
                            rebuildFolderIconBlock(fIcon);
                        }
                    }
                }
                if ([rootFolder respondsToSelector:@selector(enumerateAllIconsUsingBlock:)]) {
                    void (*enumerateAll)(id, SEL, void (^)(id)) = (void (*)(id, SEL, void (^)(id)))[rootFolder methodForSelector:@selector(enumerateAllIconsUsingBlock:)];
                    enumerateAll(rootFolder, @selector(enumerateAllIconsUsingBlock:), ^(id icon) {
                        rebuildFolderIconBlock(icon);
                    });
                }
            }
        }
    }
}

void refreshKnownIcons(void) {
    Home26Log(@"--- refreshKnownIcons START ---");
    Home26RefreshAllFolderIcons();
    Class iconCtrlCls = NSClassFromString(@"SBIconController");
    id iconController = nil;
    if ([iconCtrlCls respondsToSelector:@selector(sharedInstance)]) {
        iconController = [iconCtrlCls performSelector:@selector(sharedInstance)];
    }

    if (iconController) {
        id iconManager = nil;
        if ([iconController respondsToSelector:@selector(iconManager)]) {
            iconManager = [iconController performSelector:@selector(iconManager)];
        } else {
            iconManager = iconController;
        }

        if (iconManager && [iconManager respondsToSelector:@selector(enumerateKnownIconViewsUsingBlock:)]) {
            __block int count = 0;
            void (*enumerate)(id, SEL, void (^)(id)) = (void (*)(id, SEL, void (^)(id)))[iconManager methodForSelector:@selector(enumerateKnownIconViewsUsingBlock:)];
            enumerate(iconManager, @selector(enumerateKnownIconViewsUsingBlock:), ^(UIView *iconView) {
                count++;
                if ([iconView respondsToSelector:@selector(_26home_updateIconStyle)]) {
                    [iconView performSelector:@selector(_26home_updateIconStyle)];
                } else if ([iconView respondsToSelector:@selector(_26home_forceUpdate)]) {
                    [iconView performSelector:@selector(_26home_forceUpdate)];
                }
            });
            Home26Log(@"refreshKnownIcons updated %d icon views", count);
        }
    }
    Home26Log(@"--- refreshKnownIcons END ---");
}

void Home26TriggerGlobalRefresh(void) {
    Home26RefreshAllFolderIcons();
    refreshKnownIcons();
}

void Home26ReloadAllVisibleTables(UIView *view) {
    if (!view) return;
    if ([view isKindOfClass:[UITableView class]]) {
        UITableView *tv = (UITableView *)view;
        [tv reloadData];
        return;
    }
    if ([view isKindOfClass:[UICollectionView class]]) {
        UICollectionView *cv = (UICollectionView *)view;
        [cv reloadData];
        return;
    }
    Class sbIconImageViewClass = objc_getClass("SBIconImageView");
    if (sbIconImageViewClass && [view isKindOfClass:sbIconImageViewClass]) {
        if ([view respondsToSelector:@selector(updateImageAnimated:)]) {
            [(SBIconImageView *)view updateImageAnimated:NO];
        }
    }
    for (UIView *sub in view.subviews) {
        Home26ReloadAllVisibleTables(sub);
    }
}

UIImage *Home26RequestStyledIcon(UIImage *image, NSString *bundleID) {
    if (!bundleID) return nil;
    id generator = GetIconGenerator();
    if (!generator) return nil;

    UIImage *sourceImage = image;
    if (!sourceImage || sourceImage.size.width < 50) {
        if ([generator respondsToSelector:@selector(originalImageForBundleID:)]) {
            UIImage *origFull = [generator originalImageForBundleID:bundleID];
            if (origFull && origFull.size.width >= 50) {
                sourceImage = origFull;
            }
        }
    }
    if (!sourceImage) sourceImage = image;
    if (!sourceImage) return nil;

    @synchronized (generator) {
        return [generator requestIconImageWithBackgroundForImage:sourceImage bundleID:bundleID];
    }
}

UIImage *Home26FastCachedIcon(NSString *bundleID) {
    if (!bundleID) return nil;
    id generator = GetIconGenerator();
    if (!generator) return nil;
    if ([generator respondsToSelector:@selector(fastCachedIconForBundleID:)]) {
        return [generator fastCachedIconForBundleID:bundleID];
    }
    return nil;
}

UIImage *Home26SkeletonIcon(NSString *bundleID, struct SBIconImageInfo info) {
    if (!bundleID) return nil;
    id generator = GetIconGenerator();
    if (!generator) return nil;
    if ([generator respondsToSelector:@selector(skeletonBackgroundForBundleID:size:scale:)]) {
        return [generator skeletonBackgroundForBundleID:bundleID size:info.size scale:info.scale];
    }
    return nil;
}

void Home26RequestIconAsync(UIImage *image, NSString *bundleID, void (^completion)(UIImage *styled)) {
    if (!bundleID) {
        if (completion) completion(nil);
        return;
    }
    id generator = GetIconGenerator();
    if (!generator) {
        if (completion) completion(nil);
        return;
    }
    if ([generator respondsToSelector:@selector(requestIconAsyncForImage:bundleID:completion:)]) {
        [generator requestIconAsyncForImage:image bundleID:bundleID completion:completion];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *styled = Home26RequestStyledIcon(image, bundleID);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(styled);
            });
        });
    }
}

UIImage *Home26OriginalIconForBundleID(NSString *bundleID) {
    if (!bundleID) return nil;
    id generator = GetIconGenerator();
    if (!generator) return nil;
    @synchronized (generator) {
        return [generator originalImageForBundleID:bundleID];
    }
}

void Home26SaveOriginalIcon(UIImage *image, NSString *bundleID) {
    if (!image || !bundleID) return;
    if (image.size.width < 50 || image.size.height < 50) return;
    id generator = GetIconGenerator();
    if (!generator) return;
    @synchronized (generator) {
        [generator saveOriginalImage:image forBundleID:bundleID];
    }
}

void Home26ClearGeneratorCache(void) {
    id generator = GetIconGenerator();
    if (!generator) return;
    @synchronized (generator) {
        [generator clearCache];
    }
}

SBRootFolderController *ResolveRootFolderController(UIView *view) {
    UIViewController *vc = getViewControllerForView(view);
    Class rfcCls = NSClassFromString(@"SBRootFolderController");
    if (rfcCls && [vc isKindOfClass:rfcCls]) {
        return (SBRootFolderController *)vc;
    }
    Class iconCtrlCls = NSClassFromString(@"SBIconController");
    id iconController = nil;
    if ([iconCtrlCls respondsToSelector:@selector(sharedInstance)]) {
        iconController = [iconCtrlCls performSelector:@selector(sharedInstance)];
    }
    if (iconController) {
        if ([iconController respondsToSelector:@selector(_rootFolderController)]) {
            id rfc = [iconController performSelector:@selector(_rootFolderController)];
            if (rfcCls && [rfc isKindOfClass:rfcCls]) {
                return (SBRootFolderController *)rfc;
            }
        }
        if ([iconController respondsToSelector:@selector(iconManager)]) {
            id iconManager = [iconController performSelector:@selector(iconManager)];
            if (iconManager && [iconManager respondsToSelector:@selector(rootViewController)]) {
                id rvc = [iconManager performSelector:@selector(rootViewController)];
                if (rfcCls && [rvc isKindOfClass:rfcCls]) {
                    return (SBRootFolderController *)rvc;
                }
            }
        }
    }
    return nil;
}
