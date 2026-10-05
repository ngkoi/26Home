#import "Headers.h"
#import <notify.h>

static inline void Home26PostStyleUpdate18(void) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
        notify_post("ngkhoi.26home.UpdateIconStyle");
    });
}

static UIImage *LGCreateAutomaticWeatherImage(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSString *selectedPack = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: @"SolidGlass";
    NSString *basePath = jbroot([NSString stringWithFormat:@"/Library/Application Support/26Home/IconPacks/%@", selectedPack]);
    if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
        basePath = [NSString stringWithFormat:@"/Library/Application Support/26Home/IconPacks/%@", selectedPack];
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
        basePath = jbroot(@"/Library/Application Support/26Home/SolidGlass");
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
        basePath = @"/Library/Application Support/26Home/SolidGlass";
    }
    UIImage *lightImg = [UIImage imageWithContentsOfFile:[basePath stringByAppendingPathComponent:@"Light/com.apple.weather-large.png"]];
    UIImage *darkImg = [UIImage imageWithContentsOfFile:[basePath stringByAppendingPathComponent:@"Dark/com.apple.weather-large.png"]];

    if (!lightImg || !darkImg) return lightImg ?: darkImg;

    CGSize size = CGSizeMake(60, 60);
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);

    [lightImg drawInRect:CGRectMake(0, 0, size.width, size.height)];

    UIBezierPath *diagPath = [UIBezierPath bezierPath];
    [diagPath moveToPoint:CGPointMake(0, size.height)];
    [diagPath addLineToPoint:CGPointMake(size.width, 0)];
    [diagPath addLineToPoint:CGPointMake(size.width, size.height)];
    [diagPath closePath];

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    [diagPath addClip];
    [darkImg drawInRect:CGRectMake(0, 0, size.width, size.height)];
    CGContextRestoreGState(ctx);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@interface HomeCustomizationMenuContainer18 () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIButton *sunBtn;
@property (nonatomic, strong) UIView *scaleSegment;
@property (nonatomic, strong) UIView *scalePill;
@property (nonatomic, strong) UIButton *smallBtn;
@property (nonatomic, strong) UIButton *largeBtn;
@property (nonatomic, strong) UIButton *eyedropperBtn;

@property (nonatomic, strong) NSMutableArray<UIButton *> *styleButtons;
@property (nonatomic, strong) NSMutableArray<UILabel *> *styleLabels;
@property (nonatomic, strong) UIView *tintWeatherOverlay;

@property (nonatomic, strong) UIView *slidersContainer;
@property (nonatomic, strong) UIView *hueSlider;
@property (nonatomic, strong) UIView *hueThumb;
@property (nonatomic, strong) UIView *brightnessSlider;
@property (nonatomic, strong) UIView *brightnessThumb;
@property (nonatomic, strong) CAGradientLayer *hueGradient;
@property (nonatomic, strong) CAGradientLayer *brightnessGradient;
@property (nonatomic, assign) CGFloat currentHue;
@property (nonatomic, assign) CGFloat currentBrightness;
@end

@implementation HomeCustomizationMenuContainer18

- (CGFloat)_bottomOffset {
    CGFloat floatDockHeight = 0.0;

    NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.bounds.size.height > 0) {
            NSMutableArray *queue = [NSMutableArray arrayWithObject:window];
            UIView *foundFloatingDock = nil;

            while (queue.count > 0) {
                UIView *v = [queue firstObject];
                [queue removeObjectAtIndex:0];

                NSString *className = NSStringFromClass([v class]);

                if ([className containsString:@"FloatingDockView"]) {

                    if (!v.hidden && v.alpha > 0.0) {
                        foundFloatingDock = v;
                        break;
                    }
                }

                if (v.subviews.count > 0) {
                    [queue addObjectsFromArray:v.subviews];
                }
            }

            if (foundFloatingDock) {
                CGRect frameInSelf = [foundFloatingDock convertRect:foundFloatingDock.bounds toView:self];
                if (frameInSelf.size.height > 0 && frameInSelf.origin.y > 0) {
                    floatDockHeight = self.bounds.size.height - frameInSelf.origin.y;
                    break;
                }
            }
        }
    }

    if (floatDockHeight > 0.0 && floatDockHeight < self.bounds.size.height * 0.35) {
        return floatDockHeight + 14.0;
    }

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return 96.0 + 14.0;
    }

    return 8.0;
}

- (CGFloat)_restingYForMenuHeight:(CGFloat)menuHeight {
    CGFloat rawY = self.bounds.size.height - menuHeight - [self _bottomOffset];
    CGFloat minY = (self.safeAreaInsets.top > 0 ? self.safeAreaInsets.top : 20.0) + 10.0;
    return MAX(minY, rawY);
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.styleButtons = [NSMutableArray array];
        self.styleLabels = [NSMutableArray array];

        UIButton *bgButton = [UIButton buttonWithType:UIButtonTypeCustom];
        bgButton.frame = self.bounds;
        [bgButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:bgButton];

        CGFloat menuWidth = frame.size.width - 20;
        CGFloat initialHeight = 175;
        self.menuView = [[UIView alloc] initWithFrame:CGRectMake(10, frame.size.height, menuWidth, initialHeight)];
        self.menuView.layer.cornerRadius = 40;
        self.menuView.layer.masksToBounds = YES;
        self.menuView.layer.borderWidth = 0.5;
        self.menuView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;

        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
        if (!blurEffect) {
            blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        }
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = self.menuView.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.layer.cornerRadius = 40;
        blurView.clipsToBounds = YES;
        [self.menuView addSubview:blurView];

        UIPanGestureRecognizer *menuPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPull:)];
        menuPan.delegate = self;
        [self.menuView addGestureRecognizer:menuPan];

        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        BOOL isDimmed = [defaults boolForKey:@"ngkhoi.26home.dimWallpaper"];
        BOOL isLarge = [defaults boolForKey:@"ngkhoi.26home.largeIcons"];

        UIImageSymbolConfiguration *sunConfig = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIFontWeightMedium];
        self.sunBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.sunBtn.frame = CGRectMake(18, 16, 38, 38);
        [self.sunBtn setImage:(isDimmed ? LGImageNamed(@"sun.lefthalf.filled") : [UIImage systemImageNamed:@"sun.max" withConfiguration:sunConfig]) forState:UIControlStateNormal];
        self.sunBtn.tintColor = isDimmed ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.55];
        [self.sunBtn addTarget:self action:@selector(toggleWallpaperDimming:) forControlEvents:UIControlEventTouchUpInside];
        [self.menuView addSubview:self.sunBtn];

        CGFloat segWidth = 140;
        CGFloat segHeight = 36;
        self.scaleSegment = [[UIView alloc] initWithFrame:CGRectMake((menuWidth - segWidth) / 2.0, 17, segWidth, segHeight)];
        self.scaleSegment.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        self.scaleSegment.layer.cornerRadius = segHeight / 2.0;
        self.scaleSegment.layer.cornerCurve = kCACornerCurveContinuous;
        self.scaleSegment.clipsToBounds = YES;
        [self.menuView addSubview:self.scaleSegment];

        CGFloat itemWidth = segWidth / 2.0;
        self.scalePill = [[UIView alloc] initWithFrame:CGRectMake(isLarge ? itemWidth : 0, 0, itemWidth, segHeight)];
        self.scalePill.backgroundColor = [UIColor whiteColor];
        self.scalePill.layer.cornerRadius = segHeight / 2.0;
        self.scalePill.layer.cornerCurve = kCACornerCurveContinuous;
        [self.scaleSegment addSubview:self.scalePill];

        self.smallBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.smallBtn.frame = CGRectMake(0, 0, itemWidth, segHeight);
        [self.smallBtn setTitle:@"Small" forState:UIControlStateNormal];
        [self.smallBtn setTitleColor:(isLarge ? [UIColor whiteColor] : [UIColor blackColor]) forState:UIControlStateNormal];
        self.smallBtn.titleLabel.font = isLarge ? [UIFont systemFontOfSize:14 weight:UIFontWeightMedium] : [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [self.smallBtn addTarget:self action:@selector(selectScaleSmall:) forControlEvents:UIControlEventTouchUpInside];
        [self.scaleSegment addSubview:self.smallBtn];

        self.largeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.largeBtn.frame = CGRectMake(itemWidth, 0, itemWidth, segHeight);
        [self.largeBtn setTitle:@"Large" forState:UIControlStateNormal];
        [self.largeBtn setTitleColor:(isLarge ? [UIColor blackColor] : [UIColor whiteColor]) forState:UIControlStateNormal];
        self.largeBtn.titleLabel.font = isLarge ? [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [self.largeBtn addTarget:self action:@selector(selectScaleLarge:) forControlEvents:UIControlEventTouchUpInside];
        [self.scaleSegment addSubview:self.largeBtn];

        self.eyedropperBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.eyedropperBtn.frame = CGRectMake(menuWidth - 56, 16, 38, 38);
        UIImage *eyeIcon = [UIImage systemImageNamed:@"eyedropper" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIFontWeightMedium]];
        [self.eyedropperBtn setImage:eyeIcon forState:UIControlStateNormal];
        self.eyedropperBtn.tintColor = [UIColor whiteColor];
        [self.eyedropperBtn addTarget:self action:@selector(eyedropperTapped) forControlEvents:UIControlEventTouchUpInside];
        self.eyedropperBtn.alpha = 0.0;
        self.eyedropperBtn.userInteractionEnabled = NO;
        [self.menuView addSubview:self.eyedropperBtn];

        NSArray *styleTitles = @[@"Light", @"Dark", @"Automatic", @"Tinted"];
        CGFloat buttonSize = 60.0;
        CGFloat spacing = (menuWidth - (buttonSize * 4)) / 5.0;
        CGFloat startY = 70.0;

        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        NSString *selectedPack = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: @"SolidGlass";
        NSString *basePath = jbroot([NSString stringWithFormat:@"/Library/Application Support/26Home/IconPacks/%@", selectedPack]);
        if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
            basePath = [NSString stringWithFormat:@"/Library/Application Support/26Home/IconPacks/%@", selectedPack];
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
            basePath = jbroot(@"/Library/Application Support/26Home/SolidGlass");
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
            basePath = @"/Library/Application Support/26Home/SolidGlass";
        }

        for (int i = 0; i < 4; i++) {
            CGFloat x = spacing + i * (buttonSize + spacing);
            UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(x, startY, buttonSize, buttonSize)];
            btn.layer.cornerRadius = 16;
            btn.layer.cornerCurve = kCACornerCurveContinuous;
            btn.clipsToBounds = YES;
            btn.tag = 100 + i;
            [btn addTarget:self action:@selector(selectStyle:) forControlEvents:UIControlEventTouchUpInside];

            UIImage *iconImg = nil;
            if (i == 0) {
                iconImg = [UIImage imageWithContentsOfFile:[basePath stringByAppendingPathComponent:@"Light/com.apple.weather-large.png"]];
            } else if (i == 1) {
                iconImg = [UIImage imageWithContentsOfFile:[basePath stringByAppendingPathComponent:@"Dark/com.apple.weather-large.png"]];
            } else if (i == 2) {
                iconImg = LGCreateAutomaticWeatherImage();
            } else if (i == 3) {
                iconImg = [UIImage imageWithContentsOfFile:[basePath stringByAppendingPathComponent:@"Dark/com.apple.weather-large.png"]];
            }

            UIImageView *iv = [[UIImageView alloc] initWithImage:iconImg];
            iv.frame = btn.bounds;
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.userInteractionEnabled = NO;
            [btn addSubview:iv];

            if (i == 3) {
                self.tintWeatherOverlay = [[UIView alloc] initWithFrame:btn.bounds];
                self.tintWeatherOverlay.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.45];
                self.tintWeatherOverlay.userInteractionEnabled = NO;
                [btn addSubview:self.tintWeatherOverlay];
            }

            [self.menuView addSubview:btn];
            [self.styleButtons addObject:btn];

            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x - 10, startY + buttonSize + 6, buttonSize + 20, 20)];
            lbl.text = styleTitles[i];
            lbl.textColor = [UIColor whiteColor];
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            [self.menuView addSubview:lbl];
            [self.styleLabels addObject:lbl];
        }

        self.slidersContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 168, menuWidth, 105)];
        self.slidersContainer.alpha = 0.0;
        self.slidersContainer.userInteractionEnabled = NO;
        [self.menuView addSubview:self.slidersContainer];

        [self setupSliders];

        [self addSubview:self.menuView];

        [self updateStyleSelection:NO];
    }
    return self;
}

- (void)setupSliders {
    CGFloat pad = 24.0;
    CGFloat sliderW = self.slidersContainer.frame.size.width - (pad * 2);
    CGFloat sliderH = 32.0;
    CGFloat thumbSize = 36.0;

    self.hueSlider = [[UIView alloc] initWithFrame:CGRectMake(pad, 8, sliderW, sliderH)];
    self.hueSlider.clipsToBounds = NO;
    [self.slidersContainer addSubview:self.hueSlider];

    UIView *hueTrack = [[UIView alloc] initWithFrame:self.hueSlider.bounds];
    hueTrack.layer.cornerRadius = sliderH / 2.0;
    hueTrack.clipsToBounds = YES;
    hueTrack.userInteractionEnabled = NO;
    [self.hueSlider addSubview:hueTrack];

    self.hueGradient = [CAGradientLayer layer];
    self.hueGradient.frame = hueTrack.bounds;
    self.hueGradient.startPoint = CGPointMake(0, 0.5);
    self.hueGradient.endPoint = CGPointMake(1, 0.5);

    NSMutableArray *hueColors = [NSMutableArray array];
    for (int i = 0; i <= 360; i += 30) {
        UIColor *c = [UIColor colorWithHue:i/360.0 saturation:1.0 brightness:1.0 alpha:1.0];
        [hueColors addObject:(id)c.CGColor];
    }
    self.hueGradient.colors = hueColors;
    [hueTrack.layer addSublayer:self.hueGradient];

    self.hueThumb = [[UIView alloc] initWithFrame:CGRectMake(0, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize)];
    self.hueThumb.layer.cornerRadius = thumbSize / 2.0;
    self.hueThumb.layer.borderColor = [UIColor whiteColor].CGColor;
    self.hueThumb.layer.borderWidth = 3.5;
    self.hueThumb.layer.shadowColor = [UIColor blackColor].CGColor;
    self.hueThumb.layer.shadowOpacity = 0.35;
    self.hueThumb.layer.shadowRadius = 4;
    self.hueThumb.layer.shadowOffset = CGSizeMake(0, 2);
    self.hueThumb.userInteractionEnabled = NO;
    [self.hueSlider addSubview:self.hueThumb];

    UIPanGestureRecognizer *huePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
    [self.hueSlider addGestureRecognizer:huePan];
    UITapGestureRecognizer *hueTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
    [self.hueSlider addGestureRecognizer:hueTap];

    self.brightnessSlider = [[UIView alloc] initWithFrame:CGRectMake(pad, 52, sliderW, sliderH)];
    self.brightnessSlider.clipsToBounds = NO;
    [self.slidersContainer addSubview:self.brightnessSlider];

    UIView *brightnessTrack = [[UIView alloc] initWithFrame:self.brightnessSlider.bounds];
    brightnessTrack.layer.cornerRadius = sliderH / 2.0;
    brightnessTrack.clipsToBounds = YES;
    brightnessTrack.userInteractionEnabled = NO;
    [self.brightnessSlider addSubview:brightnessTrack];

    self.brightnessGradient = [CAGradientLayer layer];
    self.brightnessGradient.frame = brightnessTrack.bounds;
    self.brightnessGradient.startPoint = CGPointMake(0, 0.5);
    self.brightnessGradient.endPoint = CGPointMake(1, 0.5);
    [brightnessTrack.layer addSublayer:self.brightnessGradient];

    self.brightnessThumb = [[UIView alloc] initWithFrame:CGRectMake(0, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize)];
    self.brightnessThumb.layer.cornerRadius = thumbSize / 2.0;
    self.brightnessThumb.layer.borderColor = [UIColor whiteColor].CGColor;
    self.brightnessThumb.layer.borderWidth = 3.5;
    self.brightnessThumb.layer.shadowColor = [UIColor blackColor].CGColor;
    self.brightnessThumb.layer.shadowOpacity = 0.35;
    self.brightnessThumb.layer.shadowRadius = 4;
    self.brightnessThumb.layer.shadowOffset = CGSizeMake(0, 2);
    self.brightnessThumb.userInteractionEnabled = NO;
    [self.brightnessSlider addSubview:self.brightnessThumb];

    UIPanGestureRecognizer *brPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBrightnessPan:)];
    [self.brightnessSlider addGestureRecognizer:brPan];
    UITapGestureRecognizer *brTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBrightnessPan:)];
    [self.brightnessSlider addGestureRecognizer:brTap];

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    self.currentHue = [defaults floatForKey:@"ngkhoi.26home.tintHue"];
    if (self.currentHue == 0 && ![defaults objectForKey:@"ngkhoi.26home.tintHue"]) {
        self.currentHue = 0.55;
        self.currentBrightness = 0.8;
    } else {
        self.currentBrightness = [defaults floatForKey:@"ngkhoi.26home.tintBrightness"];
    }

    [self _updateThumbPositions];
    [self _updateBrightnessGradient];
}

- (void)_updateThumbPositions {
    CGFloat thumbSize = 36.0;
    CGFloat sliderH = self.hueSlider.frame.size.height;
    CGFloat maxTravel = self.hueSlider.frame.size.width - thumbSize;

    CGFloat hX = self.currentHue * maxTravel;
    self.hueThumb.frame = CGRectMake(hX, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize);
    self.hueThumb.backgroundColor = [UIColor colorWithHue:self.currentHue saturation:1.0 brightness:1.0 alpha:1.0];

    CGFloat bX = self.currentBrightness * maxTravel;
    self.brightnessThumb.frame = CGRectMake(bX, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize);

    CGFloat sat = 1.0 - self.currentBrightness;
    UIColor *currentColor = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];
    self.brightnessThumb.backgroundColor = currentColor;

    if (self.tintWeatherOverlay) {
        self.tintWeatherOverlay.backgroundColor = [currentColor colorWithAlphaComponent:0.45];
    }
}

- (void)_updateBrightnessGradient {
    UIColor *c1 = [UIColor colorWithHue:self.currentHue saturation:1.0 brightness:1.0 alpha:1.0];
    UIColor *c2 = [UIColor colorWithHue:self.currentHue saturation:0.0 brightness:1.0 alpha:1.0];
    self.brightnessGradient.colors = @[(id)c1.CGColor, (id)c2.CGColor];
}

- (void)updateStyleSelection:(BOOL)animated {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSString *style = [defaults stringForKey:@"ngkhoi.26home.iconStyle"] ?: @"Default";
    NSString *darkIconMode = [defaults stringForKey:@"ngkhoi.26home.darkIconMode"] ?: @"Always";

    NSUInteger activeIndex = 0;
    if ([style isEqualToString:@"Tinted"]) {
        activeIndex = 3;
    } else if ([style isEqualToString:@"Dark"]) {
        if ([darkIconMode isEqualToString:@"Auto"]) {
            activeIndex = 2;
        } else {
            activeIndex = 1;
        }
    } else {
        activeIndex = 0;
    }

    BOOL isTinted = (activeIndex == 3);
    CGFloat targetHeight = isTinted ? 285.0 : 175.0;

    void (^updateBlock)(void) = ^{

        for (int i = 0; i < self.styleButtons.count; i++) {
            UIButton *btn = self.styleButtons[i];
            UILabel *lbl = self.styleLabels[i];
            if (i == activeIndex) {
                btn.layer.borderWidth = 2.5;
                btn.layer.borderColor = [UIColor whiteColor].CGColor;
                lbl.textColor = [UIColor whiteColor];
                lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
            } else {
                btn.layer.borderWidth = 0.0;
                lbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.60];
                lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            }
        }

        self.eyedropperBtn.alpha = isTinted ? 1.0 : 0.0;
        self.eyedropperBtn.userInteractionEnabled = isTinted;

        self.slidersContainer.alpha = isTinted ? 1.0 : 0.0;
        self.slidersContainer.userInteractionEnabled = isTinted;

        CGRect menuFrame = self.menuView.frame;
        menuFrame.size.height = targetHeight;
        menuFrame.origin.y = [self _restingYForMenuHeight:targetHeight];
        self.menuView.frame = menuFrame;
    };

    if (animated) {
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:updateBlock completion:nil];
    } else {
        updateBlock();
    }
}

- (void)selectStyle:(UIButton *)sender {
    NSUInteger index = sender.tag - 100;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    Home26Log(@"[User Action] iOS 18 Menu - Selected style index: %lu", (unsigned long)index);

    if (index == 0) {
        [defaults setObject:@"Default" forKey:@"ngkhoi.26home.iconStyle"];
        [defaults setObject:@"Light" forKey:@"ngkhoi.26home.themeMode"];
    } else if (index == 1) {
        [defaults setObject:@"Dark" forKey:@"ngkhoi.26home.iconStyle"];
        [defaults setObject:@"Always" forKey:@"ngkhoi.26home.darkIconMode"];
    } else if (index == 2) {
        [defaults setObject:@"Dark" forKey:@"ngkhoi.26home.iconStyle"];
        [defaults setObject:@"Auto" forKey:@"ngkhoi.26home.darkIconMode"];
    } else if (index == 3) {
        [defaults setObject:@"Tinted" forKey:@"ngkhoi.26home.iconStyle"];
    }
    [defaults synchronize];

    [self updateStyleSelection:YES];

    BOOL hasSnowBoard = NO;
    if (([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/SnowBoard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/Snowboard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/AAASnowBoardStub.dylib"]) ||
        ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/SnowBoard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Snowboard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/AAASnowBoardStub.dylib"])) {
        hasSnowBoard = YES;
    }

    if (hasSnowBoard) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ SnowBoard Detected"
                                                                       message:@"Using SnowBoard (even with themes disabled) can harm performance, drain battery, and cause unexpected visual bugs with 26Home.\n\nFor the absolute best, lag-free experience, it is highly recommended to completely UNINSTALL SnowBoard."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"I Understand" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [defaults setBool:YES forKey:@"HasWarnedAboutSnowBoard"];
            [defaults synchronize];
        }]];

        UIViewController *topVC = nil;
        for (UIWindow *w in [[UIApplication sharedApplication] valueForKey:@"windows"]) {
            if (w.isKeyWindow) {
                topVC = w.rootViewController;
                break;
            }
        }
        if (!topVC && [[[UIApplication sharedApplication] valueForKey:@"windows"] count] > 0) {
            topVC = ((UIWindow *)[[[UIApplication sharedApplication] valueForKey:@"windows"] firstObject]).rootViewController;
        }
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        if (topVC) {
            [topVC presentViewController:alert animated:YES completion:nil];
        }

    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        Home26PostStyleUpdate18();
    });
}

- (void)selectScaleSmall:(UIButton *)sender {
    Home26Log(@"[User Action] iOS 18 Menu - Selected scale: Small");
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [defaults setBool:NO forKey:@"ngkhoi.26home.largeIcons"];
    [defaults synchronize];

    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGRect f = self.scalePill.frame;
        f.origin.x = 0;
        self.scalePill.frame = f;

        [self.smallBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        self.smallBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [self.largeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.largeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    } completion:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateLargeIcons" object:nil];
}

- (void)selectScaleLarge:(UIButton *)sender {
    Home26Log(@"[User Action] iOS 18 Menu - Selected scale: Large");
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [defaults setBool:YES forKey:@"ngkhoi.26home.largeIcons"];
    [defaults synchronize];

    CGFloat itemWidth = self.scaleSegment.frame.size.width / 2.0;
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        CGRect f = self.scalePill.frame;
        f.origin.x = itemWidth;
        self.scalePill.frame = f;

        [self.smallBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.smallBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [self.largeBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        self.largeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    } completion:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateLargeIcons" object:nil];
}

- (void)toggleWallpaperDimming:(UIButton *)sender {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    BOOL current = [defaults boolForKey:@"ngkhoi.26home.dimWallpaper"];
    BOOL next = !current;
    Home26Log(@"[User Action] iOS 18 Menu - Toggled wallpaper dimming to: %d", next);
    [defaults setBool:next forKey:@"ngkhoi.26home.dimWallpaper"];
    [defaults synchronize];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIFontWeightMedium];
    UIImage *newImage = (next ? LGImageNamed(@"sun.lefthalf.filled") : [UIImage systemImageNamed:@"sun.max" withConfiguration:config]);

    [UIView transitionWithView:sender duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [sender setImage:newImage forState:UIControlStateNormal];
        sender.tintColor = next ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.55];
    } completion:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateWallpaperDimming" object:nil userInfo:@{@"dimmed": @(next)}];
}

- (void)_saveTintColor {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [defaults setFloat:self.currentHue forKey:@"ngkhoi.26home.tintHue"];
    [defaults setFloat:self.currentBrightness forKey:@"ngkhoi.26home.tintBrightness"];

    CGFloat sat = 1.0 - self.currentBrightness;
    UIColor *color = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *hex = [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
    Home26Log(@"[User Action] iOS 18 Menu - Updated tint color to: %@", hex);
    [defaults setObject:hex forKey:@"ngkhoi.26home.tintColor"];
    [defaults synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        Home26PostStyleUpdate18();
    });
}

- (void)_saveLiveTintColor {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [defaults setFloat:self.currentHue forKey:@"ngkhoi.26home.tintHue"];
    [defaults setFloat:self.currentBrightness forKey:@"ngkhoi.26home.tintBrightness"];

    CGFloat sat = 1.0 - self.currentBrightness;
    UIColor *color = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *hex = [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
    [defaults setObject:hex forKey:@"ngkhoi.26home.tintColor"];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateLiveTintColor" object:nil];
}

- (void)handleHuePan:(UIGestureRecognizer *)gesture {
    CGFloat thumbSize = 36.0;
    CGPoint loc = [gesture locationInView:self.hueSlider];
    CGFloat pct = (loc.x - (thumbSize / 2.0)) / (self.hueSlider.frame.size.width - thumbSize);
    pct = MAX(0.0, MIN(1.0, pct));
    self.currentHue = pct;

    [self _updateThumbPositions];
    [self _updateBrightnessGradient];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self _saveTintColor];
    } else {
        [self _saveLiveTintColor];
    }
}

- (void)handleBrightnessPan:(UIGestureRecognizer *)gesture {
    CGFloat thumbSize = 36.0;
    CGPoint loc = [gesture locationInView:self.brightnessSlider];
    CGFloat pct = (loc.x - (thumbSize / 2.0)) / (self.brightnessSlider.frame.size.width - thumbSize);
    pct = MAX(0.0, MIN(1.0, pct));
    self.currentBrightness = pct;

    [self _updateThumbPositions];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self _saveTintColor];
    } else {
        [self _saveLiveTintColor];
    }
}

- (void)eyedropperTapped {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.0;
    }];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.EyedropperStart" object:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIWindow *keyWindow = self.window ?: [[UIApplication sharedApplication] keyWindow];

        UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, 0.0);
        for (UIWindow *w in [[UIApplication sharedApplication] valueForKey:@"windows"]) {
#pragma clang diagnostic pop
            if (w.hidden || w.alpha < 0.01) continue;
            [w drawViewHierarchyInRect:w.bounds afterScreenUpdates:YES];
        }
        UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        LGEyedropperOverlayView *overlay = [[LGEyedropperOverlayView alloc] initWithFrame:keyWindow.bounds wallpaper:snapshot];
        overlay.onColorSelected = ^(UIColor *color) {
            CGFloat h, s, b, a;
            if ([color getHue:&h saturation:&s brightness:&b alpha:&a]) {
                CGFloat boostedSat = 0.0;
                if (s < 0.08) {
                    boostedSat = 0.0;
                } else {
                    boostedSat = MIN(1.0, s * 1.8);
                }
                self.currentHue = h;
                self.currentBrightness = 1.0 - boostedSat;
                [self _updateThumbPositions];
                [self _updateBrightnessGradient];
                [self _saveTintColor];
            }

            [UIView animateWithDuration:0.3 animations:^{
                self.alpha = 1.0;
            }];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.EyedropperEnd" object:nil];
        };
        [keyWindow addSubview:overlay];
    });
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint loc = [touch locationInView:self.slidersContainer];
    if (self.slidersContainer.alpha > 0.5 && CGRectContainsPoint(self.slidersContainer.bounds, loc)) {
        CGPoint hueLoc = [touch locationInView:self.hueSlider];
        CGPoint brLoc = [touch locationInView:self.brightnessSlider];
        if (CGRectContainsPoint(self.hueSlider.bounds, hueLoc) || CGRectContainsPoint(self.brightnessSlider.bounds, brLoc)) {
            return NO;
        }
    }
    return YES;
}

- (void)handleMenuPull:(UIPanGestureRecognizer *)gesture {
    CGFloat restingY = [self _restingYForMenuHeight:self.menuView.frame.size.height];
    CGPoint translation = [gesture translationInView:self];

    if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat dy = translation.y;
        if (dy < 0) {
            CGFloat pulledUp = -dy;
            CGFloat resistedOffset = (250.0 * pulledUp) / (250.0 + pulledUp) * 0.75;
            CGRect f = self.menuView.frame;
            f.origin.y = restingY - resistedOffset;
            self.menuView.frame = f;
        } else {
            CGFloat resistedOffset = (180.0 * dy) / (180.0 + dy) * 0.65;
            CGRect f = self.menuView.frame;
            f.origin.y = restingY + resistedOffset;
            self.menuView.frame = f;
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGPoint velocity = [gesture velocityInView:self];
        CGFloat dy = translation.y;

        if (dy > 90 || velocity.y > 600) {
            [self dismiss];
        } else {
            CGFloat initialVel = -velocity.y / 250.0;
            [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.68 initialSpringVelocity:initialVel options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
                CGRect f = self.menuView.frame;
                f.origin.y = restingY;
                self.menuView.frame = f;
            } completion:nil];
        }
    }
}

- (void)presentInView:(UIView *)view {
    self.frame = view.bounds;
    self.backgroundColor = [UIColor clearColor];

    CGRect frame = self.menuView.frame;
    frame.origin.y = self.bounds.size.height;
    self.menuView.frame = frame;
    self.menuView.alpha = 0.0;

    [view addSubview:self];

    [UIView animateWithDuration:0.7 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        CGRect newFrame = self.menuView.frame;
        newFrame.origin.y = [self _restingYForMenuHeight:newFrame.size.height];
        self.menuView.frame = newFrame;
        self.menuView.alpha = 1.0;
    } completion:nil];
}

- (void)dismiss {
    [UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionAllowUserInteraction animations:^{
        CGRect frame = self.menuView.frame;
        frame.origin.y = self.bounds.size.height;
        self.menuView.frame = frame;
        self.menuView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
