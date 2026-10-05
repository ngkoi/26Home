#import "Home26PackDetailViewController.h"
#import "Home26WallpaperHelper.h"
#import "Home26WallpaperCropViewController.h"
#import "Home26IconPickerViewController.h"
#import "LGCustomIconGenerator2.h"
#import "Headers.h"
#import <notify.h>

NSString *g_iconStyle = @"Default";
NSString *g_themeMode = @"Light";
NSString *g_darkIconMode = @"Stock";
NSString *g_tintColor = @"#007AFF";
NSString *g_menuAppearance = @"iOS18";
BOOL g_exceptionsNoIconProcessing = YES;

BOOL isAppInExceptionList(NSString *bundleID) {
    if (!bundleID) return NO;
    CFPropertyListRef val = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.excludedApps"), CFSTR("com.ngkhoi.26home"));
    if (val && [(__bridge id)val isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (__bridge NSDictionary *)val;
        BOOL result = [dict[bundleID] boolValue];
        CFRelease(val);
        return result;
    }
    if (val) CFRelease(val);
    return NO;
}

BOOL isAppExcluded(NSString *bundleID) {
    return isAppInExceptionList(bundleID);
}

@interface Home26PackDetailViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, strong) UIImageView *headerIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIProgressView *progressView;

@property (nonatomic, strong) UIView *previewCardContainer;
@property (nonatomic, strong) UIImageView *wallpaperImageView;
@property (nonatomic, strong) UIView *wallpaperDimmingView;
@property (nonatomic, assign) CGFloat wallpaperVerticalOffset;
@property (nonatomic, assign) CGFloat initialPanOffsetY;
@property (nonatomic, strong) UIPanGestureRecognizer *wallpaperPanGesture;
@property (nonatomic, assign) int wallpaperExportObserverToken;
@property (nonatomic, strong) UIImage *rawWallpaperImage;

@property (nonatomic, strong) UIView *lightColumnView;
@property (nonatomic, strong) UIView *darkColumnView;
@property (nonatomic, strong) UIView *clearColumnView;
@property (nonatomic, strong) UIView *tintedColumnView;

@property (nonatomic, strong) UIImageView *lightIconView;
@property (nonatomic, strong) UIImageView *darkIconView;
@property (nonatomic, strong) UIImageView *clearIconView;
@property (nonatomic, strong) UIImageView *tintedIconView;

@property (nonatomic, strong) LGLiveBackdropView *clearGlassView;
@property (nonatomic, strong) LGAdjustableBlurView *clearBlurView;
@property (nonatomic, strong) LGLiveBackdropView *tintedGlassView;
@property (nonatomic, strong) LGAdjustableBlurView *tintedBlurView;
@property (nonatomic, strong) UIView *tintedOverlayView;

@property (nonatomic, copy) NSString *selectedBundleID;
@property (nonatomic, copy) NSString *selectedAppName;
@property (nonatomic, assign) BOOL isDarkMode;
@property (nonatomic, assign) CGFloat currentHue;
@property (nonatomic, assign) CGFloat currentBrightness;
@property (nonatomic, strong) UIColor *selectedTintColor;
@property (nonatomic, assign) BOOL specularEnabled;

@property (nonatomic, strong) UIButton *appSelectorButton;
@property (nonatomic, strong) UISegmentedControl *appearanceSegment;

@property (nonatomic, strong) UIView *hueSlider;
@property (nonatomic, strong) CAGradientLayer *hueGradient;
@property (nonatomic, strong) UIView *hueThumb;

@property (nonatomic, strong) UIView *brightnessSlider;
@property (nonatomic, strong) CAGradientLayer *brightnessGradient;
@property (nonatomic, strong) UIView *brightnessThumb;

@property (nonatomic, strong) UISwitch *specularSwitch;

@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *deleteButton;

@end

@implementation Home26PackDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.pack.name ?: @"Icon Pack";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.selectedBundleID = @"com.apple.weather";
    self.selectedAppName = @"Weather";
    self.isDarkMode = NO;
    self.currentHue = 0.58;
    self.currentBrightness = 0.20;
    self.specularEnabled = YES;

    [self updateCurrentTintColor];

    [self setupScrollView];
    [self setupHeaderSection];
    [self setupPreviewCard];
    [self setupControlsSection];
    [self setupInfoSection];

    [self refreshPreviewIcons];
    [self updateActionState];

    int token;
    __weak typeof(self) weakSelf = self;
    notify_register_dispatch("ngkhoi.26home.WallpaperExported", &token, dispatch_get_main_queue(), ^(int t) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self) {
            [self updateWallpaperDisplay];
        }
    });
    self.wallpaperExportObserverToken = token;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateWallpaperDisplay];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutWallpaperImage];
}

- (void)dealloc {
    if (self.wallpaperExportObserverToken != 0) {
        notify_cancel(self.wallpaperExportObserverToken);
    }
}

- (void)updateCurrentTintColor {
    CGFloat sat = fmaxf(1.0 - self.currentBrightness, 0.0);
    self.selectedTintColor = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];
}

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 1100)];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.contentView];
}

- (void)setupHeaderSection {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 16, self.view.bounds.size.width - 32, 100)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 14.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:card];

    self.headerIconView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 68, 68)];
    self.headerIconView.layer.cornerRadius = 16.0;
    self.headerIconView.layer.cornerCurve = kCACornerCurveContinuous;
    self.headerIconView.clipsToBounds = YES;
    self.headerIconView.backgroundColor = [UIColor systemGray5Color];
    self.headerIconView.contentMode = UIViewContentModeScaleAspectFit;
    if (self.pack.cachedPreviewIcon) {
        self.headerIconView.image = self.pack.cachedPreviewIcon;
    }
    [card addSubview:self.headerIconView];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(96, 14, card.bounds.size.width - 190, 24)];
    self.titleLabel.text = self.pack.name;
    self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:self.titleLabel];

    self.authorLabel = [[UILabel alloc] initWithFrame:CGRectMake(96, 38, card.bounds.size.width - 190, 18)];
    self.authorLabel.text = [NSString stringWithFormat:@"by %@", self.pack.author ?: @"ngkhoi"];
    self.authorLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular];
    self.authorLabel.textColor = [UIColor secondaryLabelColor];
    self.authorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:self.authorLabel];

    NSMutableArray *parts = [NSMutableArray array];
    if (self.pack.iconCount > 0) [parts addObject:[NSString stringWithFormat:@"%ld icons", (long)self.pack.iconCount]];
    if (self.pack.size.length > 0) [parts addObject:self.pack.size];
    if (self.pack.version.length > 0) [parts addObject:[NSString stringWithFormat:@"v%@", self.pack.version]];

    self.metaLabel = [[UILabel alloc] initWithFrame:CGRectMake(96, 58, card.bounds.size.width - 190, 16)];
    self.metaLabel.text = [parts componentsJoinedByString:@" • "];
    self.metaLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
    self.metaLabel.textColor = [UIColor tertiaryLabelColor];
    self.metaLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:self.metaLabel];

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.frame = CGRectMake(card.bounds.size.width - 86, 24, 72, 32);
    self.actionButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.actionButton.layer.cornerRadius = 16.0;
    self.actionButton.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [self.actionButton addTarget:self action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.actionButton];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(96, 78, card.bounds.size.width - 110, 4);
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.progressView.hidden = YES;
    [card addSubview:self.progressView];
}

- (void)setupPreviewCard {
    UILabel *sectionHeader = [[UILabel alloc] initWithFrame:CGRectMake(24, 130, self.view.bounds.size.width - 150, 20)];
    sectionHeader.text = @"LIVE WALLPAPER PREVIEW";
    sectionHeader.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    sectionHeader.textColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:sectionHeader];

    UIButton *adjustBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    adjustBtn.frame = CGRectMake(self.view.bounds.size.width - 110, 126, 94, 28);
    adjustBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    adjustBtn.layer.cornerRadius = 14.0;
    adjustBtn.layer.cornerCurve = kCACornerCurveContinuous;
    adjustBtn.backgroundColor = [UIColor secondarySystemFillColor];
    [adjustBtn setTitle:@" Adjust" forState:UIControlStateNormal];
    [adjustBtn setImage:[UIImage systemImageNamed:@"crop"] forState:UIControlStateNormal];
    adjustBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [adjustBtn addTarget:self action:@selector(openWallpaperAdjuster) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:adjustBtn];

    CGFloat cardHeight = 205.0;
    self.previewCardContainer = [[UIView alloc] initWithFrame:CGRectMake(16, 155, self.view.bounds.size.width - 32, cardHeight)];
    self.previewCardContainer.layer.cornerRadius = 22.0;
    self.previewCardContainer.layer.cornerCurve = kCACornerCurveContinuous;
    self.previewCardContainer.clipsToBounds = YES;
    self.previewCardContainer.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.previewCardContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:self.previewCardContainer];

    UITapGestureRecognizer *cardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openWallpaperAdjuster)];
    [self.previewCardContainer addGestureRecognizer:cardTap];

    self.wallpaperImageView = [[UIImageView alloc] initWithFrame:self.previewCardContainer.bounds];
    self.wallpaperImageView.contentMode = UIViewContentModeScaleToFill;
    self.wallpaperImageView.clipsToBounds = YES;
    [self.previewCardContainer addSubview:self.wallpaperImageView];

    [self updateWallpaperDisplay];

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleWallpaperDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.previewCardContainer addGestureRecognizer:doubleTap];
    [cardTap requireGestureRecognizerToFail:doubleTap];

    self.wallpaperDimmingView = [[UIView alloc] initWithFrame:self.previewCardContainer.bounds];
    self.wallpaperDimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.wallpaperDimmingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.12];
    self.wallpaperDimmingView.userInteractionEnabled = NO;
    [self.previewCardContainer addSubview:self.wallpaperDimmingView];

    NSArray *titles = @[@"Light", @"Dark", @"Clear", @"Tinted"];
    CGFloat cardWidth = self.previewCardContainer.bounds.size.width;
    CGFloat iconSize = 68.0;
    CGFloat spacing = (cardWidth - (iconSize * 4)) / 5.0;
    CGFloat topY = 40.0;

    for (int i = 0; i < 4; i++) {
        CGFloat x = spacing + i * (iconSize + spacing);

        UIView *colView = [[UIView alloc] initWithFrame:CGRectMake(x, topY, iconSize, iconSize + 32)];
        colView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.previewCardContainer addSubview:colView];

        UIView *iconContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, iconSize, iconSize)];
        iconContainer.layer.cornerRadius = 16.0;
        iconContainer.layer.cornerCurve = kCACornerCurveContinuous;
        iconContainer.clipsToBounds = YES;
        [colView addSubview:iconContainer];

        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, iconSize, iconSize)];
        iconView.layer.cornerRadius = 16.0;
        iconView.layer.cornerCurve = kCACornerCurveContinuous;
        iconView.clipsToBounds = YES;
        iconView.contentMode = UIViewContentModeScaleAspectFill;

        if (i == 0) {
            self.lightColumnView = colView;
            self.lightIconView = iconView;
            [iconContainer addSubview:iconView];
        } else if (i == 1) {
            self.darkColumnView = colView;
            self.darkIconView = iconView;
            [iconContainer addSubview:iconView];
        } else if (i == 2) {
            self.clearColumnView = colView;
            self.clearIconView = iconView;

            self.clearBlurView = [[LGAdjustableBlurView alloc] initWithFrame:iconContainer.bounds];
            self.clearBlurView.layer.cornerRadius = 16.0;
            self.clearBlurView.layer.cornerCurve = kCACornerCurveContinuous;
            self.clearBlurView.clipsToBounds = YES;
            self.clearBlurView.blurRadius = 18.0;
            [iconContainer addSubview:self.clearBlurView];

            self.clearGlassView = [[LGLiveBackdropView alloc] initWithFrame:iconContainer.bounds];
            self.clearGlassView.layer.cornerRadius = 16.0;
            self.clearGlassView.layer.cornerCurve = kCACornerCurveContinuous;
            self.clearGlassView.clipsToBounds = YES;
            self.clearGlassView.qualityScale = 0.55;
            self.clearGlassView.capturesAppIcon = YES;
            [iconContainer addSubview:self.clearGlassView];

            [iconContainer addSubview:iconView];
        } else if (i == 3) {
            self.tintedColumnView = colView;
            self.tintedIconView = iconView;

            self.tintedBlurView = [[LGAdjustableBlurView alloc] initWithFrame:iconContainer.bounds];
            self.tintedBlurView.layer.cornerRadius = 16.0;
            self.tintedBlurView.layer.cornerCurve = kCACornerCurveContinuous;
            self.tintedBlurView.clipsToBounds = YES;
            self.tintedBlurView.blurRadius = 18.0;
            [iconContainer addSubview:self.tintedBlurView];

            self.tintedGlassView = [[LGLiveBackdropView alloc] initWithFrame:iconContainer.bounds];
            self.tintedGlassView.layer.cornerRadius = 16.0;
            self.tintedGlassView.layer.cornerCurve = kCACornerCurveContinuous;
            self.tintedGlassView.clipsToBounds = YES;
            self.tintedGlassView.qualityScale = 0.55;
            self.tintedGlassView.capturesAppIcon = YES;
            [iconContainer addSubview:self.tintedGlassView];

            self.tintedOverlayView = [[UIView alloc] initWithFrame:iconContainer.bounds];
            self.tintedOverlayView.layer.cornerRadius = 16.0;
            self.tintedOverlayView.layer.cornerCurve = kCACornerCurveContinuous;
            self.tintedOverlayView.clipsToBounds = YES;
            self.tintedOverlayView.userInteractionEnabled = NO;
            [iconContainer addSubview:self.tintedOverlayView];

            [iconContainer addSubview:iconView];
        }

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(-4, iconSize + 8, iconSize + 8, 18)];
        lbl.text = titles[i];
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.layer.shadowColor = [UIColor blackColor].CGColor;
        lbl.layer.shadowOffset = CGSizeMake(0, 1.5);
        lbl.layer.shadowRadius = 3.0;
        lbl.layer.shadowOpacity = 0.95;
        [colView addSubview:lbl];
    }
}

- (void)setupControlsSection {
    CGFloat startY = 375.0;
    CGFloat cardWidth = self.view.bounds.size.width - 32;

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(24, startY, cardWidth, 20)];
    header.text = @"PREVIEW CONTROLS";
    header.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    header.textColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:header];
    startY += 25.0;

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, startY, cardWidth, 245)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 14.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:card];

    self.appSelectorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.appSelectorButton.frame = CGRectMake(16, 8, cardWidth - 32, 40);
    self.appSelectorButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.appSelectorButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.appSelectorButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [self.appSelectorButton setTitle:[NSString stringWithFormat:@"Previewing: %@  ›", self.selectedAppName] forState:UIControlStateNormal];
    [self.appSelectorButton addTarget:self action:@selector(openAppPicker) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.appSelectorButton];

    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(16, 52, cardWidth - 16, 0.5)];
    sep1.backgroundColor = [UIColor separatorColor];
    sep1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:sep1];

    UILabel *appLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 62, 120, 32)];
    appLabel.text = @"Appearance";
    appLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [card addSubview:appLabel];

    self.appearanceSegment = [[UISegmentedControl alloc] initWithItems:@[@"Light", @"Dark"]];
    self.appearanceSegment.frame = CGRectMake(cardWidth - 140, 62, 124, 30);
    self.appearanceSegment.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.appearanceSegment.selectedSegmentIndex = self.isDarkMode ? 1 : 0;
    [self.appearanceSegment addTarget:self action:@selector(appearanceChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:self.appearanceSegment];

    UIView *sep2 = [[UIView alloc] initWithFrame:CGRectMake(16, 102, cardWidth - 16, 0.5)];
    sep2.backgroundColor = [UIColor separatorColor];
    sep2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:sep2];

    UILabel *hueLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 110, 100, 18)];
    hueLabel.text = @"Tint Color (Hue)";
    hueLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    hueLabel.textColor = [UIColor secondaryLabelColor];
    [card addSubview:hueLabel];

    CGFloat sliderH = 30.0;
    CGFloat thumbSize = 34.0;
    CGFloat sliderW = cardWidth - 32;

    self.hueSlider = [[UIView alloc] initWithFrame:CGRectMake(16, 132, sliderW, sliderH)];
    self.hueSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:self.hueSlider];

    UIView *hueTrack = [[UIView alloc] initWithFrame:self.hueSlider.bounds];
    hueTrack.layer.cornerRadius = sliderH / 2.0;
    hueTrack.clipsToBounds = YES;
    hueTrack.userInteractionEnabled = NO;
    hueTrack.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.hueSlider addSubview:hueTrack];

    self.hueGradient = [CAGradientLayer layer];
    self.hueGradient.frame = hueTrack.bounds;
    self.hueGradient.startPoint = CGPointMake(0, 0.5);
    self.hueGradient.endPoint = CGPointMake(1, 0.5);
    NSMutableArray *hueColors = [NSMutableArray array];
    for (int i = 0; i <= 360; i += 10) {
        [hueColors addObject:(id)[UIColor colorWithHue:i/360.0 saturation:1.0 brightness:1.0 alpha:1.0].CGColor];
    }
    self.hueGradient.colors = hueColors;
    [hueTrack.layer addSublayer:self.hueGradient];

    self.hueThumb = [[UIView alloc] initWithFrame:CGRectMake(0, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize)];
    self.hueThumb.backgroundColor = [UIColor whiteColor];
    self.hueThumb.layer.cornerRadius = thumbSize / 2.0;
    self.hueThumb.layer.borderWidth = 3.5;
    self.hueThumb.layer.borderColor = [UIColor whiteColor].CGColor;
    self.hueThumb.layer.shadowColor = [UIColor blackColor].CGColor;
    self.hueThumb.layer.shadowOpacity = 0.35;
    self.hueThumb.layer.shadowRadius = 4.0;
    self.hueThumb.layer.shadowOffset = CGSizeMake(0, 2);
    self.hueThumb.userInteractionEnabled = NO;
    [self.hueSlider addSubview:self.hueThumb];

    UIPanGestureRecognizer *huePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
    [self.hueSlider addGestureRecognizer:huePan];
    UITapGestureRecognizer *hueTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
    [self.hueSlider addGestureRecognizer:hueTap];

    UILabel *briLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 172, 100, 18)];
    briLabel.text = @"Saturation / Brightness";
    briLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    briLabel.textColor = [UIColor secondaryLabelColor];
    [card addSubview:briLabel];

    self.brightnessSlider = [[UIView alloc] initWithFrame:CGRectMake(16, 194, sliderW, sliderH)];
    self.brightnessSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:self.brightnessSlider];

    UIView *briTrack = [[UIView alloc] initWithFrame:self.brightnessSlider.bounds];
    briTrack.layer.cornerRadius = sliderH / 2.0;
    briTrack.clipsToBounds = YES;
    briTrack.userInteractionEnabled = NO;
    briTrack.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.brightnessSlider addSubview:briTrack];

    self.brightnessGradient = [CAGradientLayer layer];
    self.brightnessGradient.frame = briTrack.bounds;
    self.brightnessGradient.startPoint = CGPointMake(0, 0.5);
    self.brightnessGradient.endPoint = CGPointMake(1, 0.5);
    [briTrack.layer addSublayer:self.brightnessGradient];

    self.brightnessThumb = [[UIView alloc] initWithFrame:CGRectMake(0, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize)];
    self.brightnessThumb.backgroundColor = [UIColor whiteColor];
    self.brightnessThumb.layer.cornerRadius = thumbSize / 2.0;
    self.brightnessThumb.layer.borderWidth = 3.5;
    self.brightnessThumb.layer.borderColor = [UIColor whiteColor].CGColor;
    self.brightnessThumb.layer.shadowColor = [UIColor blackColor].CGColor;
    self.brightnessThumb.layer.shadowOpacity = 0.35;
    self.brightnessThumb.layer.shadowRadius = 4.0;
    self.brightnessThumb.layer.shadowOffset = CGSizeMake(0, 2);
    self.brightnessThumb.userInteractionEnabled = NO;
    [self.brightnessSlider addSubview:self.brightnessThumb];

    UIPanGestureRecognizer *briPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBrightnessPan:)];
    [self.brightnessSlider addGestureRecognizer:briPan];
    UITapGestureRecognizer *briTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBrightnessPan:)];
    [self.brightnessSlider addGestureRecognizer:briTap];

    [self updateSliderThumbs];
    [self updateBrightnessGradient];

    BOOL hasNS = [self.pack.themes containsObject:@"DarkNS"] || [self.pack.themes containsObject:@"LightNS"];
    if (hasNS) {
        card.frame = CGRectMake(16, startY, cardWidth, 300);

        UIView *sep3 = [[UIView alloc] initWithFrame:CGRectMake(16, 240, cardWidth - 16, 0.5)];
        sep3.backgroundColor = [UIColor separatorColor];
        sep3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [card addSubview:sep3];

        UILabel *specLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 250, 160, 32)];
        specLabel.text = @"Specular Highlights";
        specLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        [card addSubview:specLabel];

        self.specularSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cardWidth - 66, 250, 51, 31)];
        self.specularSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        self.specularSwitch.on = self.specularEnabled;
        [self.specularSwitch addTarget:self action:@selector(specularToggled:) forControlEvents:UIControlEventValueChanged];
        [card addSubview:self.specularSwitch];
    }
}

- (void)setupInfoSection {
    CGFloat cardWidth = self.view.bounds.size.width - 32;
    BOOL hasNS = [self.pack.themes containsObject:@"DarkNS"] || [self.pack.themes containsObject:@"LightNS"];
    CGFloat startY = hasNS ? 715.0 : 660.0;

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(24, startY, cardWidth, 20)];
    header.text = @"ABOUT THIS PACK";
    header.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    header.textColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:header];
    startY += 25.0;

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, startY, cardWidth, 130)];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 14.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.contentView addSubview:card];

    self.descLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, cardWidth - 32, 50)];
    self.descLabel.text = self.pack.packDescription;
    self.descLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.descLabel.textColor = [UIColor labelColor];
    self.descLabel.numberOfLines = 0;
    self.descLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.descLabel sizeToFit];
    [card addSubview:self.descLabel];

    UILabel *themesLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, self.descLabel.frame.origin.y + self.descLabel.frame.size.height + 10, cardWidth - 32, 18)];
    themesLbl.text = [NSString stringWithFormat:@"Themes: %@", [self.pack.themes componentsJoinedByString:@", "]];
    themesLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    themesLbl.textColor = [UIColor secondaryLabelColor];
    themesLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [card addSubview:themesLbl];

    card.frame = CGRectMake(16, startY, cardWidth, themesLbl.frame.origin.y + themesLbl.frame.size.height + 14);
    startY += card.frame.size.height + 20;

    self.deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.deleteButton.frame = CGRectMake(16, startY, cardWidth, 44);
    self.deleteButton.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.deleteButton.layer.cornerRadius = 14.0;
    self.deleteButton.layer.cornerCurve = kCACornerCurveContinuous;
    self.deleteButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.deleteButton setTitle:@"Delete Icon Pack" forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    self.deleteButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.deleteButton addTarget:self action:@selector(deleteButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.deleteButton];

    self.contentView.frame = CGRectMake(0, 0, self.view.bounds.size.width, startY + 80);
    self.scrollView.contentSize = self.contentView.frame.size;
}

#pragma mark - Slider Gestures & Updating

- (void)handleHuePan:(UIGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self.hueSlider];
    CGFloat thumbSize = 34.0;
    CGFloat width = self.hueSlider.frame.size.width;
    CGFloat maxTravel = width - thumbSize;
    if (maxTravel <= 0) return;

    CGFloat val = (loc.x - thumbSize / 2.0) / maxTravel;
    val = fminf(fmaxf(val, 0.0), 1.0);
    self.currentHue = val;

    [self updateCurrentTintColor];
    [self updateSliderThumbs];
    [self updateBrightnessGradient];
    [self refreshPreviewIcons];
}

- (void)handleBrightnessPan:(UIGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self.brightnessSlider];
    CGFloat thumbSize = 34.0;
    CGFloat width = self.brightnessSlider.frame.size.width;
    CGFloat maxTravel = width - thumbSize;
    if (maxTravel <= 0) return;

    CGFloat val = (loc.x - thumbSize / 2.0) / maxTravel;
    val = fminf(fmaxf(val, 0.0), 1.0);
    self.currentBrightness = val;

    [self updateCurrentTintColor];
    [self updateSliderThumbs];
    [self refreshPreviewIcons];
}

- (void)updateSliderThumbs {
    CGFloat thumbSize = 34.0;
    CGFloat sliderH = self.hueSlider.frame.size.height;
    CGFloat maxTravelHue = self.hueSlider.frame.size.width - thumbSize;
    if (maxTravelHue <= 0) maxTravelHue = 200;

    CGFloat hX = self.currentHue * maxTravelHue;
    self.hueThumb.frame = CGRectMake(hX, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize);
    self.hueThumb.backgroundColor = [UIColor colorWithHue:self.currentHue saturation:1.0 brightness:1.0 alpha:1.0];

    CGFloat maxTravelBri = self.brightnessSlider.frame.size.width - thumbSize;
    if (maxTravelBri <= 0) maxTravelBri = 200;

    CGFloat bX = self.currentBrightness * maxTravelBri;
    self.brightnessThumb.frame = CGRectMake(bX, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize);
    self.brightnessThumb.backgroundColor = self.selectedTintColor;
}

- (void)updateBrightnessGradient {
    CGFloat h = self.currentHue;
    self.brightnessGradient.colors = @[
        (id)[UIColor colorWithHue:h saturation:1.0 brightness:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithHue:h saturation:0.0 brightness:1.0 alpha:1.0].CGColor
    ];
}

#pragma mark - IconGen Powered Live Preview Rendering

- (UIImage *)findPremadeIconForBundleID:(NSString *)bundleID theme:(NSString *)theme {
    if (!self.packDirectory || !bundleID || !theme) return nil;

    if ([bundleID isEqualToString:@"com.apple.mobiletimer"]) {
        NSString *c1 = [[self.packDirectory stringByAppendingPathComponent:theme] stringByAppendingPathComponent:@"ClockIconBackgroundSquare.png"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:c1]) return [UIImage imageWithContentsOfFile:c1];
        NSString *c2 = [[self.packDirectory stringByAppendingPathComponent:theme] stringByAppendingPathComponent:@"ClockIconBackgroundSquare-large.png"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:c2]) return [UIImage imageWithContentsOfFile:c2];
    }

    NSString *fn1 = [NSString stringWithFormat:@"%@-large.png", bundleID];
    NSString *fn2 = [NSString stringWithFormat:@"%@.png", bundleID];

    NSString *p1 = [[self.packDirectory stringByAppendingPathComponent:theme] stringByAppendingPathComponent:fn1];
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return [UIImage imageWithContentsOfFile:p1];

    NSString *p2 = [[self.packDirectory stringByAppendingPathComponent:theme] stringByAppendingPathComponent:fn2];
    if ([[NSFileManager defaultManager] fileExistsAtPath:p2]) return [UIImage imageWithContentsOfFile:p2];

    return nil;
}

- (UIImage *)baseIconForBundleID:(NSString *)bundleID {
    NSArray *themes = @[@"Light", @"Dark", @"ClearLight", @"ClearDark", @"DarkNS", @"LightNS", @"ClearLightNS", @"ClearDarkNS"];
    for (NSString *t in themes) {
        UIImage *img = [self findPremadeIconForBundleID:bundleID theme:t];
        if (img) return img;
    }

    UIImage *orig = [[LGCustomIconGenerator2 sharedGenerator] originalImageForBundleID:bundleID];
    if (orig) return orig;

    NSString *defaultSolidGlass = jbroot(@"/Library/Application Support/26Home/SolidGlass/Light");
    NSString *fbPath = [defaultSolidGlass stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-large.png", bundleID]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fbPath]) {
        return [UIImage imageWithContentsOfFile:fbPath];
    }

    return nil;
}

- (void)refreshPreviewIcons {
    NSString *bundleID = self.selectedBundleID ?: @"com.apple.weather";
    UIImage *baseGlyph = [self baseIconForBundleID:bundleID];
    LGCustomIconGenerator2 *iconGen = [LGCustomIconGenerator2 sharedGenerator];

    UIImage *lightImg = nil;
    BOOL isLightNS = NO;
    if (self.specularEnabled) {
        lightImg = [self findPremadeIconForBundleID:bundleID theme:@"Light"];
        if (!lightImg) {
            lightImg = [self findPremadeIconForBundleID:bundleID theme:@"LightNS"];
            isLightNS = (lightImg != nil);
        }
    } else {
        lightImg = [self findPremadeIconForBundleID:bundleID theme:@"LightNS"];
        if (!lightImg) {
            lightImg = [self findPremadeIconForBundleID:bundleID theme:@"Light"];
        }
    }
    if (!lightImg) {

        lightImg = baseGlyph;
        isLightNS = YES;
    }
    if (lightImg && self.specularEnabled && isLightNS) {
        lightImg = [iconGen applySpecularHighlightToImage:lightImg];
    }
    self.lightIconView.image = lightImg;

    UIImage *darkImg = nil;
    BOOL isDarkNS = NO;
    if (self.specularEnabled) {
        darkImg = [self findPremadeIconForBundleID:bundleID theme:@"Dark"];
        if (!darkImg) {
            darkImg = [self findPremadeIconForBundleID:bundleID theme:@"DarkNS"];
            isDarkNS = (darkImg != nil);
        }
    } else {
        darkImg = [self findPremadeIconForBundleID:bundleID theme:@"DarkNS"];
        if (!darkImg) {
            darkImg = [self findPremadeIconForBundleID:bundleID theme:@"Dark"];
        }
    }

    if (!darkImg) {

        darkImg = [iconGen generateDarkIconForImage:lightImg ?: baseGlyph bundleID:nil];
        isDarkNS = YES;
    }
    if (darkImg && self.specularEnabled && isDarkNS) {
        darkImg = [iconGen applySpecularHighlightToImage:darkImg];
    }
    self.darkIconView.image = darkImg ?: lightImg;

    NSString *clearTheme = self.isDarkMode ? @"ClearDark" : @"ClearLight";
    NSString *clearNSTheme = self.isDarkMode ? @"ClearDarkNS" : @"ClearLightNS";
    UIImage *clearImg = nil;
    if (self.specularEnabled) {
        clearImg = [self findPremadeIconForBundleID:bundleID theme:clearTheme];
        if (!clearImg) {
            clearImg = [self findPremadeIconForBundleID:bundleID theme:clearNSTheme];
        }
    } else {
        clearImg = [self findPremadeIconForBundleID:bundleID theme:clearNSTheme];
        if (!clearImg) {
            clearImg = [self findPremadeIconForBundleID:bundleID theme:clearTheme];
        }
    }

    if (!clearImg) {

        UIImage *glyphSource = [self findPremadeIconForBundleID:bundleID theme:self.isDarkMode ? @"ClearDarkNS" : @"ClearLightNS"];
        if (!glyphSource) {
            glyphSource = [iconGen generateClearIconForImage:darkImg ?: lightImg ?: baseGlyph bundleID:nil];
        }
        if (!glyphSource) glyphSource = darkImg ?: lightImg ?: baseGlyph;

        clearImg = [iconGen compositeGlyph:glyphSource
                       withBackgroundStyle:@"Clear"
                               isDarkTheme:self.isDarkMode
                                 tintColor:nil
                           isAutoGenerated:YES
                              drawSpecular:self.specularEnabled];
    }
    self.clearIconView.image = clearImg;

    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    BOOL disableGlass = [prefs boolForKey:@"ngkhoi.26home.disableLiquidGlassIcons"];
    BOOL keepBlur = [prefs objectForKey:@"ngkhoi.26home.keepAppIconBlur"] ? [prefs boolForKey:@"ngkhoi.26home.keepAppIconBlur"] : YES;
    CGFloat blurRadius = [prefs objectForKey:@"ngkhoi.26home.appIconBlurRadius"] ? [prefs floatForKey:@"ngkhoi.26home.appIconBlurRadius"] : 1.0;
    CGFloat quality = [prefs objectForKey:@"ngkhoi.26home.appIconGlassQuality"] ? [prefs floatForKey:@"ngkhoi.26home.appIconGlassQuality"] : 0.35;

    self.clearBlurView.blurRadius = blurRadius;
    self.clearBlurView.hidden = !keepBlur;
    self.clearGlassView.qualityScale = quality;
    self.clearGlassView.hidden = disableGlass;
    [self.clearGlassView forceReapplyForRegistrationRace];

    UIImage *clearGlyph = [self findPremadeIconForBundleID:bundleID theme:@"ClearLight"];
    if (!clearGlyph) {
        clearGlyph = [self findPremadeIconForBundleID:bundleID theme:@"ClearLightNS"];
        if (clearGlyph) {
        } else {
            UIImage *lightTheme = [self findPremadeIconForBundleID:bundleID theme:@"Light"] ?: [self findPremadeIconForBundleID:bundleID theme:@"LightNS"];
            if (lightTheme) {
                clearGlyph = [iconGen generateClearIconForImage:lightTheme bundleID:nil];
                if (!clearGlyph) clearGlyph = lightTheme;
            } else {
                clearGlyph = [self findPremadeIconForBundleID:bundleID theme:@"ClearDark"];
                if (!clearGlyph) {
                    clearGlyph = [self findPremadeIconForBundleID:bundleID theme:@"ClearDarkNS"];
                    if (clearGlyph) {
                    } else {
                        UIImage *darkTheme = [self findPremadeIconForBundleID:bundleID theme:@"DarkNS"] ?: [self findPremadeIconForBundleID:bundleID theme:@"Dark"];
                        if (darkTheme) {
                            clearGlyph = [iconGen generateClearIconForImage:darkTheme bundleID:nil];
                            if (!clearGlyph) clearGlyph = darkTheme;
                        }
                    }
                }
            }
        }
    }

    BOOL isTintedAutoGenerated = NO;
    if (!clearGlyph) {
        clearGlyph = [iconGen generateClearIconForImage:lightImg ?: darkImg ?: baseGlyph bundleID:nil];
        if (!clearGlyph) clearGlyph = lightImg ?: darkImg ?: baseGlyph;
        isTintedAutoGenerated = YES;
    }

    BOOL applyTintedSpecular = self.specularEnabled && isTintedAutoGenerated;

    if (self.isDarkMode) {

        UIImage *styled = [iconGen compositeGlyph:clearGlyph
                              withBackgroundStyle:@"Tinted"
                                      isDarkTheme:YES
                                        tintColor:self.selectedTintColor
                                  isAutoGenerated:applyTintedSpecular
                                     drawSpecular:applyTintedSpecular];
        if (styled) {
            UIGraphicsBeginImageContextWithOptions(styled.size, NO, styled.scale);
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, styled.size.width, styled.size.height) cornerRadius:styled.size.width * 0.256];
            [path addClip];

            [self.selectedTintColor setFill];
            UIRectFill(CGRectMake(0, 0, styled.size.width, styled.size.height));

            [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeLuminosity alpha:1.0];
            [styled drawInRect:CGRectMake(0, 0, styled.size.width, styled.size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0];

            UIImage *tintedResult = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            if (tintedResult && applyTintedSpecular) {
                tintedResult = [iconGen applySpecularHighlightToImage:tintedResult];
            }
            self.tintedIconView.image = tintedResult;
        } else {
            self.tintedIconView.image = clearGlyph;
        }
        self.tintedGlassView.hidden = YES;
        self.tintedBlurView.hidden = YES;
        self.tintedOverlayView.hidden = YES;
    } else {

        UIImage *styled = [iconGen compositeGlyph:clearGlyph
                              withBackgroundStyle:@"Tinted"
                                      isDarkTheme:NO
                                        tintColor:self.selectedTintColor
                                  isAutoGenerated:applyTintedSpecular
                                     drawSpecular:applyTintedSpecular];
        self.tintedIconView.image = styled ?: clearGlyph;
        self.tintedBlurView.blurRadius = blurRadius;
        self.tintedBlurView.hidden = !keepBlur;
        self.tintedGlassView.qualityScale = quality;
        self.tintedGlassView.hidden = disableGlass;
        self.tintedOverlayView.hidden = NO;
        self.tintedOverlayView.backgroundColor = [self.selectedTintColor colorWithAlphaComponent:0.35];
        [self.tintedGlassView forceReapplyForRegistrationRace];
    }
}

#pragma mark - Actions & Handlers

- (void)openAppPicker {
    Home26IconPickerViewController *picker = [[Home26IconPickerViewController alloc] init];
    picker.packDirectory = self.packDirectory;
    picker.themes = self.pack.themes;
    picker.selectedBundleID = self.selectedBundleID;

    __weak typeof(self) weakSelf = self;
    picker.onSelectApp = ^(NSString *bundleID, NSString *displayName) {
        weakSelf.selectedBundleID = bundleID;
        weakSelf.selectedAppName = displayName;
        [weakSelf.appSelectorButton setTitle:[NSString stringWithFormat:@"Previewing: %@  ›", displayName] forState:UIControlStateNormal];
        [weakSelf refreshPreviewIcons];
    };

    [self.navigationController pushViewController:picker animated:YES];
}

- (void)appearanceChanged:(UISegmentedControl *)sender {
    self.isDarkMode = (sender.selectedSegmentIndex == 1);
    [UIView transitionWithView:self.previewCardContainer duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [self refreshPreviewIcons];
    } completion:nil];
}

- (void)specularToggled:(UISwitch *)sender {
    self.specularEnabled = sender.isOn;
    [self refreshPreviewIcons];
}

- (void)updateActionState {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSString *activeId = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: @"SolidGlass";

    BOOL isInstalled = NO;
    if (self.packDirectory && [[NSFileManager defaultManager] fileExistsAtPath:self.packDirectory]) {
        for (NSString *theme in self.pack.themes) {
            NSString *tp = [self.packDirectory stringByAppendingPathComponent:theme];
            NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tp error:nil];
            if (items && items.count > 0) {
                isInstalled = YES;
                break;
            }
        }
    }

    BOOL isActive = isInstalled && [self.pack.packId isEqualToString:activeId];

    if (self.pack.isDownloading) {
        self.actionButton.hidden = YES;
        self.progressView.hidden = NO;
        self.progressView.progress = self.pack.downloadProgress;
    } else {
        self.progressView.hidden = YES;
        self.actionButton.hidden = NO;

        if (!isInstalled) {
            [self.actionButton setTitle:@"GET" forState:UIControlStateNormal];
            self.actionButton.backgroundColor = [UIColor systemBlueColor];
            [self.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self.deleteButton.hidden = YES;
        } else if (isActive) {
            [self.actionButton setTitle:@"Enabled ✓" forState:UIControlStateNormal];
            self.actionButton.backgroundColor = [UIColor systemGreenColor];
            [self.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self.deleteButton.hidden = NO;
        } else {
            [self.actionButton setTitle:@"Apply" forState:UIControlStateNormal];
            self.actionButton.backgroundColor = [UIColor systemGray5Color];
            [self.actionButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
            self.deleteButton.hidden = NO;
        }
    }
}

- (void)actionButtonTapped {
    if (self.pack.isDownloading) return;

    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSString *activeId = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: @"SolidGlass";

    BOOL isInstalled = NO;
    if (self.packDirectory && [[NSFileManager defaultManager] fileExistsAtPath:self.packDirectory]) {
        for (NSString *theme in self.pack.themes) {
            NSString *tp = [self.packDirectory stringByAppendingPathComponent:theme];
            NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tp error:nil];
            if (items && items.count > 0) {
                isInstalled = YES;
                break;
            }
        }
    }

    if (!isInstalled) {
        if (self.onRequestDownload) self.onRequestDownload(self.pack);
        [self updateActionState];
    } else if (![self.pack.packId isEqualToString:activeId]) {
        if (self.onRequestApply) self.onRequestApply(self.pack);
        [self updateActionState];
    } else {

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:self.pack.name
                                                                       message:@"This icon pack is currently active and enabled."
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Reload / Re-apply Pack" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (self.onRequestApply) self.onRequestApply(self.pack);
            [self updateActionState];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Redownload / Update Pack" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (self.onRequestDownload) self.onRequestDownload(self.pack);
            [self updateActionState];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Delete Pack" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self deleteButtonTapped];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:sheet animated:YES completion:nil];
    }
}

- (void)deleteButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Pack"
                                                                   message:[NSString stringWithFormat:@"Are you sure you want to delete %@?", self.pack.name]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if (self.onRequestDelete) {
            self.onRequestDelete(self.pack);
        }
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateDownloadProgress:(float)progress {
    self.pack.downloadProgress = progress;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.hidden = NO;
        self.progressView.progress = progress;
        self.actionButton.hidden = YES;
        self.metaLabel.text = [NSString stringWithFormat:@"Downloading... %.0f%%", progress * 100.0];
    });
}

- (void)downloadDidCompleteWithSuccess:(BOOL)success {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.hidden = YES;
        self.actionButton.hidden = NO;
        NSMutableArray *parts = [NSMutableArray array];
        if (self.pack.iconCount > 0) [parts addObject:[NSString stringWithFormat:@"%ld icons", (long)self.pack.iconCount]];
        if (self.pack.size.length > 0) [parts addObject:self.pack.size];
        if (self.pack.version.length > 0) [parts addObject:[NSString stringWithFormat:@"v%@", self.pack.version]];
        self.metaLabel.text = [parts componentsJoinedByString:@" • "];
        [self updateActionState];
        [self refreshPreviewIcons];
    });
}

#pragma mark - Wallpaper Management & Cropping

- (void)openWallpaperAdjuster {
    if (!self.rawWallpaperImage) {
        self.rawWallpaperImage = [Home26WallpaperHelper currentDeviceWallpaper];
    }
    if (!self.rawWallpaperImage) return;

    Home26WallpaperCropViewController *cropVC = [[Home26WallpaperCropViewController alloc] init];
    cropVC.wallpaperImage = self.rawWallpaperImage;
    cropVC.initialVerticalOffset = self.wallpaperVerticalOffset;
    cropVC.lightIcon = self.lightIconView.image;
    cropVC.darkIcon = self.darkIconView.image;
    cropVC.clearIcon = self.clearIconView.image;
    cropVC.tintedIcon = self.tintedIconView.image;

    __weak typeof(self) weakSelf = self;
    cropVC.onCropFinished = ^(CGFloat offsetY) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.wallpaperVerticalOffset = offsetY;
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        [prefs setFloat:offsetY forKey:@"ngkhoi.26home.previewWallpaperOffsetY"];
        [prefs synchronize];
        [self layoutWallpaperImage];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:cropVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)updateWallpaperDisplay {
    __weak typeof(self) weakSelf = self;
    [Home26WallpaperHelper fetchCurrentWallpaperAsync:^(UIImage *image) {
        if (!image) return;
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        self.rawWallpaperImage = image;
        [self layoutWallpaperImage];
    }];
}

- (void)layoutWallpaperImage {
    if (!self.rawWallpaperImage || !self.previewCardContainer) return;

    CGFloat cardWidth = self.previewCardContainer.bounds.size.width;
    CGFloat cardHeight = self.previewCardContainer.bounds.size.height;
    if (cardWidth <= 0 || cardHeight <= 0) return;

    CGFloat imgWidth = self.rawWallpaperImage.size.width;
    CGFloat imgHeight = self.rawWallpaperImage.size.height;
    if (imgWidth <= 0 || imgHeight <= 0) return;

    CGFloat scaledHeight = cardWidth * (imgHeight / imgWidth);
    if (scaledHeight < cardHeight) scaledHeight = cardHeight;
    CGFloat maxScrollY = scaledHeight - cardHeight;

    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    if (![prefs objectForKey:@"ngkhoi.26home.previewWallpaperOffsetY"]) {
        self.wallpaperVerticalOffset = maxScrollY * 0.25;
    } else {
        self.wallpaperVerticalOffset = [prefs floatForKey:@"ngkhoi.26home.previewWallpaperOffsetY"];
        if (self.wallpaperVerticalOffset < 0) self.wallpaperVerticalOffset = 0;
        if (self.wallpaperVerticalOffset > maxScrollY) self.wallpaperVerticalOffset = maxScrollY;
    }

    [UIView transitionWithView:self.wallpaperImageView duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.wallpaperImageView.image = self.rawWallpaperImage;
        self.wallpaperImageView.frame = CGRectMake(0, -self.wallpaperVerticalOffset, cardWidth, scaledHeight);
    } completion:nil];
}

- (void)handleWallpaperDoubleTap:(UITapGestureRecognizer *)tap {
    if (!self.rawWallpaperImage || !self.previewCardContainer) return;

    CGFloat cardWidth = self.previewCardContainer.bounds.size.width;
    CGFloat cardHeight = self.previewCardContainer.bounds.size.height;
    CGFloat imgWidth = self.rawWallpaperImage.size.width;
    CGFloat imgHeight = self.rawWallpaperImage.size.height;
    if (imgWidth <= 0 || imgHeight <= 0) return;

    CGFloat scaledHeight = cardWidth * (imgHeight / imgWidth);
    if (scaledHeight < cardHeight) scaledHeight = cardHeight;
    CGFloat maxScrollY = scaledHeight - cardHeight;

    self.wallpaperVerticalOffset = maxScrollY * 0.25;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.wallpaperImageView.frame = CGRectMake(0, -self.wallpaperVerticalOffset, cardWidth, scaledHeight);
    } completion:nil];

    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [prefs setFloat:self.wallpaperVerticalOffset forKey:@"ngkhoi.26home.previewWallpaperOffsetY"];
    [prefs synchronize];
}

@end
