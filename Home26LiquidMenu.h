#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Home26LiquidMenuItem : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong, nullable) UIImage *icon;
@property (nonatomic, copy, nullable) void (^action)(void);

+ (instancetype)itemWithTitle:(NSString *)title icon:(nullable UIImage *)icon action:(nullable void (^)(void))action;

@end

@interface Home26LiquidMenu : NSObject

+ (instancetype)sharedMenu;

- (void)presentFromButton:(UIControl *)button items:(NSArray<Home26LiquidMenuItem *> *)items;
- (void)dismiss;
- (void)dismissImmediately;

@property (nonatomic, readonly) BOOL isOpen;

@end

NS_ASSUME_NONNULL_END
