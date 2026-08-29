#import <Foundation/Foundation.h>
#import "Home26PrefsRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import <spawn.h>

#if __has_include(<roothide.h>)
#import <roothide.h>
#else
#define jbroot(path) [@"/var/jb" stringByAppendingString:path]
#endif

@implementation Home26PrefsRootListController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Check for SnowBoard
    BOOL hasSnowBoard = NO;
    if (([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/SnowBoard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/Snowboard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/Library/MobileSubstrate/DynamicLibraries/AAASnowBoardStub.dylib"])) {
        hasSnowBoard = YES;
    } else if (([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/SnowBoard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/Snowboard.dylib"] || [[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/AAASnowBoardStub.dylib"])) {
        hasSnowBoard = YES;
    }
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ngkhoi.26home"];
    BOOL hasWarned = [defaults boolForKey:@"HasWarnedAboutSnowBoard"];
    
    if (hasSnowBoard && !hasWarned) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ SnowBoard Detected"
                                                                       message:@"Using SnowBoard (even with themes disabled) can harm performance, drain battery, and cause unexpected visual bugs with 26Home.\n\nFor the absolute best, lag-free experience, it is highly recommended to completely UNINSTALL SnowBoard."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"I Understand" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [defaults setBool:YES forKey:@"HasWarnedAboutSnowBoard"];
            [defaults synchronize];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // hero header view
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 220)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // load tweak icon from bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *iconPath = [bundle pathForResource:@"header_icon@3x" ofType:@"png"];
    UIImage *icon = [UIImage imageWithContentsOfFile:iconPath];

    // icon shadow container
    UIView *shadowContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 86, 86)];
    shadowContainer.center = CGPointMake(headerView.frame.size.width / 2.0, 90);
    shadowContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    shadowContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    shadowContainer.layer.shadowOpacity = 0.25;
    shadowContainer.layer.shadowOffset = CGSizeMake(0, 8);
    shadowContainer.layer.shadowRadius = 14;
    [headerView addSubview:shadowContainer];

    // icon view
    UIImageView *iconView = [[UIImageView alloc] initWithImage:icon];
    iconView.frame = shadowContainer.bounds;
    iconView.layer.cornerRadius = 19; // ~22.4% squircle
    if (@available(iOS 13.0, *)) {
        iconView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    iconView.clipsToBounds = YES;
    [shadowContainer addSubview:iconView];

    // title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 150, headerView.frame.size.width, 36)];
    titleLabel.text = @"26Home";
    titleLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightHeavy];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:titleLabel];

    // subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 186, headerView.frame.size.width, 20)];
    subtitleLabel.text = @"iOS 26 Home screen customization tweak";
    subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor systemGrayColor];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:subtitleLabel];

    // attach header view to table
    UITableView *tableView = [self valueForKey:@"_table"];
    if (!tableView && [self respondsToSelector:@selector(table)]) {
        tableView = [self performSelector:@selector(table)];
    }
    if (tableView) {
        tableView.tableHeaderView = headerView;
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readSpecifierValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"sublabel"] ?: @"";
}

- (void)openDiscord:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://discord.gg/cP9aFXHV9h"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
}

- (void)clearCache:(PSSpecifier *)specifier {
    NSArray *caches = @[
        @"/var/mobile/Library/Caches/ngkhoi.26home.icons",
        @"/var/mobile/Library/Caches/com.apple.IconsCache",
        @"/var/mobile/Library/Caches/com.apple.springboard",
        @"/var/mobile/Library/Caches/26Home_IconCache"
    ];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in caches) {
        [fm removeItemAtPath:path error:nil];
    }
    
    NSArray *userCaches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (userCaches.count > 0) {
        NSString *userIconCache = [userCaches.firstObject stringByAppendingPathComponent:@"ngkhoi.26home.icons"];
        [fm removeItemAtPath:userIconCache error:nil];
    }
    
    // purge sb icon cache & refresh
    notify_post("ngkhoi.26home.clearCache");
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cache Cleared"
                                                                   message:@"The icon cache has been completely cleared. You can respring now to apply."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring Now" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self respring:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)respring:(id)sender {
    pid_t pid;
    const char *args[] = {"killall", "-9", "backboardd", NULL};
    posix_spawn(&pid, jbroot(@"/usr/bin/killall").UTF8String, NULL, NULL, (char *const *)args, NULL);
}

@end
