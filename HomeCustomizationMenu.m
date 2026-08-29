#import "Headers.h"
#import <notify.h>

static inline void Home26PostStyleUpdate(void) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
        notify_post("ngkhoi.26home.UpdateIconStyle");
    });
}

static void save26Pref(NSString *key, id value) {
    if (!key) return;
    Home26Log(@"[User Action] Preference '%@' updated to: %@", key, value);
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    if (value) {
        [defaults setObject:value forKey:key];
        CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, CFSTR("com.ngkhoi.26home"));
    } else {
        [defaults removeObjectForKey:key];
        CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, CFSTR("com.ngkhoi.26home"));
    }
    [defaults synchronize];
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));
}

@interface LGSpecularHighlightView : UIView
@property (nonatomic, strong) CAGradientLayer *specularRim;
@property (nonatomic, strong) CAShapeLayer *rimMask;
@end

@implementation LGSpecularHighlightView
- (CGFloat)_bottomOffset {
    CGFloat floatDockHeight = 0.0;
    
    // find floating dock
    NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.bounds.size.height > 0) {
            NSMutableArray *queue = [NSMutableArray arrayWithObject:window];
            UIView *foundFloatingDock = nil;
            
            while (queue.count > 0) {
                UIView *v = [queue firstObject];
                [queue removeObjectAtIndex:0];
                
                NSString *className = NSStringFromClass([v class]);
                // check for floating dock view
                if ([className containsString:@"FloatingDockView"]) {
                    // must be visible
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
                CGRect frameInScreen = [foundFloatingDock convertRect:foundFloatingDock.bounds toView:nil];
                if (frameInScreen.size.height > 0 && frameInScreen.origin.y > 0) {
                    floatDockHeight = [UIScreen mainScreen].bounds.size.height - frameInScreen.origin.y;
                    break;
                }
            }
        }
    }
    
    if (floatDockHeight > 0.0) {
        return floatDockHeight + 14.0;
    }
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return 96.0 + 14.0; // ipad fallback
    }
    
    return 8.0;
}

- (CGFloat)_restingYForMenuHeight:(CGFloat)menuHeight {
    return self.bounds.size.height - menuHeight - [self _bottomOffset];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.specularRim = [CAGradientLayer layer];
        self.specularRim.colors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.65].CGColor,
                                    (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                    (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                    (id)[UIColor colorWithWhite:1.0 alpha:0.35].CGColor];
        self.specularRim.locations = @[@0.0, @0.35, @0.65, @1.0];
        self.specularRim.startPoint = CGPointMake(0, 0);
        self.specularRim.endPoint = CGPointMake(1, 1);
        
        self.rimMask = [CAShapeLayer layer];
        self.rimMask.fillColor = [UIColor clearColor].CGColor;
        self.rimMask.strokeColor = [UIColor whiteColor].CGColor;
        self.rimMask.lineWidth = 1.5;
        self.specularRim.mask = self.rimMask;
        
        [self.layer addSublayer:self.specularRim];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.specularRim.frame = self.bounds;
    self.rimMask.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:40].CGPath;
}
@end

static inline __attribute__((unused)) UIImage *LGCreateScaleButtonImage(BOOL isLarge) {
    UIImageSymbolConfiguration *configSmall = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIFontWeightRegular];
    UIImageSymbolConfiguration *configLarge = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIFontWeightMedium];
    
    UIImage *smallImg = [UIImage systemImageNamed:(isLarge ? @"app" : @"app.fill") withConfiguration:configSmall];
    UIImage *largeImg = [UIImage systemImageNamed:(isLarge ? @"app.fill" : @"app") withConfiguration:configLarge];
    
    CGSize smallSize = smallImg.size;
    CGSize largeSize = largeImg.size;
    
    CGFloat spacing = 0.5;
    CGSize totalSize = CGSizeMake(smallSize.width + spacing + largeSize.width, MAX(smallSize.height, largeSize.height));
    
    UIGraphicsBeginImageContextWithOptions(totalSize, NO, 0.0);
    [[UIColor blackColor] setFill];
    
    // bottom alignment
    CGFloat bottomY = totalSize.height;
    CGFloat smallY = bottomY - smallSize.height;
    CGFloat largeY = bottomY - largeSize.height;
    
    [smallImg drawAtPoint:CGPointMake(0, smallY)];
    [largeImg drawAtPoint:CGPointMake(smallSize.width + spacing, largeY)];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return [result imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface LGGridOverlayView : UIView
@property (nonatomic, assign) CGFloat gridCellSize;
@end

@interface LGScaleAnimatedButton : UIButton
@property (nonatomic, assign) BOOL isLarge;
@property (nonatomic, strong) UIView *smallOutline;
@property (nonatomic, strong) UIView *largeOutline;
@property (nonatomic, strong) UIView *fillView;
- (instancetype)initWithFrame:(CGRect)frame isLarge:(BOOL)isLarge;
- (void)setIsLarge:(BOOL)isLarge animated:(BOOL)animated;
@end

@implementation LGScaleAnimatedButton

- (CGRect)smallRect {
    CGFloat smallSize = 14.0;
    CGFloat largeSize = 22.0;
    CGFloat spacing = 4.0;
    CGFloat totalW = smallSize + spacing + largeSize;
    CGFloat startX = (self.bounds.size.width - totalW) / 2.0;
    CGFloat bottomY = (self.bounds.size.height + largeSize) / 2.0;
    return CGRectMake(round(startX), round(bottomY - smallSize), smallSize, smallSize);
}

- (CGRect)largeRect {
    CGFloat smallSize = 14.0;
    CGFloat largeSize = 22.0;
    CGFloat spacing = 4.0;
    CGFloat totalW = smallSize + spacing + largeSize;
    CGFloat startX = (self.bounds.size.width - totalW) / 2.0;
    CGFloat bottomY = (self.bounds.size.height + largeSize) / 2.0;
    return CGRectMake(round(startX + smallSize + spacing), round(bottomY - largeSize), largeSize, largeSize);
}

- (instancetype)initWithFrame:(CGRect)frame isLarge:(BOOL)isLarge {
    self = [super initWithFrame:frame];
    if (self) {
        _isLarge = isLarge;
        
        self.smallOutline = [[UIView alloc] initWithFrame:[self smallRect]];
        self.smallOutline.backgroundColor = [UIColor clearColor];
        self.smallOutline.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.40].CGColor;
        self.smallOutline.layer.borderWidth = 1.5;
        self.smallOutline.layer.cornerCurve = kCACornerCurveContinuous;
        self.smallOutline.layer.cornerRadius = 3.2;
        self.smallOutline.userInteractionEnabled = NO;
        [self addSubview:self.smallOutline];
        
        self.largeOutline = [[UIView alloc] initWithFrame:[self largeRect]];
        self.largeOutline.backgroundColor = [UIColor clearColor];
        self.largeOutline.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.40].CGColor;
        self.largeOutline.layer.borderWidth = 1.5;
        self.largeOutline.layer.cornerCurve = kCACornerCurveContinuous;
        self.largeOutline.layer.cornerRadius = 5.0;
        self.largeOutline.userInteractionEnabled = NO;
        [self addSubview:self.largeOutline];
        
        CGRect initialFrame = isLarge ? [self largeRect] : [self smallRect];
        CGFloat initialRadius = isLarge ? 5.0 : 3.2;
        
        self.fillView = [[UIView alloc] initWithFrame:initialFrame];
        self.fillView.backgroundColor = [UIColor whiteColor];
        self.fillView.layer.cornerCurve = kCACornerCurveContinuous;
        self.fillView.layer.cornerRadius = initialRadius;
        self.fillView.userInteractionEnabled = NO;
        [self addSubview:self.fillView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.smallOutline.frame = [self smallRect];
    self.largeOutline.frame = [self largeRect];
    if (!self.fillView.layer.animationKeys.count) {
        self.fillView.frame = self.isLarge ? [self largeRect] : [self smallRect];
        self.fillView.layer.cornerRadius = self.isLarge ? 5.0 : 3.2;
    }
}

- (void)setIsLarge:(BOOL)isLarge animated:(BOOL)animated {
    _isLarge = isLarge;
    
    CGRect targetFrame = isLarge ? [self largeRect] : [self smallRect];
    CGFloat targetRadius = isLarge ? 5.0 : 3.2;
    
    void (^updateBlock)(void) = ^{
        self.fillView.frame = targetFrame;
        self.fillView.layer.cornerRadius = targetRadius;
    };
    
    if (animated) {
        // match sb icon scale duration (0.25s)
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:updateBlock completion:nil];
    } else {
        updateBlock();
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.alpha = highlighted ? 0.6 : 1.0;
    } completion:nil];
}

@end

@implementation LGGridOverlayView
- (instancetype)initWithFrame:(CGRect)frame gridCellSize:(CGFloat)cellSize {
    self = [super initWithFrame:frame];
    if (self) {
        self.gridCellSize = cellSize;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.35].CGColor);
    CGContextSetLineWidth(ctx, 0.5);
    
    CGFloat cx = rect.size.width / 2.0;
    CGFloat cy = rect.size.height / 2.0;
    
    CGFloat startX = cx - self.gridCellSize / 2.0;
    for (CGFloat x = startX; x < rect.size.width; x += self.gridCellSize) {
        CGContextMoveToPoint(ctx, x, 0); CGContextAddLineToPoint(ctx, x, rect.size.height);
    }
    for (CGFloat x = startX; x >= 0; x -= self.gridCellSize) {
        CGContextMoveToPoint(ctx, x, 0); CGContextAddLineToPoint(ctx, x, rect.size.height);
    }
    
    CGFloat startY = cy - self.gridCellSize / 2.0;
    for (CGFloat y = startY; y < rect.size.height; y += self.gridCellSize) {
        CGContextMoveToPoint(ctx, 0, y); CGContextAddLineToPoint(ctx, rect.size.width, y);
    }
    for (CGFloat y = startY; y >= 0; y -= self.gridCellSize) {
        CGContextMoveToPoint(ctx, 0, y); CGContextAddLineToPoint(ctx, rect.size.width, y);
    }
    CGContextStrokePath(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGRect centerRect = CGRectMake(startX, startY, self.gridCellSize, self.gridCellSize);
    CGContextStrokeRect(ctx, centerRect);
}
@end

@interface LGEyedropperOverlayView ()
@property (nonatomic, strong) UIView *loupeContainer;
@property (nonatomic, strong) UIView *loupeColorRing;
@property (nonatomic, strong) UIImageView *magnifiedImageView;
@property (nonatomic, strong) LGGridOverlayView *gridOverlay;
@property (nonatomic, assign) CGFloat gridCellSize;
@property (nonatomic, assign) CGFloat zoomFactor;
@property (nonatomic, assign) CGFloat loupeOuterSize;
@property (nonatomic, strong) UIColor *currentSampledColor;
@end

@implementation LGEyedropperOverlayView
- (instancetype)initWithFrame:(CGRect)frame wallpaper:(UIImage *)wallpaper {
    self = [super initWithFrame:frame];
    if (self) {
        self.wallpaperSnapshot = wallpaper;
        self.backgroundColor = [UIColor clearColor];
        
        self.gridCellSize = 10.0;
        self.zoomFactor = self.gridCellSize * (self.wallpaperSnapshot.scale > 0 ? self.wallpaperSnapshot.scale : [UIScreen mainScreen].scale);
        self.loupeOuterSize = 130.0;
        
        self.loupeContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.loupeOuterSize, self.loupeOuterSize)];
        self.loupeContainer.layer.shadowColor = [UIColor blackColor].CGColor;
        self.loupeContainer.layer.shadowOpacity = 0.5;
        self.loupeContainer.layer.shadowRadius = 15;
        self.loupeContainer.layer.shadowOffset = CGSizeMake(0, 8);
        self.loupeContainer.hidden = YES;
        [self addSubview:self.loupeContainer];
        
        UIView *outerGrayRing = [[UIView alloc] initWithFrame:self.loupeContainer.bounds];
        outerGrayRing.layer.cornerRadius = self.loupeOuterSize / 2.0;
        outerGrayRing.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.8];
        [self.loupeContainer addSubview:outerGrayRing];
        
        CGFloat colorRingPadding = 6.0;
        CGFloat colorRingSize = self.loupeOuterSize - colorRingPadding * 2;
        self.loupeColorRing = [[UIView alloc] initWithFrame:CGRectMake(colorRingPadding, colorRingPadding, colorRingSize, colorRingSize)];
        self.loupeColorRing.layer.cornerRadius = colorRingSize / 2.0;
        self.loupeColorRing.clipsToBounds = YES;
        self.loupeColorRing.backgroundColor = [UIColor clearColor];
        [self.loupeContainer addSubview:self.loupeColorRing];
        
        CGFloat magPadding = 12.0;
        CGFloat magSize = colorRingSize - magPadding * 2;
        UIView *innerCircle = [[UIView alloc] initWithFrame:CGRectMake(magPadding, magPadding, magSize, magSize)];
        innerCircle.layer.cornerRadius = magSize / 2.0;
        innerCircle.layer.borderColor = [UIColor whiteColor].CGColor;
        innerCircle.layer.borderWidth = 2.5;
        innerCircle.clipsToBounds = YES;
        innerCircle.backgroundColor = [UIColor blackColor];
        [self.loupeColorRing addSubview:innerCircle];
        
        self.magnifiedImageView = [[UIImageView alloc] initWithImage:self.wallpaperSnapshot];
        self.magnifiedImageView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        self.magnifiedImageView.layer.anchorPoint = CGPointMake(0, 0);
        self.magnifiedImageView.layer.position = CGPointMake(0, 0);
        self.magnifiedImageView.layer.magnificationFilter = kCAFilterNearest;
        self.magnifiedImageView.transform = CGAffineTransformMakeScale(self.zoomFactor, self.zoomFactor);
        [innerCircle addSubview:self.magnifiedImageView];
        
        self.gridOverlay = [[LGGridOverlayView alloc] initWithFrame:innerCircle.bounds gridCellSize:self.gridCellSize];
        [innerCircle addSubview:self.gridOverlay];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (UIColor *)colorAtPoint:(CGPoint)point {
    unsigned char pixel[4] = {0};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    if (context) {
        UIGraphicsPushContext(context);
        [self.wallpaperSnapshot drawAtPoint:CGPointMake(-point.x, -point.y)];
        UIGraphicsPopContext();
        
        CGContextRelease(context);
    }
    CGColorSpaceRelease(colorSpace);
    
    return [UIColor colorWithRed:pixel[0]/255.0 green:pixel[1]/255.0 blue:pixel[2]/255.0 alpha:pixel[3]/255.0];
}

- (void)updateLoupeAtLocation:(CGPoint)loc {
    CGFloat scale = self.wallpaperSnapshot.scale > 0 ? self.wallpaperSnapshot.scale : [UIScreen mainScreen].scale;
    CGFloat snapX = round(loc.x * scale) / scale;
    CGFloat snapY = round(loc.y * scale) / scale;
    
    UIColor *sampledColor = [self colorAtPoint:CGPointMake(snapX, snapY)];
    self.currentSampledColor = sampledColor;
    self.loupeColorRing.backgroundColor = sampledColor;
    
    CGFloat loupeY = (loc.y < 120.0) ? (loc.y + 75.0) : (loc.y - 75.0);
    self.loupeContainer.center = CGPointMake(loc.x, loupeY);
    
    CGFloat cx = self.gridOverlay.bounds.size.width / 2.0;
    CGFloat cy = self.gridOverlay.bounds.size.height / 2.0;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.magnifiedImageView.layer.position = CGPointMake(cx - snapX * self.zoomFactor, cy - snapY * self.zoomFactor);
    [CATransaction commit];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.loupeContainer.hidden = NO;
        self.loupeContainer.transform = CGAffineTransformMakeScale(0.1, 0.1);
        [UIView animateWithDuration:0.18 animations:^{
            self.loupeContainer.transform = CGAffineTransformIdentity;
        }];
    }
    
    [self updateLoupeAtLocation:loc];
    
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.2 animations:^{
            self.loupeContainer.transform = CGAffineTransformMakeScale(0.1, 0.1);
            self.loupeContainer.alpha = 0.0;
        } completion:^(BOOL finished) {
            if (self.onColorSelected && self.currentSampledColor) {
                self.onColorSelected(self.currentSampledColor);
            }
            [self removeFromSuperview];
        }];
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self];
    self.loupeContainer.hidden = NO;
    [self updateLoupeAtLocation:loc];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.onColorSelected && self.currentSampledColor) {
            self.onColorSelected(self.currentSampledColor);
        }
        [self removeFromSuperview];
    });
}
@end

@interface LGAdvancedColorModalView : UIView
@property (nonatomic, copy) void (^onColorChanged)(NSString *hex, CGFloat hue, CGFloat brightness);
@property (nonatomic, copy) void (^onDismiss)(void);
@property (nonatomic, assign) CGFloat currentHue;
@property (nonatomic, assign) CGFloat currentSaturation;
@property (nonatomic, assign) CGFloat currentBrightness;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *previewBox;
@property (nonatomic, strong) UILabel *hexLabel;
@property (nonatomic, strong) UIView *hueSlider;
@property (nonatomic, strong) UIView *satSlider;
@property (nonatomic, strong) UIView *briSlider;
@property (nonatomic, strong) UIView *hueThumb;
@property (nonatomic, strong) UIView *satThumb;
@property (nonatomic, strong) UIView *briThumb;
@property (nonatomic, strong) CAGradientLayer *satGradient;
@property (nonatomic, strong) CAGradientLayer *briGradient;
- (instancetype)initWithFrame:(CGRect)frame initialHex:(NSString *)initialHex;
- (void)presentInView:(UIView *)parent;
- (void)dismissModal;
@end

@implementation LGAdvancedColorModalView

- (instancetype)initWithFrame:(CGRect)frame initialHex:(NSString *)initialHex {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.40];
        self.alpha = 0.0;
        
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:initialHex ?: @"#00FFFF"];
        if ([initialHex hasPrefix:@"#"]) [scanner setScanLocation:1];
        [scanner scanHexInt:&rgbValue];
        UIColor *initColor = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
        CGFloat h, s, b, a;
        if ([initColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            self.currentHue = h;
            self.currentSaturation = s;
            self.currentBrightness = b;
        } else {
            self.currentHue = 0.55;
            self.currentSaturation = 1.0;
            self.currentBrightness = 1.0;
        }
        
        UIButton *bgDismiss = [UIButton buttonWithType:UIButtonTypeCustom];
        bgDismiss.frame = self.bounds;
        [bgDismiss addTarget:self action:@selector(dismissModal) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:bgDismiss];
        
        CGFloat cardW = frame.size.width - 32;
        CGFloat cardH = 490;
        self.cardView = [[UIView alloc] initWithFrame:CGRectMake(16, (frame.size.height - cardH) / 2.0 - 20, cardW, cardH)];
        self.cardView.layer.cornerRadius = 28;
        self.cardView.layer.masksToBounds = YES;
        self.cardView.layer.borderWidth = 0.5;
        self.cardView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
        [self addSubview:self.cardView];
        
        LGAdjustableBlurView *blur = [[LGAdjustableBlurView alloc] initWithFrame:self.cardView.bounds blurRadius:16.0];
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blur.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
        [self.cardView addSubview:blur];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 18, cardW - 70, 24)];
        titleLabel.text = @"Secret Color Palette";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
        [self.cardView addSubview:titleLabel];
        
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        closeBtn.frame = CGRectMake(cardW - 44, 15, 30, 30);
        closeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        closeBtn.layer.cornerRadius = 15;
        UIImage *closeIcon = [UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIFontWeightBold]];
        [closeBtn setImage:closeIcon forState:UIControlStateNormal];
        closeBtn.tintColor = [UIColor whiteColor];
        [closeBtn addTarget:self action:@selector(dismissModal) forControlEvents:UIControlEventTouchUpInside];
        [self.cardView addSubview:closeBtn];
        
        UIView *previewRow = [[UIView alloc] initWithFrame:CGRectMake(20, 52, cardW - 40, 48)];
        previewRow.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        previewRow.layer.cornerRadius = 14;
        [self.cardView addSubview:previewRow];
        
        self.previewBox = [[UIView alloc] initWithFrame:CGRectMake(8, 8, 32, 32)];
        self.previewBox.layer.cornerRadius = 8;
        self.previewBox.layer.borderWidth = 1.0;
        self.previewBox.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
        [previewRow addSubview:self.previewBox];
        
        self.hexLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, previewRow.frame.size.width - 60, 48)];
        self.hexLabel.textColor = [UIColor whiteColor];
        self.hexLabel.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightBold];
        [previewRow addSubview:self.hexLabel];
        
        CGFloat sliderH = 30.0;
        CGFloat sliderW = cardW - 40;
        CGFloat thumbSize = 34.0;
        
        UILabel *hueLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, sliderW, 16)];
        hueLbl.text = @"Hue (Color)";
        hueLbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        hueLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        [self.cardView addSubview:hueLbl];
        
        self.hueSlider = [[UIView alloc] initWithFrame:CGRectMake(20, 130, sliderW, sliderH)];
        [self.cardView addSubview:self.hueSlider];
        
        UIView *hueTrack = [[UIView alloc] initWithFrame:self.hueSlider.bounds];
        hueTrack.layer.cornerRadius = sliderH / 2.0;
        hueTrack.clipsToBounds = YES;
        hueTrack.userInteractionEnabled = NO;
        [self.hueSlider addSubview:hueTrack];
        
        CAGradientLayer *hueGrad = [CAGradientLayer layer];
        hueGrad.frame = hueTrack.bounds;
        hueGrad.startPoint = CGPointMake(0, 0.5);
        hueGrad.endPoint = CGPointMake(1, 0.5);
        NSMutableArray *hColors = [NSMutableArray array];
        for (int i=0; i<=6; i++) {
            [hColors addObject:(id)[UIColor colorWithHue:i/6.0 saturation:1.0 brightness:1.0 alpha:1.0].CGColor];
        }
        hueGrad.colors = hColors;
        [hueTrack.layer addSublayer:hueGrad];
        
        self.hueThumb = [self createThumbWithSize:thumbSize sliderH:sliderH];
        [self.hueSlider addSubview:self.hueThumb];
        
        UIPanGestureRecognizer *hPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
        [self.hueSlider addGestureRecognizer:hPan];
        UITapGestureRecognizer *hTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
        [self.hueSlider addGestureRecognizer:hTap];
        
        UILabel *satLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 172, sliderW, 16)];
        satLbl.text = @"Saturation (Vividness / Grayscale)";
        satLbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        satLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        [self.cardView addSubview:satLbl];
        
        self.satSlider = [[UIView alloc] initWithFrame:CGRectMake(20, 192, sliderW, sliderH)];
        [self.cardView addSubview:self.satSlider];
        
        UIView *satTrack = [[UIView alloc] initWithFrame:self.satSlider.bounds];
        satTrack.layer.cornerRadius = sliderH / 2.0;
        satTrack.clipsToBounds = YES;
        satTrack.userInteractionEnabled = NO;
        [self.satSlider addSubview:satTrack];
        
        self.satGradient = [CAGradientLayer layer];
        self.satGradient.frame = satTrack.bounds;
        self.satGradient.startPoint = CGPointMake(0, 0.5);
        self.satGradient.endPoint = CGPointMake(1, 0.5);
        [satTrack.layer addSublayer:self.satGradient];
        
        self.satThumb = [self createThumbWithSize:thumbSize sliderH:sliderH];
        [self.satSlider addSubview:self.satThumb];
        
        UIPanGestureRecognizer *sPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSatPan:)];
        [self.satSlider addGestureRecognizer:sPan];
        UITapGestureRecognizer *sTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSatPan:)];
        [self.satSlider addGestureRecognizer:sTap];
        
        UILabel *briLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 234, sliderW, 16)];
        briLbl.text = @"Brightness (Slide left for Pure Black #000000)";
        briLbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        briLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        [self.cardView addSubview:briLbl];
        
        self.briSlider = [[UIView alloc] initWithFrame:CGRectMake(20, 254, sliderW, sliderH)];
        [self.cardView addSubview:self.briSlider];
        
        UIView *briTrack = [[UIView alloc] initWithFrame:self.briSlider.bounds];
        briTrack.layer.cornerRadius = sliderH / 2.0;
        briTrack.clipsToBounds = YES;
        briTrack.userInteractionEnabled = NO;
        [self.briSlider addSubview:briTrack];
        
        self.briGradient = [CAGradientLayer layer];
        self.briGradient.frame = briTrack.bounds;
        self.briGradient.startPoint = CGPointMake(0, 0.5);
        self.briGradient.endPoint = CGPointMake(1, 0.5);
        [satTrack.layer addSublayer:self.briGradient];
        
        self.briThumb = [self createThumbWithSize:thumbSize sliderH:sliderH];
        [self.briSlider addSubview:self.briThumb];
        
        UIPanGestureRecognizer *bPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBriPan:)];
        [self.briSlider addGestureRecognizer:bPan];
        UITapGestureRecognizer *bTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBriPan:)];
        [self.briSlider addGestureRecognizer:bTap];
        
        UILabel *swatchLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 298, sliderW, 16)];
        swatchLbl.text = @"Quick Presets";
        swatchLbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        swatchLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        [self.cardView addSubview:swatchLbl];
        
        NSArray *hexPresets = @[@"#000000", @"#FFFFFF", @"#1C1C1E", @"#FF3B30", @"#FF9500", @"#FFCC00", @"#34C759", @"#00C7BE", @"#007AFF", @"#AF52DE"];
        CGFloat swatchSize = (sliderW - (hexPresets.count - 1) * 6) / hexPresets.count;
        for (int i=0; i<hexPresets.count; i++) {
            UIButton *swBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            swBtn.frame = CGRectMake(20 + i * (swatchSize + 6), 320, swatchSize, swatchSize);
            swBtn.layer.cornerRadius = swatchSize / 2.0;
            
            unsigned sRGB = 0;
            NSScanner *sScan = [NSScanner scannerWithString:hexPresets[i]];
            if ([hexPresets[i] hasPrefix:@"#"]) [sScan setScanLocation:1];
            [sScan scanHexInt:&sRGB];
            UIColor *swColor = [UIColor colorWithRed:((sRGB & 0xFF0000) >> 16)/255.0 green:((sRGB & 0xFF00) >> 8)/255.0 blue:(sRGB & 0xFF)/255.0 alpha:1.0];
            
            swBtn.backgroundColor = swColor;
            swBtn.layer.borderWidth = 1.0;
            swBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
            swBtn.tag = 300 + i;
            [swBtn addTarget:self action:@selector(swatchTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self.cardView addSubview:swBtn];
        }
        
        UIView *toggleContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 362, sliderW, 44)];
        toggleContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        toggleContainer.layer.cornerRadius = 14;
        [self.cardView addSubview:toggleContainer];
        
        UILabel *toggleLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 12, sliderW - 75, 20)];
        toggleLbl.text = @"Disable background gradient";
        toggleLbl.textColor = [UIColor whiteColor];
        toggleLbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        [toggleContainer addSubview:toggleLbl];
        
        UISwitch *gradSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(sliderW - 65, 6.5, 51, 31)];
        NSUserDefaults *def = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        gradSwitch.on = [def boolForKey:@"ngkhoi.26home.disableDarkTintGradient"];
        [gradSwitch addTarget:self action:@selector(toggleGradientSwitched:) forControlEvents:UIControlEventValueChanged];
        [toggleContainer addSubview:gradSwitch];
        
        UIButton *doneBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        doneBtn.frame = CGRectMake(20, 418, sliderW, 44);
        doneBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
        doneBtn.layer.cornerRadius = 22;
        [doneBtn setTitle:@"Done" forState:UIControlStateNormal];
        [doneBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        doneBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [doneBtn addTarget:self action:@selector(dismissModal) forControlEvents:UIControlEventTouchUpInside];
        [self.cardView addSubview:doneBtn];
        
        [self updateAllUI];
    }
    return self;
}

- (UIView *)createThumbWithSize:(CGFloat)thumbSize sliderH:(CGFloat)sliderH {
    UIView *thumb = [[UIView alloc] initWithFrame:CGRectMake(0, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize)];
    thumb.backgroundColor = [UIColor whiteColor];
    thumb.layer.cornerRadius = thumbSize / 2.0;
    thumb.layer.borderWidth = 3.0;
    thumb.layer.borderColor = [UIColor whiteColor].CGColor;
    thumb.layer.shadowColor = [UIColor blackColor].CGColor;
    thumb.layer.shadowOpacity = 0.40;
    thumb.layer.shadowRadius = 4;
    thumb.layer.shadowOffset = CGSizeMake(0, 2);
    thumb.userInteractionEnabled = NO;
    return thumb;
}

- (void)updateAllUI {
    CGFloat thumbSize = 34.0;
    CGFloat sliderH = 30.0;
    CGFloat maxTravel = self.hueSlider.frame.size.width - thumbSize;
    
    self.hueThumb.frame = CGRectMake(self.currentHue * maxTravel, (sliderH - thumbSize)/2.0, thumbSize, thumbSize);
    self.hueThumb.backgroundColor = [UIColor colorWithHue:self.currentHue saturation:1.0 brightness:1.0 alpha:1.0];
    
    self.satThumb.frame = CGRectMake(self.currentSaturation * maxTravel, (sliderH - thumbSize)/2.0, thumbSize, thumbSize);
    self.satThumb.backgroundColor = [UIColor colorWithHue:self.currentHue saturation:self.currentSaturation brightness:1.0 alpha:1.0];
    
    self.briThumb.frame = CGRectMake(self.currentBrightness * maxTravel, (sliderH - thumbSize)/2.0, thumbSize, thumbSize);
    self.briThumb.backgroundColor = [UIColor colorWithHue:self.currentHue saturation:self.currentSaturation brightness:self.currentBrightness alpha:1.0];
    
    UIColor *sat0 = [UIColor colorWithHue:self.currentHue saturation:0.0 brightness:1.0 alpha:1.0];
    UIColor *sat1 = [UIColor colorWithHue:self.currentHue saturation:1.0 brightness:1.0 alpha:1.0];
    self.satGradient.colors = @[(id)sat0.CGColor, (id)sat1.CGColor];
    
    UIColor *bri0 = [UIColor blackColor];
    UIColor *bri1 = [UIColor colorWithHue:self.currentHue saturation:self.currentSaturation brightness:1.0 alpha:1.0];
    self.briGradient.colors = @[(id)bri0.CGColor, (id)bri1.CGColor];
    
    UIColor *curr = [UIColor colorWithHue:self.currentHue saturation:self.currentSaturation brightness:self.currentBrightness alpha:1.0];
    self.previewBox.backgroundColor = curr;
    
    CGFloat r, g, b, a;
    [curr getRed:&r green:&g blue:&b alpha:&a];
    NSString *hex = [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
    self.hexLabel.text = [NSString stringWithFormat:@"HEX: %@", hex];
    
    if (self.onColorChanged) {
        self.onColorChanged(hex, self.currentHue, self.currentBrightness);
    }
}

- (void)handleHuePan:(UIGestureRecognizer *)gesture {
    CGFloat thumbSize = 34.0;
    CGPoint loc = [gesture locationInView:self.hueSlider];
    CGFloat pct = (loc.x - (thumbSize / 2.0)) / (self.hueSlider.frame.size.width - thumbSize);
    self.currentHue = MAX(0.0, MIN(1.0, pct));
    [self updateAllUI];
}

- (void)handleSatPan:(UIGestureRecognizer *)gesture {
    CGFloat thumbSize = 34.0;
    CGPoint loc = [gesture locationInView:self.satSlider];
    CGFloat pct = (loc.x - (thumbSize / 2.0)) / (self.satSlider.frame.size.width - thumbSize);
    self.currentSaturation = MAX(0.0, MIN(1.0, pct));
    [self updateAllUI];
}

- (void)handleBriPan:(UIGestureRecognizer *)gesture {
    CGFloat thumbSize = 34.0;
    CGPoint loc = [gesture locationInView:self.briSlider];
    CGFloat pct = (loc.x - (thumbSize / 2.0)) / (self.briSlider.frame.size.width - thumbSize);
    self.currentBrightness = MAX(0.0, MIN(1.0, pct));
    [self updateAllUI];
}

- (void)swatchTapped:(UIButton *)sender {
    NSArray *hexPresets = @[@"#000000", @"#FFFFFF", @"#1C1C1E", @"#FF3B30", @"#FF9500", @"#FFCC00", @"#34C759", @"#00C7BE", @"#007AFF", @"#AF52DE"];
    int idx = (int)sender.tag - 300;
    if (idx >= 0 && idx < hexPresets.count) {
        NSString *hex = hexPresets[idx];
        unsigned sRGB = 0;
        NSScanner *sScan = [NSScanner scannerWithString:hex];
        if ([hex hasPrefix:@"#"]) [sScan setScanLocation:1];
        [sScan scanHexInt:&sRGB];
        UIColor *swColor = [UIColor colorWithRed:((sRGB & 0xFF0000) >> 16)/255.0 green:((sRGB & 0xFF00) >> 8)/255.0 blue:(sRGB & 0xFF)/255.0 alpha:1.0];
        CGFloat h, s, b, a;
        if ([swColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            self.currentHue = h;
            self.currentSaturation = s;
            self.currentBrightness = b;
        }
        [self updateAllUI];
    }
}

- (void)presentInView:(UIView *)parent {
    self.frame = parent.bounds;
    self.alpha = 0.0;
    self.cardView.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [parent addSubview:self];
    
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)toggleGradientSwitched:(UISwitch *)sw {
    save26Pref(@"ngkhoi.26home.disableDarkTintGradient", @(sw.isOn));
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
        notify_post("ngkhoi.26home.UpdateIconStyle");
    });
}

- (void)dismissModal {
    [UIView animateWithDuration:0.25 animations:^{
        self.alpha = 0.0;
        self.cardView.transform = CGAffineTransformMakeScale(0.85, 0.85);
    } completion:^(BOOL finished) {
        if (self.onDismiss) self.onDismiss();
        [self removeFromSuperview];
    }];
}

@end




@interface LGSegmentLensView : UIView
@property (nonatomic, strong) LGAdjustableBlurView *blurView;
@property (nonatomic, strong) LGLiveBackdropView *glassView;
@property (nonatomic, strong) UIView *highlightView;
- (instancetype)initWithFrame:(CGRect)frame;
@end

@implementation LGSegmentLensView

- (CGFloat)_bottomOffset {
    CGFloat floatDockHeight = 0.0;
    
    // find floating dock
    NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.bounds.size.height > 0) {
            NSMutableArray *queue = [NSMutableArray arrayWithObject:window];
            UIView *foundFloatingDock = nil;
            
            while (queue.count > 0) {
                UIView *v = [queue firstObject];
                [queue removeObjectAtIndex:0];
                
                NSString *className = NSStringFromClass([v class]);
                // check for floating dock view
                if ([className containsString:@"FloatingDockView"]) {
                    // must be visible
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
                CGRect frameInScreen = [foundFloatingDock convertRect:foundFloatingDock.bounds toView:nil];
                if (frameInScreen.size.height > 0 && frameInScreen.origin.y > 0) {
                    floatDockHeight = [UIScreen mainScreen].bounds.size.height - frameInScreen.origin.y;
                    break;
                }
            }
        }
    }
    
    if (floatDockHeight > 0.0) {
        return floatDockHeight + 14.0;
    }
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return 96.0 + 14.0; // ipad fallback
    }
    
    return 8.0;
}

- (CGFloat)_restingYForMenuHeight:(CGFloat)menuHeight {
    return self.bounds.size.height - menuHeight - [self _bottomOffset];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
        
        // backdrop blur
        _blurView = [[LGAdjustableBlurView alloc] initWithFrame:self.bounds blurRadius:3.0];
        _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _blurView.layer.masksToBounds = YES;
        [self addSubview:_blurView];
        
        // liquid glass refraction
        _glassView = [[LGLiveBackdropView alloc] initWithFrame:self.bounds];
        _glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _glassView.layer.masksToBounds = YES;
        [self addSubview:_glassView];
        
        // highlight fill
        _highlightView = [[UIView alloc] initWithFrame:self.bounds];
        _highlightView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _highlightView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];
        _highlightView.layer.masksToBounds = YES;
        [self addSubview:_highlightView];
        
        // specular rim
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
        
        if (@available(iOS 13.0, *)) {
            self.layer.cornerCurve = kCACornerCurveContinuous;
            _blurView.layer.cornerCurve = kCACornerCurveContinuous;
            _glassView.layer.cornerCurve = kCACornerCurveContinuous;
            _highlightView.layer.cornerCurve = kCACornerCurveContinuous;
        }
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat r = self.bounds.size.height / 2.0;
    self.layer.cornerRadius = r;
    _blurView.layer.cornerRadius = r;
    _glassView.layer.cornerRadius = r;
    _highlightView.layer.cornerRadius = r;
}

@end













@interface HomeCustomizationMenuContainer () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) NSInteger tintedTapCount;
@property (nonatomic, assign) NSTimeInterval lastTintedTapTime;
@property (nonatomic, strong) UIView *themeSegmentContainer;
@property (nonatomic, strong) LGSegmentLensView *themeLensPill;
@property (nonatomic, assign) BOOL isThemeDragging;
@property (nonatomic, assign) CGFloat themeDragStartX;
@property (nonatomic, assign) CGFloat themePillXAtDragStart;
@property (nonatomic, strong) UIImageView *tintedThemeIcon;
@property (nonatomic, strong) UIImageView *tintedThemeOverlayIcon;
@property (nonatomic, strong) NSMutableArray<UIButton *> *styleButtons;
- (void)showAdvancedColorModal;
@end

@implementation HomeCustomizationMenuContainer

- (void)toggleWallpaperDimming:(UIButton *)sender {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    BOOL current = [defaults boolForKey:@"ngkhoi.26home.dimWallpaper"];
    BOOL next = !current;
    save26Pref(@"ngkhoi.26home.dimWallpaper", @(next));
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIFontWeightMedium];
    if (@available(iOS 15.0, *)) {
        // sf symbols color config
        UIImageSymbolConfiguration *colorConfig = [UIImageSymbolConfiguration configurationWithHierarchicalColor:(next ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.5])];
        config = [config configurationByApplyingConfiguration:colorConfig];
    }
    
    UIImage *newImage = (next ? LGImageNamed(@"sun.lefthalf.filled") : [UIImage systemImageNamed:@"sun.max" withConfiguration:config]);
    
    [UIView transitionWithView:sender duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [sender setImage:newImage forState:UIControlStateNormal];
        sender.tintColor = next ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.5];
        // no rotation
    } completion:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateWallpaperDimming" object:nil userInfo:@{@"dimmed": @(next)}];
}

- (void)toggleLargeIcons:(UIButton *)sender {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    BOOL current = [defaults boolForKey:@"ngkhoi.26home.largeIcons"];
    BOOL next = !current;
    save26Pref(@"ngkhoi.26home.largeIcons", @(next));
    
    if ([sender isKindOfClass:[LGScaleAnimatedButton class]]) {
        [(LGScaleAnimatedButton *)sender setIsLarge:next animated:YES];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateLargeIcons" object:nil];
}

- (void)updateHighlightForStyle:(NSString *)style animated:(BOOL)animated {
    NSArray *styles = @[@"Default", @"Dark", @"Clear", @"Tinted"];
    NSUInteger index = [styles indexOfObject:style];
    if (index == NSNotFound) index = 0;
    
    if (index < self.styleLabels.count) {
        UILabel *selectedLabel = self.styleLabels[index];
        
        void (^updateBlock)(void) = ^{
            // update text colors
            for (int i = 0; i < self.styleLabels.count; i++) {
                UILabel *lbl = self.styleLabels[i];
                if (i == index) {
                    lbl.textColor = [UIColor whiteColor];
                    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
                } else {
                    lbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.60];
                    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
                }
            }
            
            // animate pill frame
            CGSize textSize = [selectedLabel.text sizeWithAttributes:@{NSFontAttributeName: selectedLabel.font}];
            CGRect pillFrame = selectedLabel.frame;
            CGFloat center = CGRectGetMidX(pillFrame);
            CGFloat newWidth = textSize.width + 18;
            pillFrame.size.width = newWidth;
            pillFrame.origin.x = center - newWidth / 2.0;
            pillFrame.origin.y -= 2;
            pillFrame.size.height += 4;
            self.highlightPill.frame = pillFrame;
        };
        
        if (animated) {
            [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:updateBlock completion:nil];
        } else {
            updateBlock();
        }
    }
}

- (CGRect)_themePillFrameForIndex:(NSInteger)idx {
    if (idx < 0 || idx >= self.themeLabels.count) return CGRectZero;
    UILabel *lbl = self.themeLabels[idx];
    if (lbl.hidden || !lbl.text.length) return CGRectZero;
    
    CGSize textSize = [lbl.text sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]}];
    CGFloat pillW = textSize.width + 18.0; // fit label width
    CGFloat pillH = 28.0;
    CGFloat centerX = lbl.center.x;
    CGFloat centerY = lbl.center.y;
    
    return CGRectMake(round(centerX - pillW / 2.0), round(centerY - pillH / 2.0), pillW, pillH);
}

- (void)updateThemeSegmentForStyle:(NSString *)style animated:(BOOL)animated {
    NSArray *themeTitles = @[];
    if ([style isEqualToString:@"Dark"]) {
        themeTitles = @[@"Always", @"Auto"];
    } else if (![style isEqualToString:@"Default"]) {
        themeTitles = @[@"Light", @"Dark", @"Auto"];
    }
    
    BOOL isTinted = [style isEqualToString:@"Tinted"];
    CGFloat menuHeight = isTinted ? 380 : (themeTitles.count > 0 ? 230 : 180);
    CGFloat segmentY = isTinted ? 328 : 178;
    CGFloat segmentH = 38.0;
    
    CGFloat totalWidth = (themeTitles.count == 2) ? 220.0 : (self.menuView.frame.size.width - 40.0);
    CGFloat startX = (self.menuView.frame.size.width - totalWidth) / 2.0;
    CGFloat itemW = themeTitles.count > 0 ? (totalWidth / themeTitles.count) : 0;
    
    void (^updateBlock)(void) = ^{
        CGRect menuFrame = self.menuView.frame;
        menuFrame.size.height = menuHeight;
        menuFrame.origin.y = [self _restingYForMenuHeight:menuHeight];
        self.menuView.frame = menuFrame;
        
        self.slidersContainer.alpha = isTinted ? 1.0 : 0.0;
        self.slidersContainer.userInteractionEnabled = isTinted;
        
        self.themeSegmentContainer.frame = CGRectMake(startX, segmentY, totalWidth, segmentH);
        self.themeSegmentContainer.alpha = (themeTitles.count > 0) ? 1.0 : 0.0;
        self.themeSegmentContainer.userInteractionEnabled = (themeTitles.count > 0);
        
        for (int i = 0; i < self.themeLabels.count; i++) {
            UILabel *lbl = self.themeLabels[i];
            UIButton *btn = self.themeButtons[i];
            
            if (i < themeTitles.count) {
                lbl.text = themeTitles[i];
                lbl.hidden = NO;
                btn.hidden = NO;
                CGRect newFrame = CGRectMake(i * itemW, 0, itemW, segmentH);
                lbl.frame = newFrame;
                btn.frame = newFrame;
            } else {
                lbl.hidden = YES;
                btn.hidden = YES;
            }
        }
        
        if (themeTitles.count == 0) {
            self.themeLensPill.alpha = 0.0;
        } else {
            self.themeLensPill.alpha = 1.0;
        }
    };
    
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:updateBlock completion:nil];
    } else {
        updateBlock();
    }
    
    NSString *currentTheme = nil;
    if ([style isEqualToString:@"Dark"]) {
        currentTheme = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] stringForKey:@"ngkhoi.26home.darkIconMode"] ?: @"Always";
    } else {
        currentTheme = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] stringForKey:@"ngkhoi.26home.themeMode"] ?: @"Auto";
    }
    [self updateThemeHighlightForMode:currentTheme animated:animated];
}

- (void)updateThemeHighlightForMode:(NSString *)mode animated:(BOOL)animated {
    if (self.isThemeDragging) return;
    
    NSString *currentStyle = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] stringForKey:@"ngkhoi.26home.iconStyle"] ?: @"Default";
    NSArray *modes = @[];
    if ([currentStyle isEqualToString:@"Dark"]) {
        modes = @[@"Always", @"Auto"];
    } else if (![currentStyle isEqualToString:@"Default"]) {
        modes = @[@"Light", @"Dark", @"Auto"];
    }
    
    if (modes.count == 0) {
        self.themeLensPill.alpha = 0.0;
        return;
    }
    
    NSUInteger index = [modes indexOfObject:mode];
    if (index == NSNotFound) index = modes.count - 1; // default to auto
    
    if (index < self.themeLabels.count) {
        CGRect targetPillFrame = [self _themePillFrameForIndex:(NSInteger)index];
        
        void (^updateBlock)(void) = ^{
            self.themeLensPill.alpha = 1.0;
            self.themeLensPill.frame = targetPillFrame;
            
            for (int i = 0; i < self.themeLabels.count; i++) {
                UILabel *lbl = self.themeLabels[i];
                if (!lbl.hidden) {
                    lbl.textColor = (i == index) ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.60];
                    lbl.font = (i == index) ? [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
                }
            }
        };
        
        if (animated) {
            [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.80 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:updateBlock completion:nil];
        } else {
            updateBlock();
        }
    }
}

- (void)selectTheme:(UIButton *)sender {
    NSString *currentStyle = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] stringForKey:@"ngkhoi.26home.iconStyle"] ?: @"Default";
    NSArray *modes = @[];
    if ([currentStyle isEqualToString:@"Dark"]) {
        modes = @[@"Always", @"Auto"];
    } else if (![currentStyle isEqualToString:@"Default"]) {
        modes = @[@"Light", @"Dark", @"Auto"];
    }
    
    if (modes.count == 0) return;
    
    int index = (int)sender.tag - 200;
    if (index >= 0 && index < modes.count) {
        NSString *mode = modes[index];
        Home26Log(@"[Menu] selectTheme tapped: mode=%@ (style=%@)", mode, currentStyle);
        if ([currentStyle isEqualToString:@"Dark"]) {
            save26Pref(@"ngkhoi.26home.darkIconMode", mode);
        } else {
            save26Pref(@"ngkhoi.26home.themeMode", mode);
        }
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];
        [feedback impactOccurred];
        
        [self updateThemeHighlightForMode:mode animated:YES];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
        });
    }
}

- (void)handleThemePan:(UIPanGestureRecognizer *)pan {
    NSString *currentStyle = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] stringForKey:@"ngkhoi.26home.iconStyle"] ?: @"Default";
    NSArray *modes = @[];
    if ([currentStyle isEqualToString:@"Dark"]) {
        modes = @[@"Always", @"Auto"];
    } else if (![currentStyle isEqualToString:@"Default"]) {
        modes = @[@"Light", @"Dark", @"Auto"];
    }
    NSUInteger count = modes.count;
    if (count == 0) return;
    
    CGFloat minCenterX = [self _themePillFrameForIndex:0].origin.x + [self _themePillFrameForIndex:0].size.width / 2.0;
    CGFloat maxCenterX = [self _themePillFrameForIndex:count - 1].origin.x + [self _themePillFrameForIndex:count - 1].size.width / 2.0;
    
    CGPoint loc = [pan locationInView:self.themeSegmentContainer];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.isThemeDragging = YES;
        self.themeDragStartX = loc.x;
        self.themePillXAtDragStart = self.themeLensPill.center.x;
        
        [UIView animateWithDuration:0.15 animations:^{
            self.themeLensPill.transform = CGAffineTransformMakeScale(1.05, 1.05);
        }];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = loc.x - self.themeDragStartX;
        CGFloat rawCenterX = self.themePillXAtDragStart + dx;
        
        // rubberband past edges
        CGFloat clampedCenterX = rawCenterX;
        if (rawCenterX < minCenterX) {
            clampedCenterX = minCenterX - sqrt(fmax(0.0, minCenterX - rawCenterX)) * 1.8;
        } else if (rawCenterX > maxCenterX) {
            clampedCenterX = maxCenterX + sqrt(fmax(0.0, rawCenterX - maxCenterX)) * 1.8;
        }
        
        // lerp pill width between segments
        CGFloat pct = (clampedCenterX - minCenterX) / MAX(maxCenterX - minCenterX, 1.0);
        pct = MAX(0.0, MIN((CGFloat)(count - 1), pct * (count - 1)));
        NSInteger lowerIdx = (NSInteger)floor(pct);
        NSInteger upperIdx = (NSInteger)ceil(pct);
        CGFloat fraction = pct - lowerIdx;
        
        CGRect fLow = [self _themePillFrameForIndex:lowerIdx];
        CGRect fHigh = [self _themePillFrameForIndex:upperIdx];
        
        // velocity stretch
        CGFloat velX = [pan velocityInView:self.themeSegmentContainer].x;
        CGFloat normalizedVel = fmin(fabs(velX) / 800.0, 1.0);
        CGFloat motionStretch = pow(normalizedVel, 0.7) * 8.0;
        
        CGFloat currentW = fLow.size.width + (fHigh.size.width - fLow.size.width) * fraction + motionStretch;
        CGFloat currentH = fLow.size.height > 0 ? fLow.size.height : 28.0;
        
        self.themeLensPill.bounds = CGRectMake(0, 0, currentW, currentH);
        self.themeLensPill.center = CGPointMake(clampedCenterX, self.themeSegmentContainer.bounds.size.height / 2.0);
        
        // snap to nearest segment
        NSInteger closestIdx = (NSInteger)round(pct);
        closestIdx = MAX(0, MIN((NSInteger)count - 1, closestIdx));
        
        for (NSUInteger i = 0; i < self.themeLabels.count; i++) {
            UILabel *lbl = self.themeLabels[i];
            if (!lbl.hidden) {
                lbl.textColor = (i == (NSUInteger)closestIdx) ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.60];
                lbl.font = (i == (NSUInteger)closestIdx) ? [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            }
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        self.isThemeDragging = NO;
        
        CGFloat velX = [pan velocityInView:self.themeSegmentContainer].x;
        CGFloat projectedX = self.themeLensPill.center.x + (velX * 0.12);
        
        NSInteger targetIdx = 0;
        CGFloat minDist = CGFLOAT_MAX;
        for (NSUInteger i = 0; i < count; i++) {
            CGFloat segCenterX = [self _themePillFrameForIndex:i].origin.x + [self _themePillFrameForIndex:i].size.width / 2.0;
            CGFloat d = fabs(projectedX - segCenterX);
            if (d < minDist) {
                minDist = d;
                targetIdx = (NSInteger)i;
            }
        }
        targetIdx = MAX(0, MIN((NSInteger)count - 1, targetIdx));
        
        NSString *newMode = modes[targetIdx];
        if ([currentStyle isEqualToString:@"Dark"]) {
            save26Pref(@"ngkhoi.26home.darkIconMode", newMode);
        } else {
            save26Pref(@"ngkhoi.26home.themeMode", newMode);
        }
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback prepare];
        [feedback impactOccurred];
        
        CGRect targetPillFrame = [self _themePillFrameForIndex:targetIdx];
        
        [UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:velX / 300.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.themeLensPill.transform = CGAffineTransformIdentity;
            self.themeLensPill.frame = targetPillFrame;
            
            for (NSUInteger i = 0; i < self.themeLabels.count; i++) {
                UILabel *lbl = self.themeLabels[i];
                if (!lbl.hidden) {
                    lbl.textColor = (i == (NSUInteger)targetIdx) ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.60];
                }
            }
        } completion:nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
        });
    }
}

- (void)selectStyle:(UIButton *)sender {
    NSArray *styles = @[@"Default", @"Dark", @"Clear", @"Tinted"];
    int index = (int)sender.tag - 100;
    if (index >= 0 && index < styles.count) {
        NSString *style = styles[index];
        Home26Log(@"[Menu] selectStyle tapped: style=%@", style);
        
        if (index == 3) { // tinted selected
            NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
            if (now - self.lastTintedTapTime < 1.8) {
                self.tintedTapCount++;
            } else {
                self.tintedTapCount = 1;
            }
            self.lastTintedTapTime = now;
            
            if (self.tintedTapCount >= 5) {
                self.tintedTapCount = 0;
                [self showAdvancedColorModal];
            }
        } else {
            self.tintedTapCount = 0;
        }
        
        save26Pref(@"ngkhoi.26home.iconStyle", style);
        
        [self updateHighlightForStyle:style animated:YES];
        [self updateThemeSegmentForStyle:style animated:YES];
        
        
    // SnowBoard warning alert
    BOOL hasSnowBoard = NO;
    if (([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/SnowBoard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/Snowboard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/AAASnowBoardStub.dylib"]) || 
        ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/SnowBoard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Snowboard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/AAASnowBoardStub.dylib"])) {
        hasSnowBoard = YES;
    }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    
    if (hasSnowBoard) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WAIT!!!"
                                                                       message:@"SNOWBOARD DETECTED \n\nUsing SnowBoard (even with themes disabled) can harm performance, drain battery, and cause unexpected visual bugs with 26Home.\n\nFor the absolute best, lag-free experience, it is highly recommended to completely UNINSTALL SnowBoard."
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
    
    Home26PostStyleUpdate();
    }
}

- (CGFloat)_bottomOffset {
    CGFloat floatDockHeight = 0.0;
    
    // find floating dock
    NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
    for (UIWindow *window in windows) {
        if (!window.hidden && window.alpha > 0.0 && window.bounds.size.height > 0) {
            NSMutableArray *queue = [NSMutableArray arrayWithObject:window];
            UIView *foundFloatingDock = nil;
            
            while (queue.count > 0) {
                UIView *v = [queue firstObject];
                [queue removeObjectAtIndex:0];
                
                NSString *className = NSStringFromClass([v class]);
                // check for floating dock view
                if ([className containsString:@"FloatingDockView"]) {
                    // must be visible
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
                CGRect frameInScreen = [foundFloatingDock convertRect:foundFloatingDock.bounds toView:nil];
                if (frameInScreen.size.height > 0 && frameInScreen.origin.y > 0) {
                    floatDockHeight = [UIScreen mainScreen].bounds.size.height - frameInScreen.origin.y;
                    break;
                }
            }
        }
    }
    
    if (floatDockHeight > 0.0) {
        return floatDockHeight + 14.0;
    }
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return 96.0 + 14.0; // ipad fallback
    }
    
    return 8.0;
}

- (CGFloat)_restingYForMenuHeight:(CGFloat)menuHeight {
    return self.bounds.size.height - menuHeight - [self _bottomOffset];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.styleLabels = [NSMutableArray array];
        self.themeLabels = [NSMutableArray array];
        self.themeButtons = [NSMutableArray array];
        self.styleButtons = [NSMutableArray array];
        self.styleButtons = [NSMutableArray array];
        self.styleButtons = [NSMutableArray array];
        
        // dim bg
        UIButton *bgButton = [UIButton buttonWithType:UIButtonTypeCustom];
        bgButton.frame = self.bounds;
        [bgButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:bgButton];
        
        // main menu container
        CGFloat height = 230;
        CGFloat menuWidth = frame.size.width - 20;
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            menuWidth = MIN(frame.size.width - 40.0, 480.0);
        }
        CGFloat menuX = (frame.size.width - menuWidth) / 2.0;
        self.menuView = [[UIView alloc] initWithFrame:CGRectMake(menuX, frame.size.height, menuWidth, height)];
        self.menuView.layer.cornerRadius = 40;
        self.menuView.layer.masksToBounds = YES;
        
        // specular rim
        self.menuView.layer.borderWidth = 0.0;
        LGSpecularHighlightView *specularView = [[LGSpecularHighlightView alloc] initWithFrame:self.menuView.bounds];
        specularView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        // glass & blur backdrop
        LGAdjustableBlurView *blurView = [[LGAdjustableBlurView alloc] initWithFrame:self.menuView.bounds blurRadius:4.0];
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.layer.cornerRadius = 40;
        blurView.clipsToBounds = YES;
        [self.menuView addSubview:blurView];
        
        LGLiveBackdropView *glassView = [[LGLiveBackdropView alloc] initWithFrame:self.menuView.bounds];
        glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        glassView.layer.cornerRadius = 40;
        glassView.clipsToBounds = YES;
        [self.menuView addSubview:glassView];
        
        // dark tint overlay
        UIView *darkTintLayer = [[UIView alloc] initWithFrame:self.menuView.bounds];
        darkTintLayer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        darkTintLayer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
        darkTintLayer.layer.cornerRadius = 40;
        darkTintLayer.clipsToBounds = YES;
        darkTintLayer.userInteractionEnabled = NO;
        [self.menuView addSubview:darkTintLayer];
        
        [self.menuView addSubview:specularView];
        
        // reapply filters if race on show
        __weak LGLiveBackdropView *weakBackdrop = glassView;
        __weak LGLiveBackdropView *weakThemeLens = (LGLiveBackdropView *)self.themePill;
        for (NSNumber *delay in @[@0.5, @1.5, @3.0, @5.0, @8.0]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakBackdrop forceReapplyForRegistrationRace];
                [weakThemeLens forceReapplyForRegistrationRace];
            });
        }
        
        // pull-up gesture
        UIPanGestureRecognizer *menuPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPull:)];
        menuPan.delegate = self;
        [self.menuView addGestureRecognizer:menuPan];
        
        // title
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 18, self.menuView.frame.size.width, 30)];
        titleLabel.text = @"Customize";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        [self.menuView addSubview:titleLabel];
        
        // controls
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        BOOL isDimmed = [defaults boolForKey:@"ngkhoi.26home.dimWallpaper"];
        BOOL isLarge = [defaults boolForKey:@"ngkhoi.26home.largeIcons"];
        
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIFontWeightMedium];
        if (@available(iOS 15.0, *)) {
            UIImageSymbolConfiguration *colorConfig = [UIImageSymbolConfiguration configurationWithHierarchicalColor:(isDimmed ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.5])];
            config = [config configurationByApplyingConfiguration:colorConfig];
        }
        
        UIButton *sunBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        sunBtn.frame = CGRectMake(20, 20, 40, 40);
        sunBtn.center = CGPointMake(45, 18 + 15);
        [sunBtn setImage:(isDimmed ? LGImageNamed(@"sun.lefthalf.filled") : [UIImage systemImageNamed:@"sun.max" withConfiguration:config]) forState:UIControlStateNormal];
        sunBtn.tintColor = isDimmed ? [UIColor whiteColor] : [UIColor colorWithWhite:1.0 alpha:0.5];
        [sunBtn addTarget:self action:@selector(toggleWallpaperDimming:) forControlEvents:UIControlEventTouchUpInside];
        [self.menuView addSubview:sunBtn];
        
        LGScaleAnimatedButton *largeBtn = [[LGScaleAnimatedButton alloc] initWithFrame:CGRectMake(self.menuView.frame.size.width - 70, 22, 50, 24) isLarge:isLarge];
        largeBtn.center = CGPointMake(self.menuView.frame.size.width - 45, 18 + 15);
        [largeBtn addTarget:self action:@selector(toggleLargeIcons:) forControlEvents:UIControlEventTouchUpInside];
        [self.menuView addSubview:largeBtn];
        
        NSArray *labels = @[@"Default", @"Dark", @"Clear", @"Tinted"];
        CGFloat spacing = (self.menuView.frame.size.width - (60 * 4)) / 5;
        for (int i=0; i<4; i++) {
            UIButton *iconView = [[UIButton alloc] initWithFrame:CGRectMake(spacing + i*(60+spacing), 75, 60, 60)];
            iconView.layer.cornerRadius = 16;
            iconView.clipsToBounds = YES;
            
            NSString *basePath = jbroot(@"/Library/Application Support/26Home/SolidGlass");
            if (![[NSFileManager defaultManager] fileExistsAtPath:basePath]) {
                basePath = @"/Library/Application Support/26Home/SolidGlass";
            }
            
            NSString *imgPath = nil;
            if (i == 0) imgPath = [basePath stringByAppendingPathComponent:@"Light/com.apple.weather-large.png"];
            else if (i == 1) imgPath = [basePath stringByAppendingPathComponent:@"Dark/com.apple.weather-large.png"];
            else if (i == 2) imgPath = [basePath stringByAppendingPathComponent:@"ClearLight/com.apple.weather-large.png"];
            else if (i == 3) imgPath = [basePath stringByAppendingPathComponent:@"Dark/com.apple.weather-large.png"];
            
            UIImage *weatherImg = [UIImage imageWithContentsOfFile:imgPath];
            UIImageView *weatherIconView = [[UIImageView alloc] initWithImage:weatherImg];
            weatherIconView.frame = iconView.bounds;
            weatherIconView.contentMode = UIViewContentModeScaleAspectFill;
            weatherIconView.userInteractionEnabled = NO;
            [iconView addSubview:weatherIconView];
            
            if (i == 3) {
                UIView *tintOverlay = [[UIView alloc] initWithFrame:iconView.bounds];
                tintOverlay.backgroundColor = [UIColor colorWithRed:0.4 green:0.2 blue:1.0 alpha:0.45];
                tintOverlay.userInteractionEnabled = NO;
                tintOverlay.tag = 999;
                [iconView addSubview:tintOverlay];
            }
            
            iconView.tag = 100 + i;
            [iconView addTarget:self action:@selector(selectStyle:) forControlEvents:UIControlEventTouchUpInside];
            
            if (i == 3) {
                UILongPressGestureRecognizer *secretLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleSecretColorLongPress:)];
                secretLongPress.minimumPressDuration = 3.0;
                secretLongPress.cancelsTouchesInView = YES;
                secretLongPress.delaysTouchesBegan = YES;
                [iconView addGestureRecognizer:secretLongPress];
            }
            
            [self.menuView addSubview:iconView];
            
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(iconView.frame.origin.x - 10, 142, 80, 20)];
            lbl.text = labels[i];
            lbl.textColor = [UIColor whiteColor];
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            
            if (i == 3) {
                lbl.userInteractionEnabled = YES;
                UILongPressGestureRecognizer *secretLongPressLbl = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleSecretColorLongPress:)];
                secretLongPressLbl.minimumPressDuration = 3.0;
                secretLongPressLbl.cancelsTouchesInView = YES;
                secretLongPressLbl.delaysTouchesBegan = YES;
                [lbl addGestureRecognizer:secretLongPressLbl];
            }
            
            [self.menuView addSubview:lbl];
            [self.styleLabels addObject:lbl];
        }
        
        // highlight pill
        self.highlightPill = [[UIView alloc] initWithFrame:CGRectZero];
        self.highlightPill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
        self.highlightPill.layer.cornerRadius = 12.0;
        [self.menuView addSubview:self.highlightPill];
        
        self.themeSegmentContainer = [[UIView alloc] initWithFrame:CGRectZero];
        self.themeSegmentContainer.backgroundColor = [UIColor clearColor];
        self.themeSegmentContainer.userInteractionEnabled = YES;
        [self.menuView addSubview:self.themeSegmentContainer];
        
        // segment lens pill
        self.themeLensPill = [[LGSegmentLensView alloc] initWithFrame:CGRectZero];
        [self.themeSegmentContainer addSubview:self.themeLensPill];
        
        // light / dark / auto segment
        for (int i=0; i<3; i++) {
            UIButton *btn = [[UIButton alloc] initWithFrame:CGRectZero];
            btn.tag = 200 + i;
            [btn addTarget:self action:@selector(selectTheme:) forControlEvents:UIControlEventTouchUpInside];
            [self.themeSegmentContainer addSubview:btn];
            
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectZero];
            lbl.textColor = [UIColor whiteColor];
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            lbl.userInteractionEnabled = NO;
            [self.themeSegmentContainer addSubview:lbl];
            
            [self.themeLabels addObject:lbl];
            [self.themeButtons addObject:btn];
        }
        
        UIPanGestureRecognizer *themePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleThemePan:)];
        themePan.delegate = self;
        [self.themeSegmentContainer addGestureRecognizer:themePan];
        
        [self _setupTintedUI];
        
        NSString *currentStyle = [[[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"] stringForKey:@"ngkhoi.26home.iconStyle"] ?: @"Default";
        [self updateHighlightForStyle:currentStyle animated:NO];
        [self updateThemeSegmentForStyle:currentStyle animated:NO];
        
        [self addSubview:self.menuView];
    }
    return self;
}

- (void)_setupTintedUI {
    self.slidersContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 170, self.menuView.frame.size.width - 40, 150)];
    self.slidersContainer.alpha = 0.0; // hidden by default
    self.slidersContainer.userInteractionEnabled = NO;
    [self.menuView addSubview:self.slidersContainer];
    
    // hue slider
    CGFloat sliderH = 32.0;
    CGFloat thumbSize = 36.0;
    self.hueSlider = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.slidersContainer.frame.size.width, sliderH)];
    self.hueSlider.clipsToBounds = NO;
    [self.slidersContainer addSubview:self.hueSlider];
    
    UIView *hueTrack = [[UIView alloc] initWithFrame:self.hueSlider.bounds];
    hueTrack.layer.cornerRadius = sliderH / 2.0;
    hueTrack.clipsToBounds = YES;
    hueTrack.userInteractionEnabled = NO;
    hueTrack.layer.borderWidth = 1.0;
    hueTrack.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    [self.hueSlider addSubview:hueTrack];
    
    self.hueGradient = [CAGradientLayer layer];
    self.hueGradient.frame = hueTrack.bounds;
    self.hueGradient.startPoint = CGPointMake(0, 0.5);
    self.hueGradient.endPoint = CGPointMake(1, 0.5);
    NSMutableArray *hueColors = [NSMutableArray array];
    for (int i=0; i<=360; i+=10) {
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
    self.hueThumb.layer.shadowRadius = 4;
    self.hueThumb.layer.shadowOffset = CGSizeMake(0, 2);
    self.hueThumb.userInteractionEnabled = NO;
    [self.hueSlider addSubview:self.hueThumb];
    
    UIPanGestureRecognizer *huePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
    [self.hueSlider addGestureRecognizer:huePan];
    UITapGestureRecognizer *hueTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleHuePan:)];
    [self.hueSlider addGestureRecognizer:hueTap];
    
    // brightness slider
    self.brightnessSlider = [[UIView alloc] initWithFrame:CGRectMake(0, 48, self.slidersContainer.frame.size.width, sliderH)];
    self.brightnessSlider.clipsToBounds = NO;
    [self.slidersContainer addSubview:self.brightnessSlider];
    
    UIView *brightnessTrack = [[UIView alloc] initWithFrame:self.brightnessSlider.bounds];
    brightnessTrack.layer.cornerRadius = sliderH / 2.0;
    brightnessTrack.clipsToBounds = YES;
    brightnessTrack.userInteractionEnabled = NO;
    brightnessTrack.layer.borderWidth = 1.0;
    brightnessTrack.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    [self.brightnessSlider addSubview:brightnessTrack];
    
    self.brightnessGradient = [CAGradientLayer layer];
    self.brightnessGradient.frame = brightnessTrack.bounds;
    self.brightnessGradient.startPoint = CGPointMake(0, 0.5);
    self.brightnessGradient.endPoint = CGPointMake(1, 0.5);
    [brightnessTrack.layer addSublayer:self.brightnessGradient];
    
    self.brightnessThumb = [[UIView alloc] initWithFrame:CGRectMake(0, (sliderH - thumbSize) / 2.0, thumbSize, thumbSize)];
    self.brightnessThumb.backgroundColor = [UIColor whiteColor];
    self.brightnessThumb.layer.cornerRadius = thumbSize / 2.0;
    self.brightnessThumb.layer.borderWidth = 3.5;
    self.brightnessThumb.layer.borderColor = [UIColor whiteColor].CGColor;
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
    
    // buttons row
    CGFloat btnY = 96;
    CGFloat btnSize = 50;
    CGFloat containerW = self.slidersContainer.frame.size.width;
    CGFloat spacing = (containerW - (btnSize * 4)) / 5.0;
    
    UIColor *bodyColor = [[self _getDeviceEnclosureColor] colorWithAlphaComponent:0.70];
    UIColor *screenColor = [[self _getDeviceFrontColor] colorWithAlphaComponent:0.70];
    UIColor *wallColor = [self _getWallpaperAverageColor] ?: [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1.0];
    UIColor *eyeColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    
    NSArray *buttonConfigs = @[
        @{@"tag": @1101, @"action": @"deviceBodyColorTapped", @"symbol": @"iphone", @"color": bodyColor},
        @{@"tag": @1102, @"action": @"deviceScreenColorTapped", @"symbol": @"iphone.rear.camera", @"color": screenColor},
        @{@"tag": @1103, @"action": @"autoColorTapped", @"customImg": @"edit.wallpaper", @"color": wallColor},
        @{@"tag": @1104, @"action": @"eyedropperTapped", @"symbol": @"eyedropper", @"color": eyeColor}
    ];
    
    for (int i = 0; i < buttonConfigs.count; i++) {
        NSDictionary *cfg = buttonConfigs[i];
        CGFloat x = spacing + i * (btnSize + spacing);
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, btnY, btnSize, btnSize);
        btn.tag = [cfg[@"tag"] integerValue];
        
        // outer ring
        UIView *ring = [[UIView alloc] initWithFrame:btn.bounds];
        ring.layer.cornerRadius = btnSize / 2.0;
        ring.layer.borderWidth = 1.0;
        ring.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
        ring.backgroundColor = [UIColor clearColor];
        ring.userInteractionEnabled = NO;
        ring.tag = 10;
        ring.alpha = 1.0;
        [btn addSubview:ring];
        
        // inner circle fill
        CGFloat fillSize = 42.0;
        CGFloat fillOffset = (btnSize - fillSize) / 2.0;
        UIView *circle = [[UIView alloc] initWithFrame:CGRectMake(fillOffset, fillOffset, fillSize, fillSize)];
        circle.layer.cornerRadius = fillSize / 2.0;
        circle.clipsToBounds = YES;
        circle.backgroundColor = cfg[@"color"];
        circle.userInteractionEnabled = NO;
        circle.tag = 20;
        [btn addSubview:circle];
        
        // center glyph
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake((fillSize - 22) / 2.0, (fillSize - 22) / 2.0, 22, 22)];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.tintColor = [UIColor whiteColor];
        iconView.userInteractionEnabled = NO;
        iconView.tag = 30;
        
        if (cfg[@"customImg"]) {
            UIImage *img = [LGImageNamed(cfg[@"customImg"]) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            iconView.image = img;
        } else {
            UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIFontWeightMedium];
            UIImage *symImg = [UIImage systemImageNamed:cfg[@"symbol"] withConfiguration:symConfig];
            if (!symImg && [cfg[@"symbol"] isEqualToString:@"iphone.rear.camera"]) {
                symImg = [UIImage systemImageNamed:@"iphone.case" withConfiguration:symConfig] ?: [UIImage systemImageNamed:@"iphone" withConfiguration:symConfig];
            }
            iconView.image = symImg;
        }
        [circle addSubview:iconView];
        
        SEL actionSel = NSSelectorFromString(cfg[@"action"]);
        [btn addTarget:self action:actionSel forControlEvents:UIControlEventTouchUpInside];
        [self.slidersContainer addSubview:btn];
    }
    // load values
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    self.currentHue = [defaults floatForKey:@"ngkhoi.26home.tintHue"];
    if (self.currentHue == 0 && ![defaults objectForKey:@"ngkhoi.26home.tintHue"]) {
        self.currentHue = 0.55; // default blue
        self.currentBrightness = 0.8;
    } else {
        self.currentBrightness = [defaults floatForKey:@"ngkhoi.26home.tintBrightness"];
    }
    
    [self _updateThumbPositions];
    [self _updateBrightnessGradient];
    [self _updateTintUIExtras];
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
    self.brightnessThumb.backgroundColor = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];
}

- (void)_updateBrightnessGradient {
    UIColor *c1 = [UIColor colorWithHue:self.currentHue saturation:1.0 brightness:1.0 alpha:1.0];
    UIColor *c2 = [UIColor colorWithHue:self.currentHue saturation:0.0 brightness:1.0 alpha:1.0];
    self.brightnessGradient.colors = @[(id)c1.CGColor, (id)c2.CGColor];
}

- (void)_setActivePresetButton:(NSInteger)activeTag animated:(BOOL)animated {
    for (NSInteger t = 1101; t <= 1104; t++) {
        UIButton *btn = [self.slidersContainer viewWithTag:t];
        UIView *ring = [btn viewWithTag:10];
        if (ring) {
            BOOL isActive = (t == activeTag);
            if (animated) {
                [UIView animateWithDuration:0.2 animations:^{
                    ring.layer.borderColor = isActive ? [UIColor whiteColor].CGColor : [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
                    ring.layer.borderWidth = isActive ? 2.5 : 1.0;
                }];
            } else {
                ring.layer.borderColor = isActive ? [UIColor whiteColor].CGColor : [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
                ring.layer.borderWidth = isActive ? 2.5 : 1.0;
            }
        }
    }
}

- (UIColor *)_getDeviceFrontColor {
    UIDevice *device = [UIDevice currentDevice];
    NSString *colorHex = nil;
    if ([device respondsToSelector:NSSelectorFromString(@"_deviceInfoForKey:")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        colorHex = [device performSelector:NSSelectorFromString(@"_deviceInfoForKey:") withObject:@"DeviceColor"];
#pragma clang diagnostic pop
    }
    if ([colorHex isKindOfClass:[NSString class]] && colorHex.length > 0) {
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:colorHex];
        if ([colorHex hasPrefix:@"#"]) [scanner setScanLocation:1];
        [scanner scanHexInt:&rgbValue];
        return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
    }
    return [UIColor colorWithRed:0.65 green:0.67 blue:0.70 alpha:1.0];
}

- (UIColor *)_getDeviceEnclosureColor {
    UIDevice *device = [UIDevice currentDevice];
    UIColor *deviceColor = nil;
    if ([device respondsToSelector:NSSelectorFromString(@"_deviceEnclosureColor")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        deviceColor = [device performSelector:NSSelectorFromString(@"_deviceEnclosureColor")];
#pragma clang diagnostic pop
    }
    if (deviceColor) return deviceColor;
    return [UIColor colorWithRed:0.35 green:0.37 blue:0.40 alpha:1.0];
}

- (UIColor *)_getWallpaperAverageColor {
    id wallpaperController = nil;
    if ([NSClassFromString(@"SBWallpaperController") respondsToSelector:@selector(sharedInstance)]) {
        wallpaperController = [NSClassFromString(@"SBWallpaperController") performSelector:@selector(sharedInstance)];
    }
    
    UIColor *avgColor = nil;
    if (wallpaperController && [wallpaperController respondsToSelector:@selector(averageColorForVariant:)]) {
        avgColor = ((UIColor *(*)(id, SEL, NSInteger))[wallpaperController methodForSelector:@selector(averageColorForVariant:)])(wallpaperController, @selector(averageColorForVariant:), 0);
    }
    return avgColor;
}

- (void)_updateTintUIExtras {
    CGFloat sat = 1.0 - self.currentBrightness;
    UIColor *currentColor = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];

    // update live tint overlay
    UIButton *tintedBtn = (UIButton *)[self.menuView viewWithTag:103];
    UIView *overlay = [tintedBtn viewWithTag:999];
    if (overlay) {
        overlay.backgroundColor = [currentColor colorWithAlphaComponent:0.45];
    }

    // update eyedropper circle color
    UIButton *eyeBtn = (UIButton *)[self.slidersContainer viewWithTag:1104];
    UIView *eyeCircle = [eyeBtn viewWithTag:20];
    if (eyeCircle) {
        eyeCircle.backgroundColor = currentColor;
    }
}

- (void)_saveTintColor {
    save26Pref(@"ngkhoi.26home.tintHue", @(self.currentHue));
    save26Pref(@"ngkhoi.26home.tintBrightness", @(self.currentBrightness));
    
    // calc hex string
    CGFloat sat = 1.0 - self.currentBrightness;
    UIColor *color = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *hex = [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
    save26Pref(@"ngkhoi.26home.tintColor", hex);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
    });
}

- (void)_saveLiveTintColor {
    save26Pref(@"ngkhoi.26home.tintHue", @(self.currentHue));
    save26Pref(@"ngkhoi.26home.tintBrightness", @(self.currentBrightness));
    
    CGFloat sat = 1.0 - self.currentBrightness;
    UIColor *color = [UIColor colorWithHue:self.currentHue saturation:sat brightness:1.0 alpha:1.0];
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *hex = [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
    save26Pref(@"ngkhoi.26home.tintColor", hex);
    
    // fast tint update without reloading icons
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateLiveTintColor" object:nil];
}

- (void)showAdvancedColorModal {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [feedback prepare];
    [feedback impactOccurred];
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSString *currHex = [defaults stringForKey:@"ngkhoi.26home.tintColor"] ?: @"#00FFFF";
    
    LGAdvancedColorModalView *modal = [[LGAdvancedColorModalView alloc] initWithFrame:self.bounds initialHex:currHex];
    __weak typeof(self) weakSelf = self;
    modal.onColorChanged = ^(NSString *hex, CGFloat hue, CGFloat brightness) {
        weakSelf.currentHue = hue;
        weakSelf.currentBrightness = 1.0 - brightness;
        [weakSelf _updateThumbPositions];
        [weakSelf _updateBrightnessGradient];
        [weakSelf _updateTintUIExtras];
        [weakSelf _setActivePresetButton:1104 animated:NO];
        
        save26Pref(@"ngkhoi.26home.tintHue", @(hue));
        save26Pref(@"ngkhoi.26home.tintBrightness", @(1.0 - brightness));
        save26Pref(@"ngkhoi.26home.tintColor", hex);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateLiveTintColor" object:nil];
    };
    
    modal.onDismiss = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.PurgeCaches" object:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.UpdateIconStyle" object:nil];
        });
    };
    
    [modal presentInView:self];
}

- (void)handleHuePan:(UIGestureRecognizer *)gesture {
    CGFloat thumbSize = 36.0;
    CGPoint loc = [gesture locationInView:self.hueSlider];
    CGFloat pct = (loc.x - (thumbSize / 2.0)) / (self.hueSlider.frame.size.width - thumbSize);
    pct = MAX(0.0, MIN(1.0, pct));
    self.currentHue = pct;
    
    [self _updateThumbPositions];
    [self _updateBrightnessGradient];
    [self _updateTintUIExtras];
    [self _setActivePresetButton:1104 animated:NO];
    
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
    [self _updateTintUIExtras];
    [self _setActivePresetButton:1104 animated:NO];
    
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self _saveTintColor];
    } else {
        [self _saveLiveTintColor];
    }
}

- (void)deviceBodyColorTapped {
    UIColor *color = [self _getDeviceEnclosureColor];
    CGFloat h, s, b, a;
    if ([color getHue:&h saturation:&s brightness:&b alpha:&a]) {
        self.currentHue = h;
        self.currentBrightness = 1.0 - s;
        [self _updateThumbPositions];
        [self _updateBrightnessGradient];
        [self _updateTintUIExtras];
        [self _setActivePresetButton:1101 animated:YES];
        [self _saveTintColor];
    }
}

- (void)deviceScreenColorTapped {
    UIColor *color = [self _getDeviceFrontColor];
    CGFloat h, s, b, a;
    if ([color getHue:&h saturation:&s brightness:&b alpha:&a]) {
        self.currentHue = h;
        self.currentBrightness = 1.0 - s;
        [self _updateThumbPositions];
        [self _updateBrightnessGradient];
        [self _updateTintUIExtras];
        [self _setActivePresetButton:1102 animated:YES];
        [self _saveTintColor];
    }
}
- (void)autoColorTapped {
    UIColor *avgColor = [self _getWallpaperAverageColor];
    if (avgColor) {
        CGFloat h, s, b, a;
        if ([avgColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            CGFloat boostedSat = 0.0;
            if (s < 0.08) {
                boostedSat = 0.0;
            } else {
                boostedSat = MIN(1.0, s * 2.2);
                if (boostedSat < 0.40) boostedSat = 0.40;
            }
            
            self.currentHue = h;
            self.currentBrightness = 1.0 - boostedSat;
            
            [self _updateThumbPositions];
            [self _updateBrightnessGradient];
            [self _updateTintUIExtras];
            [self _setActivePresetButton:1103 animated:YES];
            [self _saveTintColor];
        }
    }
}
- (void)eyedropperTapped {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.0; // hide menu
    }];
    
    // hide icons/dock during eyedropper
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ngkhoi.26home.EyedropperStart" object:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIWindow *keyWindow = self.window ?: [[UIApplication sharedApplication] keyWindow];
        
        UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, 0.0);
        for (UIWindow *w in [[UIApplication sharedApplication] valueForKey:@"windows"]) {
#pragma clang diagnostic pop
            if (w.hidden || w.alpha < 0.01) continue;
            // skip our own window
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
                    boostedSat = 0.0; // monochrome
                } else {
                    boostedSat = MIN(1.0, s * 1.8);
                }
                self.currentHue = h;
                self.currentBrightness = 1.0 - boostedSat;
                [self _updateThumbPositions];
                [self _updateBrightnessGradient];
                [self _setActivePresetButton:1104 animated:YES];
                [self _setActivePresetButton:1104 animated:YES];
                [self _setActivePresetButton:1104 animated:YES];
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
            return NO; // let sliders receive touches
        }
    }
    
    CGPoint segLoc = [touch locationInView:self.themeSegmentContainer];
    if (self.themeSegmentContainer.alpha > 0.5 && CGRectContainsPoint(self.themeSegmentContainer.bounds, segLoc)) {
        if ([gestureRecognizer.view isEqual:self.menuView]) {
            return NO; // prevent menu pull on segment swipe
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
    
    // Set initial state
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
