#import <Preferences/PSViewController.h>
#import <UIKit/UIKit.h>

@interface Home26PackModel : NSObject
@property (nonatomic, copy) NSString *packId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *size;
@property (nonatomic, assign) NSInteger iconCount;
@property (nonatomic, copy) NSString *packDescription;
@property (nonatomic, copy) NSString *previewIconUrl;
@property (nonatomic, copy) NSString *downloadUrl;
@property (nonatomic, strong) NSArray<NSString *> *themes;
@property (nonatomic, strong) UIImage *cachedPreviewIcon;
@property (nonatomic, assign) BOOL isDownloading;
@property (nonatomic, assign) float downloadProgress;
@property (nonatomic, strong) NSURLSessionDownloadTask *activeTask;
@end

@interface Home26IconPacksListController : PSViewController <UITableViewDelegate, UITableViewDataSource, NSURLSessionDownloadDelegate>
- (NSString *)activePackId;
- (BOOL)isPackInstalled:(Home26PackModel *)pack;
- (NSString *)packDirectoryForId:(NSString *)packId;
- (void)applyPack:(Home26PackModel *)pack;
- (void)deletePack:(Home26PackModel *)pack indexPath:(NSIndexPath *)indexPath;
- (void)startDownloadForPack:(Home26PackModel *)pack indexPath:(NSIndexPath *)indexPath;
@end
