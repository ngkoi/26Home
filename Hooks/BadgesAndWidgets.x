#import "HooksCommon.h"

%hook SBDockView

- (void)layoutSubviews {
    %orig;
    if (g_isCoverSheetVisible || g_coverSheetProgress > 0.001) {
        return;
    }
}

%end

%hook SBIconBadgeView

- (void)layoutSubviews {
    %orig;

    NSString *style = g_iconStyle ?: @"Default";
    UIView *view = (UIView *)self;
    if ([style isEqualToString:@"Dark"]) {
        NSString *darkIconMode = g_darkIconMode ?: @"Always";
        if ([darkIconMode isEqualToString:@"Auto"]) {
            if (view.traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark) {
                style = @"Default";
            }
        }
    }

    UIColor *badgeBgColor = nil;
    UIColor *badgeTextColor = nil;
    BOOL useCustomBadge = NO;

    if ([style isEqualToString:@"Clear"]) {
        useCustomBadge = YES;
        badgeBgColor = [UIColor whiteColor];
        badgeTextColor = [UIColor colorWithWhite:0.22 alpha:1.0];
    } else if ([style isEqualToString:@"Tinted"]) {
        useCustomBadge = YES;

        NSString *tintHex = g_tintColor ?: @"#00FFFF";
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:tintHex];
        if ([tintHex hasPrefix:@"#"]) {
            [scanner setScanLocation:1];
        }
        [scanner scanHexInt:&rgbValue];

        CGFloat r = ((rgbValue & 0xFF0000) >> 16) / 255.0;
        CGFloat g = ((rgbValue & 0xFF00) >> 8) / 255.0;
        CGFloat b = (rgbValue & 0xFF) / 255.0;
        badgeBgColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];

        CGFloat luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        if (luminance > 0.55) {
            badgeTextColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        } else {
            badgeTextColor = [UIColor whiteColor];
        }
    } else {
        useCustomBadge = NO;
    }

    UIView *bgView = [view valueForKey:@"_backgroundView"];
    UIView *textView = [view valueForKey:@"_textView"];
    UIView *myBgView = bgView ? [bgView viewWithTag:2626] : [view viewWithTag:2626];
    UILabel *myLabel = [view viewWithTag:2627];

    if (useCustomBadge) {
        if (bgView) {
            if (!myBgView) {
                myBgView = [[UIView alloc] initWithFrame:bgView.bounds];
                myBgView.tag = 2626;
                myBgView.clipsToBounds = YES;
                myBgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [bgView addSubview:myBgView];
            }
            myBgView.frame = bgView.bounds;
            myBgView.layer.cornerRadius = myBgView.bounds.size.height / 2.0;
            myBgView.backgroundColor = badgeBgColor;
            myBgView.hidden = NO;
        }

        if (textView) {
            textView.hidden = YES;
        }

        NSString *badgeText = nil;
        @try {
            badgeText = [view valueForKey:@"_text"];
        } @catch (NSException *e) {}
        if (!badgeText && [view respondsToSelector:@selector(text)]) {
            badgeText = [(id)view performSelector:@selector(text)];
        }
        if (!badgeText && textView && [textView respondsToSelector:@selector(string)]) {
            badgeText = [textView performSelector:@selector(string)];
        }
        if (!badgeText && [view.superview respondsToSelector:@selector(icon)]) {
            id icon = [(id)view.superview performSelector:@selector(icon)];
            if ([icon respondsToSelector:@selector(badgeNumberOrString)]) {
                id val = [icon performSelector:@selector(badgeNumberOrString)];
                if ([val isKindOfClass:[NSString class]]) badgeText = val;
                else if ([val isKindOfClass:[NSNumber class]]) badgeText = [val stringValue];
            }
        }

        if (!myLabel) {
            myLabel = [[UILabel alloc] initWithFrame:view.bounds];
            myLabel.tag = 2627;
            myLabel.textAlignment = NSTextAlignmentCenter;
            myLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [view addSubview:myLabel];
        }
        myLabel.frame = view.bounds;
        myLabel.font = [UIFont systemFontOfSize:view.bounds.size.height * 0.58 weight:UIFontWeightBold];
        myLabel.text = badgeText ?: @"";
        myLabel.textColor = badgeTextColor;
        myLabel.hidden = NO;
        [view bringSubviewToFront:myLabel];
    } else {
        if (myBgView) {
            myBgView.hidden = YES;
        }
        if (myLabel) {
            myLabel.hidden = YES;
        }
        if (textView) {
            textView.hidden = NO;
        }
    }
}

%end

void _26home_applyWidgetTintToView(UIView *view) {
    if (!view) return;

    BOOL isWidgetClass = [view isKindOfClass:NSClassFromString(@"SBHShadowedWidgetView")] ||
                         [view isKindOfClass:NSClassFromString(@"SBHWidgetWrapperView")] ||
                         [view isKindOfClass:NSClassFromString(@"SBHWidgetContainerView")];

    UIView *bgView = nil;
    @try {
        bgView = [view valueForKey:@"_backgroundView"];
    } @catch (NSException *e) {}
    if (!bgView && [view respondsToSelector:@selector(backgroundView)]) {
        @try {
            bgView = [view performSelector:@selector(backgroundView)];
        } @catch (NSException *e) {}
    }

    if (!isWidgetClass && !bgView) {
        return;
    }

    UIView *targetView = bgView ?: view;

    UIView *tintOverlay = [targetView viewWithTag:2628];
    if ([g_iconStyle isEqualToString:@"Tinted"]) {
        if (!tintOverlay) {
            tintOverlay = [[UIView alloc] initWithFrame:targetView.bounds];
            tintOverlay.tag = 2628;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tintOverlay.userInteractionEnabled = NO;
            if (targetView == bgView) {
                [targetView addSubview:tintOverlay];
            } else {
                [targetView insertSubview:tintOverlay atIndex:0];
            }
        }

        CGFloat radius = 0.0;
        if ([view respondsToSelector:@selector(cornerRadius)]) {
            radius = ((CGFloat (*)(id, SEL))[view methodForSelector:@selector(cornerRadius)])(view, @selector(cornerRadius));
        }
        if (radius <= 0 && [targetView respondsToSelector:@selector(cornerRadius)]) {
            radius = ((CGFloat (*)(id, SEL))[targetView methodForSelector:@selector(cornerRadius)])(targetView, @selector(cornerRadius));
        }
        if (radius <= 0) {
            radius = targetView.layer.cornerRadius > 0 ? targetView.layer.cornerRadius : (view.layer.cornerRadius > 0 ? view.layer.cornerRadius : 22.0);
        }

        tintOverlay.frame = targetView.bounds;
        tintOverlay.layer.cornerRadius = radius;
        tintOverlay.layer.cornerCurve = kCACornerCurveContinuous;
        tintOverlay.clipsToBounds = YES;

        NSString *tintHex = g_tintColor ?: @"#00FFFF";
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
        b = MIN(b * 0.75, 0.75);
        b = MAX(b, 0.20);
        UIColor *tintColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:1.0];

        UIView *smokedLayer = [tintOverlay viewWithTag:2629];
        if (!smokedLayer) {
            smokedLayer = [[UIView alloc] initWithFrame:tintOverlay.bounds];
            smokedLayer.tag = 2629;
            smokedLayer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            smokedLayer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
            smokedLayer.layer.cornerRadius = radius;
            smokedLayer.layer.cornerCurve = kCACornerCurveContinuous;
            smokedLayer.clipsToBounds = YES;
            smokedLayer.userInteractionEnabled = NO;
            [tintOverlay insertSubview:smokedLayer atIndex:0];
        }
        smokedLayer.frame = tintOverlay.bounds;
        smokedLayer.layer.cornerRadius = radius;

        tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.40];
        tintOverlay.hidden = NO;
    } else {
        if (tintOverlay) {
            tintOverlay.hidden = YES;
        }
    }
}

void _26home_recursivelyApplyWidgetTint(UIView *view) {
    if (!view) return;
    _26home_applyWidgetTintToView(view);
    for (UIView *sub in view.subviews) {
        _26home_recursivelyApplyWidgetTint(sub);
    }
}

%hook SBHShadowedWidgetView

- (void)layoutSubviews {
    %orig;
    _26home_applyWidgetTintToView((UIView *)self);
}

%end

%hook SBHWidgetWrapperView

- (void)layoutSubviews {
    %orig;
    _26home_applyWidgetTintToView((UIView *)self);
}

%end

%hook SBHWidgetContainerView

- (void)layoutSubviews {
    %orig;
    _26home_applyWidgetTintToView((UIView *)self);
}

%end

void Home26InitBadgesAndWidgetsHooks(void) {
    %init();
}
