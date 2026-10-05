#import "Home26AppIconGenListController.h"
#import "Home26AppIconGenDetailController.h"
#import "LGCustomIconGenerator2.h"
#import <notify.h>

@interface Home26AppItem : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, assign) BOOL isCustom;
@end

@implementation Home26AppItem
@end

@interface LSApplicationProxy : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
- (BOOL)isLaunchProhibited;
- (BOOL)isPlaceholder;
- (NSString *)applicationType;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
- (NSArray *)allApplications;
@end

@interface UIImage (PrivateIconGen)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

@interface Home26AppIconGenListController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray<Home26AppItem *> *allApps;
@property (nonatomic, strong) NSArray<Home26AppItem *> *filteredApps;
@property (nonatomic, strong) NSDictionary *overridesDict;

@end

@implementation Home26AppIconGenListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Per-App Specular Config";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    [self loadOverrides];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 60.0;
    [self.view addSubview:self.tableView];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search applications or bundle IDs";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    UIBarButtonItem *resetAllBtn = [[UIBarButtonItem alloc] initWithTitle:@"Reset All" style:UIBarButtonItemStylePlain target:self action:@selector(resetAllAppsTapped)];
    self.navigationItem.rightBarButtonItem = resetAllBtn;

    [self loadInstalledApps];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadOverrides];
    [self updateCustomStatus];
    [self.tableView reloadData];
}

- (void)loadOverrides {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    self.overridesDict = [prefs dictionaryForKey:@"ngkhoi.26home.appIconGenOverrides"] ?: @{};
}

- (void)updateCustomStatus {
    for (Home26AppItem *item in self.allApps) {
        NSDictionary *cfg = self.overridesDict[item.bundleID];
        item.isCustom = [cfg[@"enabled"] boolValue];
    }
}

- (void)loadInstalledApps {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<Home26AppItem *> *appsList = [NSMutableArray array];

        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (workspaceClass) {
            id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
            NSArray *installed = nil;
            if ([workspace respondsToSelector:@selector(allInstalledApplications)]) {
                installed = [workspace performSelector:@selector(allInstalledApplications)];
            } else if ([workspace respondsToSelector:@selector(allApplications)]) {
                installed = [workspace performSelector:@selector(allApplications)];
            }

            for (id proxy in installed) {
                if ([proxy respondsToSelector:@selector(isLaunchProhibited)] && [proxy isLaunchProhibited]) continue;
                if ([proxy respondsToSelector:@selector(isPlaceholder)] && [proxy isPlaceholder]) continue;

                NSString *bundleID = [proxy respondsToSelector:@selector(bundleIdentifier)] ? [proxy bundleIdentifier] : nil;
                NSString *name = [proxy respondsToSelector:@selector(localizedName)] ? [proxy localizedName] : nil;

                if (!bundleID || bundleID.length == 0) continue;
                if (!name || name.length == 0) name = bundleID;

                Home26AppItem *item = [[Home26AppItem alloc] init];
                item.bundleID = bundleID;
                item.name = name;

                NSDictionary *cfg = self.overridesDict[bundleID];
                item.isCustom = [cfg[@"enabled"] boolValue];

                if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
                    item.icon = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:[UIScreen mainScreen].scale];
                }

                [appsList addObject:item];
            }
        }

        [appsList sortUsingComparator:^NSComparisonResult(Home26AppItem *a, Home26AppItem *b) {
            if (a.isCustom != b.isCustom) {
                return a.isCustom ? NSOrderedAscending : NSOrderedDescending;
            }
            return [a.name localizedCaseInsensitiveCompare:b.name];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.allApps = appsList;
            self.filteredApps = appsList;
            [self.tableView reloadData];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (query.length == 0) {
        self.filteredApps = self.allApps;
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@ OR bundleID CONTAINS[cd] %@", query, query];
        self.filteredApps = [self.allApps filteredArrayUsingPredicate:pred];
    }
    [self.tableView reloadData];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredApps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"AppIconGenCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    Home26AppItem *item = self.filteredApps[indexPath.row];
    cell.textLabel.text = item.name;
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = item.bundleID;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = item.icon;
    cell.imageView.layer.cornerRadius = 8.0;
    cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;
    cell.imageView.clipsToBounds = YES;

    if (item.isCustom) {
        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 22)];
        badge.text = @"CUSTOM";
        badge.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
        badge.textColor = [UIColor systemBlueColor];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.12];
        badge.layer.cornerRadius = 11.0;
        badge.clipsToBounds = YES;
        cell.accessoryView = badge;
    } else {
        cell.accessoryView = nil;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Home26AppItem *item = self.filteredApps[indexPath.row];

    Home26AppIconGenDetailController *detailVC = [[Home26AppIconGenDetailController alloc] init];
    detailVC.bundleID = item.bundleID;
    detailVC.appName = item.name;
    detailVC.appIcon = item.icon;

    __weak typeof(self) weakSelf = self;
    detailVC.onConfigChanged = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self loadOverrides];
        [self updateCustomStatus];
        [self.tableView reloadData];
    };

    [self.navigationController pushViewController:detailVC animated:YES];
}

- (void)resetAllAppsTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset All Per-App Configs"
                                                                   message:@"Are you sure you want to remove all custom Specular Highlights configurations for every app and revert to global defaults?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset All" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        [prefs removeObjectForKey:@"ngkhoi.26home.appIconGenOverrides"];
        [prefs synchronize];
        CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.appIconGenOverrides"), NULL, CFSTR("com.ngkhoi.26home"));
        CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));

        [[LGCustomIconGenerator2 sharedGenerator] clearCache];
        [[LGCustomIconGenerator2 sharedGenerator] clearDiskCache];
        notify_post("ngkhoi.26home.clearCache");

        [self loadOverrides];
        [self updateCustomStatus];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
