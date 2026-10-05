#import "HooksCommon.h"

static void updateLiquidGlassLayout(UIView *button);

static CGRect getStandardEditingButtonFrame(UIView *button) {
    BOOL isDone = [button isKindOfClass:%c(SBHEditingDoneButton)];
    CGFloat pillWidth = isDone ? 64.0 : 58.0;
    CGFloat pillHeight = 32.0;

    CGRect b = button.bounds;
    CGFloat pillX = (b.size.width > pillWidth) ? (b.size.width - pillWidth) / 2.0 : 0.0;

    CGFloat safeAreaTop = 0;
    UIWindow *w = button.window;
    if (!w) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        w = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
#pragma clang diagnostic pop
    }
    if (@available(iOS 11.0, *)) {
        if (w) {
            safeAreaTop = w.safeAreaInsets.top;
        }
    }
    if (safeAreaTop <= 0) {
        safeAreaTop = 44.0;
    }

    CGFloat targetScreenY = safeAreaTop + 6.0;

    CGPoint screenOrigin = CGPointZero;
    if (button.window) {
        screenOrigin = [button convertPoint:CGPointZero toView:nil];
    }

    CGFloat pillY = targetScreenY - screenOrigin.y;

    if (pillY < 0.0 || pillY + pillHeight > b.size.height) {
        if (b.size.height > pillHeight + 8.0) {
            pillY = b.size.height - pillHeight - 6.0;
        } else {
            pillY = (b.size.height > pillHeight) ? (b.size.height - pillHeight) / 2.0 : 0.0;
        }
    }

    return CGRectMake(roundf(pillX), roundf(pillY), pillWidth, pillHeight);
}

static void replaceMaterialViewWithLiquidGlass(UIView *button, CGFloat blurRadius) {
    if ([button viewWithTag:999]) {
        updateLiquidGlassLayout(button);
        return;
    }

    button.backgroundColor = [UIColor clearColor];
    button.layer.backgroundColor = [UIColor clearColor].CGColor;
    button.clipsToBounds = NO;
    button.layer.masksToBounds = NO;

    if ([button respondsToSelector:@selector(backgroundView)]) {
        UIView *bg = [button performSelector:@selector(backgroundView)];
        if (bg) {
            bg.hidden = YES;
            bg.alpha = 0;
            bg.layer.hidden = YES;
        }
    }
    if ([button respondsToSelector:@selector(materialView)]) {
        UIView *mv = [button performSelector:@selector(materialView)];
        if (mv) {
            mv.hidden = YES;
            mv.alpha = 0;
            mv.layer.hidden = YES;
        }
    }

    for (UIView *subview in button.subviews) {
        if (subview.tag != 999) {
            subview.hidden = YES;
            subview.alpha = 0;
            subview.layer.hidden = YES;
        }
    }

    BOOL isDone = [button isKindOfClass:%c(SBHEditingDoneButton)];
    CGRect initialFrame = getStandardEditingButtonFrame(button);

    NSString *title = isDone ? @"Done" : @"Edit";
    LGButtonView *btnView = [[LGButtonView alloc] initWithFrame:initialFrame title:title blurRadius:blurRadius];
    btnView.tag = 999;
    [button addSubview:btnView];
    btnView.lgView.hidden = NO;
}

static void updateLiquidGlassLayout(UIView *button) {
    button.backgroundColor = [UIColor clearColor];
    button.layer.backgroundColor = [UIColor clearColor].CGColor;
    button.clipsToBounds = NO;
    button.layer.masksToBounds = NO;
    button.layer.shadowOpacity = 0.0;

    CGRect targetFrame = getStandardEditingButtonFrame(button);

    if ([button respondsToSelector:@selector(backgroundView)]) {
        UIView *bg = [button performSelector:@selector(backgroundView)];
        if (bg) {
            bg.hidden = YES;
            bg.alpha = 0;
            bg.layer.hidden = YES;
        }
    }
    if ([button respondsToSelector:@selector(materialView)]) {
        UIView *mv = [button performSelector:@selector(materialView)];
        if (mv) {
            mv.hidden = YES;
            mv.alpha = 0;
            mv.layer.hidden = YES;
        }
    }

    LGButtonView *coverView = (LGButtonView *)[button viewWithTag:999];
    if (coverView && [coverView isKindOfClass:[LGButtonView class]]) {
        [coverView updateLayoutWithFrame:targetFrame];
        coverView.lgView.hidden = NO;
    }

    for (UIView *subview in button.subviews) {
        if (subview.tag != 999) {
            subview.hidden = YES;
            subview.alpha = 0;
            subview.layer.hidden = YES;
        }
    }
}

%hook SBHEditingWidgetButton

- (void)layoutSubviews {
    %orig;
    updateLiquidGlassLayout(self);
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        replaceMaterialViewWithLiquidGlass(self, 8.0);

        if (@available(iOS 14.0, *)) {
            self.showsMenuAsPrimaryAction = NO;
            self.menu = nil;
        }
        [self removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [self addTarget:self action:@selector(_26home_handleEditButtonTap) forControlEvents:UIControlEventTouchUpInside];
    }
}

%new
- (void)_26home_handleEditButtonTap {
    static NSTimeInterval s_lastEditButtonTapTime = 0;
    NSTimeInterval now = [NSDate date].timeIntervalSinceReferenceDate;
    if (now - s_lastEditButtonTapTime < 0.35) {
        return;
    }
    s_lastEditButtonTapTime = now;

    if ([[Home26LiquidMenu sharedMenu] isOpen]) {
        [[Home26LiquidMenu sharedMenu] dismiss];
        return;
    }

    __weak typeof(self) weakSelf = self;

    Home26LiquidMenuItem *addWidget = [Home26LiquidMenuItem itemWithTitle:@"Add Widget" icon:LGImageNamed(@"widget.small.badge.plus") action:^{
        SBRootFolderController *rootVC = ResolveRootFolderController(weakSelf);
        if (rootVC) {
            [rootVC rootFolderViewWantsWidgetEditingViewControllerPresented:nil];
        }
    }];

    Home26LiquidMenuItem *customize = [Home26LiquidMenuItem itemWithTitle:@"Customize" icon:LGImageNamed(@"apps.iphone.badge.paintbrush") action:^{
        if (g_editingDoneTarget && g_editingDoneAction) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [g_editingDoneTarget performSelector:g_editingDoneAction withObject:nil];
#pragma clang diagnostic pop
        }

        id iconController = [%c(SBIconController) sharedInstance];
        if ([iconController respondsToSelector:@selector(setIsEditing:)]) {
            void (*setIsEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconController methodForSelector:@selector(setIsEditing:)];
            if (setIsEditing) {
                setIsEditing(iconController, @selector(setIsEditing:), NO);
            }
        }

        if ([iconController respondsToSelector:@selector(iconManager)]) {
            id iconManager = [iconController performSelector:@selector(iconManager)];
            if ([iconManager respondsToSelector:@selector(setIsEditing:)]) {
                void (*setManagerEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconManager methodForSelector:@selector(setIsEditing:)];
                if (setManagerEditing) setManagerEditing(iconManager, @selector(setIsEditing:), NO);
            } else if ([iconManager respondsToSelector:@selector(setEditing:)]) {
                void (*setManagerEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconManager methodForSelector:@selector(setEditing:)];
                if (setManagerEditing) setManagerEditing(iconManager, @selector(setEditing:), NO);
            } else if ([iconManager respondsToSelector:@selector(setEditing:animated:)]) {
                void (*setManagerEditingAnim)(id, SEL, BOOL, BOOL) = (void (*)(id, SEL, BOOL, BOOL))[iconManager methodForSelector:@selector(setEditing:animated:)];
                if (setManagerEditingAnim) setManagerEditingAnim(iconManager, @selector(setEditing:animated:), NO, YES);
            }
        }

        SBRootFolderController *rootVC = ResolveRootFolderController(weakSelf);
        if (rootVC) {
            [rootVC setEditing:NO animated:YES];
        }

        BOOL foundDoneButton = NO;
        NSMutableArray *viewQueue = [NSMutableArray array];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            [viewQueue addObject:window];
        }
#pragma clang diagnostic pop

        while (viewQueue.count > 0) {
            UIView *view = [viewQueue firstObject];
            [viewQueue removeObjectAtIndex:0];

            if ([view isKindOfClass:%c(SBHEditingDoneButton)]) {
                [(UIControl *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
                foundDoneButton = YES;
                break;
            }

            [viewQueue addObjectsFromArray:view.subviews];
        }

        if (!foundDoneButton) {
            NSMutableArray *queue = [NSMutableArray array];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            for (UIWindow *window in [UIApplication sharedApplication].windows) {
                if (window.rootViewController) {
                    [queue addObject:window.rootViewController];
                }
            }
#pragma clang diagnostic pop
            while (queue.count > 0) {
                UIViewController *controller = [queue firstObject];
                [queue removeObjectAtIndex:0];

                if (controller.isEditing) {
                    if ([controller respondsToSelector:@selector(setEditing:animated:)]) {
                        void (*setEditing)(id, SEL, BOOL, BOOL) = (void (*)(id, SEL, BOOL, BOOL))[controller methodForSelector:@selector(setEditing:animated:)];
                        if (setEditing) {
                            setEditing(controller, @selector(setEditing:animated:), NO, YES);
                        }
                    }
                }

                if ([controller respondsToSelector:@selector(childViewControllers)]) {
                    NSArray *children = controller.childViewControllers;
                    if (children.count > 0) {
                        [queue addObjectsFromArray:children];
                    }
                }
                if (controller.presentedViewController) {
                    [queue addObject:controller.presentedViewController];
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *targetView = rootVC.view;
            if (!targetView) {
                id iconController = [%c(SBIconController) sharedInstance];
                if (iconController && [iconController respondsToSelector:@selector(view)]) {
                    targetView = [iconController valueForKey:@"view"];
                }
            }
            if (!targetView) {
                targetView = weakSelf.window;
            }
            if (!targetView) {
                NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
                for (UIWindow *w in windows) {
                    if (!w.hidden && w.bounds.size.height > 0) {
                        targetView = w;
                        break;
                    }
                }
            }

            if (targetView) {
                HomeCustomizationMenuContainer *container = [[HomeCustomizationMenuContainer alloc] initWithFrame:targetView.bounds];
                [container presentInView:targetView];
            }
        });
    }];

    Home26LiquidMenuItem *editWallpaper = [Home26LiquidMenuItem itemWithTitle:@"Edit Wallpaper" icon:LGImageNamed(@"apple.photos") action:^{
        id iconController = [%c(SBIconController) sharedInstance];
        if ([iconController respondsToSelector:@selector(setIsEditing:)]) {
            void (*setIsEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconController methodForSelector:@selector(setIsEditing:)];
            if (setIsEditing) {
                setIsEditing(iconController, @selector(setIsEditing:), NO);
            }
        }
        if ([iconController respondsToSelector:@selector(iconManager)]) {
            id iconManager = [iconController performSelector:@selector(iconManager)];
            if ([iconManager respondsToSelector:@selector(setIsEditing:)]) {
                void (*setManagerEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconManager methodForSelector:@selector(setIsEditing:)];
                if (setManagerEditing) setManagerEditing(iconManager, @selector(setIsEditing:), NO);
            } else if ([iconManager respondsToSelector:@selector(setEditing:)]) {
                void (*setManagerEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconManager methodForSelector:@selector(setEditing:)];
                if (setManagerEditing) setManagerEditing(iconManager, @selector(setEditing:), NO);
            } else if ([iconManager respondsToSelector:@selector(setEditing:animated:)]) {
                void (*setManagerEditingAnim)(id, SEL, BOOL, BOOL) = (void (*)(id, SEL, BOOL, BOOL))[iconManager methodForSelector:@selector(setEditing:animated:)];
                if (setManagerEditingAnim) setManagerEditingAnim(iconManager, @selector(setEditing:animated:), NO, YES);
            }
        }

        SBRootFolderController *rootVC = ResolveRootFolderController(weakSelf);
        if (rootVC) {
            [rootVC setEditing:NO animated:YES];
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSURL *url = [NSURL URLWithString:@"prefs:root=Wallpaper"];
            id workspace = [NSClassFromString(@"LSApplicationWorkspace") performSelector:@selector(defaultWorkspace)];
            [workspace performSelector:@selector(openSensitiveURL:withOptions:) withObject:url withObject:nil];
        });
    }];

    Home26LiquidMenuItem *editPages = [Home26LiquidMenuItem itemWithTitle:@"Edit Pages" icon:LGImageNamed(@"apps.iphone.on.rectangle.portrait") action:^{
        SBRootFolderController *rootVC = ResolveRootFolderController(weakSelf);
        if (rootVC) {
            [rootVC _presentPageManagement:nil];
        }
    }];

    NSArray *items = @[addWidget, customize, editWallpaper, editPages];
    [[Home26LiquidMenu sharedMenu] presentFromButton:self items:items];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    BOOL result = %orig;
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        CGPoint pt = [touch locationInView:btnView];
        [btnView handleTouchDownAtPoint:pt];
    }
    return result;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        CGPoint pt = [touch locationInView:btnView];
        [btnView handleTouchMovedToPoint:pt];
        return YES;
    }
    return %orig;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    %orig;
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        [btnView handleTouchEnded];
    }

    CGPoint loc = [touch locationInView:self];
    if (CGRectContainsPoint(CGRectInset(self.bounds, -12, -12), loc)) {
        [self _26home_handleEditButtonTap];
    }
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    %orig;
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        [btnView handleTouchEnded];
    }
}
%end

%hook SBHEditingDoneButton

- (void)layoutSubviews {
    %orig;
    updateLiquidGlassLayout(self);
}

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        replaceMaterialViewWithLiquidGlass(self, 8.0);

        NSSet *targets = [self allTargets];
        for (id target in targets) {
            NSArray *actions = [self actionsForTarget:target forControlEvent:UIControlEventTouchUpInside];
            if (actions.count > 0) {
                g_editingDoneTarget = target;
                g_editingDoneAction = NSSelectorFromString(actions.firstObject);
            }
        }
    }
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    BOOL result = %orig;
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        CGPoint pt = [touch locationInView:btnView];
        [btnView handleTouchDownAtPoint:pt];
    }
    return result;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        CGPoint pt = [touch locationInView:btnView];
        [btnView handleTouchMovedToPoint:pt];
        return YES;
    }
    return %orig;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    %orig;
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        [btnView handleTouchEnded];
    }
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    %orig;
    LGButtonView *btnView = (LGButtonView *)[self viewWithTag:999];
    if (btnView && [btnView isKindOfClass:[LGButtonView class]]) {
        [btnView handleTouchEnded];
    }
}
%end

static void setupLiquidGlassForMinusButton(UIView *minusView) {
    if ([minusView viewWithTag:996] || [minusView viewWithTag:997]) return;

    if (minusView.superview) {
        for (UIView *sibling in minusView.superview.subviews) {
            if ([sibling isKindOfClass:%c(LGLiveBackdropView)] && sibling != minusView && CGRectEqualToRect(sibling.frame, minusView.frame)) {
                [sibling removeFromSuperview];
            }
        }
    }

    for (UIView *subview in minusView.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"Material"]) {
            for (UIView *innerView in subview.subviews) {
                innerView.hidden = YES;
                innerView.alpha = 0;
            }
        }
    }

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    UIImageView *minusIcon = [[UIImageView alloc] initWithFrame:minusView.bounds];
    minusIcon.image = [UIImage systemImageNamed:@"minus" withConfiguration:config];
    minusIcon.tintColor = [UIColor labelColor];
    minusIcon.contentMode = UIViewContentModeCenter;
    minusIcon.tag = 997;
    [minusView addSubview:minusIcon];

    CGFloat height = minusView.bounds.size.height;
    LGAdjustableBlurView *blurView = [[LGAdjustableBlurView alloc] initWithFrame:minusView.bounds blurRadius:4.0];
    blurView.qualityScale = 0.35;
    blurView.capturesAppIcon = YES;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.clipsToBounds = YES;
    blurView.layer.cornerRadius = height / 2.0;
    blurView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
    blurView.tag = 996;

    CAGradientLayer *specularLayer = [CAGradientLayer layer];
    specularLayer.frame = minusView.bounds;
    specularLayer.cornerRadius = height / 2.0;
    specularLayer.name = @"dylv.minus.specular";
    specularLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.85].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.15].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.15].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.40].CGColor
    ];
    specularLayer.locations = @[@0.0, @0.35, @0.65, @1.0];
    specularLayer.startPoint = CGPointMake(0, 0);
    specularLayer.endPoint = CGPointMake(1, 1);

    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.frame = minusView.bounds;
    mask.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(minusView.bounds, 0.6, 0.6)].CGPath;
    mask.lineWidth = 1.2;
    mask.fillColor = [UIColor clearColor].CGColor;
    mask.strokeColor = [UIColor whiteColor].CGColor;
    specularLayer.mask = mask;

    [minusView insertSubview:blurView atIndex:0];
    [minusView.layer insertSublayer:specularLayer above:blurView.layer];
}

static void updateLiquidGlassLayoutForMinus(UIView *minusView) {
    if (minusView.superview) {
        for (UIView *sibling in minusView.superview.subviews) {
            if ([sibling isKindOfClass:%c(LGLiveBackdropView)] && sibling != minusView && CGRectEqualToRect(sibling.frame, minusView.frame)) {
                [sibling removeFromSuperview];
            }
        }
    }

    LGAdjustableBlurView *blurView = [minusView viewWithTag:996];
    if (blurView) {
        blurView.frame = minusView.bounds;
        blurView.layer.cornerRadius = minusView.bounds.size.height / 2.0;
    }

    for (CALayer *sublayer in minusView.layer.sublayers) {
        if ([sublayer.name isEqualToString:@"dylv.minus.specular"]) {
            sublayer.frame = minusView.bounds;
            sublayer.cornerRadius = minusView.bounds.size.height / 2.0;
            if ([sublayer.mask isKindOfClass:[CAShapeLayer class]]) {
                CAShapeLayer *mask = (CAShapeLayer *)sublayer.mask;
                mask.frame = minusView.bounds;
                mask.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(minusView.bounds, 0.6, 0.6)].CGPath;
            }
        }
    }

    UIImageView *minusIcon = [minusView viewWithTag:997];
    if (minusIcon) {
        minusIcon.frame = minusView.bounds;
    }

    for (UIView *subview in minusView.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"Material"]) {
            for (UIView *innerView in subview.subviews) {
                innerView.hidden = YES;
                innerView.alpha = 0;
            }
        }
    }
}

%hook SBMinusCloseBoxView

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    setupLiquidGlassForMinusButton(view);
    updateLiquidGlassLayoutForMinus(view);
}

%end

static void setupLiquidGlassForPageCell(UIView *cell) {
    for (UIView *subview in cell.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"MTMaterialView")] && subview.frame.size.height > 100) {
            subview.hidden = YES;
            subview.alpha = 0;
        } else if ([NSStringFromClass([subview class]) isEqualToString:@"UIView"] && subview.frame.size.height > 100) {
            subview.hidden = YES;
            subview.alpha = 0;
        }
    }

    if ([cell viewWithTag:991]) return;

    CGRect cardFrame = CGRectZero;
    for (UIView *subview in cell.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"MTMaterialView")] && subview.frame.size.height > 100) {
            cardFrame = subview.frame;
            break;
        }
    }

    if (CGRectIsEmpty(cardFrame)) return;

    LGAdjustableBlurView *blurView = [[LGAdjustableBlurView alloc] initWithFrame:cardFrame blurRadius:15.0];
    blurView.qualityScale = 0.50;
    blurView.clipsToBounds = YES;
    blurView.tag = 991;
    [blurView.layer setValue:@"dylv.liquidglass.blur.pageCell" forKey:@"groupName"];

    LGLiveBackdropView *lgView = [[LGLiveBackdropView alloc] initWithFrame:cardFrame];
    lgView.qualityScale = 0.50;
    lgView.clipsToBounds = YES;
    lgView.tag = 992;
    lgView.layer.borderWidth = 0.5;
    lgView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;

    [cell insertSubview:blurView atIndex:0];
    [cell insertSubview:lgView aboveSubview:blurView];

    __weak LGLiveBackdropView *weakBackdrop = lgView;
    for (NSNumber *delay in @[@0.5, @1.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakBackdrop forceReapplyForRegistrationRace];
        });
    }
}

static void updateLiquidGlassLayoutForPageCell(UIView *cell) {
    LGAdjustableBlurView *blurView = [cell viewWithTag:991];
    LGLiveBackdropView *lgView = [cell viewWithTag:992];

    if (blurView && lgView) {
        BOOL isAnimating = cell.bounds.size.width > 120;

        for (UIView *subview in cell.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"MTMaterialView")] && subview.frame.size.height > 100) {
                blurView.frame = subview.frame;
                lgView.frame = subview.frame;

                CGFloat cr = subview.layer.cornerRadius;
                if (cr > 0) {
                    blurView.layer.cornerRadius = cr;
                    lgView.layer.cornerRadius = cr;
                } else {
                    blurView.layer.cornerRadius = 24.0;
                    lgView.layer.cornerRadius = 24.0;
                }

                if (isAnimating) {
                    blurView.hidden = YES;
                    lgView.hidden = YES;
                    subview.hidden = NO;
                    subview.alpha = 1;
                } else {
                    blurView.hidden = NO;
                    lgView.hidden = NO;
                    subview.hidden = YES;
                    subview.alpha = 0;
                }
            } else if ([NSStringFromClass([subview class]) isEqualToString:@"UIView"] && CGRectEqualToRect(subview.frame, blurView.frame)) {
                if (isAnimating) {
                    subview.hidden = NO;
                    subview.alpha = 1;
                } else {
                    subview.hidden = YES;
                    subview.alpha = 0;
                }
            }
        }
    }
}

%hook SBHPageManagementCellView

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    setupLiquidGlassForPageCell(view);
    updateLiquidGlassLayoutForPageCell(view);
}

%end

static void setupLiquidGlassForPageCheckbox(UIView *checkbox) {
    for (UIView *subview in checkbox.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"MTMaterialView")] ||
           ([NSStringFromClass([subview class]) isEqualToString:@"UIView"] && subview.subviews.count == 0)) {
            subview.hidden = YES;
            subview.alpha = 0;
        }
    }

    if ([checkbox viewWithTag:993]) return;

    LGAdjustableBlurView *blurView = [[LGAdjustableBlurView alloc] initWithFrame:checkbox.bounds blurRadius:4.0];
    blurView.capturesAppIcon = YES;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.clipsToBounds = YES;
    blurView.tag = 993;

    LGLiveBackdropView *lgView = [[LGLiveBackdropView alloc] initWithFrame:checkbox.bounds];
    lgView.capturesAppIcon = YES;
    lgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    lgView.clipsToBounds = YES;
    lgView.tag = 994;
    lgView.layer.borderWidth = 0.5;
    lgView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;

    [checkbox insertSubview:blurView atIndex:0];
    [checkbox insertSubview:lgView atIndex:1];

    __weak LGLiveBackdropView *weakBackdrop = lgView;
    for (NSNumber *delay in @[@0.5, @1.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakBackdrop forceReapplyForRegistrationRace];
        });
    }
}

static void updateLiquidGlassLayoutForPageCheckbox(UIView *checkbox) {
    LGAdjustableBlurView *blurView = [checkbox viewWithTag:993];
    LGLiveBackdropView *lgView = [checkbox viewWithTag:994];

    if (blurView && lgView) {
        blurView.layer.cornerRadius = checkbox.bounds.size.height / 2.0;
        lgView.layer.cornerRadius = checkbox.bounds.size.height / 2.0;

        for (UIView *subview in checkbox.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"MTMaterialView")] ||
               ([NSStringFromClass([subview class]) isEqualToString:@"UIView"] && subview.subviews.count == 0)) {
                subview.hidden = YES;
                subview.alpha = 0;
            }
        }
    }
}

%hook SBHPageManagementCheckbox

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    setupLiquidGlassForPageCheckbox(view);
    updateLiquidGlassLayoutForPageCheckbox(view);
}

%end

void Home26InitEditingButtonsHooks(void) {
    %init();
}
