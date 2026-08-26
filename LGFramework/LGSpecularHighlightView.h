#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface LGSpecularHighlightView : UIView

/// Corner radius for the continuous specular rim stroke (default matches view or 40.0).
@property (nonatomic, assign) CGFloat cornerRadius;

/// Stroke width for the highlight rim (default 1.5pt).
@property (nonatomic, assign) CGFloat strokeWidth;

/// Top-left highlight opacity (default 0.65).
@property (nonatomic, assign) CGFloat topSpecularOpacity;

/// Bottom-right highlight opacity (default 0.35).
@property (nonatomic, assign) CGFloat bottomSpecularOpacity;

- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)cornerRadius;

@end
