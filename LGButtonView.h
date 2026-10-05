#import <UIKit/UIKit.h>
#import "Headers.h"

@interface LGButtonView : UIView

@property (nonatomic, strong) UIView *backgroundContainer;
@property (nonatomic, strong) LGAdjustableBlurView *blurView;
@property (nonatomic, strong) LGLiveBackdropView *lgView;
@property (nonatomic, strong) UIImageView *innerGlowView;
@property (nonatomic, strong) UIImageView *hotCoreView;
@property (nonatomic, strong) CAGradientLayer *specularRimLayer;
@property (nonatomic, strong) CAShapeLayer *specularMaskLayer;
@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, assign) BOOL isPressed;
@property (nonatomic, assign) CGPoint touchStartPoint;

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title blurRadius:(CGFloat)blurRadius;
- (void)updateLayoutWithFrame:(CGRect)frame;
- (void)handleTouchDownAtPoint:(CGPoint)point;
- (void)handleTouchMovedToPoint:(CGPoint)point;
- (void)handleTouchEnded;
- (void)setShapeCornerRadius:(CGFloat)radius;
- (void)setGlowAlpha:(CGFloat)glowAlpha;
- (void)setLabelAlpha:(CGFloat)labelAlpha;
- (void)resetToNormalState;

@end

@interface LGLiquidBlockerGesture : UIPanGestureRecognizer <UIGestureRecognizerDelegate>
@end
