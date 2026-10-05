#import "Home26LiquidMenu.h"
#import "LGButtonView.h"
#import "Headers.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#pragma mark - Layout & Timing Constants

static const CGFloat kSeedSize     = 22.0;
static const CGFloat kCircleSize   = 112.0;
static const CGFloat kMenuW        = 214.0;
static const CFTimeInterval kOpenDuration  = 0.875;
static const CFTimeInterval kCloseDuration = 0.5625;

#pragma mark - Private CAFilter Forward Declaration

@interface CAFilter : NSObject
+ (nullable instancetype)filterWithType:(NSString *)type;
@end

#pragma mark - Home26LiquidMenuItem

@implementation Home26LiquidMenuItem

+ (instancetype)itemWithTitle:(NSString *)title icon:(nullable UIImage *)icon action:(nullable void (^)(void))action {
    Home26LiquidMenuItem *item = [[Home26LiquidMenuItem alloc] init];
    item.title = title;
    item.icon = icon;
    item.action = action;
    return item;
}

@end

#pragma mark - Home26LiquidMenuRow

@interface Home26LiquidMenuRow : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIView *highlightView;
@property (nonatomic, copy) void (^actionBlock)(void);
@property (nonatomic, assign) BOOL isPressed;
- (instancetype)initWithTitle:(NSString *)title icon:(nullable UIImage *)icon action:(nullable void (^)(void))action;
@end

@implementation Home26LiquidMenuRow

- (instancetype)initWithTitle:(NSString *)title icon:(nullable UIImage *)icon action:(nullable void (^)(void))action {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _actionBlock = [action copy];
        self.backgroundColor = [UIColor clearColor];

        self.highlightView = [[UIView alloc] initWithFrame:CGRectZero];
        self.highlightView.backgroundColor = [UIColor clearColor];
        self.highlightView.layer.cornerRadius = 10.0;
        self.highlightView.layer.cornerCurve = kCACornerCurveContinuous;
        self.highlightView.userInteractionEnabled = NO;
        [self addSubview:self.highlightView];

        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.text = title;
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightRegular];
        self.titleLabel.userInteractionEnabled = NO;
        [self addSubview:self.titleLabel];

        self.iconImageView = [[UIImageView alloc] init];
        self.iconImageView.image = icon;
        self.iconImageView.tintColor = [UIColor whiteColor];
        self.iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.iconImageView.userInteractionEnabled = NO;
        [self addSubview:self.iconImageView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.highlightView.frame = self.bounds;

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat iconSize = 20.0;
    CGFloat rightPad = 14.0;
    CGFloat leftPad = 14.0;

    CGFloat iconTitleGap = 8.0;
    self.iconImageView.frame = CGRectMake(leftPad, (h - iconSize) / 2.0, iconSize, iconSize);
    CGFloat titleX = leftPad + iconSize + iconTitleGap;
    self.titleLabel.frame = CGRectMake(titleX, 0, w - titleX - rightPad, h);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.isPressed = YES;
    [UIView animateWithDuration:0.08 animations:^{
        self.highlightView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
        self.transform = CGAffineTransformMakeScale(0.985, 0.985);
    }];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *t = [touches anyObject];
    CGPoint pt = [t locationInView:self];
    BOOL inside = CGRectContainsPoint(self.bounds, pt);
    if (inside != self.isPressed) {
        self.isPressed = inside;
        [UIView animateWithDuration:0.08 animations:^{
            self.highlightView.backgroundColor = inside ? [UIColor colorWithWhite:1.0 alpha:0.18] : [UIColor clearColor];
            self.transform = inside ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        }];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.isPressed) {
        self.isPressed = NO;
        [UIView animateWithDuration:0.10 animations:^{
            self.highlightView.backgroundColor = [UIColor clearColor];
            self.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if (self.actionBlock) {
                self.actionBlock();
            }
        }];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.isPressed = NO;
    [UIView animateWithDuration:0.10 animations:^{
        self.highlightView.backgroundColor = [UIColor clearColor];
        self.transform = CGAffineTransformIdentity;
    }];
}

@end

#pragma mark - Home26LiquidMenuDismissView

@interface Home26LiquidMenuDismissView : UIView
@property (nonatomic, copy) void (^dismissHandler)(void);
@end

@implementation Home26LiquidMenuDismissView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.dismissHandler) {
        self.dismissHandler();
    }
}

@end

#pragma mark - Home26LiquidMenuMorphEntity

@interface Home26LiquidMenuMorphEntity : UIView
@property (nonatomic, strong) UIView *clipView;
@property (nonatomic, strong) UIVisualEffectView *visualEffectView;
@property (nonatomic, strong) LGLiveBackdropView *lgView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSMutableArray<Home26LiquidMenuRow *> *rows;
@property (nonatomic, strong) NSMutableArray<UIView *> *separators;
@property (nonatomic, strong) CAGradientLayer *rimLayer;
@property (nonatomic, strong) CAShapeLayer *rimMaskLayer;
@property (nonatomic, strong) id contentBlurFilter;
@property (nonatomic, assign) BOOL hasCAFilter;
@property (nonatomic, assign) CGFloat internalCornerRadius;

- (void)setCornerRadius:(CGFloat)radius;
- (void)setContentBlur:(CGFloat)blur opacity:(CGFloat)opacity scale:(CGFloat)scale interactionEnabled:(BOOL)enabled;
- (void)setGlassRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
- (void)setShadowYOffset:(CGFloat)offset radius:(CGFloat)radius opacity:(CGFloat)opacity;
- (void)configureWithItems:(NSArray<Home26LiquidMenuItem *> *)items dismissHandler:(void (^)(void))dismissHandler;
@end

@implementation Home26LiquidMenuMorphEntity

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _internalCornerRadius = 26.0;
        _rows = [NSMutableArray array];
        _separators = [NSMutableArray array];
        [self _setup];
    }
    return self;
}

- (void)_setup {
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 16);
    self.layer.shadowRadius = 24.0;
    self.layer.shadowOpacity = 0.35f;

    self.clipView = [[UIView alloc] initWithFrame:self.bounds];
    self.clipView.layer.masksToBounds = YES;
    self.clipView.layer.cornerRadius = _internalCornerRadius;
    self.clipView.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:self.clipView];

    UIBlurEffect *blurEffect = nil;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }
    self.visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.visualEffectView.frame = self.clipView.bounds;
    self.visualEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.visualEffectView.layer.cornerRadius = _internalCornerRadius;
    self.visualEffectView.layer.cornerCurve = kCACornerCurveContinuous;
    self.visualEffectView.clipsToBounds = YES;
    self.visualEffectView.alpha = 0.85;
    [self.clipView addSubview:self.visualEffectView];

    self.lgView = [[LGLiveBackdropView alloc] initWithFrame:self.clipView.bounds];
    self.lgView.qualityScale = 0.85;
    self.lgView.capturesAppIcon = NO;
    self.lgView.clipsToBounds = YES;
    self.lgView.layer.cornerRadius = _internalCornerRadius;
    self.lgView.layer.cornerCurve = kCACornerCurveContinuous;
    [self.clipView addSubview:self.lgView];

    self.tintView = [[UIView alloc] initWithFrame:self.clipView.bounds];
    self.tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.04];
    self.tintView.layer.cornerRadius = _internalCornerRadius;
    self.tintView.layer.cornerCurve = kCACornerCurveContinuous;
    self.tintView.userInteractionEnabled = NO;
    [self.clipView addSubview:self.tintView];

    self.contentView = [[UIView alloc] initWithFrame:self.clipView.bounds];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.contentView.userInteractionEnabled = NO;
    [self.clipView addSubview:self.contentView];

    [self _setupSpecularRim];
    [self _setupCAFilter];
}

- (void)_setupSpecularRim {
    self.rimLayer = [CAGradientLayer layer];
    self.rimLayer.frame = self.clipView.bounds;
    self.rimLayer.startPoint = CGPointMake(0, 0);
    self.rimLayer.endPoint = CGPointMake(1, 1);
    self.rimLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.88].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.35].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.02].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.35].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.88].CGColor,
    ];
    self.rimLayer.locations = @[@0.0, @0.18, @0.42, @0.50, @0.58, @0.82, @1.0];
    self.rimLayer.zPosition = 200;

    self.rimMaskLayer = [CAShapeLayer layer];
    self.rimMaskLayer.fillRule = kCAFillRuleEvenOdd;
    [self _updateRimPathForRadius:_internalCornerRadius];
    self.rimLayer.mask = self.rimMaskLayer;

    [self.clipView.layer addSublayer:self.rimLayer];
}

- (void)_setupCAFilter {
    Class CAFilterClass = NSClassFromString(@"CAFilter");
    if (CAFilterClass && [CAFilterClass respondsToSelector:@selector(filterWithType:)]) {
        id filter = [CAFilterClass filterWithType:@"gaussianBlur"];
        if (filter) {
            [filter setValue:@14.0 forKey:@"inputRadius"];
            self.contentBlurFilter = filter;
            self.hasCAFilter = YES;
            [self.contentView.layer setValue:@YES forKey:@"allowsGroupBlending"];
        }
    }
}

- (void)configureWithItems:(NSArray<Home26LiquidMenuItem *> *)items dismissHandler:(void (^)(void))dismissHandler {
    for (Home26LiquidMenuRow *row in self.rows) {
        [row removeFromSuperview];
    }
    [self.rows removeAllObjects];

    for (UIView *sep in self.separators) {
        [sep removeFromSuperview];
    }
    [self.separators removeAllObjects];

    for (NSUInteger i = 0; i < items.count; i++) {
        Home26LiquidMenuItem *item = items[i];
        void (^itemAction)(void) = item.action;
        Home26LiquidMenuRow *row = [[Home26LiquidMenuRow alloc] initWithTitle:item.title icon:item.icon action:^{
            if (dismissHandler) {
                dismissHandler();
            }
            if (itemAction) {
                itemAction();
            }
        }];
        [self.rows addObject:row];
        [self.contentView addSubview:row];

        if (i < items.count - 1) {
            UIView *sep = [[UIView alloc] init];
            sep.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
            sep.userInteractionEnabled = NO;
            [self.separators addObject:sep];
            [self.contentView addSubview:sep];
        }
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.clipView.frame = self.bounds;
    self.visualEffectView.frame = self.clipView.bounds;
    self.lgView.frame = self.clipView.bounds;
    self.tintView.frame = self.clipView.bounds;
    self.contentView.frame = self.clipView.bounds;

    self.rimLayer.frame = self.clipView.bounds;
    self.rimMaskLayer.frame = self.clipView.bounds;
    [self _updateRimPathForRadius:_internalCornerRadius];

    CGFloat panelW = self.contentView.bounds.size.width;
    CGFloat rowH = 44.0;
    CGFloat padTop = 8.0;
    CGFloat rowX = 6.0;
    CGFloat rowW = panelW - rowX * 2.0;

    for (NSUInteger i = 0; i < self.rows.count; i++) {
        Home26LiquidMenuRow *row = self.rows[i];
        row.frame = CGRectMake(rowX, padTop + i * rowH, rowW, rowH);
    }

    for (NSUInteger i = 0; i < self.separators.count; i++) {
        UIView *sep = self.separators[i];
        sep.frame = CGRectMake(rowX + 12.0, padTop + (i + 1) * rowH - 0.5, rowW - 24.0, 0.5);
    }

    [self _updateShadowPath];
}

- (void)_updateRimPathForRadius:(CGFloat)radius {
    CGRect b = self.rimLayer.bounds;
    CGFloat inset = 1.25;
    UIBezierPath *outer = Home26CreateSquirclePath(b, radius);
    UIBezierPath *inner = Home26CreateSquirclePath(CGRectInset(b, inset, inset), MAX(0, radius - inset));
    [outer appendPath:inner];
    self.rimMaskLayer.path = outer.CGPath;
}

- (void)_updateShadowPath {
    UIBezierPath *p = Home26CreateSquirclePath(self.bounds, _internalCornerRadius);
    self.layer.shadowPath = p.CGPath;
}

- (void)setCornerRadius:(CGFloat)radius {
    _internalCornerRadius = radius;
    self.clipView.layer.cornerRadius = radius;
    self.visualEffectView.layer.cornerRadius = radius;
    self.lgView.layer.cornerRadius = radius;
    self.tintView.layer.cornerRadius = radius;
    self.rimLayer.frame = self.clipView.bounds;
    self.rimMaskLayer.frame = self.clipView.bounds;
    [self _updateRimPathForRadius:radius];
    [self _updateShadowPath];
}

- (void)setContentBlur:(CGFloat)blur opacity:(CGFloat)opacity scale:(CGFloat)scale interactionEnabled:(BOOL)enabled {
    if (self.hasCAFilter && self.contentBlurFilter) {
        [self.contentBlurFilter setValue:@(MAX(0, blur)) forKey:@"inputRadius"];
        if (blur > 0.5) {
            self.contentView.layer.filters = @[self.contentBlurFilter];
        } else {
            self.contentView.layer.filters = @[];
        }
    }
    self.contentView.alpha = opacity;
    self.contentView.transform = CGAffineTransformMakeScale(scale, scale);
    self.contentView.userInteractionEnabled = enabled;
}

- (void)setGlassRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a {
    CGFloat transparentAlpha = MIN(a * 0.10, 0.08);
    self.tintView.backgroundColor = [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:transparentAlpha];
}

- (void)setShadowYOffset:(CGFloat)offset radius:(CGFloat)radius opacity:(CGFloat)opacity {
    self.layer.shadowOffset = CGSizeMake(0, offset);
    self.layer.shadowRadius = radius;
    self.layer.shadowOpacity = (float)opacity;
    [self _updateShadowPath];
}

@end

#pragma mark - Home26LiquidMenu

typedef NS_ENUM(NSInteger, Home26LiquidMenuState) {
    Home26LiquidMenuStateClosed = 0,
    Home26LiquidMenuStateOpening,
    Home26LiquidMenuStateOpen,
    Home26LiquidMenuStateClosing
};

@interface Home26LiquidMenu ()

@property (nonatomic, assign) Home26LiquidMenuState state;
@property (nonatomic, assign) CGFloat currentProgress;
@property (nonatomic, assign) CGFloat startProgress;
@property (nonatomic, assign) CGFloat targetProgress;
@property (nonatomic, assign) CFTimeInterval startTimestamp;
@property (nonatomic, assign) CFTimeInterval animDuration;
@property (nonatomic, assign) BOOL animatingOpen;
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, weak) UIControl *button;
@property (nonatomic, strong) Home26LiquidMenuDismissView *dismissView;
@property (nonatomic, strong) Home26LiquidMenuMorphEntity *morphEntity;

@property (nonatomic, assign) CGPoint P0;
@property (nonatomic, assign) CGPoint P1;
@property (nonatomic, assign) CGFloat targetMenuH;

@end

@implementation Home26LiquidMenu

+ (instancetype)sharedMenu {
    static Home26LiquidMenu *sSharedMenu = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSharedMenu = [[Home26LiquidMenu alloc] init];
    });
    return sSharedMenu;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = Home26LiquidMenuStateClosed;
        _currentProgress = 0.0;
        _targetProgress = 0.0;
        _targetMenuH = 192.0;
    }
    return self;
}

- (BOOL)isOpen {
    return (self.state == Home26LiquidMenuStateOpen || self.state == Home26LiquidMenuStateOpening);
}

- (void)presentFromButton:(UIControl *)button items:(NSArray<Home26LiquidMenuItem *> *)items {
    if (self.state != Home26LiquidMenuStateClosed) {
        [self dismiss];
        return;
    }

    self.button = button;
    UIWindow *window = button.window;
    if (!window) {
        NSArray *windows = [[UIApplication sharedApplication] valueForKey:@"windows"];
        for (UIWindow *w in windows) {
            if (!w.hidden && w.bounds.size.height > 0) {
                window = w;
                break;
            }
        }
    }
    if (!window) return;

    CGRect btnRect = [button convertRect:button.bounds toView:window];
    self.P0 = CGPointMake(CGRectGetMidX(btnRect), CGRectGetMidY(btnRect));

    CGFloat menuW = kMenuW;
    CGFloat menuH = 8.0 + items.count * 44.0 + 8.0;
    self.targetMenuH = menuH;

    CGFloat margin = 12.0;
    CGFloat menuX = btnRect.origin.x;
    if (menuX + menuW > window.bounds.size.width - margin) {
        menuX = window.bounds.size.width - margin - menuW;
    }
    if (menuX < margin) {
        menuX = margin;
    }
    CGFloat menuY = CGRectGetMaxY(btnRect) + 8.0;
    if (menuY + menuH > window.bounds.size.height - margin) {
        menuY = btnRect.origin.y - 8.0 - menuH;
    }
    self.P1 = CGPointMake(menuX + menuW / 2.0, menuY + menuH / 2.0);

    if (!self.dismissView) {
        self.dismissView = [[Home26LiquidMenuDismissView alloc] initWithFrame:window.bounds];
        self.dismissView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        __weak typeof(self) weakSelf = self;
        self.dismissView.dismissHandler = ^{
            [weakSelf dismiss];
        };
    }
    self.dismissView.frame = window.bounds;
    self.dismissView.hidden = YES;
    [window addSubview:self.dismissView];

    if (!self.morphEntity) {
        self.morphEntity = [[Home26LiquidMenuMorphEntity alloc] initWithFrame:CGRectZero];
    }
    __weak typeof(self) weakSelf = self;
    [self.morphEntity configureWithItems:items dismissHandler:^{
        [weakSelf dismiss];
    }];
    self.morphEntity.hidden = YES;
    [window addSubview:self.morphEntity];
    [self.morphEntity.lgView forceReapplyForRegistrationRace];

    self.state = Home26LiquidMenuStateOpening;
    [self _animateTo:1.0 duration:kOpenDuration];
}

- (void)dismiss {
    if (self.state == Home26LiquidMenuStateClosed || self.state == Home26LiquidMenuStateClosing) return;
    self.state = Home26LiquidMenuStateClosing;
    [self _animateTo:0.0 duration:kCloseDuration];
}

- (void)dismissImmediately {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    self.state = Home26LiquidMenuStateClosed;
    [self _cleanupAfterDismiss];
}

- (void)_animateTo:(CGFloat)targetP duration:(CFTimeInterval)duration {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }

    self.startProgress = self.currentProgress;
    self.targetProgress = targetP;
    self.animDuration = duration;
    self.animatingOpen = (targetP > self.startProgress);
    self.startTimestamp = 0;

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_displayLinkFired:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (double)_solveTimingCurve:(double)t isOpening:(BOOL)isOpening {
    if (!isOpening) {

        return (t < 0.5) ? (2.0 * t * t) : (1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0);
    }

    const double alpha = 5.4;
    const double omega = 4.8;
    const double c = 0.28;
    double decay = exp(-alpha * t);
    double oscillation = cos(omega * t) + c * sin(omega * t);
    return 1.0 - decay * oscillation;
}

- (void)_displayLinkFired:(CADisplayLink *)link {
    CFTimeInterval now = CACurrentMediaTime();
    if (self.startTimestamp <= 0) {
        self.startTimestamp = now;
        return;
    }

    CFTimeInterval elapsed = now - self.startTimestamp;
    double linearT = (self.animDuration > 0) ? MIN(elapsed / self.animDuration, 1.0) : 1.0;
    double curvedT = [self _solveTimingCurve:linearT isOpening:self.animatingOpen];
    CGFloat p = (CGFloat)(self.startProgress + (self.targetProgress - self.startProgress) * curvedT);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self renderProgress:p];
    [CATransaction commit];

    if (linearT >= 1.0) {
        [self.displayLink invalidate];
        self.displayLink = nil;

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self renderProgress:self.targetProgress];
        [CATransaction commit];

        if (self.targetProgress <= 0.0) {
            self.state = Home26LiquidMenuStateClosed;
            [self _cleanupAfterDismiss];
        } else {
            self.state = Home26LiquidMenuStateOpen;
        }
    }
}

- (void)_cleanupAfterDismiss {
    self.currentProgress = 0.0;
    self.targetProgress = 0.0;
    self.morphEntity.hidden = YES;
    self.dismissView.hidden = YES;
    [self.morphEntity removeFromSuperview];
    [self.dismissView removeFromSuperview];

    if (self.button) {
        self.button.hidden = NO;
        self.button.alpha = 1.0;
        self.button.transform = CGAffineTransformIdentity;
        LGButtonView *lgBtn = (LGButtonView *)[self.button viewWithTag:999];
        if (lgBtn && [lgBtn isKindOfClass:NSClassFromString(@"LGButtonView")]) {
            [lgBtn resetToNormalState];
        }
        [self.button setNeedsLayout];
        [self.button layoutIfNeeded];
    }
}

- (void)renderProgress:(CGFloat)p {
    self.currentProgress = p;

    if (p <= 0.0) {
        [self _cleanupAfterDismiss];
        return;
    }

    if (p <= 0.10) {
        CGFloat t = p / 0.10;
        LGButtonView *lgBtn = (LGButtonView *)[self.button viewWithTag:999];
        CGFloat btnW = (lgBtn && lgBtn.bounds.size.width > 0) ? lgBtn.bounds.size.width : (self.button ? self.button.bounds.size.width : 56.0);
        CGFloat btnH = (lgBtn && lgBtn.bounds.size.height > 0) ? lgBtn.bounds.size.height : (self.button ? self.button.bounds.size.height : 28.0);
        CGFloat scaleX = (btnW - (btnW - kSeedSize) * t) / btnW;
        CGFloat scaleY = (btnH - (btnH - kSeedSize) * t) / btnH;
        CGFloat cornerRadius = (btnH / 2.0) * (1.0 - t) + 11.0 * t;
        CGFloat glowAlpha = (CGFloat)sin(t * M_PI);
        CGFloat labelAlpha = MAX(0.0, 1.0 - t * 2.5);

        if (self.button) {
            self.button.hidden = NO;
            self.button.alpha = 1.0;
            self.button.transform = CGAffineTransformMakeScale(scaleX, scaleY);
            if (lgBtn && [lgBtn isKindOfClass:NSClassFromString(@"LGButtonView")]) {
                [lgBtn setShapeCornerRadius:cornerRadius];
                [lgBtn setGlowAlpha:glowAlpha];
                [lgBtn setLabelAlpha:labelAlpha];
            }
        }

        self.morphEntity.hidden = YES;
        self.dismissView.hidden = YES;

    } else if (p <= 0.42) {
        CGFloat flightT = (p - 0.10) / 0.32;
        CGFloat cx = self.P0.x + (self.P1.x - self.P0.x) * flightT;
        CGFloat cy = self.P0.y + (self.P1.y - self.P0.y) * flightT;
        CGFloat w = kSeedSize + (kCircleSize - kSeedSize) * flightT;
        CGFloat h = w;
        CGFloat radius = w / 2.0;

        CGFloat contentBlur = 14.0 - 7.0 * flightT;
        CGFloat contentOpacity = 0.25 + 0.45 * flightT;
        CGFloat contentScale = 0.78 + 0.16 * flightT;

        CGFloat bgAlpha = 0.30 + 0.08 * flightT;
        CGFloat shadowY = 6.0 + 8.0 * flightT;
        CGFloat shadowR = 12.0 + 6.0 * flightT;
        CGFloat shadowA = 0.20 + 0.10 * flightT;

        if (self.button) {
            self.button.alpha = 0.0;
        }

        [self.morphEntity setCornerRadius:radius];
        self.morphEntity.hidden = NO;
        self.morphEntity.transform = CGAffineTransformIdentity;
        self.morphEntity.frame = CGRectMake(cx - w/2.0, cy - h/2.0, w, h);
        [self.morphEntity setGlassRed:220 green:220 blue:230 alpha:bgAlpha];
        [self.morphEntity setShadowYOffset:shadowY radius:shadowR opacity:shadowA];
        [self.morphEntity setContentBlur:contentBlur opacity:contentOpacity scale:contentScale interactionEnabled:NO];
        self.dismissView.hidden = NO;

    } else if (p <= 0.70) {
        CGFloat expandT = (p - 0.42) / 0.28;
        CGFloat targetH = self.targetMenuH;
        CGFloat w = kCircleSize + (kMenuW - kCircleSize) * expandT;
        CGFloat h = kCircleSize + (targetH - kCircleSize) * expandT;
        CGFloat radius = (kCircleSize / 2.0) - ((kCircleSize / 2.0) - 50.0) * expandT;

        CGFloat contentBlur = MAX(0.0, 7.0 * (1.0 - expandT));
        CGFloat contentOpacity = MIN(1.0, 0.70 + 0.30 * expandT);
        CGFloat contentScale = 0.94 + 0.06 * expandT;

        if (self.button) {
            self.button.alpha = 0.0;
        }

        [self.morphEntity setCornerRadius:radius];
        self.morphEntity.hidden = NO;
        self.morphEntity.transform = CGAffineTransformIdentity;
        self.morphEntity.frame = CGRectMake(self.P1.x - w/2.0, self.P1.y - h/2.0, w, h);
        [self.morphEntity setGlassRed:220 green:220 blue:230 alpha:0.35];
        [self.morphEntity setShadowYOffset:14 radius:18 opacity:0.30];
        [self.morphEntity setContentBlur:contentBlur opacity:contentOpacity scale:contentScale interactionEnabled:NO];
        self.dismissView.hidden = NO;

    } else if (p <= 0.88) {
        CGFloat cornerT = (p - 0.70) / 0.18;
        CGFloat radius = 50.0 - (50.0 - 26.0) * cornerT;
        CGFloat targetH = self.targetMenuH;

        if (self.button) {
            self.button.alpha = 0.0;
        }

        [self.morphEntity setCornerRadius:radius];
        self.morphEntity.hidden = NO;
        self.morphEntity.transform = CGAffineTransformIdentity;
        self.morphEntity.frame = CGRectMake(self.P1.x - kMenuW/2.0, self.P1.y - targetH/2.0, kMenuW, targetH);
        [self.morphEntity setGlassRed:220 green:220 blue:230 alpha:0.35];
        [self.morphEntity setShadowYOffset:16 radius:20 opacity:0.32];
        [self.morphEntity setContentBlur:0 opacity:1.0 scale:1.0 interactionEnabled:NO];
        self.dismissView.hidden = NO;

    } else {
        CGFloat bounceScale = 1.0;
        CGFloat bounceY = 0.0;
        if (p > 1.0) {
            bounceScale = 1.0 + (p - 1.0) * 0.42;
            bounceY = (p - 1.0) * 6.0;
        } else {
            CGFloat settleRatio = MIN(1.0, (p - 0.88) / 0.12);
            bounceScale = 0.995 + 0.005 * settleRatio;
        }
        CGFloat targetH = self.targetMenuH;

        if (self.button) {
            self.button.alpha = 0.0;
        }

        [self.morphEntity setCornerRadius:26.0];
        self.morphEntity.hidden = NO;
        self.morphEntity.bounds = CGRectMake(0, 0, kMenuW, targetH);
        self.morphEntity.center = CGPointMake(self.P1.x, self.P1.y + bounceY);
        self.morphEntity.transform = CGAffineTransformMakeScale(bounceScale, bounceScale);
        [self.morphEntity setGlassRed:220 green:220 blue:230 alpha:0.35];
        [self.morphEntity setShadowYOffset:18 radius:24 opacity:0.35];
        [self.morphEntity setContentBlur:0 opacity:1.0 scale:1.0 interactionEnabled:YES];
        self.dismissView.hidden = NO;
    }
}

@end
