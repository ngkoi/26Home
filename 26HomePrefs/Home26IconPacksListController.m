#import "Home26IconPacksListController.h"
#import "Home26PackDetailViewController.h"
#import "../LGCustomIconGenerator2.h"
#import <notify.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>

#import "Headers.h"

@implementation Home26PackModel
@end

@interface Home26PackCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authorLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIImageView *chevronImageView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, copy) void (^onActionTapped)(void);
@end

@implementation Home26PackCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        self.iconView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 60, 60)];
        self.iconView.layer.cornerRadius = 14.0;
        self.iconView.layer.cornerCurve = kCACornerCurveContinuous;
        self.iconView.clipsToBounds = YES;
        self.iconView.backgroundColor = [UIColor systemGray5Color];
        self.iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.iconView];

        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 12, self.contentView.bounds.size.width - 200, 22)];
        self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:self.titleLabel];

        self.authorLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 34, self.contentView.bounds.size.width - 200, 17)];
        self.authorLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
        self.authorLabel.textColor = [UIColor secondaryLabelColor];
        self.authorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:self.authorLabel];

        self.metaLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 52, self.contentView.bounds.size.width - 110, 16)];
        self.metaLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        self.metaLabel.textColor = [UIColor tertiaryLabelColor];
        self.metaLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:self.metaLabel];

        self.descLabel = [[UILabel alloc] initWithFrame:CGRectMake(86, 70, self.contentView.bounds.size.width - 110, 34)];
        self.descLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        self.descLabel.textColor = [UIColor secondaryLabelColor];
        self.descLabel.numberOfLines = 2;
        self.descLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:self.descLabel];

        self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.actionButton.frame = CGRectMake(self.contentView.bounds.size.width - 105, 14, 76, 30);
        self.actionButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        self.actionButton.layer.cornerRadius = 15;
        self.actionButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [self.actionButton addTarget:self action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.actionButton];

        self.chevronImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.contentView.bounds.size.width - 22, 47, 10, 16)];
        self.chevronImageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        self.chevronImageView.image = [UIImage systemImageNamed:@"chevron.right"];
        self.chevronImageView.tintColor = [UIColor tertiaryLabelColor];
        self.chevronImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.chevronImageView];

        self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressView.frame = CGRectMake(86, 78, self.contentView.bounds.size.width - 110, 4);
        self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.progressView.hidden = YES;
        [self.contentView addSubview:self.progressView];
    }
    return self;
}

- (void)actionButtonTapped {
    if (self.onActionTapped) {
        self.onActionTapped();
    }
}

@end

@interface Home26PriorityCell : UITableViewCell
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UIImageView *packIconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *priorityLabel;
@property (nonatomic, strong) UIButton *upButton;
@property (nonatomic, strong) UIButton *downButton;
@property (nonatomic, copy) void (^onMoveUp)(void);
@property (nonatomic, copy) void (^onMoveDown)(void);
@end

@implementation Home26PriorityCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        self.badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 18, 26, 26)];
        self.badgeLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        self.badgeLabel.textAlignment = NSTextAlignmentCenter;
        self.badgeLabel.layer.cornerRadius = 13;
        self.badgeLabel.clipsToBounds = YES;
        [self.contentView addSubview:self.badgeLabel];

        self.packIconView = [[UIImageView alloc] initWithFrame:CGRectMake(50, 12, 38, 38)];
        self.packIconView.layer.cornerRadius = 9.0;
        self.packIconView.layer.cornerCurve = kCACornerCurveContinuous;
        self.packIconView.clipsToBounds = YES;
        self.packIconView.contentMode = UIViewContentModeScaleAspectFit;
        self.packIconView.backgroundColor = [UIColor systemGray5Color];
        [self.contentView addSubview:self.packIconView];

        CGFloat textLeft = 98.0;
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 11, self.contentView.bounds.size.width - textLeft - 85, 20)];
        self.nameLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
        self.nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:self.nameLabel];

        self.priorityLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, 32, self.contentView.bounds.size.width - textLeft - 85, 17)];
        self.priorityLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        self.priorityLabel.textColor = [UIColor secondaryLabelColor];
        self.priorityLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:self.priorityLabel];

        self.upButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.upButton.frame = CGRectMake(self.contentView.bounds.size.width - 76, 16, 30, 30);
        self.upButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [self.upButton setImage:[UIImage systemImageNamed:@"chevron.up.circle.fill"] forState:UIControlStateNormal];
        [self.upButton addTarget:self action:@selector(upTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.upButton];

        self.downButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.downButton.frame = CGRectMake(self.contentView.bounds.size.width - 40, 16, 30, 30);
        self.downButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [self.downButton setImage:[UIImage systemImageNamed:@"chevron.down.circle.fill"] forState:UIControlStateNormal];
        [self.downButton addTarget:self action:@selector(downTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:self.downButton];
    }
    return self;
}

- (void)upTapped {
    if (self.onMoveUp) self.onMoveUp();
}

- (void)downTapped {
    if (self.onMoveDown) self.onMoveDown();
}

@end

@interface Home26IconPacksListController ()
@property (nonatomic, strong) UITableView *packTableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableArray<Home26PackModel *> *packs;
@property (nonatomic, strong) NSURLSession *downloadSession;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, Home26PackModel *> *taskMap;
@end

@implementation Home26IconPacksListController

- (void)viewDidLoad {
    [super viewDidLoad];
    notify_post("ngkhoi.26home.ExportWallpaper");
    self.title = @"Icons Pack Manager";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.packs = [NSMutableArray array];
    self.taskMap = [NSMutableDictionary dictionary];

    [self ensureIconPacksStructure];

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.downloadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];

    self.packTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.packTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.packTableView.dataSource = self;
    self.packTableView.delegate = self;
    [self.view addSubview:self.packTableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(fetchCatalog) forControlEvents:UIControlEventValueChanged];
    self.packTableView.refreshControl = self.refreshControl;

    [self fetchCatalog];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.packTableView setEditing:editing animated:animated];
}

- (NSString *)base26HomeDirectory {
    return jbroot(@"/Library/Application Support/26Home");
}

- (NSString *)iconPacksDirectory {
    return [[self base26HomeDirectory] stringByAppendingPathComponent:@"IconPacks"];
}

- (NSString *)packDirectoryForId:(NSString *)packId {
    return [[self iconPacksDirectory] stringByAppendingPathComponent:packId];
}

- (void)ensureIconPacksStructure {
    NSString *packsDir = [self iconPacksDirectory];
    [[NSFileManager defaultManager] createDirectoryAtPath:packsDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *legacySolidGlass = [[self base26HomeDirectory] stringByAppendingPathComponent:@"SolidGlass"];
    NSString *newSolidGlass = [self packDirectoryForId:@"SolidGlass"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:legacySolidGlass]) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:legacySolidGlass error:nil];
        if ([attrs[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
            [[NSFileManager defaultManager] removeItemAtPath:legacySolidGlass error:nil];
        } else if (![[NSFileManager defaultManager] fileExistsAtPath:newSolidGlass]) {
            [[NSFileManager defaultManager] moveItemAtPath:legacySolidGlass toPath:newSolidGlass error:nil];
        }
    }

    NSArray *packDirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:packsDir error:nil];
    for (NSString *sub in packDirs) {
        NSString *pDir = [packsDir stringByAppendingPathComponent:sub];
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pDir error:nil];
        for (NSString *item in contents) {
            if ([item hasPrefix:@"."]) continue;
            NSString *itemPath = [pDir stringByAppendingPathComponent:item];
            BOOL isDir = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:itemPath isDirectory:&isDir] && isDir) {
                NSArray *subSub = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:itemPath error:nil];
                if ([subSub containsObject:@"Light"] || [subSub containsObject:@"Dark"] || [subSub containsObject:@"ClearLight"] || [subSub containsObject:@"ClearDark"]) {
                    for (NSString *theme in subSub) {
                        NSString *fromTheme = [itemPath stringByAppendingPathComponent:theme];
                        NSString *toTheme = [pDir stringByAppendingPathComponent:theme];
                        [[NSFileManager defaultManager] removeItemAtPath:toTheme error:nil];
                        [[NSFileManager defaultManager] moveItemAtPath:fromTheme toPath:toTheme error:nil];
                    }
                    [[NSFileManager defaultManager] removeItemAtPath:itemPath error:nil];
                }
            }
        }
    }
}

- (NSString *)activePackId {
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));
    CFPropertyListRef packVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.selectedIconPack"), CFSTR("com.ngkhoi.26home"));
    NSString *selected = nil;
    if (packVal && [(__bridge id)packVal isKindOfClass:[NSString class]]) {
        selected = [(__bridge NSString *)packVal copy];
        CFRelease(packVal);
    }
    if (!selected || selected.length == 0) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        selected = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"];
    }
    if (!selected || selected.length == 0) {
        return @"SolidGlass";
    }
    return selected;
}

- (void)setActivePackId:(NSString *)packId {
    if (!packId || packId.length == 0) packId = @"SolidGlass";
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [prefs setObject:packId forKey:@"ngkhoi.26home.selectedIconPack"];
    [prefs setObject:packId forKey:@"ngkhoi.26home.activePackId"];
    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.selectedIconPack"), (__bridge CFPropertyListRef)packId, CFSTR("com.ngkhoi.26home"));
    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.activePackId"), (__bridge CFPropertyListRef)packId, CFSTR("com.ngkhoi.26home"));
    [prefs synchronize];
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));
}

- (BOOL)isMultiPackFallbackEnabled {
    Boolean exists = false;
    Boolean val = CFPreferencesGetAppBooleanValue(CFSTR("ngkhoi.26home.multiPackFallbackEnabled"), CFSTR("com.ngkhoi.26home"), &exists);
    if (exists) return (BOOL)val;
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    return [prefs boolForKey:@"ngkhoi.26home.multiPackFallbackEnabled"];
}

- (void)setMultiPackFallbackEnabled:(BOOL)enabled {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [prefs setBool:enabled forKey:@"ngkhoi.26home.multiPackFallbackEnabled"];
    [prefs synchronize];
    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.multiPackFallbackEnabled"), enabled ? kCFBooleanTrue : kCFBooleanFalse, CFSTR("com.ngkhoi.26home"));
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));

    [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];
    notify_post("ngkhoi.26home.clearCache");
    notify_post("ngkhoi.26home.UpdateIconStyle");
    [self.packTableView reloadData];
}

- (NSArray<Home26PackModel *> *)allInstalledPackModels {
    NSMutableArray<Home26PackModel *> *result = [NSMutableArray array];
    for (Home26PackModel *p in self.packs) {
        if ([self isPackInstalled:p]) {
            [result addObject:p];
        }
    }

    NSString *packsDir = [self iconPacksDirectory];
    NSArray *subdirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:packsDir error:nil];
    for (NSString *sub in subdirs) {
        if ([sub hasPrefix:@"."]) continue;
        BOOL found = NO;
        for (Home26PackModel *p in result) {
            if ([p.packId isEqualToString:sub]) {
                found = YES;
                break;
            }
        }
        if (!found) {
            Home26PackModel *extra = [[Home26PackModel alloc] init];
            extra.packId = sub;
            extra.name = sub;
            extra.author = @"Local";
            extra.themes = @[@"Light", @"Dark", @"ClearLight", @"ClearDark", @"LightNS", @"DarkNS"];
            if ([self isPackInstalled:extra]) {
                [result addObject:extra];
            }
        }
    }
    return result;
}

- (Home26PackModel *)packModelForId:(NSString *)packId {
    for (Home26PackModel *p in self.packs) {
        if ([p.packId isEqualToString:packId]) return p;
    }
    for (Home26PackModel *p in [self allInstalledPackModels]) {
        if ([p.packId isEqualToString:packId]) return p;
    }
    return nil;
}

- (UIImage *)previewIconForPackId:(NSString *)packId {
    Home26PackModel *model = [self packModelForId:packId];
    if (model && model.cachedPreviewIcon) {
        return model.cachedPreviewIcon;
    }
    NSString *packDir = [self packDirectoryForId:packId];
    NSArray *subdirs = @[@"Light", @"LightNS", @"Dark", @"DarkNS", @"ClearLight", @"ClearDark"];
    for (NSString *sub in subdirs) {
        NSString *themeDir = [packDir stringByAppendingPathComponent:sub];
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:themeDir error:nil];
        for (NSString *file in files) {
            if ([file hasSuffix:@".png"]) {
                UIImage *img = [UIImage imageWithContentsOfFile:[themeDir stringByAppendingPathComponent:file]];
                if (img) return img;
            }
        }
    }
    return nil;
}

- (NSArray<NSString *> *)priorityPacksList {
    NSString *active = [self activePackId];
    NSMutableArray<NSString *> *list = [NSMutableArray array];
    if (active.length > 0) [list addObject:active];

    CFPropertyListRef listVal = CFPreferencesCopyAppValue(CFSTR("ngkhoi.26home.enabledPacksPriority"), CFSTR("com.ngkhoi.26home"));
    NSArray *saved = nil;
    if (listVal && [(__bridge id)listVal isKindOfClass:[NSArray class]]) {
        saved = [(__bridge NSArray *)listVal copy];
        CFRelease(listVal);
    }
    if (!saved) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        saved = [prefs arrayForKey:@"ngkhoi.26home.enabledPacksPriority"];
    }
    if (saved) {
        for (id item in saved) {
            if ([item isKindOfClass:[NSString class]] && ![list containsObject:item]) {
                [list addObject:item];
            }
        }
    }

    NSArray<Home26PackModel *> *installed = [self allInstalledPackModels];
    for (Home26PackModel *p in installed) {
        if (![list containsObject:p.packId]) {
            [list addObject:p.packId];
        }
    }

    NSMutableArray<NSString *> *validInstalled = [NSMutableArray array];
    for (NSString *pid in list) {
        Home26PackModel *model = [self packModelForId:pid];
        if (model && [self isPackInstalled:model]) {
            [validInstalled addObject:pid];
        }
    }
    if (validInstalled.count == 0 && active.length > 0) {
        [validInstalled addObject:active];
    }
    return [validInstalled copy];
}

- (void)savePriorityPacksList:(NSArray<NSString *> *)list {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [prefs setObject:list forKey:@"ngkhoi.26home.enabledPacksPriority"];
    [prefs synchronize];
    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.enabledPacksPriority"), (__bridge CFPropertyListRef)list, CFSTR("com.ngkhoi.26home"));
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));

    [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];
    notify_post("ngkhoi.26home.clearCache");
    notify_post("ngkhoi.26home.UpdateIconStyle");
}

- (void)movePriorityPackFromIndex:(NSInteger)from toIndex:(NSInteger)to {
    NSMutableArray<NSString *> *list = [NSMutableArray arrayWithArray:[self priorityPacksList]];
    if (from < 0 || from >= list.count || to < 0 || to >= list.count) return;

    NSString *moved = list[from];
    [list removeObjectAtIndex:from];
    [list insertObject:moved atIndex:to];

    if (to == 0) {
        [self setActivePackId:moved];
    } else if (from == 0 && list.count > 0) {
        [self setActivePackId:list[0]];
    }

    [self savePriorityPacksList:list];
    [self.packTableView reloadData];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

- (BOOL)shouldShowPrioritySection {
    if (![self isMultiPackFallbackEnabled]) return NO;
    NSArray *installed = [self priorityPacksList];
    return installed.count >= 2;
}

- (NSInteger)fallbackSectionIndex {
    return 0;
}

- (NSInteger)prioritySectionIndex {
    return [self shouldShowPrioritySection] ? 1 : -1;
}

- (NSInteger)catalogSectionIndex {
    return [self shouldShowPrioritySection] ? 2 : 1;
}

- (BOOL)isPackInstalled:(Home26PackModel *)pack {
    if (!pack.packId) return NO;

    NSString *packDir = [self packDirectoryForId:pack.packId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:packDir]) {
        for (NSString *theme in pack.themes) {
            NSString *themePath = [packDir stringByAppendingPathComponent:theme];
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:themePath error:nil];
            if (contents && contents.count > 0) {
                return YES;
            }
        }
    }

    if ([pack.packId isEqualToString:@"SolidGlass"]) {
        NSString *legacyPath = [[self base26HomeDirectory] stringByAppendingPathComponent:@"SolidGlass"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:legacyPath]) {
            for (NSString *theme in pack.themes) {
                NSString *themePath = [legacyPath stringByAppendingPathComponent:theme];
                NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:themePath error:nil];
                if (contents && contents.count > 0) {
                    return YES;
                }
            }
        }
    }

    return NO;
}

- (void)applyPack:(Home26PackModel *)pack {
    [self setActivePackId:pack.packId];

    NSMutableArray<NSString *> *list = [NSMutableArray arrayWithArray:[self priorityPacksList]];
    [list removeObject:pack.packId];
    [list insertObject:pack.packId atIndex:0];
    [self savePriorityPacksList:list];

    [[LGCustomIconGenerator2 sharedGenerator] clearCache];
    [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];

    notify_post("ngkhoi.26home.clearCache");
    notify_post("ngkhoi.26home.UpdateIconStyle");
    [self.packTableView reloadData];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
}

- (void)fetchCatalog {
    [self.refreshControl beginRefreshing];

    NSURL *catalogURL = [NSURL URLWithString:@"https://raw.githubusercontent.com/ngkoi/26Home-Icons/main/index.json"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:catalogURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
            if (error || !data) {
                [self loadLocalCatalog];
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json && [json[@"packs"] isKindOfClass:[NSArray class]]) {
                [self parsePacksArray:json[@"packs"]];
            } else {
                [self loadLocalCatalog];
            }
        });
    }];
    [task resume];
}

- (void)loadLocalCatalog {
    NSDictionary *p1 = @{
        @"id": @"SolidGlass",
        @"name": @"Solid Glass",
        @"author": @"ngkhoi, MacVerse",
        @"version": @"1.0.0",
        @"size": @"26.1 MB",
        @"iconCount": @800,
        @"description": @"Complete official premade icon collection including Light, Dark, Clear, and NS themes.",
        @"previewIcon": @"https://raw.githubusercontent.com/ngkoi/26Home-Icons/main/previews/solidglass.png",
        @"downloadUrl": @"https://raw.githubusercontent.com/ngkoi/26Home-Icons/main/IconPacks/SolidGlass/SolidGlass.tar.gz",
        @"themes": @[@"Light", @"Dark", @"ClearLight", @"ClearDark", @"LightNS", @"DarkNS", @"ClearLightNS", @"ClearDarkNS"]
    };
    NSDictionary *p2 = @{
        @"id": @"SolidGlass27",
        @"name": @"Solid Glass 27",
        @"author": @"MacVerse",
        @"version": @"1.0.0",
        @"size": @"28.1 MB",
        @"iconCount": @864,
        @"description": @"Solid Glass 27 icon collection by MacVerse, featuring Light, Dark, ClearLight, ClearDark, and DarkNS themes.",
        @"previewIcon": @"https://raw.githubusercontent.com/ngkoi/26Home-Icons/main/previews/solidglass27.png",
        @"downloadUrl": @"https://raw.githubusercontent.com/ngkoi/26Home-Icons/main/IconPacks/SolidGlass27/SolidGlass27.tar.gz",
        @"themes": @[@"Light", @"Dark", @"ClearLight", @"ClearDark", @"DarkNS"]
    };
    [self parsePacksArray:@[p1, p2]];
}

- (void)parsePacksArray:(NSArray *)arr {
    [self.packs removeAllObjects];
    for (NSDictionary *dict in arr) {
        Home26PackModel *model = [[Home26PackModel alloc] init];
        model.packId = dict[@"id"];
        model.name = dict[@"name"];
        model.author = dict[@"author"] ?: @"ngkhoi";
        model.version = dict[@"version"] ?: @"1.0.0";
        model.size = dict[@"size"] ?: @"";
        model.iconCount = [dict[@"iconCount"] integerValue];
        model.packDescription = dict[@"description"] ?: @"";
        model.previewIconUrl = dict[@"previewIcon"] ?: @"";
        model.downloadUrl = dict[@"downloadUrl"] ?: @"";
        model.themes = dict[@"themes"] ?: @[];
        [self.packs addObject:model];
    }
    [self.packTableView reloadData];
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self shouldShowPrioritySection] ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == [self fallbackSectionIndex]) {
        return 1;
    } else if (section == [self prioritySectionIndex]) {
        return [self priorityPacksList].count;
    } else {
        return self.packs.count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == [self fallbackSectionIndex]) {
        return 52.0;
    } else if (indexPath.section == [self prioritySectionIndex]) {
        return 62.0;
    } else {
        return 112.0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == [self fallbackSectionIndex]) {
        return @"Multi-Pack Fallback";
    } else if (section == [self prioritySectionIndex]) {
        return @"Pack Priority Order";
    } else {
        return @"Available Online Icon Packs";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == [self fallbackSectionIndex]) {
        return @"When enabled, if an app icon is missing in your active pack, 26Home will search other installed packs in priority order before falling back to dynamic generation.";
    } else if (section == [self prioritySectionIndex]) {
        return @"Higher priority packs take precedence for conflicting icons. Drag rows or use chevrons to adjust priority.";
    } else {
        return @"Icon packs are downloaded from the official ngkoi/26Home-Icons repository and installed directly into 26Home.";
    }
}

- (void)fallbackSwitchToggled:(UISwitch *)sender {
    [self setMultiPackFallbackEnabled:sender.isOn];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == [self fallbackSectionIndex]) {
        static NSString *switchCellId = @"Home26FallbackSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:switchCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
            cell.textLabel.text = @"Enable Multi-Pack Fallback";

            UISwitch *sw = [[UISwitch alloc] init];
            [sw addTarget:self action:@selector(fallbackSwitchToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        }
        UISwitch *sw = (UISwitch *)cell.accessoryView;
        sw.on = [self isMultiPackFallbackEnabled];
        return cell;
    }

    if (indexPath.section == [self prioritySectionIndex]) {
        static NSString *priorityCellId = @"Home26PriorityCell";
        Home26PriorityCell *cell = [tableView dequeueReusableCellWithIdentifier:priorityCellId];
        if (!cell) {
            cell = [[Home26PriorityCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:priorityCellId];
        }

        NSArray<NSString *> *priorityList = [self priorityPacksList];
        NSString *packId = priorityList[indexPath.row];
        Home26PackModel *model = [self packModelForId:packId];

        BOOL isPrimary = (indexPath.row == 0);
        cell.badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)(indexPath.row + 1)];
        if (isPrimary) {
            cell.badgeLabel.backgroundColor = [UIColor systemBlueColor];
            cell.badgeLabel.textColor = [UIColor whiteColor];
            cell.priorityLabel.text = @"Active Pack (Primary)";
            cell.priorityLabel.textColor = [UIColor systemBlueColor];
        } else {
            cell.badgeLabel.backgroundColor = [UIColor systemGray5Color];
            cell.badgeLabel.textColor = [UIColor labelColor];
            cell.priorityLabel.text = [NSString stringWithFormat:@"Fallback Level %ld", (long)(indexPath.row + 1)];
            cell.priorityLabel.textColor = [UIColor secondaryLabelColor];
        }

        cell.nameLabel.text = model.name ?: packId;
        cell.packIconView.image = [self previewIconForPackId:packId];

        cell.upButton.hidden = isPrimary;
        cell.downButton.hidden = (indexPath.row == priorityList.count - 1);

        __weak typeof(self) weakSelf = self;
        cell.onMoveUp = ^{
            [weakSelf movePriorityPackFromIndex:indexPath.row toIndex:indexPath.row - 1];
        };
        cell.onMoveDown = ^{
            [weakSelf movePriorityPackFromIndex:indexPath.row toIndex:indexPath.row + 1];
        };

        return cell;
    }

    static NSString *cellID = @"Home26PackCell";
    Home26PackCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[Home26PackCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }

    Home26PackModel *pack = self.packs[indexPath.row];
    cell.titleLabel.text = pack.name;
    cell.authorLabel.text = [NSString stringWithFormat:@"by %@", pack.author];

    NSMutableArray *metaParts = [NSMutableArray array];
    if (pack.iconCount > 0) [metaParts addObject:[NSString stringWithFormat:@"%ld icons", (long)pack.iconCount]];
    if (pack.size.length > 0) [metaParts addObject:pack.size];
    if (pack.version.length > 0) [metaParts addObject:[NSString stringWithFormat:@"v%@", pack.version]];
    cell.metaLabel.text = [metaParts componentsJoinedByString:@"  •  "];

    cell.descLabel.text = pack.packDescription;

    if (pack.cachedPreviewIcon) {
        cell.iconView.image = pack.cachedPreviewIcon;
    } else if (pack.previewIconUrl.length > 0) {
        cell.iconView.image = nil;
        NSURL *imgURL = [NSURL URLWithString:pack.previewIconUrl];
        __weak typeof(self) weakSelf = self;
        NSURLSessionDataTask *imgTask = [[NSURLSession sharedSession] dataTaskWithURL:imgURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (data && !error) {
                UIImage *img = [UIImage imageWithData:data];
                if (img) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        pack.cachedPreviewIcon = img;
                        NSIndexPath *ip = [NSIndexPath indexPathForRow:indexPath.row inSection:[weakSelf catalogSectionIndex]];
                        Home26PackCell *updateCell = [weakSelf.packTableView cellForRowAtIndexPath:ip];
                        if (updateCell) {
                            updateCell.iconView.image = img;
                        }
                    });
                }
            }
        }];
        [imgTask resume];
    }

    BOOL isInstalled = [self isPackInstalled:pack];
    BOOL isActive = isInstalled && [pack.packId isEqualToString:[self activePackId]];
    cell.chevronImageView.hidden = !isInstalled;

    if (pack.isDownloading) {
        cell.actionButton.hidden = YES;
        cell.progressView.hidden = NO;
        cell.descLabel.hidden = YES;
        cell.progressView.progress = pack.downloadProgress;
    } else {
        cell.progressView.hidden = YES;
        cell.descLabel.hidden = NO;
        cell.actionButton.hidden = NO;

        if (!isInstalled) {
            [cell.actionButton setTitle:@"GET" forState:UIControlStateNormal];
            cell.actionButton.backgroundColor = [UIColor systemBlueColor];
            [cell.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else if (isActive) {
            [cell.actionButton setTitle:@"Enabled ✓" forState:UIControlStateNormal];
            cell.actionButton.backgroundColor = [UIColor systemGreenColor];
            [cell.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            [cell.actionButton setTitle:@"Apply" forState:UIControlStateNormal];
            cell.actionButton.backgroundColor = [UIColor systemGray5Color];
            [cell.actionButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        }
    }

    __weak typeof(self) weakSelf = self;
    cell.onActionTapped = ^{
        [weakSelf handlePackAction:pack indexPath:indexPath];
    };

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == [self fallbackSectionIndex]) {
        return;
    }

    if (indexPath.section == [self prioritySectionIndex]) {
        NSArray<NSString *> *priorityList = [self priorityPacksList];
        if (indexPath.row >= priorityList.count) return;
        NSString *packId = priorityList[indexPath.row];
        Home26PackModel *pack = [self packModelForId:packId];
        if (!pack) return;

        Home26PackDetailViewController *detailVC = [[Home26PackDetailViewController alloc] init];
        detailVC.pack = pack;
        detailVC.packDirectory = [self packDirectoryForId:pack.packId];

        __weak typeof(self) weakSelf = self;
        detailVC.onRequestApply = ^(Home26PackModel *p) {
            [weakSelf applyPack:p];
        };
        detailVC.onRequestDelete = ^(Home26PackModel *p) {
            [weakSelf deletePack:p indexPath:indexPath];
        };
        detailVC.onPackStateChanged = ^{
            [weakSelf.packTableView reloadData];
        };

        [self.navigationController pushViewController:detailVC animated:YES];
        return;
    }

    Home26PackModel *pack = self.packs[indexPath.row];
    BOOL isInstalled = [self isPackInstalled:pack];
    if (!isInstalled) {
        [self handlePackAction:pack indexPath:indexPath];
        return;
    }

    Home26PackDetailViewController *detailVC = [[Home26PackDetailViewController alloc] init];
    detailVC.pack = pack;
    detailVC.packDirectory = [self packDirectoryForId:pack.packId];

    __weak typeof(self) weakSelf = self;
    detailVC.onRequestDownload = ^(Home26PackModel *p) {
        NSUInteger row = [weakSelf.packs indexOfObject:p];
        if (row != NSNotFound) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:[weakSelf catalogSectionIndex]];
            [weakSelf startDownloadForPack:p indexPath:ip];
        }
    };
    detailVC.onRequestApply = ^(Home26PackModel *p) {
        [weakSelf applyPack:p];
    };
    detailVC.onRequestDelete = ^(Home26PackModel *p) {
        NSUInteger row = [weakSelf.packs indexOfObject:p];
        if (row != NSNotFound) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:[weakSelf catalogSectionIndex]];
            [weakSelf deletePack:p indexPath:ip];
        }
    };
    detailVC.onPackStateChanged = ^{
        [weakSelf.packTableView reloadData];
    };

    [self.navigationController pushViewController:detailVC animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == [self prioritySectionIndex];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.section != [self prioritySectionIndex] || destinationIndexPath.section != [self prioritySectionIndex]) {
        [self.packTableView reloadData];
        return;
    }

    NSMutableArray<NSString *> *list = [NSMutableArray arrayWithArray:[self priorityPacksList]];
    if (sourceIndexPath.row >= list.count || destinationIndexPath.row >= list.count) return;

    NSString *movedPackId = list[sourceIndexPath.row];
    [list removeObjectAtIndex:sourceIndexPath.row];
    [list insertObject:movedPackId atIndex:destinationIndexPath.row];

    if (destinationIndexPath.row == 0) {
        [self setActivePackId:movedPackId];
    } else if (sourceIndexPath.row == 0 && list.count > 0) {
        [self setActivePackId:list[0]];
    }

    [self savePriorityPacksList:list];
    [self.packTableView reloadData];
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    NSInteger pSec = [self prioritySectionIndex];
    if (proposedDestinationIndexPath.section != pSec) {
        NSInteger row = (proposedDestinationIndexPath.section < pSec) ? 0 : [tableView numberOfRowsInSection:pSec] - 1;
        return [NSIndexPath indexPathForRow:row inSection:pSec];
    }
    return proposedDestinationIndexPath;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)handlePackAction:(Home26PackModel *)pack indexPath:(NSIndexPath *)indexPath {
    if (pack.isDownloading) return;

    BOOL isInstalled = [self isPackInstalled:pack];
    BOOL isActive = isInstalled && [pack.packId isEqualToString:[self activePackId]];

    if (!isInstalled) {

        [self startDownloadForPack:pack indexPath:indexPath];
    } else if (!isActive) {

        [self applyPack:pack];
    } else {

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:pack.name
                                                                       message:@"This icon pack is currently active and enabled."
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Reload / Re-apply Pack" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self applyPack:pack];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Redownload / Update Pack" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self startDownloadForPack:pack indexPath:indexPath];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Delete Pack" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self deletePack:pack indexPath:indexPath];
        }]];

        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:sheet animated:YES completion:nil];
    }
}

- (void)deletePack:(Home26PackModel *)pack indexPath:(NSIndexPath *)indexPath {
    NSString *packDir = [self packDirectoryForId:pack.packId];
    [[NSFileManager defaultManager] removeItemAtPath:packDir error:nil];

    NSMutableArray<NSString *> *list = [NSMutableArray arrayWithArray:[self priorityPacksList]];
    [list removeObject:pack.packId];
    [self savePriorityPacksList:list];

    if ([pack.packId isEqualToString:[self activePackId]]) {
        NSString *fallbackPackId = @"SolidGlass";
        if (list.count > 0) {
            fallbackPackId = list[0];
        }
        [self setActivePackId:fallbackPackId];
    }

    [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];
    notify_post("ngkhoi.26home.clearCache");
    notify_post("ngkhoi.26home.UpdateIconStyle");
    [self.packTableView reloadData];
}

- (Home26PackModel *)packForDownloadTask:(NSURLSessionTask *)task {
    if (!task) return nil;
    Home26PackModel *pack = self.taskMap[@(task.taskIdentifier)];
    if (pack) return pack;
    for (Home26PackModel *p in self.packs) {
        if (p.activeTask == task || p.activeTask.taskIdentifier == task.taskIdentifier) {
            return p;
        }
    }
    return nil;
}

- (void)startDownloadForPack:(Home26PackModel *)pack indexPath:(NSIndexPath *)indexPath {
    if (pack.downloadUrl.length == 0) return;

    pack.isDownloading = YES;
    pack.downloadProgress = 0.0;
    if (indexPath) {
        [self.packTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        NSUInteger row = [self.packs indexOfObject:pack];
        if (row != NSNotFound) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:[self catalogSectionIndex]];
            [self.packTableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }
    }

    NSURL *url = [NSURL URLWithString:pack.downloadUrl];
    NSURLSessionDownloadTask *task = [self.downloadSession downloadTaskWithURL:url];
    self.taskMap[@(task.taskIdentifier)] = pack;
    pack.activeTask = task;
    [task resume];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    Home26PackModel *pack = [self packForDownloadTask:downloadTask];
    if (!pack) return;

    if (totalBytesExpectedToWrite > 0) {
        pack.downloadProgress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    } else {
        float estimatedTotal = 25.0 * 1024.0 * 1024.0;
        pack.downloadProgress = fminf(0.95f, (float)totalBytesWritten / estimatedTotal);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger row = [self.packs indexOfObject:pack];
        if (row != NSNotFound) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:[self catalogSectionIndex]];
            Home26PackCell *cell = [self.packTableView cellForRowAtIndexPath:ip];
            if (cell) {
                cell.actionButton.hidden = YES;
                cell.progressView.hidden = NO;
                cell.descLabel.hidden = YES;
                cell.progressView.progress = pack.downloadProgress;
                if (totalBytesExpectedToWrite > 0) {
                    cell.metaLabel.text = [NSString stringWithFormat:@"Downloading... %.0f%% (%.1f / %.1f MB)",
                                           pack.downloadProgress * 100.0,
                                           (float)totalBytesWritten / (1024.0 * 1024.0),
                                           (float)totalBytesExpectedToWrite / (1024.0 * 1024.0)];
                } else {
                    cell.metaLabel.text = [NSString stringWithFormat:@"Downloading... (%.1f MB)",
                                           (float)totalBytesWritten / (1024.0 * 1024.0)];
                }
            }
        }

        for (UIViewController *vc in self.navigationController.viewControllers) {
            if ([vc isKindOfClass:[Home26PackDetailViewController class]]) {
                Home26PackDetailViewController *detailVC = (Home26PackDetailViewController *)vc;
                if ([detailVC.pack.packId isEqualToString:pack.packId]) {
                    [detailVC updateDownloadProgress:pack.downloadProgress];
                }
            }
        }
    });
}

static BOOL ExtractTarGz(NSString *archivePath, NSString *destinationPath, NSString **outError) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:archivePath]) {
        if (outError) *outError = @"Downloaded archive file not found on disk.";
        return NO;
    }

    [[NSFileManager defaultManager] createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray *candidateTars = @[
        jbroot(@"/usr/bin/tar"),
        jbroot(@"/bin/tar"),
        jbroot(@"/usr/bin/bsdtar"),
        jbroot(@"/bin/bsdtar"),
        jbroot(@"/usr/local/bin/tar"),
        @"/var/jb/usr/bin/tar",
        @"/var/jb/bin/tar",
        @"/var/jb/usr/bin/bsdtar",
        @"/var/jb/bin/bsdtar",
        @"/usr/local/bin/tar",
        @"/usr/bin/tar",
        @"/bin/tar"
    ];

    NSString *tarPath = nil;
    for (NSString *cand in candidateTars) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:cand]) {
            tarPath = cand;
            break;
        }
    }

    NSString *pathEnv = [NSString stringWithFormat:@"PATH=%@:%@:%@:%@:%@:%@:%@:%@",
        jbroot(@"/usr/bin"),
        jbroot(@"/bin"),
        jbroot(@"/usr/local/bin"),
        @"/var/jb/usr/bin",
        @"/var/jb/bin",
        @"/usr/local/bin",
        @"/usr/bin",
        @"/bin"
    ];

    char *const envp[] = {
        (char *)[pathEnv UTF8String],
        "TMPDIR=/tmp",
        NULL
    };

    int status = -1;
    pid_t pid = 0;

    if (tarPath) {
        const char *argv[] = {
            [tarPath UTF8String],
            "-xzf",
            [archivePath UTF8String],
            "-C",
            [destinationPath UTF8String],
            NULL
        };

        int spawnRes = posix_spawn(&pid, [tarPath UTF8String], NULL, NULL, (char *const *)argv, envp);
        if (spawnRes == 0) {
            waitpid(pid, &status, 0);
        }
    }

    if (status != 0) {
        NSString *shPath = jbroot(@"/bin/sh");
        if (![[NSFileManager defaultManager] fileExistsAtPath:shPath]) {
            shPath = @"/var/jb/bin/sh";
            if (![[NSFileManager defaultManager] fileExistsAtPath:shPath]) {
                shPath = @"/bin/sh";
            }
        }

        NSString *cmd = [NSString stringWithFormat:@"tar -xzf \"%@\" -C \"%@\" || bsdtar -xzf \"%@\" -C \"%@\"", archivePath, destinationPath, archivePath, destinationPath];
        const char *shArgv[] = {
            [shPath UTF8String],
            "-c",
            [cmd UTF8String],
            NULL
        };

        int spawnRes = posix_spawn(&pid, [shPath UTF8String], NULL, NULL, (char *const *)shArgv, envp);
        if (spawnRes == 0) {
            waitpid(pid, &status, 0);
        }
    }

    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:destinationPath error:nil];
    if (contents.count > 0) {
        return YES;
    }

    if (outError) {
        *outError = [NSString stringWithFormat:@"Extraction failed (exit code: %d). Ensure 'tar' is installed on your jailbreak.", status];
    }
    return NO;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    Home26PackModel *pack = [self packForDownloadTask:downloadTask];
    if (!pack) return;

    [self.taskMap removeObjectForKey:@(downloadTask.taskIdentifier)];
    pack.isDownloading = NO;
    pack.downloadProgress = 1.0;

    NSString *tempTarPath = [NSString stringWithFormat:@"/tmp/pack_download_%@.tar.gz", pack.packId];
    [[NSFileManager defaultManager] removeItemAtPath:tempTarPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:location.path toPath:tempTarPath error:nil];

    NSString *packDir = [self packDirectoryForId:pack.packId];
    NSString *tempExtractDir = [NSString stringWithFormat:@"/tmp/pack_extract_%@", pack.packId];
    [[NSFileManager defaultManager] removeItemAtPath:tempExtractDir error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:tempExtractDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *extractErr = nil;
    BOOL extractOk = ExtractTarGz(tempTarPath, tempExtractDir, &extractErr);
    if (!extractOk) {
        [[NSFileManager defaultManager] removeItemAtPath:tempTarPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:tempExtractDir error:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.packTableView reloadData];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Extraction Error"
                                                                           message:extractErr ?: @"Failed to unpack icon pack archive."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
        return;
    }

    NSDictionary *dirAttrs = @{ NSFilePosixPermissions: @0777 };
    NSString *baseDir = [self base26HomeDirectory];
    NSString *packsDir = [self iconPacksDirectory];
    [[NSFileManager defaultManager] createDirectoryAtPath:baseDir withIntermediateDirectories:YES attributes:dirAttrs error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:packsDir withIntermediateDirectories:YES attributes:dirAttrs error:nil];
    chmod(baseDir.UTF8String, 0777);
    chmod(packsDir.UTF8String, 0777);

    [[NSFileManager defaultManager] removeItemAtPath:packDir error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:packDir withIntermediateDirectories:YES attributes:dirAttrs error:nil];
    chmod(packDir.UTF8String, 0777);

    NSMutableArray *searchQueue = [NSMutableArray arrayWithObject:tempExtractDir];
    BOOL foundThemes = NO;

    while (searchQueue.count > 0) {
        NSString *currDir = searchQueue.firstObject;
        [searchQueue removeObjectAtIndex:0];

        NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:currDir error:nil];
        BOOL hasThemeFolders = NO;
        for (NSString *theme in pack.themes) {
            if ([items containsObject:theme]) {
                hasThemeFolders = YES;
                break;
            }
        }

        if (hasThemeFolders) {
            for (NSString *item in items) {
                if ([item hasPrefix:@"."]) continue;
                NSString *src = [currDir stringByAppendingPathComponent:item];
                NSString *dst = [packDir stringByAppendingPathComponent:item];
                [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];

                NSError *mErr = nil;
                if (![[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:&mErr]) {
                    [[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:nil];
                }
                chmod(dst.UTF8String, 0777);
            }
            foundThemes = YES;
            break;
        } else {
            for (NSString *sub in items) {
                if ([sub hasPrefix:@"."]) continue;
                NSString *subPath = [currDir stringByAppendingPathComponent:sub];
                BOOL isDir = NO;
                if ([[NSFileManager defaultManager] fileExistsAtPath:subPath isDirectory:&isDir] && isDir) {
                    [searchQueue addObject:subPath];
                }
            }
        }
    }

    if (!foundThemes) {
        NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempExtractDir error:nil];
        for (NSString *item in items) {
            if ([item hasPrefix:@"."]) continue;
            NSString *src = [tempExtractDir stringByAppendingPathComponent:item];
            NSString *dst = [packDir stringByAppendingPathComponent:item];
            [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];

            if (![[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil]) {
                [[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:nil];
            }
            chmod(dst.UTF8String, 0777);
        }
    }

    [[NSFileManager defaultManager] removeItemAtPath:tempTarPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:tempExtractDir error:nil];

    BOOL installed = [self isPackInstalled:pack];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.packTableView reloadData];

        for (UIViewController *vc in self.navigationController.viewControllers) {
            if ([vc isKindOfClass:[Home26PackDetailViewController class]]) {
                Home26PackDetailViewController *detailVC = (Home26PackDetailViewController *)vc;
                if ([detailVC.pack.packId isEqualToString:pack.packId]) {
                    [detailVC downloadDidCompleteWithSuccess:installed];
                }
            }
        }

        if (installed) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Icon Pack Downloaded"
                                                                           message:[NSString stringWithFormat:@"%@ has been downloaded and installed. Tap 'Apply' whenever you want to enable it.", pack.name]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Installation Failed"
                                                                           message:@"The icon pack was extracted, but valid icon theme folders could not be verified."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        Home26PackModel *pack = [self packForDownloadTask:task];
        if (pack) {
            [self.taskMap removeObjectForKey:@(task.taskIdentifier)];
            pack.isDownloading = NO;
            pack.downloadProgress = 0.0;
            [self.packTableView reloadData];

            for (UIViewController *vc in self.navigationController.viewControllers) {
                if ([vc isKindOfClass:[Home26PackDetailViewController class]]) {
                    Home26PackDetailViewController *detailVC = (Home26PackDetailViewController *)vc;
                    if ([detailVC.pack.packId isEqualToString:pack.packId]) {
                        [detailVC downloadDidCompleteWithSuccess:NO];
                    }
                }
            }

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Download Failed"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

@end
