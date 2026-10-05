#pragma once

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>
#import "../Headers.h"
#import "../LGButtonView.h"
#import "../Home26LiquidMenu.h"
#import "../LGCustomIconGenerator2.h"

#ifdef __cplusplus
extern "C" {
#endif

extern BOOL g_tweakEnabled;
extern BOOL g_bypassingIconHook;
extern NSString *g_engineVersion;
extern NSString *g_selectedIconPack;
extern NSString *g_iconStyle;
extern NSString *g_themeMode;
extern NSString *g_darkIconMode;
extern NSString *g_tintColor;
extern BOOL g_largeIconsEnabled;
extern BOOL g_disableLiquidGlassIcons;
extern BOOL g_keepAppIconBlur;
extern NSDictionary *g_excludedApps;
extern BOOL g_exceptionsApplyOnlyToSolid;
extern BOOL g_exceptionsNoIconProcessing;
extern CGFloat g_appIconBlurRadius;
extern CGFloat g_appIconGlassQuality;
extern BOOL g_hideGlassWhenUnfocused;
extern NSString *g_menuAppearance;

extern BOOL g_isAppOpening;
extern BOOL g_isFolderOpen;
extern BOOL g_isHomeScreenVisible;
extern BOOL g_isSwitcherOpen;
extern BOOL g_isCoverSheetVisible;
extern BOOL g_isEditingMode;
extern BOOL g_isAnimatingScale;
extern BOOL g_eyedropperActive;
extern double g_coverSheetProgress;
extern BOOL g_isWallpaperDimmed;
extern UIView *g_dimView;

extern NSCache *g_appIconImageCache;
extern NSCache *g_notificationIconsCache;

extern __weak id g_editingDoneTarget;
extern SEL g_editingDoneAction;

BOOL isAppInExceptionList(NSString *bundleID);
BOOL isAppExcluded(NSString *bundleID);
BOOL isAppExcludedFromEffects(NSString *bundleID);
BOOL Home26IsCoverSheetActive(void);
BOOL Home26IsViewInFolder(UIView *view);
void ForceLayoutAllIconViews(UIView *view);
void updateTintViews(UIView *view, UIColor *tintColor);

void reload26HomePrefs(void);
UIWindow *GetWallpaperWindow(void);
UIWindow *Home26GetKeyWindow(void);
void EnsureWallpaperDimView(void);
void UpdateWallpaperDimState(BOOL dimmed, BOOL animated);
void notifyAllIconsVisibilityChanged(void);
void refreshKnownIcons(void);
void Home26RefreshAllFolderIcons(void);
void Home26TriggerGlobalRefresh(void);
void Home26ReloadAllVisibleTables(UIView *view);
void _26home_applyWidgetTintToView(UIView *view);
void _26home_recursivelyApplyWidgetTint(UIView *view);

id GetIconGenerator(void);
UIImage *Home26RequestStyledIcon(UIImage *image, NSString *bundleID);
UIImage *Home26FastCachedIcon(NSString *bundleID);
UIImage *Home26SkeletonIcon(NSString *bundleID, struct SBIconImageInfo info);
void Home26RequestIconAsync(UIImage *image, NSString *bundleID, void (^completion)(UIImage *styled));
UIImage *Home26OriginalIconForBundleID(NSString *bundleID);
void Home26SaveOriginalIcon(UIImage *image, NSString *bundleID);
void Home26ClearGeneratorCache(void);

SBRootFolderController *ResolveRootFolderController(UIView *view);

void Home26InitEditingButtonsHooks(void);
void Home26InitIconViewHooks(void);
void Home26InitIconImageViewHooks(void);
void Home26InitBadgesAndWidgetsHooks(void);
void Home26InitSpringBoardCoreHooks(void);
void Home26InitPreferencesHooks(void);
void Home26InitSpotlightHooks(void);
void Home26RegisterPreferencesNotifications(void);
void Home26RegisterSpotlightNotifications(void);

#ifdef __cplusplus
}
#endif
