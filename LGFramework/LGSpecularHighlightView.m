#import "LGSpecularHighlightView.h"

@interface LGSpecularHighlightView ()
@property (nonatomic, strong) CAGradientLayer *specularRim;
@property (nonatomic, strong) CAShapeLayer *rimMask;
@end

@implementation LGSpecularHighlightView

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame cornerRadius:40.0];
}

- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)cornerRadius {
    self = [super initWithFrame:frame];
    if (self) {
        _cornerRadius = cornerRadius;
        _strokeWidth = 1.5;
        _topSpecularOpacity = 0.65;
        _bottomSpecularOpacity = 0.35;

        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];

        self.specularRim = [CAGradientLayer layer];
        self.specularRim.colors = @[(id)[UIColor colorWithWhite:1.0 alpha:_topSpecularOpacity].CGColor,
                                    (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                    (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
                                    (id)[UIColor colorWithWhite:1.0 alpha:_bottomSpecularOpacity].CGColor];
        self.specularRim.locations = @[@0.0, @0.35, @0.65, @1.0];
        self.specularRim.startPoint = CGPointMake(0, 0);
        self.specularRim.endPoint = CGPointMake(1, 1);

        self.rimMask = [CAShapeLayer layer];
        self.rimMask.fillColor = [UIColor clearColor].CGColor;
        self.rimMask.strokeColor = [UIColor whiteColor].CGColor;
        self.rimMask.lineWidth = _strokeWidth;
        self.specularRim.mask = self.rimMask;

        [self.layer addSublayer:self.specularRim];
    }
    return self;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    self.rimMask.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius].CGPath;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.specularRim.frame = self.bounds;
    self.rimMask.lineWidth = self.strokeWidth;
    self.rimMask.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.cornerRadius].CGPath;
}

@end
