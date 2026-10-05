#import "HooksCommon.h"

static void applyClockHandsInversion(CALayer *layer, BOOL apply, CGSize parentBoundsSize, CALayer *secondsLayer) {
    if (!layer) return;
    if (secondsLayer && layer == secondsLayer) {
        if (layer.filters.count > 0) layer.filters = nil;
        return;
    }

    BOOL isFullBackgroundPlate = (layer.contents != nil &&
                                 layer.bounds.size.width >= parentBoundsSize.width * 0.85 &&
                                 layer.bounds.size.height >= parentBoundsSize.height * 0.85);
    if (isFullBackgroundPlate) return;

    if (layer.sublayers.count == 0) {
        if (apply) {
            BOOL hasFilter = NO;
            for (id f in layer.filters) {
                if ([[f description] containsString:@"colorInvert"]) {
                    hasFilter = YES;
                    break;
                }
            }
            if (!hasFilter) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id invertFilter = [NSClassFromString(@"CAFilter") performSelector:NSSelectorFromString(@"filterWithType:") withObject:@"colorInvert"];
#pragma clang diagnostic pop
                if (invertFilter) layer.filters = @[invertFilter];
            }
        } else {
            if (layer.filters.count > 0) {
                layer.filters = nil;
            }
        }
    } else {
        for (CALayer *sub in layer.sublayers) {
            applyClockHandsInversion(sub, apply, parentBoundsSize, secondsLayer);
        }
    }
}

static void updateClockHandsInversionForView(UIView *view) {
    if (!view) return;
    id icon = nil;
    if ([view respondsToSelector:@selector(icon)]) {
        icon = [view performSelector:@selector(icon)];
    }
    NSString *bundleID = nil;
    if (icon && [icon respondsToSelector:@selector(applicationBundleID)]) {
        bundleID = [icon performSelector:@selector(applicationBundleID)];
    }
    BOOL isClock = [bundleID isEqualToString:@"com.apple.mobiletimer"] || [view isKindOfClass:NSClassFromString(@"SBClockIconImageView")];
    if (isClock) {
        BOOL isDarkTheme = NO;
        if ([g_themeMode isEqualToString:@"Dark"]) isDarkTheme = YES;
        else if ([g_themeMode isEqualToString:@"Light"]) isDarkTheme = NO;
        else isDarkTheme = ([UIScreen mainScreen].traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);

        BOOL isDarkIcon = [g_iconStyle isEqualToString:@"Dark"];
        if (isDarkIcon && [g_darkIconMode isEqualToString:@"Auto"]) {
            isDarkIcon = isDarkTheme;
        }

        BOOL needsWhiteHands = NO;
        if (isDarkIcon || [g_iconStyle isEqualToString:@"Tinted"]) {
            needsWhiteHands = YES;
        } else if ([g_iconStyle isEqualToString:@"Clear"]) {
            needsWhiteHands = YES;
        } else if (isDarkTheme) {
            needsWhiteHands = YES;
        }

        UIView *secondsView = nil;
        @try {
            secondsView = [view valueForKey:@"_secondsView"] ?: [view valueForKey:@"_secondHandView"] ?: [view valueForKey:@"_seconds"];
        } @catch (id e) {}

        CALayer *secondsLayer = secondsView ? secondsView.layer : nil;
        applyClockHandsInversion(view.layer, needsWhiteHands, view.bounds.size, secondsLayer);
    }
}

static inline CGFloat GetIconCornerRadius(UIView *iconImageView, UIView *iconView) {
    CGFloat width = 0.0;
    if (iconImageView && iconImageView.bounds.size.width > 0.0) {
        width = iconImageView.bounds.size.width;
    } else if (iconView && [iconView respondsToSelector:@selector(iconImageInfo)]) {
        struct SBIconImageInfo info = [(SBIconView *)iconView iconImageInfo];
        if (info.size.width > 0.0) {
            width = info.size.width;
        }
    }
    if (width <= 0.0 && iconView && iconView.bounds.size.width > 0.0) {
        width = iconView.bounds.size.width;
    }
    if (width <= 0.0) width = 60.0;
    return width * 0.256;
}

%hook SBIconView

- (void)layoutSubviews {
    %orig;
    [self performSelector:@selector(_26home_updateCustomScale)];

    if (g_eyedropperActive) {
        self.alpha = 0.0;
        return;
    } else if (self.alpha < 1.0) {
        self.alpha = 1.0;
    }

    if (g_largeIconsEnabled) {
        UIView *labelView = [self valueForKey:@"_labelView"];
        if (labelView) {
            labelView.hidden = YES;
            labelView.alpha = 0.0;
        }
        if ([self respondsToSelector:@selector(labelView)]) {
            UIView *lv = [self labelView];
            if (lv) {
                lv.hidden = YES;
                lv.alpha = 0.0;
            }
        }
        for (UIView *sub in self.subviews) {
            NSString *cls = NSStringFromClass([sub class]);
            if ([cls containsString:@"Label"] || [cls containsString:@"Legibility"]) {
                sub.hidden = YES;
                sub.alpha = 0.0;
            }
        }
    } else {
        UIView *labelView = [self valueForKey:@"_labelView"];
        if (labelView) {
            labelView.hidden = NO;
            labelView.alpha = 1.0;
        }
    }

    BOOL isFolder = NO;
    if ([self respondsToSelector:@selector(isFolderIcon)]) {
        isFolder = ((BOOL (*)(id, SEL))[self methodForSelector:@selector(isFolderIcon)])(self, @selector(isFolderIcon));
    }
    if (isFolder) {
        [[self viewWithTag:9001] removeFromSuperview];
        [[self viewWithTag:9002] removeFromSuperview];
        [[self viewWithTag:9003] removeFromSuperview];
        return;
    }

    UIView *iconImageView = [self valueForKey:@"_iconImageView"];
    if (iconImageView) {
        CGFloat standardCornerRadius = GetIconCornerRadius(iconImageView, self);
        iconImageView.layer.cornerRadius = standardCornerRadius;
        iconImageView.layer.cornerCurve = kCACornerCurveCircular;
        iconImageView.layer.masksToBounds = NO;
        updateClockHandsInversionForView(iconImageView);
    }

    NSString *style = g_iconStyle;
    if ([style isEqualToString:@"Dark"]) {
        NSString *darkIconMode = g_darkIconMode;
        if ([darkIconMode isEqualToString:@"Auto"]) {
            if (self.traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark) {
                style = @"Default";
            }
        }
    }

    NSString *themeMode = g_themeMode;
    BOOL isDarkTheme = NO;
    if ([themeMode isEqualToString:@"Dark"]) {
        isDarkTheme = YES;
    } else if ([themeMode isEqualToString:@"Light"]) {
        isDarkTheme = NO;
    } else {
        isDarkTheme = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }

    NSString *currentBundleID = nil;
    if ([self respondsToSelector:@selector(icon)]) {
        id icon = [self performSelector:@selector(icon)];
        if (icon && [icon respondsToSelector:@selector(applicationBundleID)]) {
            currentBundleID = [icon performSelector:@selector(applicationBundleID)];
        }
    }
    BOOL isExcludedApp = isAppExcludedFromEffects(currentBundleID);

    BOOL isClearOrTintedLight = ([style isEqualToString:@"Clear"] || ([style isEqualToString:@"Tinted"] && !isDarkTheme)) && iconImageView && !isFolder && !isExcludedApp;

    BOOL shouldApplyGlass = !g_disableLiquidGlassIcons && isClearOrTintedLight;
    BOOL shouldApplyBlur = (g_appIconBlurRadius > 0.0) && (shouldApplyGlass || (!g_disableLiquidGlassIcons ? NO : g_keepAppIconBlur)) && isClearOrTintedLight;

    if (shouldApplyBlur || shouldApplyGlass) {
        LGLiveBackdropView *glassView = [self viewWithTag:9001];
        LGAdjustableBlurView *blurView = [self viewWithTag:9002];
        UIView *tintView = [self viewWithTag:9003];

        UIView *container = iconImageView.superview ?: self;
        NSUInteger iconIndex = [container.subviews indexOfObject:iconImageView];
        if (iconIndex == NSNotFound) iconIndex = 0;

        CGFloat effectiveBlurRadius = fmaxf(g_appIconBlurRadius, 0.0);
        CGFloat effectiveQuality = g_appIconGlassQuality > 0.0 ? g_appIconGlassQuality : 0.35;

        CGFloat standardCornerRadius = GetIconCornerRadius(iconImageView, self);
        iconImageView.layer.cornerRadius = standardCornerRadius;
        iconImageView.layer.cornerCurve = kCACornerCurveCircular;
        iconImageView.layer.masksToBounds = NO;

        if (shouldApplyBlur) {
            if (!blurView) {
                blurView = [[LGAdjustableBlurView alloc] initWithFrame:iconImageView.frame blurRadius:effectiveBlurRadius];
                blurView.qualityScale = effectiveQuality;
                blurView.tag = 9002;
                [blurView.layer setValue:@"dylv.liquidglass.blur.shared" forKey:@"groupName"];
                blurView.layer.masksToBounds = YES;
                blurView.layer.cornerCurve = kCACornerCurveCircular;
                [container insertSubview:blurView belowSubview:iconImageView];
            } else {
                blurView.blurRadius = effectiveBlurRadius;
                blurView.qualityScale = effectiveQuality;
            }
            blurView.hidden = NO;
        } else {
            [[self viewWithTag:9002] removeFromSuperview];
            blurView = nil;
        }

        if (shouldApplyGlass) {
            if (!glassView) {
                glassView = [[LGLiveBackdropView alloc] initWithFrame:iconImageView.frame];
                glassView.qualityScale = effectiveQuality;
                glassView.capturesAppIcon = YES;
                glassView.tag = 9001;
                glassView.layer.masksToBounds = YES;
                glassView.layer.cornerCurve = kCACornerCurveCircular;
                if (blurView) {
                    [container insertSubview:glassView aboveSubview:blurView];
                } else {
                    [container insertSubview:glassView belowSubview:iconImageView];
                }
                [glassView forceReapplyForRegistrationRace];
            } else {
                glassView.qualityScale = effectiveQuality;
            }
            glassView.hidden = NO;
        } else {
            [[self viewWithTag:9001] removeFromSuperview];
            glassView = nil;
        }

        if (shouldApplyGlass || shouldApplyBlur) {
            if (!tintView) {
                tintView = [[UIView alloc] initWithFrame:iconImageView.frame];
                tintView.tag = 9003;
                tintView.layer.masksToBounds = YES;
                tintView.layer.cornerCurve = kCACornerCurveCircular;
                UIView *aboveView = glassView ?: blurView;
                if (aboveView) {
                    [container insertSubview:tintView aboveSubview:aboveView];
                } else {
                    [container insertSubview:tintView belowSubview:iconImageView];
                }
            } else if (tintView.superview == container) {
                [container bringSubviewToFront:iconImageView];
                [container insertSubview:tintView belowSubview:iconImageView];
            }
            tintView.hidden = NO;
        } else {
            [[self viewWithTag:9003] removeFromSuperview];
            tintView = nil;
        }

        if (glassView) {
            glassView.bounds = iconImageView.bounds;
            glassView.center = iconImageView.center;
            glassView.transform = iconImageView.transform;
            glassView.layer.cornerRadius = standardCornerRadius;
            glassView.layer.cornerCurve = kCACornerCurveCircular;
            glassView.layer.masksToBounds = YES;
            glassView.backgroundColor = [UIColor clearColor];
        }

        if (blurView) {
            blurView.bounds = iconImageView.bounds;
            blurView.center = iconImageView.center;
            blurView.transform = iconImageView.transform;
            blurView.layer.cornerRadius = standardCornerRadius;
            blurView.layer.cornerCurve = kCACornerCurveCircular;
            blurView.layer.masksToBounds = YES;
            blurView.backgroundColor = [UIColor clearColor];
        }

        if (tintView) {
            tintView.bounds = iconImageView.bounds;
            tintView.center = iconImageView.center;
            tintView.transform = iconImageView.transform;
            tintView.layer.cornerRadius = standardCornerRadius;
            tintView.layer.cornerCurve = kCACornerCurveCircular;
            tintView.layer.masksToBounds = YES;

            if (isDarkTheme) {
                if ([style isEqualToString:@"Tinted"]) {
                    NSString *hex = g_tintColor;
                    if (hex) {
                        unsigned rgbValue = 0;
                        NSScanner *scanner = [NSScanner scannerWithString:hex];
                        if ([hex hasPrefix:@"#"]) {
                            [scanner setScanLocation:1];
                        }
                        [scanner scanHexInt:&rgbValue];
                        tintView.backgroundColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:0.35];
                    } else {
                        tintView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
                    }
                } else {
                    tintView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
                }
            } else {
                if ([style isEqualToString:@"Tinted"]) {
                    NSString *hex = g_tintColor;
                    if (hex) {
                        unsigned rgbValue = 0;
                        NSScanner *scanner = [NSScanner scannerWithString:hex];
                        if ([hex hasPrefix:@"#"]) {
                            [scanner setScanLocation:1];
                        }
                        [scanner scanHexInt:&rgbValue];
                        tintView.backgroundColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:0.22];
                    } else {
                        tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
                    }
                } else {
                    tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
                }
            }
        }

        [self _26home_updateGlassVisibility];
    } else {
        [[self viewWithTag:9001] removeFromSuperview];
        [[self viewWithTag:9002] removeFromSuperview];
        [[self viewWithTag:9003] removeFromSuperview];
        UIView *container = iconImageView.superview ?: self;
        for (UIView *subview in container.subviews) {
            if ([subview isKindOfClass:%c(LGLiveBackdropView)]) {
                subview.hidden = YES;
            }
        }
    }
}

- (void)prepareForReuse {
    %orig;
    [[self viewWithTag:9001] removeFromSuperview];
    [[self viewWithTag:9002] removeFromSuperview];
    [[self viewWithTag:9003] removeFromSuperview];
}

- (void)setIcon:(id)icon {
    id oldIcon = nil;
    if ([self respondsToSelector:@selector(icon)]) {
        oldIcon = [self performSelector:@selector(icon)];
    }
    %orig;
    if (icon != oldIcon) {
        [[self viewWithTag:9001] removeFromSuperview];
        [[self viewWithTag:9002] removeFromSuperview];
        [[self viewWithTag:9003] removeFromSuperview];
    }
    [self performSelector:@selector(_26home_updateCustomScale)];
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    if (!hidden) {
        [self performSelector:@selector(_26home_updateCustomScale)];
        UIView *glassView = [self viewWithTag:9001];
        if (glassView && [glassView respondsToSelector:@selector(forceReapplyForRegistrationRace)]) {
            [glassView performSelector:@selector(forceReapplyForRegistrationRace)];
        }
        [self _26home_updateGlassVisibility];
    }
}

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    if (alpha > 0.0) {
        [self performSelector:@selector(_26home_updateCustomScale)];
    }
}

- (void)_updateIconImageViewAnimated:(BOOL)animated {
    %orig;
    [self performSelector:@selector(_26home_updateCustomScale)];
}

- (void)setIconContentScale:(CGFloat)scale {
    %orig;
    [self performSelector:@selector(_26home_updateCustomScale)];
}

- (void)didMoveToSuperview {
    %orig;
    [self performSelector:@selector(_26home_updateCustomScale)];
}

- (CGFloat)iconContentScale {
    CGFloat orig = %orig;

    if (g_largeIconsEnabled) {
        if ([self respondsToSelector:@selector(location)]) {
            NSString *location = [self performSelector:@selector(location)];
            if (location && [location isKindOfClass:[NSString class]] && ([location containsString:@"Library"] || [location containsString:@"AppLibrary"])) {
                return orig;
            }
        }

        if ([self respondsToSelector:@selector(isFolderIcon)]) {
            BOOL isFolder = ((BOOL (*)(id, SEL))[self methodForSelector:@selector(isFolderIcon)])(self, @selector(isFolderIcon));
            if (isFolder) {
                return 1.20;
            }
        }
    }

    return orig;
}

- (void)setIsGrabbed:(BOOL)grabbed {
    %orig;
    [self performSelector:@selector(_26home_updateCustomScale)];
    [self _26home_updateGlassVisibility];
}

- (void)setDragging:(BOOL)dragging {
    %orig;
    [self performSelector:@selector(_26home_updateCustomScale)];
    [self _26home_updateGlassVisibility];
}

- (void)cleanUpAfterDrag {
    %orig;
    [self performSelector:@selector(_26home_updateCustomScale)];
    [self _26home_updateGlassVisibility];
}

- (void)dragInteraction:(id)interaction item:(id)item willAnimateDropWithAnimator:(id)animator {
    %orig;
    if (g_largeIconsEnabled && [self respondsToSelector:@selector(_26home_updateCustomScale)]) {
        [self performSelector:@selector(_26home_updateCustomScale)];
        if (animator && [animator respondsToSelector:@selector(addAnimations:)]) {
            [animator addAnimations:^{
                [self performSelector:@selector(_26home_updateCustomScale)];
            }];
        }
        if (animator && [animator respondsToSelector:@selector(addCompletion:)]) {
            [animator addCompletion:^(NSInteger finalPosition) {
                [self performSelector:@selector(_26home_updateCustomScale)];
                [self _26home_updateGlassVisibility];
            }];
        }
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    %orig;
    [self _26home_updateGlassVisibility];
}

- (void)setHighlighted:(BOOL)highlighted {
    %orig;
    [self _26home_updateGlassVisibility];
}

- (void)setTouchDown:(BOOL)touchDown {
    %orig;
    [self _26home_updateGlassVisibility];
}

- (void)setCrossfadeFraction:(CGFloat)fraction {
    %orig;
    if (fraction > 0.0) {
        [self viewWithTag:9001].hidden = YES;
        [self viewWithTag:9002].hidden = YES;
        [self viewWithTag:9003].hidden = YES;
    } else {
        [self _26home_updateGlassVisibility];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    %orig;
    [self _26home_updateGlassVisibility];
}

- (void)setEditing:(BOOL)editing {
    %orig;
    [self _26home_updateGlassVisibility];
}

- (void)setMorphingFraction:(CGFloat)fraction {
    %orig;
    if (fraction > 0.0) {
        [self viewWithTag:9001].hidden = YES;
        [self viewWithTag:9002].hidden = YES;
        [self viewWithTag:9003].hidden = YES;
    } else {
        [self _26home_updateGlassVisibility];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (instancetype)initWithConfigurationOptions:(NSUInteger)options listLayoutProvider:(id)provider {
    id orig = %orig;
    if (orig) {
        [[NSNotificationCenter defaultCenter] addObserver:orig selector:@selector(_26home_iconReady:) name:@"ngkhoi.26home.IconReady" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:orig selector:@selector(_26home_updateGlassVisibility) name:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:orig selector:@selector(_26home_updateGlassVisibility) name:@"ngkhoi.26home.FolderStateChanged" object:nil];
    }
    return orig;
}

%new
- (void)_26home_updateGlassVisibility {
    UIView *glassView = [self viewWithTag:9001];
    UIView *blurView = [self viewWithTag:9002];
    UIView *tintView = [self viewWithTag:9003];
    UIView *iconImageView = [self valueForKey:@"_iconImageView"];
    UIView *container = iconImageView.superview ?: self;
    LGLiveBackdropView *liquidAssGlass = nil;
    for (UIView *sub in container.subviews) {
        if ([sub isKindOfClass:%c(LGLiveBackdropView)] && sub.tag != 9001) {
            liquidAssGlass = (LGLiveBackdropView *)sub;
            break;
        }
    }
    if (!glassView && !blurView && !tintView && !liquidAssGlass) {
        [self setNeedsLayout];
        return;
    }

    NSString *currentBundleID = nil;
    if ([self respondsToSelector:@selector(icon)]) {
        id icon = [self performSelector:@selector(icon)];
        if (icon && [icon respondsToSelector:@selector(applicationBundleID)]) {
            currentBundleID = [icon performSelector:@selector(applicationBundleID)];
        }
    }
    if (isAppExcludedFromEffects(currentBundleID)) {
        if (glassView) {
            glassView.hidden = YES;
            [glassView.layer setValue:@NO forKey:@"enabled"];
        }
        if (blurView) {
            blurView.hidden = YES;
            [blurView.layer setValue:@NO forKey:@"enabled"];
        }
        if (liquidAssGlass) {
            liquidAssGlass.hidden = YES;
            [liquidAssGlass.layer setValue:@NO forKey:@"enabled"];
        }
        if (tintView) tintView.hidden = YES;
        return;
    }

    if (g_hideGlassWhenUnfocused && (!g_isHomeScreenVisible || g_isCoverSheetVisible || g_isSwitcherOpen || g_isAppOpening)) {
        if (glassView) {
            glassView.hidden = YES;
            [glassView.layer setValue:@NO forKey:@"enabled"];
        }
        if (blurView) {
            blurView.hidden = YES;
            [blurView.layer setValue:@NO forKey:@"enabled"];
        }
        if (liquidAssGlass) {
            liquidAssGlass.hidden = YES;
            [liquidAssGlass.layer setValue:@NO forKey:@"enabled"];
        }
        if (tintView) tintView.hidden = YES;
        return;
    }

    BOOL isHighlighted = NO;
    if ([self respondsToSelector:@selector(isHighlighted)]) {
        isHighlighted = ((BOOL (*)(id, SEL))[self methodForSelector:@selector(isHighlighted)])(self, @selector(isHighlighted));
    }
    BOOL isTouchDown = NO;
    if ([self respondsToSelector:@selector(isTouchDown)]) {
        isTouchDown = ((BOOL (*)(id, SEL))[self methodForSelector:@selector(isTouchDown)])(self, @selector(isTouchDown));
    }
    if (isHighlighted || isTouchDown) {
        if (glassView) {
            glassView.hidden = YES;
            [glassView.layer setValue:@NO forKey:@"enabled"];
        }
        if (blurView) {
            blurView.hidden = YES;
            [blurView.layer setValue:@NO forKey:@"enabled"];
        }
        if (liquidAssGlass) {
            liquidAssGlass.hidden = YES;
            [liquidAssGlass.layer setValue:@NO forKey:@"enabled"];
        }
        if (tintView) tintView.hidden = YES;
        return;
    }

    if (g_hideGlassWhenUnfocused && g_isFolderOpen) {
        BOOL isInsideOpenFolder = NO;
        if ([self respondsToSelector:@selector(location)]) {
            NSString *loc = [self performSelector:@selector(location)];
            if (loc && [loc isKindOfClass:[NSString class]] && ([loc isEqualToString:@"SBIconLocationFolder"] || [loc containsString:@"Folder"])) {
                isInsideOpenFolder = YES;
            }
        }
        if (!isInsideOpenFolder) {
            UIView *v = self.superview;
            while (v) {
                if ([v isKindOfClass:%c(SBFloatyFolderView)]) {
                    isInsideOpenFolder = YES;
                    break;
                }
                v = v.superview;
            }
        }

        if (!isInsideOpenFolder) {
            if (glassView) {
                glassView.hidden = YES;
                [glassView.layer setValue:@NO forKey:@"enabled"];
            }
            if (blurView) {
                blurView.hidden = YES;
                [blurView.layer setValue:@NO forKey:@"enabled"];
            }
            if (liquidAssGlass) {
                liquidAssGlass.hidden = YES;
                [liquidAssGlass.layer setValue:@NO forKey:@"enabled"];
            }
            if (tintView) tintView.hidden = YES;
            return;
        }
    }

    if (glassView) {
        glassView.hidden = NO;
        [glassView.layer setValue:@YES forKey:@"enabled"];
    }
    if (blurView) {
        blurView.hidden = NO;
        [blurView.layer setValue:@YES forKey:@"enabled"];
    }
    if (liquidAssGlass) {
        liquidAssGlass.hidden = NO;
        [liquidAssGlass.layer setValue:@YES forKey:@"enabled"];
    }
    if (tintView) tintView.hidden = NO;
}

%new
- (void)_26home_iconReady:(NSNotification *)note {
    NSString *bundleID = note.userInfo[@"bundleID"];
    if (bundleID && [self respondsToSelector:@selector(icon)]) {
        id icon = [self performSelector:@selector(icon)];
        if ([icon respondsToSelector:@selector(applicationBundleID)]) {
            NSString *myBundleID = [icon performSelector:@selector(applicationBundleID)];
            if ([myBundleID isEqualToString:bundleID]) {
                UIView *iconImageView = [self valueForKey:@"_iconImageView"];
                if (iconImageView && [iconImageView respondsToSelector:@selector(updateImageAnimated:)]) {
                    void (*method)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconImageView methodForSelector:@selector(updateImageAnimated:)];
                    method(iconImageView, @selector(updateImageAnimated:), YES);
                } else if ([self respondsToSelector:@selector(updateImageAnimated:)]) {
                    [self performSelector:@selector(updateImageAnimated:) withObject:@YES];
                } else if ([self respondsToSelector:@selector(_updateIconImageViewAnimated:)]) {
                    void (*method)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[self methodForSelector:@selector(_updateIconImageViewAnimated:)];
                    method(self, @selector(_updateIconImageViewAnimated:), YES);
                }
            }
        }
    }
}

%new
- (void)_26home_updateIconStyle {
    [self setNeedsLayout];

    if ([(id)self respondsToSelector:@selector(icon)]) {
        id myIcon = [(id)self performSelector:@selector(icon)];
        if ([myIcon respondsToSelector:@selector(purgeCachedImages)]) {
            [myIcon performSelector:@selector(purgeCachedImages)];
        }
        if ([myIcon respondsToSelector:@selector(reloadIconImage)]) {
            [myIcon performSelector:@selector(reloadIconImage)];
        }
    }

    UIView *myIconImageView = [self valueForKey:@"_iconImageView"];
    if (myIconImageView && [myIconImageView respondsToSelector:@selector(updateImageAnimated:)]) {
        void (*method)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[myIconImageView methodForSelector:@selector(updateImageAnimated:)];
        method(myIconImageView, @selector(updateImageAnimated:), YES);
    } else if ([self respondsToSelector:@selector(updateImageAnimated:)]) {
        [self performSelector:@selector(updateImageAnimated:) withObject:@YES];
    } else if ([self respondsToSelector:@selector(_updateIconImageViewAnimated:)]) {
        void (*method)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[self methodForSelector:@selector(_updateIconImageViewAnimated:)];
        method(self, @selector(_updateIconImageViewAnimated:), YES);
    }

    if (myIconImageView) {
        [myIconImageView setNeedsLayout];
        updateClockHandsInversionForView(myIconImageView);
    }

    UIView *accessoryView = nil;
    @try {
        accessoryView = [self valueForKey:@"_accessoryView"];
    } @catch (NSException *e) {}
    if (accessoryView && [accessoryView isKindOfClass:%c(SBIconBadgeView)]) {
        [accessoryView setNeedsLayout];
        [accessoryView layoutIfNeeded];
    }

    BOOL isWidget = NO;
    if ([self respondsToSelector:@selector(icon)]) {
        id icon = [self performSelector:@selector(icon)];
        if ([icon isKindOfClass:NSClassFromString(@"SBWidgetIcon")]) {
            isWidget = YES;
        }
    }
    if (isWidget) {
        _26home_recursivelyApplyWidgetTint((UIView *)self);
    }
}

%new
- (void)_26home_updateCustomScale {
    if (g_largeIconsEnabled) {
        UIView *labelView = [self valueForKey:@"_labelView"];
        if (labelView) {
            labelView.hidden = YES;
            labelView.alpha = 0.0;
        }
        if ([self respondsToSelector:@selector(labelView)]) {
            UIView *lv = [self labelView];
            if (lv) {
                lv.hidden = YES;
                lv.alpha = 0.0;
            }
        }
        for (UIView *sub in self.subviews) {
            NSString *cls = NSStringFromClass([sub class]);
            if ([cls containsString:@"Label"] || [cls containsString:@"Legibility"]) {
                sub.hidden = YES;
                sub.alpha = 0.0;
            }
        }
    } else {
        UIView *labelView = [self valueForKey:@"_labelView"];
        if (labelView) {
            labelView.hidden = NO;
            labelView.alpha = 1.0;
        }
    }

    CATransform3D old = self.layer.sublayerTransform;

    if (!g_largeIconsEnabled) {
        if (old.m11 != 1.0 || old.m22 != 1.0) {
            if (g_isAnimatingScale) {
                CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"sublayerTransform"];
                anim.duration = 0.25;
                anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                anim.fromValue = [NSValue valueWithCATransform3D:old];
                anim.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
                [self.layer addAnimation:anim forKey:@"scaleAnim"];
            }
            self.layer.sublayerTransform = CATransform3DIdentity;
        }
        return;
    }

    if ([self respondsToSelector:@selector(location)]) {
        NSString *location = [self performSelector:@selector(location)];
        if (location && [location isKindOfClass:[NSString class]]) {
            if ([location containsString:@"Library"] || [location containsString:@"AppLibrary"]) {
                if (old.m11 != 1.0 || old.m22 != 1.0) {
                    self.layer.sublayerTransform = CATransform3DIdentity;
                }
                return;
            }
        }
    }

    BOOL isWidget = NO;
    if ([self respondsToSelector:@selector(icon)]) {
        id icon = [self performSelector:@selector(icon)];
        if ([icon isKindOfClass:NSClassFromString(@"SBWidgetIcon")]) {
            isWidget = YES;
        }
    }

    CGFloat customScale = isWidget ? 1.05 : 1.20;

    if (old.m11 == customScale && old.m22 == customScale) {
        return;
    }

    [self.layer removeAnimationForKey:@"scaleAnim"];
    if (g_isAnimatingScale) {
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"sublayerTransform"];
        anim.duration = 0.25;
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        anim.fromValue = [NSValue valueWithCATransform3D:old];
        anim.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(customScale, customScale, 1.0)];
        [self.layer addAnimation:anim forKey:@"scaleAnim"];
    }
    self.layer.sublayerTransform = CATransform3DMakeScale(customScale, customScale, 1.0);
}

%end

%group IconImageViewHooks

%hook SBIconImageView

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ngkhoi.26home.IconDidGenerate" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_home26_handleIconDidGenerateNotification:) name:@"ngkhoi.26home.IconDidGenerate" object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ngkhoi.26home.IconDidGenerate" object:nil];
    }
    updateClockHandsInversionForView(self);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ngkhoi.26home.IconDidGenerate" object:nil];
    %orig;
}

%new
- (void)_home26_handleIconDidGenerateNotification:(NSNotification *)note {
    NSString *readyBundleID = note.userInfo[@"bundleID"];
    if (!readyBundleID) return;
    if (Home26IsCoverSheetActive()) return;
    if ([self isKindOfClass:%c(SBFolderIconImageView)] || [self isKindOfClass:NSClassFromString(@"SBHLibraryAdditionalItemsIndicatorIconImageView")]) {
        return;
    }

    id currentIcon = nil;
    if ([self respondsToSelector:@selector(icon)]) {
        currentIcon = [self performSelector:@selector(icon)];
    }
    if ([currentIcon respondsToSelector:@selector(applicationBundleID)]) {
        NSString *myBundleID = [currentIcon performSelector:@selector(applicationBundleID)];
        if ([myBundleID isEqualToString:readyBundleID]) {
            UIImage *styled = note.userInfo[@"image"] ?: Home26FastCachedIcon(myBundleID);
            if (styled && self.layer.contents != (id)styled.CGImage) {
                CATransition *transition = [CATransition animation];
                transition.duration = 0.35;
                transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                transition.type = kCATransitionFade;
                [self.layer addAnimation:transition forKey:@"glyphFadeIn"];
                self.layer.contents = (id)styled.CGImage;
                updateClockHandsInversionForView(self);
            }
        }
    }
}

- (void)updateImageAnimated:(BOOL)animated {
    %orig;
    if (Home26IsCoverSheetActive()) return;
    if ([self isKindOfClass:%c(SBFolderIconImageView)] || [self isKindOfClass:NSClassFromString(@"SBHLibraryAdditionalItemsIndicatorIconImageView")]) {
        return;
    }
    if ([self respondsToSelector:@selector(displayedImage)] && [self respondsToSelector:@selector(icon)]) {
        UIImage *image = [self performSelector:@selector(displayedImage)];
        id icon = [self performSelector:@selector(icon)];
        if (image && icon && [icon respondsToSelector:@selector(applicationBundleID)]) {
            NSString *bundleID = [icon performSelector:@selector(applicationBundleID)];
            if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
                if (isAppExcluded(bundleID)) {
                    self.layer.contents = (id)image.CGImage;
                    return;
                }

                struct SBIconImageInfo info;
                if ([self respondsToSelector:@selector(iconImageInfo)]) {
                    info = [(SBIconImageView *)self iconImageInfo];
                } else {
                    info.size = CGSizeMake(60, 60);
                    info.scale = [UIScreen mainScreen].scale;
                    info.continuousCornerRadius = 13.5;
                }

                UIImage *cached = Home26FastCachedIcon(bundleID);
                if (cached) {
                    self.layer.contents = (id)cached.CGImage;
                    updateClockHandsInversionForView(self);
                    return;
                }

                BOOL isInFolder = Home26IsViewInFolder(self) || g_isFolderOpen;
                if (isInFolder) {
                    UIImage *orig = Home26OriginalIconForBundleID(bundleID);
                    if (!orig) {
                        extern BOOL g_bypassingIconHook;
                        g_bypassingIconHook = YES;
                        if ([icon respondsToSelector:@selector(unmaskedIconImageWithInfo:)]) {
                            orig = [icon unmaskedIconImageWithInfo:info];
                        } else if ([icon respondsToSelector:@selector(iconImageWithInfo:)]) {
                            orig = [icon iconImageWithInfo:info];
                        }
                        g_bypassingIconHook = NO;
                        if (orig) {
                            Home26SaveOriginalIcon(orig, bundleID);
                        } else {
                            orig = image;
                        }
                    }
                    UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
                    if (styled) {
                        self.layer.contents = (id)styled.CGImage;
                        updateClockHandsInversionForView(self);
                        return;
                    }
                }

                UIImage *skeleton = Home26SkeletonIcon(bundleID, info);
                if (skeleton) {
                    self.layer.contents = (id)skeleton.CGImage;
                }

                UIImage *orig = Home26OriginalIconForBundleID(bundleID);
                if (!orig) {
                    extern BOOL g_bypassingIconHook;
                    g_bypassingIconHook = YES;
                    if ([icon respondsToSelector:@selector(unmaskedIconImageWithInfo:)]) {
                        orig = [icon unmaskedIconImageWithInfo:info];
                    } else if ([icon respondsToSelector:@selector(iconImageWithInfo:)]) {
                        orig = [icon iconImageWithInfo:info];
                    }
                    g_bypassingIconHook = NO;
                    if (orig) {
                        Home26SaveOriginalIcon(orig, bundleID);
                    } else {
                        orig = image;
                    }
                }

                NSString *capturedBundleID = bundleID;
                __weak typeof(self) weakSelf = self;

                Home26RequestIconAsync(orig, capturedBundleID, ^(UIImage *styled) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf || !styled) return;
                    if (Home26IsCoverSheetActive()) return;

                    id currentIcon = nil;
                    if ([strongSelf respondsToSelector:@selector(icon)]) {
                        currentIcon = [strongSelf performSelector:@selector(icon)];
                    }
                    if ([currentIcon respondsToSelector:@selector(applicationBundleID)]) {
                        NSString *currentBundleID = [currentIcon performSelector:@selector(applicationBundleID)];
                        if (currentBundleID && ![currentBundleID isEqualToString:capturedBundleID]) {
                            return;
                        }
                    }

                    if (strongSelf.layer.contents != (id)styled.CGImage) {
                        CATransition *transition = [CATransition animation];
                        transition.duration = 0.35;
                        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                        transition.type = kCATransitionFade;
                        [strongSelf.layer addAnimation:transition forKey:@"glyphFadeIn"];
                        strongSelf.layer.contents = (id)styled.CGImage;
                        updateClockHandsInversionForView(strongSelf);
                    }
                });
            }
        }
    }
    updateClockHandsInversionForView(self);
}

- (void)layoutSubviews {
    %orig;
    if ([self isKindOfClass:%c(SBFolderIconImageView)] || [self isKindOfClass:NSClassFromString(@"SBHLibraryAdditionalItemsIndicatorIconImageView")]) {
        return;
    }
    CGFloat cornerRadius = GetIconCornerRadius(self, nil);
    self.layer.cornerRadius = cornerRadius;
    self.layer.cornerCurve = kCACornerCurveCircular;
    self.layer.masksToBounds = NO;
    updateClockHandsInversionForView(self);
}

- (void)didMoveToSuperview {
    %orig;
    updateClockHandsInversionForView(self);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    updateClockHandsInversionForView(self);
}

%end

%hook SBClockIconImageView

- (void)_updateVisualDate:(id)date animated:(BOOL)animated {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)_setPropertiesForCurrentTime:(id)time {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)_updateSecondsAnimated:(BOOL)animated {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)_timerFired {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)setPaused:(BOOL)paused {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)updateAnimatingState {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)updateUnanimated {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)layoutSubviews {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)didMoveToWindow {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)prepareForReuse {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)setIcon:(id)icon location:(id)location animated:(BOOL)animated {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

- (void)didMoveToSuperview {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

%end

%end

%hook SBFolderIconImageView

- (instancetype)initWithFrame:(CGRect)frame {
    id orig = %orig;
    if (orig) {
        [[NSNotificationCenter defaultCenter] addObserver:orig selector:@selector(_26home_forceUpdate) name:@"ngkhoi.26home.UpdateIconStyle" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:orig selector:@selector(_26home_forceUpdate) name:@"ngkhoi.26home.IconDidGenerate" object:nil];
    }
    return orig;
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        [self _26home_forceUpdate];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%new
- (void)_26home_forceUpdate {
    id folderIcon = nil;
    if ([(id)self respondsToSelector:@selector(icon)]) {
        folderIcon = [(id)self performSelector:@selector(icon)];
    }
    if (!folderIcon && [(id)self respondsToSelector:@selector(_folderIcon)]) {
        folderIcon = [(id)self performSelector:@selector(_folderIcon)];
    }
    if (!folderIcon) return;

    id cache = nil;
    if ([(id)self respondsToSelector:@selector(_folderIconImageCache)]) {
        cache = [(id)self performSelector:@selector(_folderIconImageCache)];
    }
    if (!cache && [%c(SBIconController) respondsToSelector:@selector(sharedInstance)]) {
        id ic = [%c(SBIconController) performSelector:@selector(sharedInstance)];
        id im = [ic respondsToSelector:@selector(iconManager)] ? [ic performSelector:@selector(iconManager)] : ic;
        if ([im respondsToSelector:@selector(folderIconImageCache)]) {
            cache = [im performSelector:@selector(folderIconImageCache)];
        }
    }
    if (cache) {
        if ([cache respondsToSelector:@selector(rebuildImagesForFolderIcon:)]) {
            [cache performSelector:@selector(rebuildImagesForFolderIcon:) withObject:folderIcon];
        }
        if ([cache respondsToSelector:@selector(informObserversOfUpdateForFolderIcon:)]) {
            [cache performSelector:@selector(informObserversOfUpdateForFolderIcon:) withObject:folderIcon];
        }
        if ([(id)self respondsToSelector:@selector(folderIconImageCache:didUpdateImagesForFolderIcon:)]) {
            [(id)self folderIconImageCache:cache didUpdateImagesForFolderIcon:folderIcon];
        }
    }
    if ([(id)self respondsToSelector:@selector(updateImageAnimated:)]) {
        ((void (*)(id, SEL, BOOL))[(id)self methodForSelector:@selector(updateImageAnimated:)])(self, @selector(updateImageAnimated:), NO);
    }
}

- (void)updateImageAnimated:(BOOL)animated {
    if (animated) {
        [UIView transitionWithView:(UIView *)self
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                        animations:^{
                            %orig(NO);
                        }
                        completion:nil];
    } else {
        %orig;
    }
}

%end

%hook SBFolderIcon

- (instancetype)initWithFolder:(id)folder {
    id orig = %orig;
    if (orig) {
        [[NSNotificationCenter defaultCenter] addObserver:orig selector:@selector(_26home_purgeCache) name:@"ngkhoi.26home.UpdateIconStyle" object:nil];
    }
    return orig;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ngkhoi.26home.UpdateIconStyle" object:nil];
    %orig;
}

%new
- (void)_26home_purgeCache {
    if ([(id)self respondsToSelector:@selector(iconImageDidUpdate:)]) {
        [(id)self performSelector:@selector(iconImageDidUpdate:) withObject:self];
    }
}

%end

%hook SBIcon

- (UIImage *)iconImageWithInfo:(struct SBIconImageInfo)info {
    if (g_bypassingIconHook) return %orig;
    UIImage *orig = %orig;
    if (Home26IsCoverSheetActive()) return orig;
    if ([(id)self respondsToSelector:@selector(applicationBundleID)]) {
        NSString *bundleID = [(id)self performSelector:@selector(applicationBundleID)];
        if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
            if (isAppExcluded(bundleID)) return orig;
            Home26SaveOriginalIcon(orig, bundleID);

            UIImage *cached = Home26FastCachedIcon(bundleID);
            if (cached) return cached;

            BOOL isFolderContext = (info.size.width < 50 || g_isFolderOpen);
            if (!isFolderContext && [(id)self respondsToSelector:@selector(parentFolderIcon)]) {
                if ([(id)self performSelector:@selector(parentFolderIcon)] != nil) {
                    isFolderContext = YES;
                }
            }
            if (isFolderContext) {
                UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
                if (styled) return styled;
                return orig;
            }

            if ([NSThread isMainThread]) {
                Home26RequestIconAsync(orig, bundleID, nil);
                UIImage *skeleton = Home26SkeletonIcon(bundleID, info);
                if (skeleton) return skeleton;
            } else {
                UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
                if (styled) return styled;
            }
        }
    }
    return orig;
}

- (UIImage *)unmaskedIconImageWithInfo:(struct SBIconImageInfo)info {
    if (g_bypassingIconHook) return %orig;
    UIImage *orig = %orig;
    if (Home26IsCoverSheetActive()) return orig;
    if ([(id)self respondsToSelector:@selector(applicationBundleID)]) {
        NSString *bundleID = [(id)self performSelector:@selector(applicationBundleID)];
        if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
            if (isAppExcluded(bundleID)) return orig;
            Home26SaveOriginalIcon(orig, bundleID);

            UIImage *cached = Home26FastCachedIcon(bundleID);
            if (cached) return cached;

            BOOL isFolderContext = (info.size.width < 50 || g_isFolderOpen);
            if (!isFolderContext && [(id)self respondsToSelector:@selector(parentFolderIcon)]) {
                if ([(id)self performSelector:@selector(parentFolderIcon)] != nil) {
                    isFolderContext = YES;
                }
            }
            if (isFolderContext) {
                UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
                if (styled) return styled;
                return orig;
            }

            if ([NSThread isMainThread]) {
                Home26RequestIconAsync(orig, bundleID, nil);
                UIImage *skeleton = Home26SkeletonIcon(bundleID, info);
                if (skeleton) return skeleton;
            } else {
                UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
                if (styled) return styled;
            }
        }
    }
    return orig;
}

- (UIImage *)generateIconImageWithInfo:(struct SBIconImageInfo)info {
    if (g_bypassingIconHook) return %orig;
    UIImage *orig = %orig;
    if (Home26IsCoverSheetActive()) return orig;
    if ([(id)self respondsToSelector:@selector(applicationBundleID)]) {
        NSString *bundleID = [(id)self performSelector:@selector(applicationBundleID)];
        if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
            if (isAppExcluded(bundleID)) return orig;
            Home26SaveOriginalIcon(orig, bundleID);

            UIImage *cached = Home26FastCachedIcon(bundleID);
            if (cached) return cached;

            BOOL isFolderContext = (info.size.width < 50 || g_isFolderOpen);
            if (!isFolderContext && [(id)self respondsToSelector:@selector(parentFolderIcon)]) {
                if ([(id)self performSelector:@selector(parentFolderIcon)] != nil) {
                    isFolderContext = YES;
                }
            }
            if (isFolderContext) {
                UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
                if (styled) return styled;
                return orig;
            }

            if ([NSThread isMainThread]) {
                Home26RequestIconAsync(orig, bundleID, nil);
                UIImage *skeleton = Home26SkeletonIcon(bundleID, info);
                if (skeleton) return skeleton;
            } else {
                UIImage *styled = Home26RequestStyledIcon(orig, bundleID);
                if (styled) return styled;
            }
        }
    }
    return orig;
}

%end

void Home26InitIconImageViewHooks(void) {
    if (objc_getClass("SBIconImageView")) {
        %init(IconImageViewHooks);
    }
}

void Home26InitIconViewHooks(void) {
    %init();
    Home26InitIconImageViewHooks();
}
