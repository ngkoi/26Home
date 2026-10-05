#import "Home26ExceptionListController.h"
#import <notify.h>
#import <objc/runtime.h>
#import "../LGDebugger.h"

@interface UIImage (PrivateIcon)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
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

@interface Home26AppModel : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) UIImage *icon;
@end

@implementation Home26AppModel
@end

@interface Home26ExceptionListController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSArray<Home26AppModel *> *allApps;
@property (nonatomic, strong) NSArray<Home26AppModel *> *filteredApps;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *excludedApps;
@end

@implementation Home26ExceptionListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Exception List";

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    NSDictionary *stored = [defaults dictionaryForKey:@"ngkhoi.26home.excludedApps"];
    self.excludedApps = stored ? [stored mutableCopy] : [NSMutableDictionary dictionary];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 56.0;
    [self.view addSubview:self.tableView];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search apps or bundle IDs";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    UIBarButtonItem *resetBtn = [[UIBarButtonItem alloc] initWithTitle:@"Reset All" style:UIBarButtonItemStylePlain target:self action:@selector(resetAll:)];
    self.navigationItem.rightBarButtonItem = resetBtn;

    [self loadInstalledApps];
}

- (void)loadInstalledApps {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<Home26AppModel *> *appsList = [NSMutableArray array];

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
                if ([proxy respondsToSelector:@selector(isPlaceholder)] && [proxy isPlaceholder]) continue;
                if ([proxy respondsToSelector:@selector(isLaunchProhibited)] && [proxy isLaunchProhibited]) continue;

                NSString *bid = [proxy respondsToSelector:@selector(bundleIdentifier)] ? [proxy bundleIdentifier] : nil;
                NSString *name = [proxy respondsToSelector:@selector(localizedName)] ? [proxy localizedName] : nil;

                if (!bid || bid.length == 0) continue;
                if (!name || name.length == 0) name = bid;

                Home26AppModel *model = [[Home26AppModel alloc] init];
                model.bundleID = bid;
                model.name = name;

                UIImage *rawIcon = nil;

                @try {
                    Class lsProxyClass = NSClassFromString(@"LSApplicationProxy");
                    if (lsProxyClass) {
                        id proxy = [lsProxyClass performSelector:@selector(applicationProxyForIdentifier:) withObject:bid];
                        if (proxy && [proxy respondsToSelector:@selector(iconDataForVariant:)]) {

                            for (int variant = 2; variant <= 5; variant++) {
                                id data = [proxy performSelector:@selector(iconDataForVariant:) withObject:@(variant)];
                                if (data && [data isKindOfClass:[NSData class]]) {
                                    rawIcon = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
                                    if (rawIcon) break;
                                }
                            }
                        }
                    }
                } @catch (NSException *e) {}

                if (!rawIcon && [UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
                    rawIcon = [UIImage _applicationIconImageForBundleIdentifier:bid format:0 scale:[UIScreen mainScreen].scale];
                }

                if (rawIcon) {
                    Class genClass = NSClassFromString(@"LGCustomIconGenerator2");
                    if (genClass && [genClass respondsToSelector:@selector(sharedInstance)]) {
                        id gen = [genClass performSelector:@selector(sharedInstance)];
                        if (gen && [gen respondsToSelector:@selector(requestIconImageWithBackgroundForImage:bundleID:)]) {
                            UIImage *styled = [gen performSelector:@selector(requestIconImageWithBackgroundForImage:bundleID:) withObject:rawIcon withObject:bid];
                            if (styled) rawIcon = styled;
                        }
                    }
                }
                model.icon = rawIcon;

                [appsList addObject:model];
            }
        }

        [appsList sortUsingComparator:^NSComparisonResult(Home26AppModel *a, Home26AppModel *b) {
            return [a.name localizedCaseInsensitiveCompare:b.name];
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.allApps = appsList;
            self.filteredApps = appsList;
            [self.tableView reloadData];
        });
    });
}

- (void)resetAll:(id)sender {
    if (self.excludedApps.count == 0) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Exceptions"
                                                                   message:@"Do you want to clear all excluded apps and theme all icons?"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear Exceptions" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self.excludedApps removeAllObjects];
        [self saveExcludedApps];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveExcludedApps {
    Home26Log(@"[User Action] Prefs - Updated excluded apps: %lu apps excluded", (unsigned long)self.excludedApps.count);
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    [defaults setObject:self.excludedApps forKey:@"ngkhoi.26home.excludedApps"];
    [defaults synchronize];

    CFPreferencesSetAppValue(CFSTR("ngkhoi.26home.excludedApps"), (__bridge CFPropertyListRef)self.excludedApps, CFSTR("com.ngkhoi.26home"));
    CFPreferencesAppSynchronize(CFSTR("com.ngkhoi.26home"));

    notify_post("ngkhoi.26home.clearCache");
    notify_post("ngkhoi.26home.UpdateIconStyle");
}

#pragma mark - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text;
    if (!query || query.length == 0) {
        self.filteredApps = self.allApps;
    } else {
        NSPredicate *pred = [NSPredicate predicateWithBlock:^BOOL(Home26AppModel *app, NSDictionary *bindings) {
            return [app.name localizedCaseInsensitiveContainsString:query] ||
                   [app.bundleID localizedCaseInsensitiveContainsString:query];
        }];
        self.filteredApps = [self.allApps filteredArrayUsingPredicate:pred];
    }
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredApps.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Turn the switch ON to exclude the app from 26Home icon theming (the app will keep its original stock appearance).";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"Home26AppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;

        cell.imageView.layer.cornerRadius = 7.0;
        cell.imageView.clipsToBounds = YES;
        if (@available(iOS 13.0, *)) {
            cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;
        }
    }

    Home26AppModel *model = self.filteredApps[indexPath.row];
    cell.textLabel.text = model.name;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];

    cell.detailTextLabel.text = model.bundleID;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    cell.imageView.image = model.icon;

    UISwitch *sw = (UISwitch *)cell.accessoryView;
    sw.tag = indexPath.row;
    BOOL isExcluded = [self.excludedApps[model.bundleID] boolValue];
    sw.on = isExcluded;

    return cell;
}

- (void)switchToggled:(UISwitch *)sw {
    NSInteger index = sw.tag;
    if (index >= 0 && index < self.filteredApps.count) {
        Home26AppModel *model = self.filteredApps[index];
        if (sw.isOn) {
            self.excludedApps[model.bundleID] = @YES;
        } else {
            [self.excludedApps removeObjectForKey:model.bundleID];
        }
        [self saveExcludedApps];
    }
}

@end
