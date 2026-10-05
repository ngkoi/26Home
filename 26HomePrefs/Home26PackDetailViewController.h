#import <UIKit/UIKit.h>
#import "Home26IconPacksListController.h"

@interface Home26PackDetailViewController : UIViewController

@property (nonatomic, strong) Home26PackModel *pack;
@property (nonatomic, copy) NSString *packDirectory;
@property (nonatomic, copy) void (^onPackStateChanged)(void);
@property (nonatomic, copy) void (^onRequestDownload)(Home26PackModel *pack);
@property (nonatomic, copy) void (^onRequestApply)(Home26PackModel *pack);
@property (nonatomic, copy) void (^onRequestDelete)(Home26PackModel *pack);

- (void)updateDownloadProgress:(float)progress;
- (void)downloadDidCompleteWithSuccess:(BOOL)success;

@end
