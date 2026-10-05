#import "Home26AppIconGenDetailController.h"
#import "Home26WallpaperHelper.h"
#import "LGCustomIconGenerator2.h"
#import "Headers.h"
#import <notify.h>

static UIImage *ApplySpecularHighlightWithParams(UIImage *image, CGFloat angle, CGFloat widthScale, CGFloat perimeterAlpha, CGFloat topAlpha, CGFloat botAlpha) {
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, image.size.width, image.size.height) cornerRadius:image.size.width * 0.256];
    [path addClip];
    [image drawAtPoint:CGPointZero];

    CGFloat rimWidth = 6.0 * (widthScale > 0 ? widthScale : 1.0);
    [path setLineWidth:rimWidth];
    [[UIColor colorWithWhite:1.0 alpha:(perimeterAlpha >= 0 ? perimeterAlpha : 0.28)] setStroke];
    [path stroke];

    CGContextSaveGState(context);
    CGContextSetLineWidth(context, rimWidth);
    CGContextAddPath(context, path.CGPath);
    CGContextReplacePathWithStrokedPath(context);
    CGContextClip(context);

    CGColorSpaceRef rimColorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat tAlpha = (topAlpha >= 0 ? topAlpha : 0.92);
    CGFloat bAlpha = (botAlpha >= 0 ? botAlpha : 0.48);
    NSArray *rimColors = @[(id)[UIColor colorWithWhite:1.0 alpha:tAlpha].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                           (id)[UIColor colorWithWhite:1.0 alpha:bAlpha].CGColor];

    CGFloat rimLocations[] = {0.0, 0.38, 0.62, 1.0};
    CGGradientRef rimGradient = CGGradientCreateWithColors(rimColorSpace, (__bridge CFArrayRef)rimColors, rimLocations);

    CGFloat rad = angle * M_PI / 180.0;
    CGFloat cx = image.size.width * 0.5;
    CGFloat cy = image.size.height * 0.5;
    CGFloat r = sqrt(cx * cx + cy * cy);
    CGPoint rimStart = CGPointMake(cx - r * cos(rad), cy - r * sin(rad));
    CGPoint rimEnd   = CGPointMake(cx + r * cos(rad), cy + r * sin(rad));

    CGContextSetBlendMode(context, kCGBlendModePlusLighter);
    CGContextDrawLinearGradient(context, rimGradient, rimStart, rimEnd, 0);

    CGGradientRelease(rimGradient);
    CGColorSpaceRelease(rimColorSpace);
    CGContextRestoreGState(context);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@interface Home26AppIconGenDetailController ()

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

@property (nonatomic, assign) BOOL customEnabled;
@property (nonatomic, copy) NSString *engineOverride;
@property (nonatomic, strong) UISegmentedControl *engineSegment;
@property (nonatomic, assign) BOOL specularEnabled;
@property (nonatomic, assign) CGFloat specularAngle;
@property (nonatomic, assign) CGFloat specularWidth;
@property (nonatomic, assign) CGFloat specularSubtleRim;
@property (nonatomic, assign) CGFloat specularTopAlpha;
@property (nonatomic, assign) CGFloat specularBotAlpha;

@property (nonatomic, assign) uint64_t currentRenderToken;

@property (nonatomic, strong) UIView *controlsContainer;
@property (nonatomic, strong) UISwitch *customSwitch;
@property (nonatomic, strong) UIView *specCard;
@property (nonatomic, strong) UISwitch *specularSwitch;
@property (nonatomic, strong) UIButton *resetAppBtn;

@property (nonatomic, strong) UISlider *angleSlider;
@property (nonatomic, strong) UILabel *angleValLabel;
@property (nonatomic, strong) UISlider *widthSlider;
@property (nonatomic, strong) UILabel *widthValLabel;
@property (nonatomic, strong) UISlider *rimSlider;
@property (nonatomic, strong) UILabel *rimValLabel;
@property (nonatomic, strong) UISlider *topAlphaSlider;
@property (nonatomic, strong) UILabel *topAlphaValLabel;
@property (nonatomic, strong) UISlider *botAlphaSlider;
@property (nonatomic, strong) UILabel *botAlphaValLabel;

@end

@interface UIImage (PrivateAppIcon)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

@implementation Home26AppIconGenDetailController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.appName ?: self.bundleID;
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    if (!self.appIcon && self.bundleID) {
        if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
            self.appIcon = [UIImage _applicationIconImageForBundleIdentifier:self.bundleID format:2 scale:[UIScreen mainScreen].scale];
        }
    }

    [self loadAppConfig];
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

- (void)updateLayoutAndContentSize {
    CGFloat w = self.view.bounds.size.width - 32.0;
    self.controlsContainer.hidden = !self.customEnabled;

    if (!self.customEnabled) {
        self.contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 320.0);
        self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, 320.0);
        return;
    }

    CGFloat cy = 0.0;

    self.specCard.frame = CGRectMake(0, cy, w, 360);
    cy += 372.0;

    self.resetAppBtn.frame = CGRectMake(0, cy, w, 48);
    cy += 64.0;

    self.controlsContainer.frame = CGRectMake(16, 287.0, w, cy);
    CGFloat totalH = 287.0 + cy + 30.0;
    self.contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, totalH);
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, totalH);
}

- (void)loadAppConfig {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSDictionary *allOverrides = [prefs dictionaryForKey:@"ngkhoi.26home.appIconGenOverrides"];
    NSDictionary *cfg = self.bundleID ? allOverrides[self.bundleID] : nil;

    self.customEnabled = [cfg[@"enabled"] boolValue];
    self.engineOverride = cfg[@"engineOverride"] ?: @"Inherit";
    self.specularEnabled = cfg[@"specularEnabled"] ? [cfg[@"specularEnabled"] boolValue] : YES;
    self.specularAngle = cfg[@"specularAngle"] ? [cfg[@"specularAngle"] floatValue] : 45.0;
    self.specularWidth = cfg[@"specularWidth"] ? [cfg[@"specularWidth"] floatValue] : 1.0;
    self.specularSubtleRim = cfg[@"specularSubtleRim"] ? [cfg[@"specularSubtleRim"] floatValue] : 0.20;
    self.specularTopAlpha = cfg[@"specularTopAlpha"] ? [cfg[@"specularTopAlpha"] floatValue] : 0.88;
    self.specularBotAlpha = cfg[@"specularBotAlpha"] ? [cfg[@"specularBotAlpha"] floatValue] : 0.50;
}

- (void)saveAppConfig {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSMutableDictionary *allOverrides = [[prefs dictionaryForKey:@"ngkhoi.26home.appIconGenOverrides"] mutableCopy] ?: [NSMutableDictionary dictionary];

    if (self.bundleID) {
        allOverrides[self.bundleID] = @{
            @"enabled": @(self.customEnabled),
            @"engineOverride": self.engineOverride ?: @"Inherit",
            @"specularEnabled": @(self.specularEnabled),
            @"specularAngle": @(self.specularAngle),
            @"specularWidth": @(self.specularWidth),
            @"specularSubtleRim": @(self.specularSubtleRim),
            @"specularTopAlpha": @(self.specularTopAlpha),
            @"specularBotAlpha": @(self.specularBotAlpha)
        };
    }

    [prefs setObject:allOverrides forKey:@"ngkhoi.26home.appIconGenOverrides"];
    [prefs synchronize];

    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.appIconGenOverrides"), (__bridge CFPropertyListRef)allOverrides, CFSTR("com.ngkhoi.26home"));
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));

    [[LGCustomIconGenerator2 sharedGenerator] clearCache];
    [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];
    notify_post("ngkhoi.26home.clearCache");
    notify_post("ngkhoi.26home.UpdateIconStyle");

    if (self.onConfigChanged) self.onConfigChanged();
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 950.0)];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.contentView];
}

- (void)setupPreviewCard {
    CGFloat cardWidth = self.view.bounds.size.width - 32.0;
    CGFloat cardHeight = 155.0;
    self.previewCard = [[UIView alloc] initWithFrame:CGRectMake(16, 20, cardWidth, cardHeight)];
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

    CGFloat iconSize = 58.0;
    CGFloat spacing = (cardWidth - (iconSize * 4)) / 5.0;
    CGFloat topY = 28.0;
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

- (void)setupControls {
    CGFloat y = 195.0;
    CGFloat w = self.view.bounds.size.width - 32.0;

    UIView *engineCard = [[UIView alloc] initWithFrame:CGRectMake(16, y, w, 84)];
    engineCard.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    engineCard.layer.cornerRadius = 14.0;
    engineCard.layer.cornerCurve = kCACornerCurveContinuous;
    engineCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:engineCard];

    UILabel *eLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 32, 20)];
    eLabel.text = @"Generator Engine Override";
    eLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [engineCard addSubview:eLabel];

    self.engineSegment = [[UISegmentedControl alloc] initWithItems:@[@"Inherit", @"IconGen 2", @"IconGen 3"]];
    self.engineSegment.frame = CGRectMake(16, 40, w - 32, 32);
    self.engineSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if ([self.engineOverride hasPrefix:@"IconGen3"]) self.engineSegment.selectedSegmentIndex = 2;
    else if ([self.engineOverride isEqualToString:@"IconGen2"]) self.engineSegment.selectedSegmentIndex = 1;
    else self.engineSegment.selectedSegmentIndex = 0;
    [self.engineSegment addTarget:self action:@selector(engineSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [engineCard addSubview:self.engineSegment];

    y += 100.0;

    UIView *switchCard = [[UIView alloc] initWithFrame:CGRectMake(16, y, w, 56)];
    switchCard.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    switchCard.layer.cornerRadius = 14.0;
    switchCard.layer.cornerCurve = kCACornerCurveContinuous;
    switchCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:switchCard];

    UILabel *switchLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 17, w - 90, 22)];
    switchLabel.text = @"Custom Specular Configuration";
    switchLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [switchCard addSubview:switchLabel];

    self.customSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(w - 68, 12, 51, 31)];
    self.customSwitch.on = self.customEnabled;
    self.customSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.customSwitch addTarget:self action:@selector(customSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [switchCard addSubview:self.customSwitch];

    y += 72.0;

    self.controlsContainer = [[UIView alloc] initWithFrame:CGRectMake(16, y, w, 500)];
    self.controlsContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.controlsContainer.hidden = !self.customEnabled;
    [self.contentView addSubview:self.controlsContainer];

    self.specCard = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 360)];
    self.specCard.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.specCard.layer.cornerRadius = 14.0;
    self.specCard.layer.cornerCurve = kCACornerCurveContinuous;
    self.specCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.specCard.clipsToBounds = YES;
    self.specCard.layer.masksToBounds = YES;
    [self.controlsContainer addSubview:self.specCard];

    UILabel *sLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, w - 90, 22)];
    sLbl.text = @"Specular Highlights";
    sLbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.specCard addSubview:sLbl];

    self.specularSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(w - 68, 10, 51, 31)];
    self.specularSwitch.on = self.specularEnabled;
    self.specularSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.specularSwitch addTarget:self action:@selector(specularSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.specCard addSubview:self.specularSwitch];

    CGFloat sy = 50.0;
    __weak typeof(self) weakSelf = self;
    self.angleSlider = [self addSliderRowToView:self.specCard title:@"Angle" min:0.0 max:360.0 value:self.specularAngle isDegrees:YES tag:1 y:&sy labelHolder:^(UILabel *l){ weakSelf.angleValLabel = l; }];
    self.widthSlider = [self addSliderRowToView:self.specCard title:@"Stroke Width" min:0.2 max:3.0 value:self.specularWidth isDegrees:NO tag:2 y:&sy labelHolder:^(UILabel *l){ weakSelf.widthValLabel = l; }];
    self.rimSlider = [self addSliderRowToView:self.specCard title:@"Subtle Perimeter Rim" min:0.0 max:0.60 value:self.specularSubtleRim isDegrees:NO tag:3 y:&sy labelHolder:^(UILabel *l){ weakSelf.rimValLabel = l; }];
    self.topAlphaSlider = [self addSliderRowToView:self.specCard title:@"Top Highlight Opacity" min:0.0 max:1.0 value:self.specularTopAlpha isDegrees:NO tag:4 y:&sy labelHolder:^(UILabel *l){ weakSelf.topAlphaValLabel = l; }];
    self.botAlphaSlider = [self addSliderRowToView:self.specCard title:@"Bottom Rim Opacity" min:0.0 max:1.0 value:self.specularBotAlpha isDegrees:NO tag:5 y:&sy labelHolder:^(UILabel *l){ weakSelf.botAlphaValLabel = l; }];

    self.resetAppBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resetAppBtn.frame = CGRectMake(0, 372, w, 48);
    self.resetAppBtn.layer.cornerRadius = 14.0;
    self.resetAppBtn.layer.cornerCurve = kCACornerCurveContinuous;
    self.resetAppBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:0.12];
    [self.resetAppBtn setTitle:@"Reset This App to Global Defaults" forState:UIControlStateNormal];
    [self.resetAppBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    self.resetAppBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.resetAppBtn addTarget:self action:@selector(resetAppTapped) forControlEvents:UIControlEventTouchUpInside];
    self.resetAppBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.controlsContainer addSubview:self.resetAppBtn];
}

- (UISlider *)addSliderRowToView:(UIView *)parent title:(NSString *)title min:(CGFloat)min max:(CGFloat)max value:(CGFloat)value isDegrees:(BOOL)isDegrees tag:(NSInteger)tag y:(CGFloat *)y labelHolder:(void(^)(UILabel *label))labelHolder {
    UILabel *tLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, *y, parent.bounds.size.width - 90, 18)];
    tLbl.text = title;
    tLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    tLbl.textColor = [UIColor labelColor];
    [parent addSubview:tLbl];

    UILabel *vLbl = [[UILabel alloc] initWithFrame:CGRectMake(parent.bounds.size.width - 80, *y, 64, 18)];
    vLbl.font = [UIFont monospacedDigitSystemFontOfSize:12.5 weight:UIFontWeightSemibold];
    vLbl.textColor = [UIColor secondaryLabelColor];
    vLbl.textAlignment = NSTextAlignmentRight;
    vLbl.text = isDegrees ? [NSString stringWithFormat:@"%.0f°", value] : [NSString stringWithFormat:@"%.2f", value];
    [parent addSubview:vLbl];
    if (labelHolder) labelHolder(vLbl);

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(16, *y + 20, parent.bounds.size.width - 32, 28)];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.value = value;
    slider.tag = tag;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(sliderEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [parent addSubview:slider];

    *y += 58.0;
    return slider;
}

- (void)engineSegmentChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 2) self.engineOverride = @"IconGen3";
    else if (sender.selectedSegmentIndex == 1) self.engineOverride = @"IconGen2";
    else self.engineOverride = @"Inherit";
    [self saveAppConfig];
    [self refreshPreview];
}

- (void)customSwitchChanged:(UISwitch *)sender {
    self.customEnabled = sender.on;
    [self updateLayoutAndContentSize];
    [self saveAppConfig];
    [self refreshPreview];
}

- (void)specularSwitchChanged:(UISwitch *)sender {
    self.specularEnabled = sender.on;
    [self saveAppConfig];
    [self refreshPreview];
}

- (void)sliderChanged:(UISlider *)sender {
    if (sender.tag == 1) {
        self.specularAngle = sender.value;
        self.angleValLabel.text = [NSString stringWithFormat:@"%.0f°", sender.value];
    } else if (sender.tag == 2) {
        self.specularWidth = sender.value;
        self.widthValLabel.text = [NSString stringWithFormat:@"%.2fx", sender.value];
    } else if (sender.tag == 3) {
        self.specularSubtleRim = sender.value;
        self.rimValLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    } else if (sender.tag == 4) {
        self.specularTopAlpha = sender.value;
        self.topAlphaValLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    } else if (sender.tag == 5) {
        self.specularBotAlpha = sender.value;
        self.botAlphaValLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(debouncedRefreshPreview) object:nil];
    [self performSelector:@selector(debouncedRefreshPreview) withObject:nil afterDelay:0.02];
}

- (void)debouncedRefreshPreview {
    [self refreshPreview];
    [self saveAppConfig];
}

- (void)sliderEnded:(UISlider *)sender {
    [self saveAppConfig];
}

- (void)resetAppTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset App Config"
                                                                   message:[NSString stringWithFormat:@"Reset all custom Specular settings for %@ back to global defaults?", self.appName ?: self.bundleID]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        self.customEnabled = NO;
        self.customSwitch.on = NO;
        [self updateLayoutAndContentSize];
        [self saveAppConfig];
        [self loadAppConfig];
        [self refreshPreview];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
    if (self.appIcon) return self.appIcon;

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
    NSString *bundleID = self.bundleID ?: @"com.apple.weather";
    UIImage *baseGlyph = [self baseIconForBundleID:bundleID];

    UIImage *lightPremade = [self findPremadeIconForBundleID:bundleID theme:@"Light"];
    UIImage *lightNSPremade = [self findPremadeIconForBundleID:bundleID theme:@"LightNS"];
    UIImage *darkPremade = [self findPremadeIconForBundleID:bundleID theme:@"Dark"];
    UIImage *darkNSPremade = [self findPremadeIconForBundleID:bundleID theme:@"DarkNS"];
    UIImage *clearPremade = [self findPremadeIconForBundleID:bundleID theme:@"ClearLight"];
    UIImage *clearNSPremade = [self findPremadeIconForBundleID:bundleID theme:@"ClearLightNS"];

    CGFloat angle = self.customEnabled ? self.specularAngle : 45.0;
    CGFloat widthScale = self.customEnabled ? self.specularWidth : 1.0;
    CGFloat rimAlpha = self.customEnabled ? self.specularSubtleRim : 0.20;
    CGFloat topAlpha = self.customEnabled ? self.specularTopAlpha : 0.88;
    CGFloat botAlpha = self.customEnabled ? self.specularBotAlpha : 0.50;
    BOOL specOn = self.customEnabled ? self.specularEnabled : YES;

    if (!self.customEnabled) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        specOn = [prefs objectForKey:@"ngkhoi.26home.icongen.specularEnabled"] ? [prefs boolForKey:@"ngkhoi.26home.icongen.specularEnabled"] : YES;
        angle = [prefs objectForKey:@"ngkhoi.26home.icongen.specularAngle"] ? [prefs floatForKey:@"ngkhoi.26home.icongen.specularAngle"] : 45.0;
        widthScale = [prefs objectForKey:@"ngkhoi.26home.icongen.specularWidth"] ? [prefs floatForKey:@"ngkhoi.26home.icongen.specularWidth"] : 1.0;
        rimAlpha = [prefs objectForKey:@"ngkhoi.26home.icongen.specularSubtleRim"] ? [prefs floatForKey:@"ngkhoi.26home.icongen.specularSubtleRim"] : 0.20;
        topAlpha = [prefs objectForKey:@"ngkhoi.26home.icongen.specularTopAlpha"] ? [prefs floatForKey:@"ngkhoi.26home.icongen.specularTopAlpha"] : 0.88;
        botAlpha = [prefs objectForKey:@"ngkhoi.26home.icongen.specularBotAlpha"] ? [prefs floatForKey:@"ngkhoi.26home.icongen.specularBotAlpha"] : 0.50;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id iconGen;
        NSString *activeEngine = self.engineOverride;
        if (!activeEngine || [activeEngine isEqualToString:@"Inherit"]) {
            NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
            activeEngine = [prefs stringForKey:@"ngkhoi.26home.icongen.engineVersion"] ?: @"IconGen2";
        }
        iconGen = [LGCustomIconGenerator2 sharedGenerator];

        BOOL isLightNS = NO;
        UIImage *lightImg = nil;
        if (specOn) {
            lightImg = lightPremade ?: lightNSPremade;
            isLightNS = (lightImg == lightNSPremade);
        } else {
            lightImg = lightNSPremade ?: lightPremade;
        }
        if (!lightImg) {
            lightImg = baseGlyph;
            isLightNS = YES;
        }
        if (lightImg && specOn && isLightNS) {
            lightImg = ApplySpecularHighlightWithParams(lightImg, angle, widthScale, rimAlpha, topAlpha, botAlpha);
        }

        BOOL isDarkNS = NO;
        UIImage *darkImg = nil;
        if (specOn) {
            darkImg = darkPremade ?: darkNSPremade;
            isDarkNS = (darkImg == darkNSPremade);
        } else {
            darkImg = darkNSPremade ?: darkPremade;
        }
        if (darkImg && specOn && isDarkNS) {
            darkImg = ApplySpecularHighlightWithParams(darkImg, angle, widthScale, rimAlpha, topAlpha, botAlpha);
        }
        if (!darkImg) {
            darkImg = [iconGen generateDarkIconForImage:lightImg ?: baseGlyph bundleID:bundleID];
            if (darkImg && specOn) {
                darkImg = ApplySpecularHighlightWithParams(darkImg, angle, widthScale, rimAlpha, topAlpha, botAlpha);
            }
        }
        if (!darkImg) darkImg = lightImg;

        BOOL isClearNS = NO;
        UIImage *clearImg = nil;
        if (specOn) {
            clearImg = clearPremade ?: clearNSPremade;
            isClearNS = (clearImg == clearNSPremade);
        } else {
            clearImg = clearNSPremade ?: clearPremade;
        }
        if (clearImg && specOn && isClearNS && clearImg != clearNSPremade) {
            clearImg = ApplySpecularHighlightWithParams(clearImg, angle, widthScale, rimAlpha, topAlpha, botAlpha);
        }
        if (!clearImg) {
            UIImage *glyphSource = clearNSPremade;
            if (!glyphSource) {
                glyphSource = [iconGen generateClearIconForImage:darkImg ?: lightImg ?: baseGlyph bundleID:bundleID];
            }
            if (!glyphSource) glyphSource = darkImg ?: lightImg ?: baseGlyph;

            clearImg = [iconGen compositeGlyph:glyphSource
                           withBackgroundStyle:@"Clear"
                                   isDarkTheme:NO
                                     tintColor:nil
                               isAutoGenerated:YES
                                  drawSpecular:specOn];
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
