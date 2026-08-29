#import "Headers.h"

@implementation LGAdjustableBlurView

+ (Class)layerClass {
    return NSClassFromString(@"CABackdropLayer") ?: [CALayer class];
}

- (instancetype)initWithFrame:(CGRect)frame blurRadius:(CGFloat)radius {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _blurRadius = radius;
    _qualityScale = 0.35;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;
    [self applyFilters];
    return self;
}

- (void)setQualityScale:(CGFloat)qualityScale {
    _qualityScale = fminf(fmaxf(qualityScale, 0.10), 0.75);
    CALayer *layer = self.layer;
    if (layer) {
        @try {
            [layer setValue:@(_qualityScale) forKey:@"scale"];
        } @catch (NSException *e) {}
    }
}

- (void)setBlurRadius:(CGFloat)blurRadius {
    _blurRadius = blurRadius;
    CALayer *layer = self.layer;
    if (layer) {
        NSArray *existing = layer.filters;
        if (existing.count >= 1) {
            id blurFilter = existing[0];
            @try {
                [blurFilter setValue:@(_blurRadius) forKey:@"inputRadius"];
                layer.filters = @[blurFilter];
                return;
            } @catch (NSException *e) {}
        }
    }
    [self applyFilters];
}

- (void)didMoveToWindow { [super didMoveToWindow]; [self applyFilters]; }
- (void)layoutSubviews  { [super layoutSubviews];  [self applyFilters]; }

- (void)applyFilters {
    CALayer *layer = self.layer;
    Class backdropCls = NSClassFromString(@"CABackdropLayer");
    if (!backdropCls || ![layer isKindOfClass:backdropCls]) return;

    @try {
        [layer setValue:@NO  forKey:@"layerUsesCoreImageFilters"];
        [layer setValue:@(!self.capturesAppIcon) forKey:@"windowServerAware"];
        if (self.capturesAppIcon) {
            [layer setValue:[NSString stringWithFormat:@"dylv.liquidglass.blur.%p", self] forKey:@"groupName"];
        }
        [layer setValue:@(self.qualityScale) forKey:@"scale"];

        // skip if filter set with same radius, avoids oom
        NSArray *existing = layer.filters;
        if (existing.count == 1) {
            NSString *type = nil;
            @try { type = [existing[0] valueForKey:@"type"]; } @catch (...) {}
            if ([type isEqualToString:@"gaussianBlur"]) {
                NSNumber *rad = nil;
                @try { rad = [existing[0] valueForKey:@"inputRadius"]; } @catch (...) {}
                if (rad && fabs(rad.doubleValue - self.blurRadius) < 0.01) {
                    return;
                }
            }
        }

        Class filterCls = NSClassFromString(@"CAFilter");
        if (!filterCls) return;

        id blurFilter = ((id (*)(Class, SEL, NSString *))objc_msgSend)(
            filterCls, NSSelectorFromString(@"filterWithType:"), @"gaussianBlur");
            
        if (blurFilter) {
            [blurFilter setValue:@(self.blurRadius) forKey:@"inputRadius"];
            layer.filters = @[blurFilter];
        }
    } @catch (NSException *e) {
    }
}
@end
