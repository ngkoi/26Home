#import "Headers.h"
#import "LGButtonView.h"
#import "LGCustomIconGenerator2.h"
#import <notify.h>

static id GetIconGenerator() {
    return [LGCustomIconGenerator2 sharedGenerator];
}
#import <UIKit/UIKit.h>

BOOL g_tweakEnabled = YES;
BOOL g_bypassingIconHook = NO;

NSString *g_iconStyle = @"Default";
NSString *g_themeMode = @"Auto";
NSString *g_darkIconMode = @"Always";
NSString *g_tintColor = @"#00FFFF";
BOOL g_largeIconsEnabled = NO;
BOOL g_disableLiquidGlassIcons = NO;
BOOL g_keepAppIconBlur = YES;
NSDictionary *g_excludedApps = nil;
BOOL g_exceptionsApplyOnlyToSolid = YES;

BOOL isAppExcluded(NSString *bundleID) {
    if (!bundleID || !g_excludedApps) return NO;
    NSNumber *val = g_excludedApps[bundleID];
    BOOL isExcluded = val ? [val boolValue] : NO;
    
    if (!isExcluded) return NO;
    
    if (g_exceptionsApplyOnlyToSolid) {
        NSString *style = g_iconStyle ?: @"Default";
        // keep clear/tinted generated even if excluded
        if ([style isEqualToString:@"Clear"] || [style isEqualToString:@"Tinted"]) {
            return NO;
        }
    }
    
    return YES;
}
@interface _26HomeDimmingViewController : UIViewController
@end

@implementation _26HomeDimmingViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
    self.view.userInteractionEnabled = NO;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (self.view.window) {
        self.view.frame = self.view.window.bounds;
    }
}

@end

@interface _26HomeDimmingWindow : UIWindow
@end

@implementation _26HomeDimmingWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil; // pass-through touches completely
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO; // pass-through touches completely
}

- (BOOL)_canBecomeKeyWindow {
    return NO;
}

- (BOOL)_canAffectStatusBarAppearance {
    return NO;
}

- (BOOL)_shouldControlAutorotation {
    return YES;
}

@end

static _26HomeDimmingWindow *g_dimmingWindow = nil;

static void updateWallpaperDimmingState(BOOL animated) {
    if (!g_dimmingWindow) {
        g_dimmingWindow = [[_26HomeDimmingWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_dimmingWindow.userInteractionEnabled = NO;
        g_dimmingWindow.windowLevel = -2.5; // between wallpaper (-3.0) and hs (-2.0)
        g_dimmingWindow.rootViewController = [[_26HomeDimmingViewController alloc] init];
    }
    
    if (!g_dimmingWindow.windowScene) {
        for (UIScene *scene in [[UIApplication sharedApplication] valueForKey:@"connectedScenes"]) {
            if ([scene isKindOfClass:NSClassFromString(@"UIWindowScene")]) {
                g_dimmingWindow.windowScene = (UIWindowScene *)scene;
                break;
            }
        }
    }
    
    g_dimmingWindow.frame = [UIScreen mainScreen].bounds;
    if (g_dimmingWindow.rootViewController) {
        g_dimmingWindow.rootViewController.view.frame = g_dimmingWindow.bounds;
    }
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    BOOL shouldDim = [defaults boolForKey:@"ngkhoi.26home.dimWallpaper"];
    
    if (shouldDim) {
        g_dimmingWindow.hidden = NO;
        if (animated) {
            [UIView animateWithDuration:0.3 animations:^{
                g_dimmingWindow.alpha = 1.0;
            }];
        } else {
            g_dimmingWindow.alpha = 1.0;
        }
    } else {
        if (animated) {
            [UIView animateWithDuration:0.3 animations:^{
                g_dimmingWindow.alpha = 0.0;
            } completion:^(BOOL finished) {
                if (![defaults boolForKey:@"ngkhoi.26home.dimWallpaper"]) {
                    g_dimmingWindow.hidden = YES;
                }
            }];
        } else {
            g_dimmingWindow.alpha = 0.0;
            g_dimmingWindow.hidden = YES;
        }
    }
}

CGFloat g_appIconBlurRadius = 1.0;
BOOL g_isAppOpening = NO;
BOOL g_isFolderOpen = NO;
BOOL g_isHomeScreenVisible = YES;
BOOL g_isSwitcherOpen = NO;
BOOL g_isCoverSheetVisible = NO;
BOOL g_isEditingMode = NO;
NSString *g_menuAppearance = @"iOS26";

void reload26HomePrefs(void) {
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));
    
    Boolean enableKeyExists = false;
    Boolean enabled = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.enabled"), CFSTR("com.ngkhoi.26home"), &enableKeyExists);
    g_tweakEnabled = enableKeyExists ? enabled : YES;
    
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    g_iconStyle = [prefs stringForKey:@"ngkhoi.26home.iconStyle"] ?: @"Default";
    g_themeMode = [prefs stringForKey:@"ngkhoi.26home.themeMode"] ?: @"Auto";
    g_darkIconMode = [prefs stringForKey:@"ngkhoi.26home.darkIconMode"] ?: @"Always";
    g_tintColor = [prefs stringForKey:@"ngkhoi.26home.tintColor"] ?: @"#00FFFF";
    g_largeIconsEnabled = [prefs boolForKey:@"ngkhoi.26home.largeIcons"];
    g_disableLiquidGlassIcons = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.disableLiquidGlassIcons"), CFSTR("com.ngkhoi.26home"), NULL);
    g_excludedApps = [prefs dictionaryForKey:@"ngkhoi.26home.excludedApps"] ?: @{};
    if ([prefs objectForKey:@"ngkhoi.26home.exceptionsApplyOnlyToSolid"]) {
        g_exceptionsApplyOnlyToSolid = [prefs boolForKey:@"ngkhoi.26home.exceptionsApplyOnlyToSolid"];
    } else {
        g_exceptionsApplyOnlyToSolid = YES;
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
}

static void notifyAllIconsVisibilityChanged(void) {
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
                if ([iconView respondsToSelector:@selector(_26home_updateGlassVisibility)]) {
                    [iconView performSelector:@selector(_26home_updateGlassVisibility)];
                }
            });
        }
    }
}

static __weak id g_editingDoneTarget = nil;
static SEL g_editingDoneAction = NULL;

static void replaceMaterialViewWithLiquidGlass(UIView *button, CGFloat blurRadius) {
    if ([button viewWithTag:999]) return; // already applied
    
    // hide native subviews
    for (UIView *subview in button.subviews) {
        subview.hidden = YES;
        subview.alpha = 0;
    }
    
    CGFloat width = 56.0;
    CGFloat height = 28.0;
    CGRect b = button.bounds;
    CGFloat x = (b.size.width > width) ? (b.size.width - width) / 2.0 : 0;
    CGFloat y = (b.size.height > height) ? (b.size.height - height) / 2.0 : 0;
    CGRect initialFrame = CGRectMake(x, y, width, height);
    
    NSString *title = [button isKindOfClass:%c(SBHEditingDoneButton)] ? @"Done" : @"Edit";
    LGButtonView *btnView = [[LGButtonView alloc] initWithFrame:initialFrame title:title blurRadius:blurRadius];
    btnView.tag = 999;
    [button addSubview:btnView];
    
    // reapply filters if race on launch
    __weak LGLiveBackdropView *weakBackdrop = btnView.lgView;
    for (NSNumber *delay in @[@0.5, @1.5, @3.0, @5.0, @8.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakBackdrop forceReapplyForRegistrationRace];
        });
    }
}

static void updateLiquidGlassLayout(UIView *button) {
    LGButtonView *coverView = (LGButtonView *)[button viewWithTag:999];
    if (coverView && [coverView isKindOfClass:[LGButtonView class]]) {
        CGFloat width = 56.0;
        CGFloat height = 28.0;
        CGRect b = button.bounds;
        CGFloat x = (b.size.width > width) ? (b.size.width - width) / 2.0 : 0;
        CGFloat y = (b.size.height > height) ? (b.size.height - height) / 2.0 : 0;
        [coverView updateLayoutWithFrame:CGRectMake(x, y, width, height)];
    }
    
    // keep native subviews hidden
    for (UIView *subview in button.subviews) {
        if (subview.tag != 999) {
            subview.hidden = YES;
            subview.alpha = 0;
        }
    }
}

%group SpringBoardHooks

%hook SBHEditingWidgetButton

- (void)layoutSubviews {
    %orig;
    updateLiquidGlassLayout(self);
}










- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        replaceMaterialViewWithLiquidGlass(self, 8.0);
        
        // context menu on ios 14+
        if (@available(iOS 14.0, *)) {
            self.showsMenuAsPrimaryAction = YES;
            __weak typeof(self) weakSelf = self;
            
            UIAction *addWidget = [UIAction actionWithTitle:@"Add Widget" image:LGImageNamed(@"widget.small.badge.plus") identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                UIViewController *vc = getViewControllerForView(weakSelf);
                if ([vc isKindOfClass:%c(SBRootFolderController)]) {
                    [(SBRootFolderController *)vc rootFolderViewWantsWidgetEditingViewControllerPresented:nil];
                }
            }];
            
            UIAction *customize = [UIAction actionWithTitle:@"Customize" image:LGImageNamed(@"apps.iphone.badge.paintbrush") identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                // tap done button to exit edit mode
                if (g_editingDoneTarget && g_editingDoneAction) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [g_editingDoneTarget performSelector:g_editingDoneAction withObject:nil];
#pragma clang diagnostic pop
                }
                
                // fallback: tell iconcontroller to stop editing
                id iconController = [%c(SBIconController) sharedInstance];
                if ([iconController respondsToSelector:@selector(setIsEditing:)]) {
                    void (*setIsEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconController methodForSelector:@selector(setIsEditing:)];
                    if (setIsEditing) {
                        setIsEditing(iconController, @selector(setIsEditing:), NO);
                    }
                }
                
                UIViewController *vc = getViewControllerForView(weakSelf);
                if ([vc isKindOfClass:%c(SBRootFolderController)]) {
                    SBRootFolderController *rootVC = (SBRootFolderController *)vc;
                    [rootVC setEditing:NO animated:YES];
                    
                    // tap done button on screen
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
                        // fallback: loop view controllers to exit edit mode
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
                    
                    HomeCustomizationMenuContainer *container = [[HomeCustomizationMenuContainer alloc] initWithFrame:rootVC.view.bounds];
                    [container presentInView:rootVC.view];
                }
            }];
            
            UIAction *editWallpaper = [UIAction actionWithTitle:@"Edit Wallpaper" image:LGImageNamed(@"apple.photos") identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                id iconController = [%c(SBIconController) sharedInstance];
                if ([iconController respondsToSelector:@selector(setIsEditing:)]) {
                    void (*setIsEditing)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[iconController methodForSelector:@selector(setIsEditing:)];
                    if (setIsEditing) {
                        setIsEditing(iconController, @selector(setIsEditing:), NO);
                    }
                }
                
                UIViewController *vc = getViewControllerForView(weakSelf);
                if ([vc respondsToSelector:@selector(setEditing:animated:)]) {
                    // safe setEditing:animated: call
                    void (*setEditing)(id, SEL, BOOL, BOOL) = (void (*)(id, SEL, BOOL, BOOL))[vc methodForSelector:@selector(setEditing:animated:)];
                    if (setEditing) {
                        setEditing(vc, @selector(setEditing:animated:), NO, YES);
                    }
                }
                
                // bg dispatch to avoid sb main thread deadlock on ipc
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSURL *url = [NSURL URLWithString:@"prefs:root=Wallpaper"];
                    id workspace = [NSClassFromString(@"LSApplicationWorkspace") performSelector:@selector(defaultWorkspace)];
                    [workspace performSelector:@selector(openSensitiveURL:withOptions:) withObject:url withObject:nil];
                });
            }];
            
            UIAction *editPages = [UIAction actionWithTitle:@"Edit Pages" image:LGImageNamed(@"apps.iphone.on.rectangle.portrait") identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                UIViewController *vc = getViewControllerForView(weakSelf);
                if ([vc isKindOfClass:%c(SBRootFolderController)]) {
                    [(SBRootFolderController *)vc _presentPageManagement:nil];
                }
            }];
            
            self.menu = [UIMenu menuWithTitle:@"" children:@[addWidget, customize, editWallpaper, editPages]];
            [self removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        }
    }
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator {
    if ([self respondsToSelector:@selector(contextMenuInteraction:willDisplayMenuForConfiguration:animator:)]) {
        %orig;
    }
    self.alpha = 0.01;
}

- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator {
    if ([self respondsToSelector:@selector(contextMenuInteraction:willEndForConfiguration:animator:)]) {
        %orig;
    }
    self.alpha = 1.0;
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
        return YES; // keep tracking
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    g_isCoverSheetVisible = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
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
        return YES; // keep tracking
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
    if ([minusView viewWithTag:996]) return;
    
    CGFloat height = minusView.bounds.size.height;
    
    // hide native material bg and glyphs
    for (UIView *subview in minusView.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"Material"]) {
            for (UIView *innerView in subview.subviews) {
                innerView.hidden = YES;
                innerView.alpha = 0;
            }
        }
    }
    
    LGAdjustableBlurView *blurView = [[LGAdjustableBlurView alloc] initWithFrame:minusView.bounds blurRadius:4.0];
    blurView.qualityScale = 0.35;
    blurView.capturesAppIcon = YES;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.clipsToBounds = YES;
    blurView.layer.cornerRadius = height / 2.0;
    blurView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
    blurView.tag = 996;
    
    // specular rim layer
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
    
    // custom minus glyph
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBold];
    UIImageView *minusIcon = [[UIImageView alloc] initWithFrame:minusView.bounds];
    minusIcon.image = [UIImage systemImageNamed:@"minus" withConfiguration:config];
    minusIcon.tintColor = [UIColor labelColor];
    minusIcon.contentMode = UIViewContentModeCenter;
    minusIcon.tag = 997;
    [minusView insertSubview:minusIcon atIndex:1];
}

static void updateLiquidGlassLayoutForMinus(UIView *minusView) {
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
    if ([cell viewWithTag:991]) return;
    
    CGRect cardFrame = CGRectZero;
    for (UIView *subview in cell.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"MTMaterialView")] && subview.frame.size.height > 100) {
            cardFrame = subview.frame;
            subview.hidden = YES;
            subview.alpha = 0;
        } else if ([NSStringFromClass([subview class]) isEqualToString:@"UIView"] && CGRectEqualToRect(subview.frame, cardFrame)) {
            subview.hidden = YES;
            subview.alpha = 0;
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
        BOOL isAnimating = cell.bounds.size.width > 120; // normal width ~90
        
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

static void setupLiquidGlassForPageCheckbox(UIView *checkbox) {
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

%hook SBHPageManagementCellView

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    setupLiquidGlassForPageCell(view);
    updateLiquidGlassLayoutForPageCell(view);
}

%end



@interface SBIcon : NSObject
- (UIImage *)unmaskedIconImageWithInfo:(struct SBIconImageInfo)info;
- (UIImage *)iconImageWithInfo:(struct SBIconImageInfo)info;
- (NSString *)applicationBundleID;
@end

@class SBHPageManagementCheckbox; @class SBFolderIconImageView; @class SBHEditingDoneButton; @class SBHPageManagementCellView; @class SBMinusCloseBoxView; @class SBIconBadgeView; @class SBIconImageView; @class SBHEditingWidgetButton; @class SBIconView; @class SpringBoard; @class SBRootFolderController; @class SBHShadowedWidgetView; @class SBHWidgetWrapperView; @class SBHWidgetContainerView;

%hook SBHPageManagementCheckbox

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    setupLiquidGlassForPageCheckbox(view);
    updateLiquidGlassLayoutForPageCheckbox(view);
}

%end

static void _26home_applyWidgetTintToView(UIView *view);
static void _26home_recursivelyApplyWidgetTint(UIView *view);

static void ForceLayoutAllIconViews(UIView *view) {
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

static BOOL g_isAnimatingScale = NO;
static BOOL g_eyedropperActive = NO;

static void updateTintViews(UIView *view, UIColor *tintColor) {
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

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    updateWallpaperDimmingState(NO);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateWallpaperDimming" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            updateWallpaperDimmingState(YES);
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

%hook SBDockView
- (void)layoutSubviews {
    %orig;
    if (g_eyedropperActive) {
        self.alpha = 0.0;
    } else if (self.alpha < 1.0) {
        self.alpha = 1.0;
    }
}
%end

static void invertLeafLayers(CALayer *parentLayer, BOOL apply, CGSize parentBoundsSize) {
    if (!parentLayer) return;
    for (CALayer *layer in parentLayer.sublayers) {
        BOOL isFullBackgroundPlate = (layer.contents != nil && 
                                     layer.bounds.size.width >= parentBoundsSize.width * 0.95 && 
                                     layer.bounds.size.height >= parentBoundsSize.height * 0.95);
        if (!isFullBackgroundPlate) {
            if (layer.sublayers.count == 0) {
                if (apply) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id invertFilter = [NSClassFromString(@"CAFilter") performSelector:NSSelectorFromString(@"filterWithType:") withObject:@"colorInvert"];
#pragma clang diagnostic pop
                    if (invertFilter) layer.filters = @[invertFilter];
                } else {
                    layer.filters = nil;
                }
            } else {
                invertLeafLayers(layer, apply, parentBoundsSize);
            }
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
        
        BOOL needsWhiteHands = NO;
        if ([g_iconStyle isEqualToString:@"Dark"] || [g_iconStyle isEqualToString:@"Tinted"]) needsWhiteHands = YES;
        else if ([g_iconStyle isEqualToString:@"Clear"] && isDarkTheme) needsWhiteHands = YES;
        
        NSString *currentConfig = [NSString stringWithFormat:@"%d", needsWhiteHands];
        NSString *lastConfig = objc_getAssociatedObject(view, @selector(updateClockHandsInversionForView:));
        if ([currentConfig isEqualToString:lastConfig]) return;
        
        invertLeafLayers(view.layer, needsWhiteHands, view.bounds.size);
        objc_setAssociatedObject(view, @selector(updateClockHandsInversionForView:), currentConfig, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
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
    
    UIView *iconImageView = [self valueForKey:@"_iconImageView"];
    if (iconImageView) {
        updateClockHandsInversionForView(iconImageView);
    }
    
    UIView *labelView = [self valueForKey:@"_labelView"];
    if (labelView) {
        labelView.hidden = g_largeIconsEnabled;
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
    
    BOOL isFolder = NO;
    if ([self respondsToSelector:@selector(isFolderIcon)]) {
        isFolder = ((BOOL (*)(id, SEL))[self methodForSelector:@selector(isFolderIcon)])(self, @selector(isFolderIcon));
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
    BOOL isExcludedApp = isAppExcluded(currentBundleID);
    
    BOOL isEditingMode = g_isEditingMode;
    if (!isEditingMode && [self respondsToSelector:@selector(isEditing)]) {
        isEditingMode = ((BOOL (*)(id, SEL))[self methodForSelector:@selector(isEditing)])(self, @selector(isEditing));
    }
    BOOL shouldHideForState = isExcludedApp || isEditingMode || !g_isHomeScreenVisible || g_isCoverSheetVisible || g_isSwitcherOpen || g_isAppOpening;
    if (shouldHideForState) {
        UIView *glassView = [self viewWithTag:9001];
        if (glassView) {
            glassView.hidden = YES;
            [glassView.layer setValue:@NO forKey:@"enabled"];
        }
        UIView *blurView = [self viewWithTag:9002];
        if (blurView) {
            blurView.hidden = YES;
            [blurView.layer setValue:@NO forKey:@"enabled"];
        }
        UIView *tintView = [self viewWithTag:9003];
        if (tintView) tintView.hidden = YES;
        return;
    }
    
    if (g_isFolderOpen) {
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
            UIView *glassView = [self viewWithTag:9001];
            if (glassView) {
                glassView.hidden = YES;
                [glassView.layer setValue:@NO forKey:@"enabled"];
            }
            UIView *blurView = [self viewWithTag:9002];
            if (blurView) {
                blurView.hidden = YES;
                [blurView.layer setValue:@NO forKey:@"enabled"];
            }
            UIView *tintView = [self viewWithTag:9003];
            if (tintView) tintView.hidden = YES;
            return;
        }
    }

    BOOL isClearOrTintedLight = ([style isEqualToString:@"Clear"] || ([style isEqualToString:@"Tinted"] && !isDarkTheme)) && iconImageView && !isFolder;
    
    BOOL shouldApplyGlass = !g_disableLiquidGlassIcons && isClearOrTintedLight;
    BOOL shouldApplyBlur = (shouldApplyGlass || (!g_disableLiquidGlassIcons ? NO : g_keepAppIconBlur)) && isClearOrTintedLight;
    
    if (shouldApplyBlur || shouldApplyGlass) {
        LGLiveBackdropView *glassView = [self viewWithTag:9001];
        LGAdjustableBlurView *blurView = [self viewWithTag:9002];
        UIView *tintView = [self viewWithTag:9003];
        
        UIView *container = iconImageView.superview ?: self;
        NSUInteger iconIndex = [container.subviews indexOfObject:iconImageView];
        if (iconIndex == NSNotFound) iconIndex = 0;
        
        CGFloat effectiveBlurRadius = g_appIconBlurRadius > 0.0 ? g_appIconBlurRadius : 1.0;
        
        if (shouldApplyBlur) {
            if (!blurView) {
                blurView = [[LGAdjustableBlurView alloc] initWithFrame:iconImageView.frame blurRadius:effectiveBlurRadius];
                blurView.qualityScale = 0.35;
                blurView.tag = 9002;
                [blurView.layer setValue:@"dylv.liquidglass.blur.shared" forKey:@"groupName"];
                blurView.layer.masksToBounds = YES;
                blurView.layer.cornerCurve = kCACornerCurveContinuous;
                [container insertSubview:blurView belowSubview:iconImageView];
            } else {
                blurView.blurRadius = effectiveBlurRadius;
            }
            blurView.hidden = NO;
        } else {
            [[self viewWithTag:9002] removeFromSuperview];
            blurView = nil;
        }
        
        if (shouldApplyGlass) {
            if (!glassView) {
                glassView = [[LGLiveBackdropView alloc] initWithFrame:iconImageView.frame];
                glassView.qualityScale = 0.35;
                glassView.capturesAppIcon = YES;
                glassView.tag = 9001;
                glassView.layer.masksToBounds = YES;
                glassView.layer.cornerCurve = kCACornerCurveContinuous;
                if (blurView) {
                    [container insertSubview:glassView aboveSubview:blurView];
                } else {
                    [container insertSubview:glassView belowSubview:iconImageView];
                }
                [glassView forceReapplyForRegistrationRace];
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
                tintView.layer.cornerCurve = kCACornerCurveContinuous;
                UIView *aboveView = glassView ?: blurView;
                if (aboveView) {
                    [container insertSubview:tintView aboveSubview:aboveView];
                } else {
                    [container insertSubview:tintView belowSubview:iconImageView];
                }
            }
            tintView.hidden = NO;
        } else {
            [[self viewWithTag:9003] removeFromSuperview];
            tintView = nil;
        }
        
        CGFloat standardCornerRadius = iconImageView.frame.size.width * 0.225;
        iconImageView.layer.cornerRadius = standardCornerRadius;
        iconImageView.layer.cornerCurve = kCACornerCurveContinuous;

        if (glassView) {
            glassView.bounds = iconImageView.bounds;
            glassView.center = iconImageView.center;
            glassView.transform = iconImageView.transform;
            glassView.layer.cornerRadius = standardCornerRadius;
            glassView.layer.cornerCurve = kCACornerCurveContinuous;
            glassView.layer.masksToBounds = YES;
            glassView.backgroundColor = [UIColor clearColor];
        }
        
        if (blurView) {
            blurView.bounds = iconImageView.bounds;
            blurView.center = iconImageView.center;
            blurView.transform = iconImageView.transform;
            blurView.layer.cornerRadius = iconImageView.frame.size.width * 0.225;
            blurView.backgroundColor = [UIColor clearColor];
        }
        
        if (tintView) {
            tintView.bounds = iconImageView.bounds;
            tintView.center = iconImageView.center;
            tintView.transform = iconImageView.transform;
            tintView.layer.cornerRadius = iconImageView.frame.size.width * 0.225;
            
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
    if (!glassView && !blurView && !tintView) return;
    
    NSString *currentBundleID = nil;
    if ([self respondsToSelector:@selector(icon)]) {
        id icon = [self performSelector:@selector(icon)];
        if (icon && [icon respondsToSelector:@selector(applicationBundleID)]) {
            currentBundleID = [icon performSelector:@selector(applicationBundleID)];
        }
    }
    if (isAppExcluded(currentBundleID)) {
        if (glassView) {
            glassView.hidden = YES;
            [glassView.layer setValue:@NO forKey:@"enabled"];
        }
        if (blurView) {
            blurView.hidden = YES;
            [blurView.layer setValue:@NO forKey:@"enabled"];
        }
        if (tintView) tintView.hidden = YES;
        return;
    }
    
    // hide glass in edit mode
    BOOL isEditingMode = g_isEditingMode;
    if (!isEditingMode && [self respondsToSelector:@selector(isEditing)]) {
        isEditingMode = ((BOOL (*)(id, SEL))[self methodForSelector:@selector(isEditing)])(self, @selector(isEditing));
    }
    if (isEditingMode) {
        if (glassView) {
            glassView.hidden = YES;
            [glassView.layer setValue:@NO forKey:@"enabled"];
        }
        if (blurView) {
            blurView.hidden = YES;
            [blurView.layer setValue:@NO forKey:@"enabled"];
        }
        if (tintView) tintView.hidden = YES;
        return;
    }

    // hide glass if hs is obscured / in-app
    if (!g_isHomeScreenVisible || g_isCoverSheetVisible || g_isSwitcherOpen || g_isAppOpening) {
        if (glassView) {
            glassView.hidden = YES;
            [glassView.layer setValue:@NO forKey:@"enabled"];
        }
        if (blurView) {
            blurView.hidden = YES;
            [blurView.layer setValue:@NO forKey:@"enabled"];
        }
        if (tintView) tintView.hidden = YES;
        return;
    }
    
    // hide glass while icon pressed
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
        if (tintView) tintView.hidden = YES;
        return;
    }
    
    // hide outside icons when folder open
    if (g_isFolderOpen) {
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
    
    // skip scaling in app library
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

@interface SBIconImageView : UIView
- (UIImage *)displayedImage;
- (struct SBIconImageInfo)iconImageInfo;
@end

%end // End SpringBoardHooks (part 1)

%group IconImageViewHooks

%hook SBIconImageView

- (void)updateImageAnimated:(BOOL)animated {
    %orig;
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
                UIImage *orig = [GetIconGenerator() originalImageForBundleID:bundleID];
                if (!orig) {
                    struct SBIconImageInfo info;
                    if ([self respondsToSelector:@selector(iconImageInfo)]) {
                        info = [(SBIconImageView *)self iconImageInfo];
                    } else {
                        info.size = CGSizeMake(60, 60);
                        info.scale = [UIScreen mainScreen].scale;
                        info.continuousCornerRadius = 13.5;
                    }
                    extern BOOL g_bypassingIconHook;
                    g_bypassingIconHook = YES;
                    if ([icon respondsToSelector:@selector(unmaskedIconImageWithInfo:)]) {
                        orig = [icon unmaskedIconImageWithInfo:info];
                    } else if ([icon respondsToSelector:@selector(iconImageWithInfo:)]) {
                        orig = [icon iconImageWithInfo:info];
                    }
                    g_bypassingIconHook = NO;
                    if (orig) {
                        [GetIconGenerator() saveOriginalImage:orig forBundleID:bundleID];
                    } else {
                        orig = image;
                    }
                }
                
                NSString *capturedBundleID = bundleID;
                __weak typeof(self) weakSelf = self;
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:capturedBundleID];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) return;
                        
                        id currentIcon = nil;
                        if ([strongSelf respondsToSelector:@selector(icon)]) {
                            currentIcon = [strongSelf performSelector:@selector(icon)];
                        }
                        if ([currentIcon respondsToSelector:@selector(applicationBundleID)]) {
                            NSString *currentBundleID = [currentIcon performSelector:@selector(applicationBundleID)];
                            if (currentBundleID && ![currentBundleID isEqualToString:capturedBundleID]) {
                                return; // recycled view
                            }
                        }
                        
                        void (^applyContents)(id) = ^(id contents) {
                            if (strongSelf.layer.contents != contents) {
                                if (animated) {
                                    CATransition *transition = [CATransition animation];
                                    transition.duration = 0.25;
                                    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                                    transition.type = kCATransitionFade;
                                    [strongSelf.layer addAnimation:transition forKey:@"contentsFade"];
                                }
                                strongSelf.layer.contents = contents;
                            }
                        };
                        
                        if (styled) {
                            applyContents((id)styled.CGImage);
                        } else {
                            applyContents((id)image.CGImage);
                        }
                    });
                });
            }
        }
    }
    updateClockHandsInversionForView(self);
}

- (void)layoutSubviews {
    %orig;
    self.layer.cornerRadius = self.bounds.size.width * 0.225;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    updateClockHandsInversionForView(self);
}

- (void)didMoveToWindow {
    %orig;
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

- (void)didMoveToSuperview {
    %orig;
    updateClockHandsInversionForView((UIView *)self);
}

%end

%end // End IconImageViewHooks

%group SpringBoardHooks // Resume SpringBoardHooks (part 2)

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
        badgeTextColor = [UIColor colorWithWhite:0.22 alpha:1.0]; // dark grey text
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
        
        // calc luminance for badge text contrast
        CGFloat luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        if (luminance > 0.55) {
            badgeTextColor = [UIColor colorWithWhite:0.12 alpha:1.0]; // dark text on bright bg
        } else {
            badgeTextColor = [UIColor whiteColor]; // white text on dark bg
        }
    } else {
        // default & dark stock red badge
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
        // stock badge (default & dark)
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

static void _26home_applyWidgetTintToView(UIView *view) {
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
        
        // parse tint color
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

static void _26home_recursivelyApplyWidgetTint(UIView *view) {
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

%hook SBFolderIconImageView

- (instancetype)initWithFrame:(CGRect)frame {
    id orig = %orig;
    return orig;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%new
- (void)_26home_forceUpdate {
    if ([(id)self respondsToSelector:@selector(_folderIcon)]) {
        id folderIcon = [(id)self performSelector:@selector(_folderIcon)];
        if (folderIcon) {
            if ([(id)self respondsToSelector:@selector(_folderIconImageCache)]) {
                id cache = [(id)self performSelector:@selector(_folderIconImageCache)];
                if ([cache respondsToSelector:@selector(rebuildImagesForFolderIcon:)]) {
                    [cache performSelector:@selector(rebuildImagesForFolderIcon:) withObject:folderIcon];
                }
                if ([cache respondsToSelector:@selector(informObserversOfUpdateForFolderIcon:)]) {
                    [cache performSelector:@selector(informObserversOfUpdateForFolderIcon:) withObject:folderIcon];
                }
            }
            if ([(id)self respondsToSelector:@selector(updateImageAnimated:)]) {
                [(id)self performSelector:@selector(updateImageAnimated:) withObject:@(NO)];
            }
        }
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
    if ([(id)self respondsToSelector:@selector(applicationBundleID)]) {
        NSString *bundleID = [(id)self performSelector:@selector(applicationBundleID)];
        if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
            if (isAppExcluded(bundleID)) return orig;
            [GetIconGenerator() saveOriginalImage:orig forBundleID:bundleID];
            UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:bundleID];
            if (styled) return styled;
        }
    }
    return orig;
}

- (UIImage *)unmaskedIconImageWithInfo:(struct SBIconImageInfo)info {
    if (g_bypassingIconHook) return %orig;
    UIImage *orig = %orig;
    if ([(id)self respondsToSelector:@selector(applicationBundleID)]) {
        NSString *bundleID = [(id)self performSelector:@selector(applicationBundleID)];
        if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
            if (isAppExcluded(bundleID)) return orig;
            [GetIconGenerator() saveOriginalImage:orig forBundleID:bundleID];
            UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:bundleID];
            if (styled) return styled;
        }
    }
    return orig;
}

- (UIImage *)generateIconImageWithInfo:(struct SBIconImageInfo)info {
    if (g_bypassingIconHook) return %orig;
    UIImage *orig = %orig;
    if ([(id)self respondsToSelector:@selector(applicationBundleID)]) {
        NSString *bundleID = [(id)self performSelector:@selector(applicationBundleID)];
        if (bundleID && [bundleID isKindOfClass:[NSString class]]) {
            if (isAppExcluded(bundleID)) return orig;
            [GetIconGenerator() saveOriginalImage:orig forBundleID:bundleID];
            UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:bundleID];
            if (styled) return styled;
        }
    }
    return orig;
}

%end

%hook SBHIconManager

- (void)setEditing:(BOOL)editing withFeedbackBehavior:(id)behavior {
    %orig;
    g_isEditingMode = editing;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)setEditing:(BOOL)editing {
    %orig;
    g_isEditingMode = editing;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.VisibilityStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)folderControllerWillOpen:(id)folderController {
    %orig;
    g_isFolderOpen = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.FolderStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)folderControllerDidClose:(id)folderController {
    %orig;
    g_isFolderOpen = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.FolderStateChanged" object:nil];
    notifyAllIconsVisibilityChanged();
}

- (void)iconTapped:(id)iconView {
    %orig;
    
    // hide glass during app launch for smooth anim
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


static void Home26TriggerGlobalRefresh(void) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
    });
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
    
    if (bundleID && isAppExcluded(bundleID)) {
        return orig;
    }
    
    if (bundleID && orig && orig.count > 0) {
        id firstObj = orig.firstObject;
        if ([firstObj isKindOfClass:[UIImage class]]) {
            UIImage *origImage = (UIImage *)firstObj;
            UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:origImage bundleID:bundleID];
            if (styled) {
                NSMutableArray *newIcons = [orig mutableCopy];
                newIcons[0] = styled;
                return [newIcons copy];
            }
        }
    }
    return orig;
}

%end

%hook NCNotificationViewController

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateContent) name:@"ngkhoi.26home.UpdateIconStyle" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ngkhoi.26home.UpdateIconStyle" object:nil];
    %orig;
}

%end

%hook SBIconController

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

%end // End SpringBoardHooks

%group UIKitHooks

%hook UIImage

+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale {
    UIImage *orig = %orig;
    if (!bundleID || !orig) return orig;
    if (isAppExcluded(bundleID)) return orig;
    
    NSString *style = g_iconStyle ?: @"Default";
    if ([style isEqualToString:@"Default"]) {
        return orig;
    }
    
    UIImage *baked = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:bundleID];
    if (baked) {
        if (orig.size.width > 0 && orig.size.height > 0 && !CGSizeEqualToSize(baked.size, orig.size)) {
            CGFloat targetScale = orig.scale > 0 ? orig.scale : (scale > 0 ? scale : [UIScreen mainScreen].scale);
            UIGraphicsBeginImageContextWithOptions(orig.size, NO, targetScale);
            [baked drawInRect:CGRectMake(0, 0, orig.size.width, orig.size.height)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (resized) return resized;
        }
        return baked;
    }
    
    return orig;
}

%end

%end // End UIKitHooks

%group SearchUIHooks

%hook SearchUIAppIconImage

- (void)loadImageWithScale:(double)scale isDarkStyle:(BOOL)isDark completionHandler:(void (^)(UIImage *))completionHandler {
    NSString *style = g_iconStyle ?: @"Default";
    if ([style isEqualToString:@"Default"] || !completionHandler) {
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
            UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:origImage bundleID:capturedBundleID];
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
    
    NSString *style = g_iconStyle ?: @"Default";
    if ([style isEqualToString:@"Default"]) {
        return orig;
    }
    
    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [self bundleIdentifier];
    }
    
    if (!bundleID || isAppExcluded(bundleID)) {
        return orig;
    }
    
    UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:bundleID];
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
    
    NSString *style = g_iconStyle ?: @"Default";
    if ([style isEqualToString:@"Default"]) {
        return orig;
    }
    
    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [self bundleIdentifier];
    }
    
    if (!bundleID || isAppExcluded(bundleID)) {
        return orig;
    }
    
    UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:bundleID];
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
    
    NSString *style = g_iconStyle ?: @"Default";
    if ([style isEqualToString:@"Default"]) {
        return orig;
    }
    
    NSString *bundleID = nil;
    if ([self respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [(id)self performSelector:@selector(bundleIdentifier)];
    }
    
    if (bundleID && !isAppExcluded(bundleID)) {
        UIImage *styled = [GetIconGenerator() requestIconImageWithBackgroundForImage:orig bundleID:bundleID];
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

%end

%end // End SearchUIHooks

%ctor {
    reload26HomePrefs();
    
    if (!g_tweakEnabled) {
        Home26Log(@"26Home is disabled via preferences. Skipping initialization.");
        return;
    }
    
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    BOOL isSpringBoard = [bundleId isEqualToString:@"com.apple.springboard"];
    
        %init(UIKitHooks);
    if (objc_getClass("SearchUIAppIconImage") || objc_getClass("SearchUIImage")) {
        %init(SearchUIHooks);
    }
    if (objc_getClass("SBIconImageView")) {
        %init(IconImageViewHooks);
    }
    
    if (isSpringBoard) {
        %init(SpringBoardHooks);
    
    void (^refreshKnownIcons)(void) = ^{
        Home26Log(@"--- refreshKnownIcons START ---");
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
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.PurgeCaches" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        Home26Log(@"=== PurgeCaches Notification Received ===");
        reload26HomePrefs();
        [GetIconGenerator() clearCache];
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
            
            // purge regular icon cache
            if ([iconManager respondsToSelector:@selector(iconImageCache)]) {
                id iconCache = [iconManager performSelector:@selector(iconImageCache)];
                if ([iconCache respondsToSelector:@selector(purgeAllCachedImages)]) {
                    Home26Log(@"Purging iconImageCache: %p", iconCache);
                    [iconCache performSelector:@selector(purgeAllCachedImages)];
                }
            }
            
            // wipe folder image cache maps
            if ([iconManager respondsToSelector:@selector(folderIconImageCache)]) {
                id folderCache = [iconManager performSelector:@selector(folderIconImageCache)];
                Home26Log(@"Found folderIconImageCache: %p", folderCache);
                if (folderCache) {
                    @try {
                        id cachedFolderImages = [folderCache valueForKey:@"_cachedFolderImages"];
                        Home26Log(@"folderCache _cachedFolderImages count before: %@", [cachedFolderImages respondsToSelector:@selector(count)] ? @([cachedFolderImages count]) : @"N/A");
                        if ([cachedFolderImages respondsToSelector:@selector(removeAllObjects)]) {
                            [cachedFolderImages removeAllObjects];
                            Home26Log(@"Cleared _cachedFolderImages!");
                        }
                        
                        id cachedMiniGridImages = [folderCache valueForKey:@"_cachedMiniGridImages"];
                        Home26Log(@"folderCache _cachedMiniGridImages count before: %@", [cachedMiniGridImages respondsToSelector:@selector(count)] ? @([cachedMiniGridImages count]) : @"N/A");
                        if ([cachedMiniGridImages respondsToSelector:@selector(removeAllObjects)]) {
                            [cachedMiniGridImages removeAllObjects];
                            Home26Log(@"Cleared _cachedMiniGridImages!");
                        }
                    } @catch (NSException *e) {
                        Home26Log(@"Exception clearing folder cache ivars: %@", e);
                    }
                    
                    // enumerate icon views and rebuild folder icons
                    if ([iconManager respondsToSelector:@selector(enumerateKnownIconViewsUsingBlock:)]) {
                        void (*enumerate)(id, SEL, void (^)(id)) = (void (*)(id, SEL, void (^)(id)))[iconManager methodForSelector:@selector(enumerateKnownIconViewsUsingBlock:)];
                        enumerate(iconManager, @selector(enumerateKnownIconViewsUsingBlock:), ^(UIView *iconView) {
                            id icon = [iconView respondsToSelector:@selector(icon)] ? [iconView performSelector:@selector(icon)] : nil;
                            BOOL isFolder = NO;
                            if (icon && [icon respondsToSelector:@selector(isFolderIcon)]) {
                                isFolder = ((BOOL (*)(id, SEL))[icon methodForSelector:@selector(isFolderIcon)])(icon, @selector(isFolderIcon));
                            }
                            
                            if (isFolder && icon) {
                                Home26Log(@"Rebuilding folder icon: %@", icon);
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
                        });
                    }
                }
            }
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateIconStyle" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        Home26Log(@"=== UpdateIconStyle Notification Received ===");
        reload26HomePrefs();
        [GetIconGenerator() clearCache];
        refreshKnownIcons();
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"ngkhoi.26home.UpdateLargeIcons" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        Home26Log(@"=== UpdateLargeIcons Notification Received ===");
        reload26HomePrefs();
    }];
    
    // sync prefs changes via darwin notify
    int clearToken;
    notify_register_dispatch("ngkhoi.26home.clearCache", &clearToken, dispatch_get_main_queue(), ^(int token) {
        Home26Log(@"=== Darwin clearCache Notification Received ===");
        reload26HomePrefs();
        [GetIconGenerator() clearDiskCache];
        Home26TriggerGlobalRefresh();
        refreshKnownIcons();
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.IconReady" object:nil];
    });

    int styleToken;
    notify_register_dispatch("ngkhoi.26home.UpdateIconStyle", &styleToken, dispatch_get_main_queue(), ^(int token) {
        Home26Log(@"=== Darwin UpdateIconStyle Notification Received ===");
        reload26HomePrefs();
        [GetIconGenerator() clearCache];
        refreshKnownIcons();
    });
    
    int largeToken;
    notify_register_dispatch("ngkhoi.26home.UpdateLargeIcons", &largeToken, dispatch_get_main_queue(), ^(int token) {
        Home26Log(@"=== Darwin UpdateLargeIcons Notification Received ===");
        reload26HomePrefs();
        refreshKnownIcons();
    });
    
    // auto theme switch on dark mode toggle
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
    } else {
        int clearToken;
        notify_register_dispatch("ngkhoi.26home.clearCache", &clearToken, dispatch_get_main_queue(), ^(int token) {
            reload26HomePrefs();
            [GetIconGenerator() clearDiskCache];
        });

        int styleToken;
        notify_register_dispatch("ngkhoi.26home.UpdateIconStyle", &styleToken, dispatch_get_main_queue(), ^(int token) {
            reload26HomePrefs();
            [GetIconGenerator() clearCache];
        });
    }
}





