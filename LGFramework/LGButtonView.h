#import <UIKit/UIKit.h>
#import "LGAdjustableBlurView.h"
#import "LGLiveBackdropView.h"

@interface LGButtonView : UIView

@property (nonatomic, strong) UIView *backgroundContainer;
@property (nonatomic, strong) LGAdjustableBlurView *blurView;
@property (nonatomic, strong) LGLiveBackdropView *lgView;
@property (nonatomic, strong) UIImageView *innerGlowView;
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

@end

@interface LGLiquidBlockerGesture : UIPanGestureRecognizer <UIGestureRecognizerDelegate>
@end
