#import "Home26IconPickerViewController.h"
#import "Headers.h"
#import <objc/runtime.h>

@interface LSApplicationProxy : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)localizedName;
- (BOOL)isLaunchProhibited;
- (BOOL)isPlaceholder;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
- (NSArray *)allApplications;
@end

@interface UIImage (PrivateIconPicker)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

@implementation Home26IconItem
@end

@interface Home26IconPickerViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSMutableArray<Home26IconItem *> *allItems;
@property (nonatomic, strong) NSArray<Home26IconItem *> *filteredItems;
@end

@implementation Home26IconPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Select Preview App";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.allItems = [NSMutableArray array];
    self.filteredItems = @[];

    if (self.navigationController.viewControllers.firstObject == self) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];
    }

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 60.0;
    [self.view addSubview:self.tableView];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search app name or bundle ID";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    [self loadIconsFromPack];
}

- (void)cancelTapped {
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (NSString *)humanizeBundleID:(NSString *)bundleID {
    NSDictionary *knownNames = @{
        @"com.apple.weather": @"Weather",
        @"com.apple.camera": @"Camera",
        @"com.apple.mobilesafari": @"Safari",
        @"com.apple.mobilemail": @"Mail",
        @"com.apple.mobilecal": @"Calendar",
        @"com.apple.mobilenotes": @"Notes",
        @"com.apple.mobiletimer": @"Clock",
        @"com.apple.Music": @"Music",
        @"com.apple.AppStore": @"App Store",
        @"com.apple.Preferences": @"Settings",
        @"com.apple.Photos": @"Photos",
        @"com.apple.Maps": @"Maps",
        @"com.apple.facetime": @"FaceTime",
        @"com.apple.MobileAddressBook": @"Contacts",
        @"com.apple.reminders": @"Reminders",
        @"com.apple.calculator": @"Calculator",
        @"com.apple.Health": @"Health",
        @"com.apple.Passbook": @"Wallet",
        @"com.apple.findmy": @"Find My",
        @"com.apple.podcasts": @"Podcasts",
        @"com.apple.news": @"News",
        @"com.apple.shortcuts": @"Shortcuts",
        @"com.apple.Fitness": @"Fitness",
        @"com.apple.Freeform": @"Freeform",
        @"com.spotify.client": @"Spotify",
        @"com.burbn.instagram": @"Instagram",
        @"com.facebook.Facebook": @"Facebook",
        @"com.facebook.Messenger": @"Messenger",
        @"com.atebits.Tweetie2": @"X / Twitter",
        @"com.google.ios.youtube": @"YouTube",
        @"com.google.chrome.ios": @"Google Chrome",
        @"com.google.Gmail": @"Gmail",
        @"com.google.Maps": @"Google Maps",
        @"com.google.Drive": @"Google Drive",
        @"com.google.Photos": @"Google Photos",
        @"com.zhiliaoapp.musically": @"TikTok",
        @"com.hammerandchisel.discord": @"Discord",
        @"com.netflix.Netflix": @"Netflix",
        @"ph.telegra.Telegraph": @"Telegram",
        @"com.toyopagroup.picaboo": @"Snapchat",
        @"com.reddit.Reddit": @"Reddit",
        @"com.openai.chat": @"ChatGPT"
    };

    if (knownNames[bundleID]) {
        return knownNames[bundleID];
    }

    NSArray *components = [bundleID componentsSeparatedByString:@"."];
    NSString *lastPart = components.lastObject;
    if ([lastPart hasPrefix:@"mobile"]) {
        lastPart = [lastPart substringFromIndex:6];
    }
    if (lastPart.length > 0) {
        NSString *firstChar = [[lastPart substringToIndex:1] uppercaseString];
        NSString *rest = [lastPart substringFromIndex:1];
        return [firstChar stringByAppendingString:rest];
    }
    return bundleID;
}

- (void)loadIconsFromPack {
    [self.allItems removeAllObjects];

    NSMutableSet *seenIDs = [NSMutableSet set];

    NSString *packDir = self.packDirectory;
    if (!packDir || ![[NSFileManager defaultManager] fileExistsAtPath:packDir]) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
        NSString *activeId = [prefs stringForKey:@"ngkhoi.26home.selectedIconPack"] ?: [prefs stringForKey:@"ngkhoi.26home.activePackId"] ?: @"SolidGlass";
        NSString *baseDir = jbroot(@"/Library/Application Support/26Home/IconPacks");
        packDir = [baseDir stringByAppendingPathComponent:activeId];
    }

    if (packDir && [[NSFileManager defaultManager] fileExistsAtPath:packDir]) {

        NSArray *themeCandidates = @[@"Light", @"Dark", @"ClearLight", @"ClearDark", @"DarkNS", @"LightNS", @"ClearDarkNS", @"ClearLightNS"];
        for (NSString *theme in themeCandidates) {
            NSString *themePath = [packDir stringByAppendingPathComponent:theme];
            if ([[NSFileManager defaultManager] fileExistsAtPath:themePath]) {
                NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:themePath error:nil];
                for (NSString *file in files) {
                    if (![file hasSuffix:@".png"]) continue;
                    NSString *bundleID = file;
                    if ([bundleID hasSuffix:@"-large.png"]) {
                        bundleID = [bundleID substringToIndex:bundleID.length - 10];
                    } else if ([bundleID hasSuffix:@".png"]) {
                        bundleID = [bundleID substringToIndex:bundleID.length - 4];
                    }
                    if ([seenIDs containsObject:bundleID]) continue;
                    [seenIDs addObject:bundleID];

                    Home26IconItem *item = [[Home26IconItem alloc] init];
                    item.bundleID = bundleID;
                    item.displayName = [self humanizeBundleID:bundleID];
                    item.iconPath = [themePath stringByAppendingPathComponent:file];
                    [self.allItems addObject:item];
                }
            }
        }
    }

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
            if (!name || name.length == 0) name = [self humanizeBundleID:bundleID];

            if ([seenIDs containsObject:bundleID]) {

                for (Home26IconItem *item in self.allItems) {
                    if ([item.bundleID isEqualToString:bundleID] && name) {
                        item.displayName = name;
                        break;
                    }
                }
                continue;
            }
            [seenIDs addObject:bundleID];

            Home26IconItem *item = [[Home26IconItem alloc] init];
            item.bundleID = bundleID;
            item.displayName = name;
            item.iconPath = nil;
            [self.allItems addObject:item];
        }
    }

    [self.allItems sortUsingComparator:^NSComparisonResult(Home26IconItem *a, Home26IconItem *b) {
        return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
    }];

    self.filteredItems = [self.allItems copy];
    [self.tableView reloadData];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (query.length == 0) {
        self.filteredItems = [self.allItems copy];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName CONTAINS[cd] %@ OR bundleID CONTAINS[cd] %@", query, query];
        self.filteredItems = [self.allItems filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"Home26IconPickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.imageView.layer.cornerRadius = 9.0;
        cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;
        cell.imageView.clipsToBounds = YES;
    }

    Home26IconItem *item = self.filteredItems[indexPath.row];
    cell.textLabel.text = item.displayName;
    cell.textLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = item.bundleID;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

    if (!item.cachedIcon) {
        UIImage *iconImg = nil;
        if (item.iconPath && [[NSFileManager defaultManager] fileExistsAtPath:item.iconPath]) {
            iconImg = [UIImage imageWithContentsOfFile:item.iconPath];
        }
        if (!iconImg && [UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
            iconImg = [UIImage _applicationIconImageForBundleIdentifier:item.bundleID format:2 scale:[UIScreen mainScreen].scale];
        }

        if (iconImg) {
            CGSize size = CGSizeMake(38, 38);
            UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
            [iconImg drawInRect:CGRectMake(0, 0, size.width, size.height)];
            UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            item.cachedIcon = scaled;
        }
    }
    cell.imageView.image = item.cachedIcon;

    if ([item.bundleID isEqualToString:self.selectedBundleID]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    Home26IconItem *item = self.filteredItems[indexPath.row];
    if (self.onSelectApp) {
        self.onSelectApp(item.bundleID, item.displayName);
    }
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
