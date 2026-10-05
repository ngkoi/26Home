#import <UIKit/UIKit.h>

@interface Home26IconItem : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *iconPath;
@property (nonatomic, strong) UIImage *cachedIcon;
@end

@interface Home26IconPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

@property (nonatomic, copy) NSString *packDirectory;
@property (nonatomic, strong) NSArray<NSString *> *themes;
@property (nonatomic, copy) NSString *selectedBundleID;
@property (nonatomic, copy) void (^onSelectApp)(NSString *bundleID, NSString *displayName);

@end
