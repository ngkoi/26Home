#import "Home26IconGenConfigController.h"
#import "Home26IconPickerViewController.h"
#import "Home26WallpaperHelper.h"
#import "LGCustomIconGenerator2.h"
#import "Headers.h"
#import <notify.h>

static UIImage *ApplySpecularHighlightForStyle(UIImage *image, NSString *style) {
    if (!image) return nil;
    if ([style isEqualToString:@"none"]) return image;

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, image.size.width, image.size.height) cornerRadius:image.size.width * 0.256];
    [path addClip];
    [image drawAtPoint:CGPointZero];

    CGFloat rimWidth = 6.0;
    [path setLineWidth:rimWidth];
    [[UIColor colorWithWhite:1.0 alpha:0.28] setStroke];
    [path stroke];

    CGContextSaveGState(context);
    CGContextSetLineWidth(context, rimWidth);
    CGContextAddPath(context, path.CGPath);
    CGContextReplacePathWithStrokedPath(context);
    CGContextClip(context);

    CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat tAlpha = 0.92;
    CGFloat bAlpha = 0.48;
    NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:tAlpha].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:bAlpha].CGColor];

    CGFloat rimLocations[] = {0.0, 0.38, 0.62, 1.0};
    CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);

    CGPoint rimStart, rimEnd;
    if ([style isEqualToString:@"27"]) {
        rimStart = CGPointMake(image.size.width / 2.0, 0);
        rimEnd   = CGPointMake(image.size.width / 2.0, image.size.height);
    } else {
        rimStart = CGPointMake(0, 0);
        rimEnd   = CGPointMake(image.size.width, image.size.height);
    }

    CGContextSetBlendMode(context, kCGBlendModePlusLighter);
    CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);

    CGGradientRelease(rimGradient);
    CGColorSpaceRelease(rimColorSpace);
    CGContextRestoreGState(context);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@interface UIImage (PrivateIconGenGlobal)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

@interface Home26IconGenConfigController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) UIView *previewCard;
@property (nonatomic, strong) UIImageView *wallpaperView;
@property (nonatomic, strong) UIImageView *lightIconView;
@property (nonatomic, strong) UIImageView *darkIconView;
@property (nonatomic, strong) UIImageView *clearIconView;
@property (nonatomic, strong) UIImageView *tintedIconView;

@property (nonatomic, strong) LGAdjustableBlurView *clearBlurView;
@property (nonatomic, strong) LGLiveBackdropView *clearGlassView;
@property (nonatomic, strong) LGAdjustableBlurView *tintedBlurView;
@property (nonatomic, strong) LGLiveBackdropView *tintedGlassView;
@property (nonatomic, strong) UIView *tintedOverlayView;

@property (nonatomic, copy) NSString *selectedBundleID;
@property (nonatomic, copy) NSString *selectedAppName;
@property (nonatomic, strong) UIImage *selectedAppIcon;
@property (nonatomic, strong) UIButton *appSelectorButton;

@property (nonatomic, copy) NSString *specularStyle;
@property (nonatomic, assign) uint64_t currentRenderToken;

@property (nonatomic, strong) UIView *optionsCard;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *checkmarks;

@end

@implementation Home26IconGenConfigController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"IconGen Config";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.selectedBundleID = @"com.apple.weather";
    self.selectedAppName = @"Weather";
    if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
        self.selectedAppIcon = [UIImage _applicationIconImageForBundleIdentifier:self.selectedBundleID format:2 scale:[UIScreen mainScreen].scale];
    }

    [self loadGlobalConfig];
    [self setupScrollView];
    [self setupPreviewCard];
    [self setupControls];
    [self updateLayoutAndContentSize];
    [self refreshPreview];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    static CGFloat lastLayoutWidth = 0.0;
    CGFloat currentWidth = self.view.bounds.size.width;
    if (currentWidth > 0 && currentWidth != lastLayoutWidth) {
        lastLayoutWidth = currentWidth;
        [self updateLayoutAndContentSize];
    }
}

- (void)loadGlobalConfig {
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));
    CFPropertyListRef styleVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.icongen.specularStyle"), CFSTR("com.ngkhoi.26home"));
    if (styleVal && [(__bridge id)styleVal isKindOfClass:[NSString class]]) {
        self.specularStyle = [(__bridge NSString *)styleVal copy];
        CFRelease(styleVal);
    } else {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        self.specularStyle = [prefs stringForKey:@"ngkhoi.26home.icongen.specularStyle"];
        if (!self.specularStyle) {
            Boolean exists = false;
            Boolean enabled = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.icongen.specularEnabled"), CFSTR("com.ngkhoi.26home"), &exists);
            if (exists && !enabled) {
                self.specularStyle = @"none";
            } else {
                CGFloat angle = [prefs floatForKey:@"ngkhoi.26home.icongen.specularAngle"];
                if (angle == 90.0) {
                    self.specularStyle = @"27";
                } else {
                    self.specularStyle = @"26";
                }
            }
        }
    }
    if (!self.specularStyle || self.specularStyle.length == 0) {
        self.specularStyle = @"26";
    }
}

- (void)saveGlobalConfig {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];

    BOOL specOn = ![self.specularStyle isEqualToString:@"none"];
    CGFloat angle = [self.specularStyle isEqualToString:@"27"] ? 90.0 : 45.0;

    [prefs setObject:self.specularStyle forKey:@"ngkhoi.26home.icongen.specularStyle"];
    [prefs setBool:specOn forKey:@"ngkhoi.26home.icongen.specularEnabled"];
    [prefs setFloat:angle forKey:@"ngkhoi.26home.icongen.specularAngle"];
    [prefs synchronize];

    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.icongen.specularStyle"), (__bridge CFPropertyListRef)self.specularStyle, CFSTR("com.ngkhoi.26home"));
    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.icongen.specularEnabled"), (__bridge CFPropertyListRef)@(specOn), CFSTR("com.ngkhoi.26home"));
    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.icongen.specularAngle"), (__bridge CFPropertyListRef)@(angle), CFSTR("com.ngkhoi.26home"));
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));

    [[LGCustomIconGenerator2 sharedGenerator] clearCache];
    [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];
    notify_post("ngkhoi.26home.clearCache");
    notify_post("ngkhoi.26home.UpdateIconStyle");
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 500)];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.contentView];
}

- (void)setupPreviewCard {
    CGFloat cardWidth = self.view.bounds.size.width - 32.0;
    CGFloat cardHeight = 160.0;
    self.previewCard = [[UIView alloc] initWithFrame:CGRectMake(16, 16, cardWidth, cardHeight)];
    self.previewCard.layer.cornerRadius = 20.0;
    self.previewCard.layer.cornerCurve = kCACornerCurveContinuous;
    self.previewCard.clipsToBounds = YES;
    self.previewCard.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.previewCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:self.previewCard];

    self.wallpaperView = [[UIImageView alloc] initWithFrame:self.previewCard.bounds];
    self.wallpaperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.wallpaperView.contentMode = UIViewContentModeScaleAspectFill;
    self.wallpaperView.image = [Home26WallpaperHelper currentDeviceWallpaper];
    [self.previewCard addSubview:self.wallpaperView];

    UIView *dim = [[UIView alloc] initWithFrame:self.previewCard.bounds];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.15];
    [self.previewCard addSubview:dim];

    self.appSelectorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.appSelectorButton.frame = CGRectMake(14, 12, cardWidth - 28, 28);
    self.appSelectorButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.appSelectorButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    self.appSelectorButton.layer.cornerRadius = 14.0;
    self.appSelectorButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.appSelectorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.appSelectorButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.appSelectorButton setTitle:[NSString stringWithFormat:@"Previewing: %@ ▾", self.selectedAppName] forState:UIControlStateNormal];
    [self.appSelectorButton addTarget:self action:@selector(openAppPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.previewCard addSubview:self.appSelectorButton];

    CGFloat iconSize = 58.0;
    CGFloat spacing = (cardWidth - (iconSize * 4)) / 5.0;
    CGFloat topY = 48.0;
    NSArray *labels = @[@"Light", @"Dark", @"Clear", @"Tinted"];

    for (int i = 0; i < 4; i++) {
        CGFloat x = spacing + i * (iconSize + spacing);
        UIView *box = [[UIView alloc] initWithFrame:CGRectMake(x, topY, iconSize, iconSize + 28)];
        box.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.previewCard addSubview:box];

        UIView *iconContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, iconSize, iconSize)];
        iconContainer.layer.cornerRadius = 13.5;
        iconContainer.layer.cornerCurve = kCACornerCurveContinuous;
        iconContainer.clipsToBounds = YES;
        [box addSubview:iconContainer];

        UIImageView *iv = [[UIImageView alloc] initWithFrame:iconContainer.bounds];
        iv.layer.cornerRadius = 13.5;
        iv.layer.cornerCurve = kCACornerCurveContinuous;
        iv.clipsToBounds = YES;
        iv.contentMode = UIViewContentModeScaleAspectFill;

        if (i == 0) {
            self.lightIconView = iv;
            [iconContainer addSubview:iv];
        } else if (i == 1) {
            self.darkIconView = iv;
            [iconContainer addSubview:iv];
        } else if (i == 2) {
            self.clearIconView = iv;

            self.clearBlurView = [[LGAdjustableBlurView alloc] initWithFrame:iconContainer.bounds];
            self.clearBlurView.layer.cornerRadius = 13.5;
            self.clearBlurView.layer.cornerCurve = kCACornerCurveContinuous;
            self.clearBlurView.clipsToBounds = YES;
            self.clearBlurView.blurRadius = 18.0;
            [iconContainer addSubview:self.clearBlurView];

            self.clearGlassView = [[LGLiveBackdropView alloc] initWithFrame:iconContainer.bounds];
            self.clearGlassView.layer.cornerRadius = 13.5;
            self.clearGlassView.layer.cornerCurve = kCACornerCurveContinuous;
            self.clearGlassView.clipsToBounds = YES;
            self.clearGlassView.qualityScale = 0.55;
            self.clearGlassView.capturesAppIcon = YES;
            [iconContainer addSubview:self.clearGlassView];

            [iconContainer addSubview:iv];
        } else if (i == 3) {
            self.tintedIconView = iv;

            self.tintedBlurView = [[LGAdjustableBlurView alloc] initWithFrame:iconContainer.bounds];
            self.tintedBlurView.layer.cornerRadius = 13.5;
            self.tintedBlurView.layer.cornerCurve = kCACornerCurveContinuous;
            self.tintedBlurView.clipsToBounds = YES;
            self.tintedBlurView.blurRadius = 18.0;
            [iconContainer addSubview:self.tintedBlurView];

            self.tintedGlassView = [[LGLiveBackdropView alloc] initWithFrame:iconContainer.bounds];
            self.tintedGlassView.layer.cornerRadius = 13.5;
            self.tintedGlassView.layer.cornerCurve = kCACornerCurveContinuous;
            self.tintedGlassView.clipsToBounds = YES;
            self.tintedGlassView.qualityScale = 0.55;
            self.tintedGlassView.capturesAppIcon = YES;
            [iconContainer addSubview:self.tintedGlassView];

            self.tintedOverlayView = [[UIView alloc] initWithFrame:iconContainer.bounds];
            self.tintedOverlayView.layer.cornerRadius = 13.5;
            self.tintedOverlayView.layer.cornerCurve = kCACornerCurveContinuous;
            self.tintedOverlayView.clipsToBounds = YES;
            self.tintedOverlayView.userInteractionEnabled = NO;
            [iconContainer addSubview:self.tintedOverlayView];

            [iconContainer addSubview:iv];
        }

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(-4, iconSize + 4, iconSize + 8, 16)];
        lbl.text = labels[i];
        lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.layer.shadowColor = [UIColor blackColor].CGColor;
        lbl.layer.shadowOpacity = 0.6;
        lbl.layer.shadowOffset = CGSizeMake(0, 1);
        [box addSubview:lbl];
    }
}

- (void)openAppPicker {
    Home26IconPickerViewController *picker = [[Home26IconPickerViewController alloc] init];
    picker.selectedBundleID = self.selectedBundleID;
    __weak typeof(self) weakSelf = self;
    picker.onSelectApp = ^(NSString *bundleID, NSString *displayName) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.selectedBundleID = bundleID;
        self.selectedAppName = displayName;
        [self.appSelectorButton setTitle:[NSString stringWithFormat:@"Previewing: %@ ▾", displayName] forState:UIControlStateNormal];
        self.selectedAppIcon = nil;
        [self refreshPreview];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)setupControls {
    CGFloat w = self.view.bounds.size.width - 32.0;

    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 192, w - 8, 20)];
    headerLabel.text = @"SPECULAR HIGHLIGHT STYLE";
    headerLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    headerLabel.textColor = [UIColor secondaryLabelColor];
    headerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:headerLabel];

    CGFloat rowH = 64.0;
    self.optionsCard = [[UIView alloc] initWithFrame:CGRectMake(16, 218, w, rowH * 3)];
    self.optionsCard.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.optionsCard.layer.cornerRadius = 14.0;
    self.optionsCard.layer.cornerCurve = kCACornerCurveContinuous;
    self.optionsCard.clipsToBounds = YES;
    self.optionsCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:self.optionsCard];

    NSArray *options = @[
        @{
            @"id": @"26",
            @"title": @"26 Specular",
            @"subtitle": @"Specular Rims angle 45° (top-left & bottom-right)"
        },
        @{
            @"id": @"27",
            @"title": @"27 Specular",
            @"subtitle": @"Specular Rims angle 90° (top & bottom)"
        },
        @{
            @"id": @"none",
            @"title": @"No specular",
            @"subtitle": @"Clean matte icons without specular rims"
        }
    ];

    self.checkmarks = [NSMutableArray array];

    for (NSInteger i = 0; i < options.count; i++) {
        NSDictionary *opt = options[i];
        CGFloat y = i * rowH;

        UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, rowH)];
        rowView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        rowView.userInteractionEnabled = YES;
        rowView.tag = 100 + i;
        [self.optionsCard addSubview:rowView];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 60, 21)];
        titleLabel.text = opt[@"title"];
        titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        titleLabel.textColor = [UIColor labelColor];
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [rowView addSubview:titleLabel];

        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 34, w - 60, 17)];
        subLabel.text = opt[@"subtitle"];
        subLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
        subLabel.textColor = [UIColor secondaryLabelColor];
        subLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [rowView addSubview:subLabel];

        UIImageView *check = [[UIImageView alloc] initWithFrame:CGRectMake(w - 38, 22, 20, 20)];
        check.contentMode = UIViewContentModeScaleAspectFit;
        check.image = [UIImage systemImageNamed:@"checkmark"];
        check.tintColor = [UIColor systemBlueColor];
        check.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        check.hidden = ![self.specularStyle isEqualToString:opt[@"id"]];
        [rowView addSubview:check];
        [self.checkmarks addObject:check];

        if (i < options.count - 1) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(16, rowH - 0.5, w - 16, 0.5)];
            sep.backgroundColor = [UIColor separatorColor];
            sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [rowView addSubview:sep];
        }

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(optionRowTapped:)];
        [rowView addGestureRecognizer:tap];
    }

    UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 218 + (rowH * 3) + 10, w - 8, 38)];
    footerLabel.text = @"26 Specular creates diagonal glass highlights at 45°. 27 Specular creates top & bottom highlights at 90°. No specular produces a clean matte finish.";
    footerLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    footerLabel.textColor = [UIColor secondaryLabelColor];
    footerLabel.numberOfLines = 0;
    footerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:footerLabel];
}

- (void)optionRowTapped:(UITapGestureRecognizer *)sender {
    NSInteger index = sender.view.tag - 100;
    NSArray *styleIds = @[@"26", @"27", @"none"];
    if (index < 0 || index >= styleIds.count) return;

    NSString *newStyle = styleIds[index];
    if ([self.specularStyle isEqualToString:newStyle]) return;

    UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
    [feedback selectionChanged];

    self.specularStyle = newStyle;
    for (NSInteger i = 0; i < self.checkmarks.count; i++) {
        self.checkmarks[i].hidden = (i != index);
    }

    [self saveGlobalConfig];
    [self refreshPreview];
}

- (void)updateLayoutAndContentSize {
    CGFloat totalH = 490.0;
    self.contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, totalH);
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, totalH);
}

- (NSString *)activePackDirectory {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSString *activeId = [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: @"SolidGlass";
    NSString *baseDir = jbroot(@"/Library/Application Support/26Home/IconPacks");
    return [baseDir stringByAppendingPathComponent:activeId];
}

- (UIImage *)findPremadeIconForBundleID:(NSString *)bundleID theme:(NSString *)theme {
    if (!bundleID || !theme) return nil;
    NSString *packDir = [self activePackDirectory];
    if (!packDir || ![[NSFileManager defaultManager] fileExistsAtPath:packDir]) return nil;

    NSString *themePath = [packDir stringByAppendingPathComponent:theme];
    NSMutableArray *candidates = [NSMutableArray array];
    if ([bundleID isEqualToString:@"com.apple.mobiletimer"]) {
        [candidates addObject:@"ClockIconBackgroundSquare.png"];
        [candidates addObject:@"ClockIconBackgroundSquare-large.png"];
    }
    [candidates addObject:[NSString stringWithFormat:@"%@-large.png", bundleID]];
    [candidates addObject:[NSString stringWithFormat:@"%@.png", bundleID]];
    for (NSString *cand in candidates) {
        NSString *filePath = [themePath stringByAppendingPathComponent:cand];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            return [UIImage imageWithContentsOfFile:filePath];
        }
    }

    for (NSString *cand in candidates) {
        NSString *filePath = [packDir stringByAppendingPathComponent:cand];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            return [UIImage imageWithContentsOfFile:filePath];
        }
    }
    return nil;
}

- (UIImage *)baseIconForBundleID:(NSString *)bundleID {
    if (self.selectedAppIcon) return self.selectedAppIcon;

    NSArray *packThemes = @[@"Light", @"LightNS", @"Dark", @"DarkNS", @"ClearLight", @"ClearDark"];
    for (NSString *th in packThemes) {
        UIImage *img = [self findPremadeIconForBundleID:bundleID theme:th];
        if (img) return img;
    }

    if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
        UIImage *sys = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:[UIScreen mainScreen].scale];
        if (sys) return sys;
    }

    UIImage *orig = [[LGCustomIconGenerator2 sharedGenerator] originalImageForBundleID:bundleID];
    if (orig) return orig;

    return nil;
}

- (void)refreshPreview {
    uint64_t renderToken = ++self.currentRenderToken;
    NSString *bundleID = self.selectedBundleID ?: @"com.apple.weather";
    UIImage *baseGlyph = [self baseIconForBundleID:bundleID];

    NSString *specStyle = self.specularStyle ?: @"26";
    BOOL specOn = ![specStyle isEqualToString:@"none"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id iconGen = [LGCustomIconGenerator2 sharedGenerator];

        UIImage *lightPremade = [self findPremadeIconForBundleID:bundleID theme:@"Light"];
        UIImage *lightNSPremade = [self findPremadeIconForBundleID:bundleID theme:@"LightNS"];
        UIImage *lightImg = nil;
        if (specOn) {
            lightImg = lightPremade ?: lightNSPremade;
        } else {
            lightImg = lightNSPremade ?: lightPremade;
        }
        if (!lightImg) lightImg = baseGlyph;
        if (lightImg && specOn && (lightImg == lightNSPremade || lightImg == baseGlyph)) {
            lightImg = ApplySpecularHighlightForStyle(lightImg, specStyle);
        }

        UIImage *darkPremade = [self findPremadeIconForBundleID:bundleID theme:@"Dark"];
        UIImage *darkNSPremade = [self findPremadeIconForBundleID:bundleID theme:@"DarkNS"];
        UIImage *darkImg = nil;
        if (specOn) {
            darkImg = darkPremade ?: darkNSPremade;
        } else {
            darkImg = darkNSPremade ?: darkPremade;
        }
        BOOL isGeneratedDark = NO;
        if (!darkImg) {
            darkImg = [iconGen generateDarkIconForImage:lightImg ?: baseGlyph bundleID:bundleID];
            isGeneratedDark = YES;
        }
        if (darkImg && specOn && (darkImg == darkNSPremade || darkImg == baseGlyph || isGeneratedDark)) {
            darkImg = ApplySpecularHighlightForStyle(darkImg, specStyle);
        }
        if (!darkImg) darkImg = lightImg;

        UIImage *clearPremade = [self findPremadeIconForBundleID:bundleID theme:@"ClearLight"];
        UIImage *clearNSPremade = [self findPremadeIconForBundleID:bundleID theme:@"ClearLightNS"];
        UIImage *clearImg = clearPremade ?: clearNSPremade;
        if (!clearImg) {
            UIImage *glyphSource = clearNSPremade ?: [iconGen generateClearIconForImage:darkImg ?: lightImg ?: baseGlyph bundleID:bundleID];
            if (!glyphSource) glyphSource = darkImg ?: lightImg ?: baseGlyph;

            clearImg = [iconGen compositeGlyph:glyphSource
                           withBackgroundStyle:@"Clear"
                                   isDarkTheme:NO
                                     tintColor:nil
                               isAutoGenerated:YES
                                  drawSpecular:specOn];
        } else if (specOn && clearImg == clearNSPremade) {
            clearImg = ApplySpecularHighlightForStyle(clearImg, specStyle);
        }

        UIImage *tintSource = clearPremade ?: clearNSPremade ?: lightPremade ?: lightNSPremade ?: darkNSPremade ?: darkPremade ?: baseGlyph;
        UIColor *tintColor = [UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:1.0];
        UIImage *extractedGlyph = [iconGen generateClearIconForImage:tintSource bundleID:bundleID];
        if (!extractedGlyph) extractedGlyph = tintSource;

        UIImage *tintedImg = [iconGen compositeGlyph:extractedGlyph
                                 withBackgroundStyle:@"Tinted"
                                         isDarkTheme:NO
                                           tintColor:tintColor
                                     isAutoGenerated:YES
                                        drawSpecular:specOn];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.currentRenderToken != renderToken) return;

            self.lightIconView.image = lightImg;
            self.darkIconView.image = darkImg;
            self.clearIconView.image = clearImg;
            self.tintedIconView.image = tintedImg ?: extractedGlyph;

            NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
            BOOL disableGlass = [prefs boolForKey:@"ngkhoi.26home.disableLiquidGlassIcons"];
            BOOL keepBlur = [prefs objectForKey:@"ngkhoi.26home.keepAppIconBlur"] ? [prefs boolForKey:@"ngkhoi.26home.keepAppIconBlur"] : YES;
            CGFloat blurRadius = [prefs objectForKey:@"ngkhoi.26home.appIconBlurRadius"] ? [prefs floatForKey:@"ngkhoi.26home.appIconBlurRadius"] : 18.0;
            CGFloat quality = [prefs objectForKey:@"ngkhoi.26home.appIconGlassQuality"] ? [prefs floatForKey:@"ngkhoi.26home.appIconGlassQuality"] : 0.55;

            self.clearBlurView.blurRadius = blurRadius;
            self.clearBlurView.hidden = !keepBlur;
            self.clearGlassView.qualityScale = quality;
            self.clearGlassView.hidden = disableGlass;
            [self.clearGlassView forceReapplyForRegistrationRace];

            self.tintedBlurView.blurRadius = blurRadius;
            self.tintedBlurView.hidden = !keepBlur;
            self.tintedGlassView.qualityScale = quality;
            self.tintedGlassView.hidden = disableGlass;
            [self.tintedGlassView forceReapplyForRegistrationRace];

            self.tintedOverlayView.backgroundColor = [tintColor colorWithAlphaComponent:0.35];
            self.tintedOverlayView.hidden = disableGlass;
        });
    });
}

@end
