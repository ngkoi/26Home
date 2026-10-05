#import <UIKit/UIKit.h>

@interface Home26WallpaperCropViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, strong) UIImage *wallpaperImage;
@property (nonatomic, assign) CGFloat initialVerticalOffset;

@property (nonatomic, strong) UIImage *lightIcon;
@property (nonatomic, strong) UIImage *darkIcon;
@property (nonatomic, strong) UIImage *clearIcon;
@property (nonatomic, strong) UIImage *tintedIcon;

@property (nonatomic, copy) void (^onCropFinished)(CGFloat offsetY);

@end
