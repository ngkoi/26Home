#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define kLGFilterType @"dylv.liquidglass.refraction"

@interface LGLiveBackdropView : UIView

@property (nonatomic, assign) CGFloat cornerRadius;

@property (nonatomic, assign) CGFloat qualityScale;

@property (nonatomic, assign) BOOL capturesAppIcon;

- (void)forceReapplyForRegistrationRace;

- (void)applyFilters;

@end
