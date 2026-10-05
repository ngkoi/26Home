#import <Preferences/PSViewController.h>
#import <UIKit/UIKit.h>

@interface Home26AppIconGenDetailController : PSViewController

@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, strong) UIImage *appIcon;
@property (nonatomic, copy) void (^onConfigChanged)(void);

@end
