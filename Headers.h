#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#if __has_include(<roothide.h>)
#import <roothide.h>
#else
static inline NSString *Home26JbRoot(NSString *path) {
    if (!path) return nil;
    static NSString *s_jbroot_prefix = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typedef const char *(*roothide_jbroot_t)(const char *);
        roothide_jbroot_t roothide_fn = (roothide_jbroot_t)dlsym(RTLD_DEFAULT, "jbroot");
        if (roothide_fn) {
            const char *res = roothide_fn("/Library");
            if (res) {
                NSString *str = [NSString stringWithUTF8String:res];
                if ([str hasSuffix:@"/Library"]) {
                    s_jbroot_prefix = [str substringToIndex:str.length - @"/Library".length];
                }
            }
        }
        if (!s_jbroot_prefix) {
            typedef const char *(*libroot_prefix_t)(void);
            libroot_prefix_t libroot_fn = (libroot_prefix_t)dlsym(RTLD_DEFAULT, "libroot_dyn_get_jbroot_prefix");
            if (libroot_fn) {
                const char *res = libroot_fn();
                if (res && strlen(res) > 0) {
                    s_jbroot_prefix = [NSString stringWithUTF8String:res];
                }
            }
        }
        if (!s_jbroot_prefix) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
                s_jbroot_prefix = @"/var/jb";
            } else {
                s_jbroot_prefix = @"";
            }
        }
    });
    if (s_jbroot_prefix.length > 0) {
        if (![path hasPrefix:@"/"]) {
            return [s_jbroot_prefix stringByAppendingPathComponent:path];
        }
        return [s_jbroot_prefix stringByAppendingString:path];
    }
    return path;
}
#define jbroot(path) Home26JbRoot(path)
#endif

#import "LGDebugger.h"

@interface SBHEditingWidgetButton : UIButton
- (void)_26home_handleEditButtonTap;
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

static inline UIBezierPath *Home26CreateSquirclePath(CGRect rect, CGFloat radius) {
    return [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
}

@interface SBRootFolderView : UIView
@end

@interface SBIcon : NSObject
@property (nonatomic, copy, readonly) NSString *applicationBundleID;
- (NSString *)applicationBundleID;
- (UIImage *)unmaskedIconImageWithInfo:(struct SBIconImageInfo)info;
- (UIImage *)iconImageWithInfo:(struct SBIconImageInfo)info;
- (id)parentFolderIcon;
- (id)folder;
- (BOOL)isFolderIcon;
- (void)reloadIconImage;
- (void)purgeCachedImages;
- (void)_notifyImageDidUpdate;
@end

@interface SBFolderIconImageCache : NSObject
- (void)rebuildImagesForFolderIcon:(id)folderIcon;
- (void)informObserversOfUpdateForFolderIcon:(id)folderIcon;
- (void)folderIcon:(id)folderIcon containedIconImageDidUpdate:(id)containedIcon;
- (void)iconImageCache:(id)cache didUpdateImageForIcon:(id)icon;
@end

@interface SBFolderIcon : SBIcon
- (id)folder;
- (void)iconImageDidUpdate:(id)icon;
- (void)_26home_purgeCache;
@end

@interface SBIconView : UIView
@property (nonatomic, retain) SBIcon *icon;
@property (nonatomic, strong, readwrite) SBFolderIconImageCache *folderIconImageCache;
- (struct SBIconImageInfo)iconImageInfo;
- (UIView *)labelView;
- (BOOL)isFolderIcon;
- (void)_26home_updateGlassVisibility;
- (void)_26home_updateIconStyle;
- (void)_26home_updateCustomScale;
- (BOOL)isHighlighted;
- (BOOL)isTouchDown;
@end

@interface SBIconImageView : UIView
- (UIImage *)displayedImage;
- (struct SBIconImageInfo)iconImageInfo;
- (void)updateImageAnimated:(BOOL)animated;
@end

@interface SBFolderIconImageView : SBIconImageView
- (void)_26home_forceUpdate;
- (void)folderIconImageCache:(id)cache didUpdateImagesForFolderIcon:(id)folderIcon;
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

static NSString * const kLGFilterType = @"dylv.liquidglass.folder";

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
- (NSString *)bundleIdentifier;
- (id)loadImageWithScale:(double)scale isDarkStyle:(BOOL)isDarkStyle;
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

#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>

@interface PSTableCell (Home26Private)
- (UIImageView *)iconImageView;
@end

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

extern BOOL isAppInExceptionList(NSString *bundleID);
extern BOOL isAppExcluded(NSString *bundleID);
extern BOOL isAppExcludedFromEffects(NSString *bundleID);
extern BOOL g_exceptionsNoIconProcessing;
extern BOOL g_exceptionsApplyOnlyToSolid;

