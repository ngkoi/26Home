#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface LGAdjustableBlurView : UIView

/// Dynamic continuous corner radius in points.
@property (nonatomic, assign) CGFloat cornerRadius;

/// Gaussian blur radius in points.
@property (nonatomic, assign) CGFloat blurRadius;

/// Hardware sampling resolution multiplier (default 0.35 for optimal performance).
@property (nonatomic, assign) CGFloat qualityScale;

/// Isolated backdrop group name for capturing parent container contents.
@property (nonatomic, assign) BOOL capturesAppIcon;

/// Initializes the backdrop view with an explicit blur radius.
- (instancetype)initWithFrame:(CGRect)frame blurRadius:(CGFloat)radius;

/// Internal filter application routine (idempotent, safe against duplicate allocations).
- (void)applyFilters;

@end
