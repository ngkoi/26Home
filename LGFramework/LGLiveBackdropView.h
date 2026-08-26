#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define kLGFilterType @"dylv.liquidglass.refraction"

@interface LGLiveBackdropView : UIView

/// Dynamic continuous corner radius in points.
@property (nonatomic, assign) CGFloat cornerRadius;

/// Hardware sampling resolution multiplier (default 0.35 for optimal performance).
@property (nonatomic, assign) CGFloat qualityScale;

/// Isolated backdrop group name for capturing parent container contents.
@property (nonatomic, assign) BOOL capturesAppIcon;

/// Re-commits the refraction filter to resolve any render server registration races on launch.
- (void)forceReapplyForRegistrationRace;

/// Internal filter application routine (idempotent, safe against duplicate allocations).
- (void)applyFilters;

@end
