#import "HooksCommon.h"

%hook SBFloatyFolderController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_isFolderOpen = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.FolderStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    g_isFolderOpen = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.FolderStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

%end

%hook SBFluidSwitcherViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_isSwitcherOpen = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    g_isSwitcherOpen = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

%end

%hook SBHomeScreenViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_isHomeScreenVisible = YES;
    g_isAppOpening = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    g_isHomeScreenVisible = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

%end

%hook CSCoverSheetViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_isCoverSheetVisible = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    g_isCoverSheetVisible = NO;
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    Home26GenerateDiagnosticsReport();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL isDimmedInit = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] boolForKey:@"ngkhoi.26home.dimWallpaper"];
        if (isDimmedInit) {
            UpdateWallpaperDimState(YES, NO);
        }

        [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateWallpaperDimming" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            BOOL dimmed = [note.userInfo[@"dimmed"] boolValue];
            UpdateWallpaperDimState(dimmed, YES);
        }];

        [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateLiveTintColor" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            NSString *hex = g_tintColor;
            if (!hex) return;
            unsigned rgbValue = 0;
            NSScanner *scanner = [NSScanner scannerWithString:hex];
            [scanner setScanLocation:1];
            [scanner scanHexInt:&rgbValue];
            UIColor *tintColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:0.6];

            for (UIWindow *window in [[UIApplication sharedApplication] valueForKey:@"windows"]) {
                updateTintViews(window, tintColor);
            }
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateLargeIcons" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
                        g_isAnimatingScale = YES;
            for (UIWindow *window in [[UIApplication sharedApplication] valueForKey:@"windows"]) {
                ForceLayoutAllIconViews(window);
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                g_isAnimatingScale = NO;
            });
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.EyedropperStart" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            g_eyedropperActive = YES;
            for (UIWindow *window in [[UIApplication sharedApplication] valueForKey:@"windows"]) {
                ForceLayoutAllIconViews(window);
            }
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.EyedropperEnd" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            g_eyedropperActive = NO;
            for (UIWindow *window in [[UIApplication sharedApplication] valueForKey:@"windows"]) {
                ForceLayoutAllIconViews(window);
            }
        }];
    });
}

%end

%hook SBHIconManager

- (void)setEditing:(BOOL)editing withFeedbackBehavior:(id)behavior {
    %orig;
    g_isEditingMode = editing;
    if (!editing) {
        [[Home26LiquidMenu sharedMenu] dismissImmediately];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)setEditing:(BOOL)editing {
    %orig;
    g_isEditingMode = editing;
    if (!editing) {
        [[Home26LiquidMenu sharedMenu] dismissImmediately];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)folderControllerWillOpen:(id)folderController {
    %orig;
    g_isFolderOpen = YES;
    [[Home26LiquidMenu sharedMenu] dismissImmediately];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.FolderStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
    if (folderController && [folderController respondsToSelector:@selector(view)]) {
        UIView *folderView = [folderController performSelector:@selector(view)];
        if (folderView) {
            Home26ReloadAllVisibleTables(folderView);
        }
    }
}

- (void)folderControllerDidClose:(id)folderController {
    %orig;
    g_isFolderOpen = NO;
    [[Home26LiquidMenu sharedMenu] dismissImmediately];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.FolderStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();

    if (folderController && [folderController respondsToSelector:@selector(folderIcon)]) {
        id fIcon = [folderController performSelector:@selector(folderIcon)];
        if (fIcon) {
            id ic = [%c(SBIconController) respondsToSelector:@selector(sharedInstance)] ? [%c(SBIconController) sharedInstance] : nil;
            id im = [ic respondsToSelector:@selector(iconManager)] ? [ic performSelector:@selector(iconManager)] : ic;
            id fCache = [im respondsToSelector:@selector(folderIconImageCache)] ? [im performSelector:@selector(folderIconImageCache)] : nil;
            if (fCache && [fCache respondsToSelector:@selector(rebuildImagesForFolderIcon:)]) {
                [fCache rebuildImagesForFolderIcon:fIcon];
                if ([fCache respondsToSelector:@selector(informObserversOfUpdateForFolderIcon:)]) {
                    [fCache informObserversOfUpdateForFolderIcon:fIcon];
                }
            }
            if ([fIcon respondsToSelector:@selector(iconImageDidUpdate:)]) {
                [fIcon iconImageDidUpdate:fIcon];
            }
        }
    }
}

- (void)iconTapped:(id)iconView {
    %orig;

    g_isAppOpening = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_isAppOpening = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
        notifyAllIconsVisibilityChanged();
    });
}

%end

static void EnsureNotificationIconCache(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_notificationIconsCache = [[NSCache alloc] init];
        g_notificationIconsCache.countLimit = 120;
    });
}

static UIImage *Home26GenerateNotificationIcon(UIImage *image, NSString *bundleID) {
    if (!image || !bundleID) return nil;

    __block UIImage *styled = nil;
    void (^generate)(void) = ^{
        @autoreleasepool {
            styled = Home26RequestStyledIcon(image, bundleID);
        }
    };

    if ([NSThread isMainThread]) {
        generate();
    } else {
        dispatch_sync(dispatch_get_main_queue(), generate);
    }
    return styled;
}

%hook NCNotificationRequestContentProvider

- (NSArray *)icons {
    NSArray *orig = %orig;
    NSString *style = g_iconStyle ?: @"Default";
    if ([style isEqualToString:@"Default"]) {
        return orig;
    }

    NCNotificationRequest *request = nil;
    if ([self respondsToSelector:@selector(notificationRequest)]) {
        request = [self notificationRequest];
    }

    NSString *bundleID = nil;
    if (request && [request respondsToSelector:@selector(sectionIdentifier)]) {
        bundleID = [request sectionIdentifier];
    }

    if (!bundleID || bundleID.length == 0 || isAppExcluded(bundleID)) {
        return orig;
    }

    if (!orig || orig.count == 0) {
        return orig;
    }

    id firstObj = orig.firstObject;
    if (![firstObj isKindOfClass:[UIImage class]]) {
        return orig;
    }

    UIImage *origImage = (UIImage *)firstObj;
    if (origImage.size.width <= 0 || origImage.size.height <= 0) {
        return orig;
    }

    EnsureNotificationIconCache();

    CGFloat targetScale = origImage.scale > 0 ? origImage.scale : [UIScreen mainScreen].scale;
    NSString *notifKey = [NSString stringWithFormat:@"%@_%@_%@_%.0fx%.0f_%.0f", bundleID, g_selectedIconPack, style, origImage.size.width, origImage.size.height, targetScale];
    UIImage *cachedScaled = [g_notificationIconsCache objectForKey:notifKey];
    if (cachedScaled) {
        NSMutableArray *newIcons = [orig mutableCopy];
        newIcons[0] = cachedScaled;
        return [newIcons copy];
    }

    UIImage *styled = Home26GenerateNotificationIcon(origImage, bundleID);
    if (styled) {
        UIImage *finalIcon = styled;
        if (!CGSizeEqualToSize(styled.size, origImage.size)) {
            UIGraphicsBeginImageContextWithOptions(origImage.size, NO, targetScale);
            [styled drawInRect:CGRectMake(0, 0, origImage.size.width, origImage.size.height)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resized) finalIcon = resized;
        }
        [g_notificationIconsCache setObject:finalIcon forKey:notifKey];
        NSMutableArray *newIcons = [orig mutableCopy];
        newIcons[0] = finalIcon;
        return [newIcons copy];
    }

    return orig;
}

%end

%hook SBIconController
- (void)viewDidLoad {
    %orig;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            NSString *style = g_iconStyle ?: @"Default";
            NSString *themeMode = g_themeMode ?: @"Auto";
            NSString *darkIconMode = g_darkIconMode ?: @"Always";

            BOOL isAuto = NO;
            if ([style isEqualToString:@"Dark"] && [darkIconMode isEqualToString:@"Auto"]) {
                isAuto = YES;
            } else if (![style isEqualToString:@"Default"] && [themeMode isEqualToString:@"Auto"]) {
                isAuto = YES;
            }

            if (isAuto) {
                Home26Log(@"[Appearance] SBIconController traitCollectionDidChange -> Triggering Auto refresh");
                Home26TriggerGlobalRefresh();
            }
        }
    }
}

%end

void Home26InitSpringBoardCoreHooks(void) {
    %init();
}
