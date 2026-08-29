#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#if __has_include(<roothide.h>)
#import <roothide.h>
#else
#define jbroot(path) [@"/var/jb" stringByAppendingString:path]
#endif

#import "LGDebugger.h"

@interface SBHEditingWidgetButton : UIButton
@end

@interface SBHEditingDoneButton : UIButton
@end

@interface SBHPageManagementCheckbox : UIView
@end

@interface SBMinusCloseBoxView : UIView
@end

@interface SBHPageManagementCellView : UIView
@end

@interface SBDockView : UIView
@end

struct SBIconImageInfo {
    CGSize size;
    CGFloat scale;
    CGFloat continuousCornerRadius;
};

@interface SBRootFolderView : UIView
@end

@class SBIcon;

@interface SBFolderIconImageCache : NSObject
@end

@interface SBIconView : UIView
@property (nonatomic, retain) SBIcon *icon; 
@property (nonatomic, strong, readwrite) SBFolderIconImageCache *folderIconImageCache;
- (void)_26home_updateGlassVisibility;
- (void)_26home_updateIconStyle;
- (void)_26home_updateCustomScale;
- (BOOL)isHighlighted;
- (BOOL)isTouchDown;
@end

@interface SpringBoard : UIApplication
@end

@interface SBRootFolderController : UIViewController
- (void)_presentPageManagement:(id)arg1;
- (void)rootFolderViewWantsWidgetEditingViewControllerPresented:(id)arg1;
- (void)setEditing:(BOOL)arg1 animated:(BOOL)arg2;
@end

@interface SBIconController : UIViewController
+ (id)sharedInstance;
- (void)setIsEditing:(BOOL)editing;
@end

@interface SBFolderView : UIView
@end

@interface SBFloatyFolderView : SBFolderView
@end

@interface SBFolderController : NSObject
@end

@interface SBFloatyFolderController : SBFolderController
@end

@interface SBUIAnimationController : NSObject
@end

@interface SBHIconManager : NSObject
@end

@interface SBHomeScreenViewController : UIViewController
@end

@interface SBFluidSwitcherViewController : UIViewController
@end

@interface CSCoverSheetViewController : UIViewController
@end

@interface SBFolderContainerView : UIView
@end

static inline __attribute__((unused)) UIViewController *getViewControllerForView(UIView *view) {
    UIResponder *responder = view;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

static NSString * const kLGFilterType = @"dylv.liquidglass.refraction";

extern NSString *g_iconStyle;
extern NSString *g_themeMode;
extern NSString *g_darkIconMode;
extern NSString *g_tintColor;
extern BOOL g_largeIconsEnabled;
extern BOOL g_disableLiquidGlassIcons;
extern BOOL g_keepAppIconBlur;
extern CGFloat g_appIconBlurRadius;
extern BOOL g_isAppOpening;
extern BOOL g_isFolderOpen;
extern BOOL g_isHomeScreenVisible;
extern BOOL g_isSwitcherOpen;
extern BOOL g_isCoverSheetVisible;
extern BOOL g_isEditingMode;
extern void reload26HomePrefs(void);

static inline UIImage *LGImageNamed(NSString *name) {
    NSString *path = jbroot([NSString stringWithFormat:@"/Library/Application Support/26Home/Icons/%@@3x.png", name]);
    UIImage *img = [UIImage imageWithContentsOfFile:path];
    if (img) return [[[UIImage alloc] initWithCGImage:img.CGImage scale:3.0 orientation:img.imageOrientation] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    path = jbroot([NSString stringWithFormat:@"/Library/Application Support/26Home/Icons/%@@2x.png", name]);
    img = [UIImage imageWithContentsOfFile:path];
    if (img) return [[[UIImage alloc] initWithCGImage:img.CGImage scale:2.0 orientation:img.imageOrientation] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    path = jbroot([NSString stringWithFormat:@"/Library/Application Support/26Home/Icons/%@.png", name]);
    img = [UIImage imageWithContentsOfFile:path];
    if (img) return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    return [[UIImage systemImageNamed:name] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface LGLiveBackdropView : UIView
@property (nonatomic, assign) BOOL capturesAppIcon;
@property (nonatomic, assign) CGFloat qualityScale;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)applyFilters;
- (void)forceReapplyForRegistrationRace;
@end

@interface LGAdjustableBlurView : UIView
@property (nonatomic, assign) CGFloat blurRadius;
@property (nonatomic, assign) BOOL capturesAppIcon;
@property (nonatomic, assign) CGFloat qualityScale;
- (instancetype)initWithFrame:(CGRect)frame blurRadius:(CGFloat)radius;
- (void)applyFilters;
@end

@interface LGEyedropperOverlayView : UIView
@property (nonatomic, strong) UIImage *wallpaperSnapshot;
@property (nonatomic, strong) UIView *loupeView;
@property (nonatomic, strong) UIView *loupeColorView;
@property (nonatomic, copy) void (^onColorSelected)(UIColor *color);
- (instancetype)initWithFrame:(CGRect)frame wallpaper:(UIImage *)wallpaper;
@end

@interface HomeCustomizationMenuContainer : UIView
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) UIView *highlightPill;
@property (nonatomic, strong) NSMutableArray<UILabel *> *styleLabels;
@property (nonatomic, strong) UIView *themePill;
@property (nonatomic, strong) NSMutableArray<UILabel *> *themeLabels;
@property (nonatomic, strong) NSMutableArray<UIButton *> *themeButtons;

// tinted mode ui
@property (nonatomic, strong) UIView *slidersContainer;
@property (nonatomic, strong) UIView *hueSlider;
@property (nonatomic, strong) UIView *hueThumb;
@property (nonatomic, strong) UIView *brightnessSlider;
@property (nonatomic, strong) UIView *brightnessThumb;
@property (nonatomic, strong) CAGradientLayer *hueGradient;
@property (nonatomic, strong) CAGradientLayer *brightnessGradient;
@property (nonatomic, assign) CGFloat currentHue;
@property (nonatomic, assign) CGFloat currentBrightness;

- (void)presentInView:(UIView *)view;
- (void)dismiss;
@end

@interface HomeCustomizationMenuContainer18 : UIView
@property (nonatomic, strong) UIView *menuView;
- (void)presentInView:(UIView *)view;
- (void)dismiss;
@end

@interface NCNotificationRequest : NSObject
- (NSString *)sectionIdentifier;
@end

@interface NCNotificationRequestContentProvider : NSObject
- (NCNotificationRequest *)notificationRequest;
- (NSArray *)icons;
@end

@interface NCNotificationContent : NSObject
- (NSArray *)icons;
- (UIImage *)icon;
@end

@interface NCNotificationShortLookView : UIView
- (void)setProminentIcon:(UIImage *)icon;
- (void)setSubordinateIcon:(UIImage *)icon;
- (void)setIcons:(NSArray *)icons;
@end

@interface NCNotificationAppSectionListHeaderView : UIView
- (void)setIconImage:(UIImage *)image;
@end

@interface NCNotificationSummaryExpandedHeaderView : UIView
- (void)setIcon:(UIImage *)icon;
- (void)setIcons:(NSArray *)icons;
@end

@interface SearchUIAppIconImage : NSObject
- (NSString *)bundleIdentifier;
- (id)loadImageWithScale:(double)scale isDarkStyle:(BOOL)isDarkStyle;
- (id)generateImageWithFormat:(int)format scale:(double)scale;
- (void)loadImageWithScale:(double)scale isDarkStyle:(BOOL)isDark completionHandler:(void (^)(UIImage *))completionHandler;
@end


@interface SearchUIHomeScreenAppIconView : UIView
@end


@interface SearchUIImage : NSObject
- (UIImage *)uiImage;
@end


@interface NCNotificationViewController : UIViewController
- (void)updateContent;
@end


@interface SBHIconImageCache : NSObject
- (UIImage *)imageForIcon:(id)icon;
- (UIImage *)unmaskedImageForIcon:(id)icon;
- (UIImage *)_iconImageWithInfo:(struct SBIconImageInfo)info forIcon:(id)icon;
- (UIImage *)_unmaskedIconImageWithInfo:(struct SBIconImageInfo)info forIcon:(id)icon;
@end

extern BOOL isAppExcluded(NSString *bundleID);
