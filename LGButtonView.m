#import "LGButtonView.h"

static UIImage *CreateRadialGlowImage(CGFloat diameter) {
    CGSize size = CGSizeMake(diameter, diameter);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.95].CGColor,
                        (id)[UIColor colorWithWhite:1.0 alpha:0.60].CGColor,
                        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
    CGFloat locations[] = {0.0, 0.35, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    
    CGPoint center = CGPointMake(diameter / 2.0, diameter / 2.0);
    CGContextDrawRadialGradient(ctx, gradient, center, 0.0, center, diameter / 2.0, kCGGradientDrawsAfterEndLocation);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@implementation LGButtonView

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title blurRadius:(CGFloat)blurRadius {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.clipsToBounds = NO;
        CGFloat radius = frame.size.height / 2.0;
        
        self.backgroundContainer = [[UIView alloc] initWithFrame:self.bounds];
        self.backgroundContainer.clipsToBounds = YES;
        self.backgroundContainer.layer.cornerRadius = radius;
        self.backgroundContainer.layer.cornerCurve = kCACornerCurveContinuous;
        self.backgroundContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        [self addSubview:self.backgroundContainer];
        
        self.blurView = [[LGAdjustableBlurView alloc] initWithFrame:self.backgroundContainer.bounds blurRadius:blurRadius];
        self.blurView.qualityScale = 0.35;
        self.blurView.clipsToBounds = YES;
        self.blurView.layer.cornerRadius = radius;
        self.blurView.layer.cornerCurve = kCACornerCurveContinuous;
        self.blurView.tag = 996;
        [self.backgroundContainer addSubview:self.blurView];
        
        self.lgView = [[LGLiveBackdropView alloc] initWithFrame:self.backgroundContainer.bounds];
        self.lgView.qualityScale = 0.35;
        self.lgView.clipsToBounds = YES;
        self.lgView.layer.cornerRadius = radius;
        self.lgView.layer.cornerCurve = kCACornerCurveContinuous;
        self.lgView.tag = 998;
        [self.backgroundContainer addSubview:self.lgView];
        
        CGFloat glowDiameter = 90.0;
        self.innerGlowView = [[UIImageView alloc] initWithImage:CreateRadialGlowImage(glowDiameter)];
        self.innerGlowView.frame = CGRectMake(0, 0, glowDiameter, glowDiameter);
        self.innerGlowView.center = CGPointMake(frame.size.width / 2.0, frame.size.height / 2.0);
        self.innerGlowView.alpha = 0.0;
        [self.backgroundContainer addSubview:self.innerGlowView];
        
        self.specularRimLayer = [CAGradientLayer layer];
        self.specularRimLayer.frame = self.backgroundContainer.bounds;
        self.specularRimLayer.startPoint = CGPointMake(0, 0);
        self.specularRimLayer.endPoint = CGPointMake(1, 1);
        self.specularRimLayer.colors = @[(id)[UIColor colorWithWhite:1.0 alpha:0.75].CGColor,
                                         (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                         (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                         (id)[UIColor colorWithWhite:1.0 alpha:0.75].CGColor];
        self.specularRimLayer.locations = @[@0.0, @0.28, @0.72, @1.0];
        
        self.specularMaskLayer = [CAShapeLayer layer];
        UIBezierPath *rimPath = [UIBezierPath bezierPathWithRoundedRect:self.backgroundContainer.bounds cornerRadius:radius];
        self.specularMaskLayer.path = rimPath.CGPath;
        self.specularMaskLayer.fillColor = [UIColor clearColor].CGColor;
        self.specularMaskLayer.strokeColor = [UIColor whiteColor].CGColor;
        self.specularMaskLayer.lineWidth = 1.2;
        self.specularRimLayer.mask = self.specularMaskLayer;
        [self.backgroundContainer.layer addSublayer:self.specularRimLayer];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:self.bounds];
        self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        self.titleLabel.textColor = [UIColor labelColor];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.text = title;
        self.titleLabel.tag = 997;
        [self addSubview:self.titleLabel];
    }
    return self;
}

- (void)updateLayoutWithFrame:(CGRect)frame {
    self.frame = frame;
    [self updateShapeWithScale:1.0 stretchX:1.0 stretchY:1.0 shiftX:0 shiftY:0];
    self.titleLabel.frame = self.bounds;
}

- (void)updateShapeWithScale:(CGFloat)baseScale stretchX:(CGFloat)stretchX stretchY:(CGFloat)stretchY shiftX:(CGFloat)shiftX shiftY:(CGFloat)shiftY {
    CGFloat newW = self.bounds.size.width * baseScale * stretchX;
    CGFloat newH = self.bounds.size.height * baseScale * stretchY;
    CGFloat newRadius = newH / 2.0;

    CGRect newBounds = CGRectMake(0, 0, newW, newH);

    self.backgroundContainer.bounds = newBounds;
    self.backgroundContainer.layer.cornerRadius = newRadius;
    self.backgroundContainer.transform = CGAffineTransformMakeTranslation(shiftX, shiftY);

    self.blurView.frame = newBounds;
    self.blurView.layer.cornerRadius = newRadius;

    self.lgView.frame = newBounds;
    self.lgView.layer.cornerRadius = newRadius;

    self.specularRimLayer.frame = newBounds;
    UIBezierPath *rimPath = [UIBezierPath bezierPathWithRoundedRect:newBounds cornerRadius:newRadius];
    self.specularMaskLayer.path = rimPath.CGPath;

    self.titleLabel.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(baseScale * stretchX, baseScale * stretchY), CGAffineTransformMakeTranslation(shiftX, shiftY));
}

- (void)updateGlowPositionWithTouchPoint:(CGPoint)point shiftX:(CGFloat)shiftX shiftY:(CGFloat)shiftY containerWidth:(CGFloat)cw containerHeight:(CGFloat)ch {
    CGFloat cx = cw / 2.0;
    CGFloat cy = ch / 2.0;
    
    CGFloat dx = (point.x - shiftX) - (self.bounds.size.width / 2.0);
    CGFloat dy = (point.y - shiftY) - (self.bounds.size.height / 2.0);
    
    CGFloat padding = 2.0;
    CGFloat R = MAX(0.0, (ch / 2.0) - padding);
    CGFloat straightW = MAX(0.0, (cw / 2.0) - (ch / 2.0));
    
    dy = MAX(-R, MIN(dy, R));
    
    if (dx < -straightW) {
        CGFloat capX = dx + straightW;
        CGFloat dist = sqrt(capX * capX + dy * dy);
        if (dist > R && dist > 0.001) {
            dx = -straightW + (capX / dist) * R;
            dy = (dy / dist) * R;
        }
    } else if (dx > straightW) {
        CGFloat capX = dx - straightW;
        CGFloat dist = sqrt(capX * capX + dy * dy);
        if (dist > R && dist > 0.001) {
            dx = straightW + (capX / dist) * R;
            dy = (dy / dist) * R;
        }
    }
    
    self.innerGlowView.center = CGPointMake(cx + dx, cy + dy);
}

- (void)handleTouchDownAtPoint:(CGPoint)point {
    self.isPressed = YES;
    self.touchStartPoint = point;
    
    CGFloat initialW = self.bounds.size.width * 1.08;
    CGFloat initialH = self.bounds.size.height * 1.08;
    [self updateGlowPositionWithTouchPoint:point shiftX:0 shiftY:0 containerWidth:initialW containerHeight:initialH];
    
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.60 initialSpringVelocity:0.5 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self updateShapeWithScale:1.08 stretchX:1.0 stretchY:1.0 shiftX:0 shiftY:0];
        self.innerGlowView.alpha = 0.90;
    } completion:nil];
}

- (void)handleTouchMovedToPoint:(CGPoint)point {
    if (!self.isPressed) {
        self.isPressed = YES;
        self.touchStartPoint = point;
    }
    
    CGFloat dx = point.x - self.touchStartPoint.x;
    CGFloat dy = point.y - self.touchStartPoint.y;
    CGFloat dist = sqrt(dx * dx + dy * dy);
    
    CGFloat stretchX = 1.0;
    CGFloat stretchY = 1.0;
    CGFloat shiftX = 0;
    CGFloat shiftY = 0;
    
    if (dist > 0.001) {
        CGFloat maxEffect = 50.0;
        CGFloat effectDist = MIN(dist * 0.45, maxEffect);
        
        CGFloat effectX = (dx / dist) * effectDist;
        CGFloat effectY = (dy / dist) * effectDist;
        
        stretchX = 1.0 + (fabs(effectX) * 0.0030);
        stretchY = 1.0 + (fabs(effectY) * 0.0060);
        
        shiftX = effectX * 0.50;
        shiftY = effectY * 0.50;
    }
    
    CGFloat newW = self.bounds.size.width * 1.08 * stretchX;
    CGFloat newH = self.bounds.size.height * 1.08 * stretchY;
    
    [self updateShapeWithScale:1.08 stretchX:stretchX stretchY:stretchY shiftX:shiftX shiftY:shiftY];
    [self updateGlowPositionWithTouchPoint:point shiftX:shiftX shiftY:shiftY containerWidth:newW containerHeight:newH];
}

- (void)handleTouchEnded {
    self.isPressed = NO;
    
    [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.52 initialSpringVelocity:0.8 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self updateShapeWithScale:1.0 stretchX:1.0 stretchY:1.0 shiftX:0 shiftY:0];
        self.innerGlowView.alpha = 0.0;
    } completion:nil];
}

@end


@implementation LGLiquidBlockerGesture

- (instancetype)init {
    self = [super initWithTarget:nil action:nil];
    if (self) {
        self.delegate = self;
        self.cancelsTouchesInView = NO;
        self.delaysTouchesEnded = NO;
        self.delaysTouchesBegan = NO;
    }
    return self;
}

// prevent system edge gestures (cc, coversheet) from taking over (idk why this wont work)
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
    return YES;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer {
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO; // keep gesture exclusive
}

@end
