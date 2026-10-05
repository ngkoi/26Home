#import "HooksCommon.h"

%ctor {
    reload26HomePrefs();

    if (!g_tweakEnabled) {
        Home26Log(@"26Home is disabled via preferences. Skipping initialization.");
        return;
    }

    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleId isEqualToString:@"com.apple.Preferences"]) {
        Home26InitPreferencesHooks();
        return;
    }

    if ([bundleId isEqualToString:@"com.apple.Spotlight"]) {
        Home26InitSpotlightHooks();
        Home26InitIconImageViewHooks();
        return;
    }

    if (![bundleId isEqualToString:@"com.apple.springboard"]) {
        return;
    }

    Home26InitSpotlightHooks();
    Home26InitIconViewHooks();
    Home26InitEditingButtonsHooks();
    Home26InitBadgesAndWidgetsHooks();
    Home26InitSpringBoardCoreHooks();
    static void (^Home26RefreshAllFolderIcons)(void) = ^{
        id iconController = nil;
        if ([%c(SBIconController) respondsToSelector:@selector(sharedInstance)]) {
            iconController = [%c(SBIconController) performSelector:@selector(sharedInstance)];
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
                    if (isFolder || [icon isKindOfClass:%c(SBFolderIcon)]) {
                        if ([folderCache respondsToSelector:@selector(rebuildImagesForFolderIcon:)]) {
                            [folderCache performSelector:@selector(rebuildImagesForFolderIcon:) withObject:icon];
                        }
                        if ([folderCache respondsToSelector:@selector(informObserversOfUpdateForFolderIcon:)]) {
                            [folderCache performSelector:@selector(informObserversOfUpdateForFolderIcon:) withObject:icon];
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
                if (rootFolder && [rootFolder respondsToSelector:@selector(folderIcons)]) {
                    NSArray *fIcons = [rootFolder performSelector:@selector(folderIcons)];
                    if ([fIcons isKindOfClass:[NSArray class]]) {
                        for (id fIcon in fIcons) {
                            rebuildFolderIconBlock(fIcon);
                        }
                    }
                }
                if (rootFolder && [rootFolder respondsToSelector:@selector(enumerateAllIconsUsingBlock:)]) {
                    void (*enumerateAll)(id, SEL, void (^)(id)) = (void (*)(id, SEL, void (^)(id)))[rootFolder methodForSelector:@selector(enumerateAllIconsUsingBlock:)];
                    enumerateAll(rootFolder, @selector(enumerateAllIconsUsingBlock:), ^(id icon) {
                        rebuildFolderIconBlock(icon);
                    });
                }

                if ([iconManager respondsToSelector:@selector(enumerateKnownIconViewsUsingBlock:)]) {
                    void (*enumerateViews)(id, SEL, void (^)(id)) = (void (*)(id, SEL, void (^)(id)))[iconManager methodForSelector:@selector(enumerateKnownIconViewsUsingBlock:)];
                    enumerateViews(iconManager, @selector(enumerateKnownIconViewsUsingBlock:), ^(UIView *iconView) {
                        if ([iconView respondsToSelector:@selector(_26home_forceUpdate)]) {
                            [iconView performSelector:@selector(_26home_forceUpdate)];
                        }
                    });
                }
            }
        }
    };

    void (^refreshKnownIcons)(void) = ^{
        Home26Log(@"--- refreshKnownIcons START ---");
        Home26RefreshAllFolderIcons();
        id iconController = nil;
        if ([%c(SBIconController) respondsToSelector:@selector(sharedInstance)]) {
            iconController = [%c(SBIconController) performSelector:@selector(sharedInstance)];
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
    };

    void (^handleContainedIconDidGenerate)(NSString *) = ^(NSString *bundleID) {
        if (!bundleID || ![bundleID isKindOfClass:[NSString class]]) return;

        id iconController = nil;
        if ([%c(SBIconController) respondsToSelector:@selector(sharedInstance)]) {
            iconController = [%c(SBIconController) performSelector:@selector(sharedInstance)];
        }
        if (!iconController) return;

        id iconManager = [iconController respondsToSelector:@selector(iconManager)] ?
                         [iconController performSelector:@selector(iconManager)] : iconController;
        if (!iconManager) return;

        id folderCache = [iconManager respondsToSelector:@selector(folderIconImageCache)] ?
                         [iconManager performSelector:@selector(folderIconImageCache)] : nil;
        id iconImageCache = [folderCache respondsToSelector:@selector(iconImageCache)] ?
                            [folderCache performSelector:@selector(iconImageCache)] : nil;
        if (!iconImageCache && [iconManager respondsToSelector:@selector(iconImageCache)]) {
            iconImageCache = [iconManager performSelector:@selector(iconImageCache)];
        }

        id model = [iconManager respondsToSelector:@selector(iconModel)] ?
                   [iconManager performSelector:@selector(iconModel)] : nil;
        id appIcon = nil;
        if (model && [model respondsToSelector:@selector(applicationIconForBundleIdentifier:)]) {
            appIcon = [model performSelector:@selector(applicationIconForBundleIdentifier:) withObject:bundleID];
        }

        if (appIcon) {
            if (iconImageCache) {
                if ([iconImageCache respondsToSelector:@selector(purgeCachedImagesForIcons:)]) {
                    [iconImageCache performSelector:@selector(purgeCachedImagesForIcons:) withObject:@[appIcon]];
                }
                if ([iconImageCache respondsToSelector:@selector(notifyObserversOfUpdateForIcon:)]) {
                    [iconImageCache performSelector:@selector(notifyObserversOfUpdateForIcon:) withObject:appIcon];
                }
            }
            if (folderCache) {
                @try {
                    id miniGrid = [folderCache valueForKey:@"_cachedMiniGridImages"];
                    if ([miniGrid respondsToSelector:@selector(removeObjectForKey:)]) {
                        [miniGrid removeObjectForKey:appIcon];
                    }
                } @catch (NSException *e) {}

                if ([folderCache respondsToSelector:@selector(iconImageCache:didUpdateImageForIcon:)]) {
                    [folderCache performSelector:@selector(iconImageCache:didUpdateImageForIcon:) withObject:iconImageCache withObject:appIcon];
                }
            }
        } else {
            if (folderCache) {
                @try {
                    id miniGrid = [folderCache valueForKey:@"_cachedMiniGridImages"];
                    if ([miniGrid respondsToSelector:@selector(removeAllObjects)]) {
                        [miniGrid removeAllObjects];
                    }
                } @catch (NSException *e) {}
            }
        }

        id rootFolder = [iconManager respondsToSelector:@selector(rootFolder)] ?
                        [iconManager performSelector:@selector(rootFolder)] : nil;
        if (!rootFolder && [iconController respondsToSelector:@selector(rootFolder)]) {
            rootFolder = [iconController performSelector:@selector(rootFolder)];
        }

        void (^rebuildFolderIconBlock)(id) = ^(id icon) {
            if (!icon) return;
            BOOL isFolder = NO;
            if ([icon respondsToSelector:@selector(isFolderIcon)]) {
                isFolder = ((BOOL (*)(id, SEL))[icon methodForSelector:@selector(isFolderIcon)])(icon, @selector(isFolderIcon));
            }
            if (isFolder || [icon isKindOfClass:%c(SBFolderIcon)]) {
                if (folderCache) {
                    if (appIcon && [folderCache respondsToSelector:@selector(folderIcon:containedIconImageDidUpdate:)]) {
                        [folderCache performSelector:@selector(folderIcon:containedIconImageDidUpdate:) withObject:icon withObject:appIcon];
                    }
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

        if (iconManager && [iconManager respondsToSelector:@selector(enumerateKnownIconViewsUsingBlock:)]) {
            void (*enumerateViews)(id, SEL, void (^)(id)) = (void (*)(id, SEL, void (^)(id)))[iconManager methodForSelector:@selector(enumerateKnownIconViewsUsingBlock:)];
            enumerateViews(iconManager, @selector(enumerateKnownIconViewsUsingBlock:), ^(UIView *iconView) {
                if ([iconView respondsToSelector:@selector(_26home_forceUpdate)]) {
                    [iconView performSelector:@selector(_26home_forceUpdate)];
                }
            });
        }
    };

    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.IconDidGenerate" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        NSString *bundleID = note.userInfo[@"bundleID"];
        if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
            handleContainedIconDidGenerate(bundleID);
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.PurgeCaches" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        Home26Log(@"=== PurgeCaches Notification Received ===");
        reload26HomePrefs();
        Home26ClearGeneratorCache();
        Home26RefreshAllFolderIcons();
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateIconStyle" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        Home26Log(@"=== UpdateIconStyle Notification Received ===");
        reload26HomePrefs();
        [[LGCustomIconGenerator2 sharedGenerator] clearCache];
        if (g_notificationIconsCache) [g_notificationIconsCache removeAllObjects];
        Home26RefreshAllFolderIcons();
        refreshKnownIcons();
    }];

    void (^updateLiveGlassAndBlur)(void) = ^{
        reload26HomePrefs();
        CGFloat effectiveQuality = g_appIconGlassQuality > 0.0 ? g_appIconGlassQuality : 0.35;
        CGFloat effectiveBlurRadius = fmaxf(g_appIconBlurRadius, 0.0);

        id iconController = nil;
        if ([%c(SBIconController) respondsToSelector:@selector(sharedInstance)]) {
            iconController = [%c(SBIconController) performSelector:@selector(sharedInstance)];
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
                    LGLiveBackdropView *glassView = [iconView viewWithTag:9001];
                    if (glassView) {
                        glassView.qualityScale = effectiveQuality;
                    }
                    LGAdjustableBlurView *blurView = [iconView viewWithTag:9002];
                    if (blurView) {
                        blurView.qualityScale = effectiveQuality;
                        blurView.blurRadius = effectiveBlurRadius;
                        if (effectiveBlurRadius <= 0.0) {
                            blurView.hidden = YES;
                            blurView.layer.filters = @[];
                        } else {
                            blurView.hidden = NO;
                            [blurView applyFilters];
                        }
                    }
                });
            }
        }
    };

    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateGlassQuality" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        updateLiveGlassAndBlur();
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateBlurRadius" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        updateLiveGlassAndBlur();
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateLargeIcons" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        Home26Log(@"=== UpdateLargeIcons Notification Received ===");
        reload26HomePrefs();
    }];

    int clearToken;
    notify_register_dispatch("ngkhoi.26home.clearCache", &clearToken, dispatch_get_main_queue(), ^(int token) {
        Home26Log(@"=== Darwin clearCache Notification Received ===");
        reload26HomePrefs();
        [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];
        if (g_notificationIconsCache) [g_notificationIconsCache removeAllObjects];
        if (g_appIconImageCache) [g_appIconImageCache removeAllObjects];

        id iconController = nil;
        if ([%c(SBIconController) respondsToSelector:@selector(sharedInstance)]) {
            iconController = [%c(SBIconController) performSelector:@selector(sharedInstance)];
        }
        if (iconController) {
            id iconManager = nil;
            if ([iconController respondsToSelector:@selector(iconManager)]) {
                iconManager = [iconController performSelector:@selector(iconManager)];
            } else {
                iconManager = iconController;
            }
            if ([iconManager respondsToSelector:@selector(iconImageCache)]) {
                id iconCache = [iconManager performSelector:@selector(iconImageCache)];
                if ([iconCache respondsToSelector:@selector(purgeAllCachedImages)]) {
                    [iconCache performSelector:@selector(purgeAllCachedImages)];
                }
            }
        }

        refreshKnownIcons();
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.IconReady" object:nil];
    });

    int styleToken;
    notify_register_dispatch("ngkhoi.26home.UpdateIconStyle", &styleToken, dispatch_get_main_queue(), ^(int token) {
        Home26Log(@"=== Darwin UpdateIconStyle Notification Received ===");
        reload26HomePrefs();
        [[LGCustomIconGenerator2 sharedGenerator] clearCache];
        if (g_notificationIconsCache) [g_notificationIconsCache removeAllObjects];
        Home26RefreshAllFolderIcons();
        refreshKnownIcons();
    });

    int largeToken;
    notify_register_dispatch("ngkhoi.26home.UpdateLargeIcons", &largeToken, dispatch_get_main_queue(), ^(int token) {
        Home26Log(@"=== Darwin UpdateLargeIcons Notification Received ===");
        reload26HomePrefs();
        refreshKnownIcons();
    });

    int qualityToken;
    notify_register_dispatch("ngkhoi.26home.UpdateGlassQuality", &qualityToken, dispatch_get_main_queue(), ^(int token) {
        updateLiveGlassAndBlur();
    });

    int blurToken;
    notify_register_dispatch("ngkhoi.26home.UpdateBlurRadius", &blurToken, dispatch_get_main_queue(), ^(int token) {
        updateLiveGlassAndBlur();
    });

    int darkToken;
    notify_register_dispatch("AppleInterfaceThemeChangedNotification", &darkToken, dispatch_get_main_queue(), ^(int token) {
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
            Home26Log(@"[Appearance] AppleInterfaceThemeChangedNotification -> Triggering Auto refresh");
            Home26TriggerGlobalRefresh();
        }
    });

    void (^exportWallpaperBlock)(BOOL immediate) = ^(BOOL immediate) {
        void (^performExport)(void) = ^{
            @try {
                id wc = [NSClassFromString(@"SBWallpaperController") sharedInstance];
                if (!wc) return;

                UIImage *img = nil;
                if ([wc respondsToSelector:@selector(wallpaperConfigurationManager)]) {
                    id wcm = [wc performSelector:@selector(wallpaperConfigurationManager)];
                    if (wcm && [wcm respondsToSelector:@selector(wallpaperImageForVariant:wallpaperMode:)]) {
                        typedef UIImage *(*WCMImgFunc)(id, SEL, NSInteger, NSInteger);
                        WCMImgFunc getImg = (WCMImgFunc)[wcm methodForSelector:@selector(wallpaperImageForVariant:wallpaperMode:)];

                        img = getImg(wcm, @selector(wallpaperImageForVariant:wallpaperMode:), 1, 0);
                        if (!img) {
                            img = getImg(wcm, @selector(wallpaperImageForVariant:wallpaperMode:), 0, 0);
                        }
                    }
                }

                if (img) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        NSData *data = UIImageJPEGRepresentation(img, 0.90);
                        NSString *dir = @"/var/mobile/Library/SpringBoard";
                        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
                        NSString *wpPath = [dir stringByAppendingPathComponent:@"26HomeCurrentWallpaper.jpg"];
                        [data writeToFile:wpPath atomically:YES];
                        notify_post("ngkhoi.26home.WallpaperExported");
                    });
                }
            } @catch (NSException *e) {
                Home26Log(@"[WallpaperExport] Exception: %@", e);
            }
        };

        if (immediate) {
            performExport();
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), performExport);
        }
    };

    int wpToken;
    notify_register_dispatch("ngkhoi.26home.ExportWallpaper", &wpToken, dispatch_get_main_queue(), ^(int token) {
        exportWallpaperBlock(YES);
    });
}
