#import "LGLiveBackdropView.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation LGLiveBackdropView

+ (Class)layerClass {
    return NSClassFromString(@"CABackdropLayer") ?: [CALayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _qualityScale = 0.35;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    [self applyFilters];
    return self;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    self.layer.cornerRadius = cornerRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self applyFilters];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self applyFilters];
}

- (void)applyFilters {
    CALayer *layer = self.layer;
    Class backdropCls = NSClassFromString(@"CABackdropLayer");
    if (!backdropCls || ![layer isKindOfClass:backdropCls]) return;

    @try {
        [layer setValue:@NO forKey:@"layerUsesCoreImageFilters"];
        [layer setValue:@(!self.capturesAppIcon) forKey:@"windowServerAware"];
        
        if (self.capturesAppIcon) {
            [layer setValue:[NSString stringWithFormat:@"dylv.liquidglass.refract.%p", self] forKey:@"groupName"];
        } else {
            if (![layer valueForKey:@"groupName"]) {
                [layer setValue:@"dylv.liquidglass.sharedGroup" forKey:@"groupName"];
            }
        }

        [layer setValue:@"dylv.liquidglass" forKey:@"groupNamespace"];
        [layer setValue:@(self.qualityScale) forKey:@"scale"];

        // Idempotent guard: skip if already configured with this filter to prevent surface allocation loops / OOM
        NSArray *existing = layer.filters;
        if (existing.count == 1) {
            NSString *type = nil;
            @try { type = [existing[0] valueForKey:@"type"]; } @catch (...) {}
            if ([type isEqualToString:kLGFilterType]) return;
        }

        Class filterCls = NSClassFromString(@"CAFilter");
        if (!filterCls) return;

        id glassFilter = ((id (*)(Class, SEL, NSString *))objc_msgSend)(
            filterCls, NSSelectorFromString(@"filterWithType:"), kLGFilterType);
            
        if (glassFilter) {
            layer.filters = @[glassFilter];
        }
    } @catch (NSException *e) {
    }
}

- (void)forceReapplyForRegistrationRace {
    CALayer *layer = self.layer;
    Class backdropCls = NSClassFromString(@"CABackdropLayer");
    if (!backdropCls || ![layer isKindOfClass:backdropCls]) return;
    Class filterCls = NSClassFromString(@"CAFilter");
    if (!filterCls) return;
    @try {
        id glassFilter = ((id (*)(Class, SEL, NSString *))objc_msgSend)(
            filterCls, NSSelectorFromString(@"filterWithType:"), kLGFilterType);
        if (!glassFilter) return;
        layer.filters = @[glassFilter];
    } @catch (NSException *e) {
    }
}

@end
