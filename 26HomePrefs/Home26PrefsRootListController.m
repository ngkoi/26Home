#import <Foundation/Foundation.h>
#import "Home26PrefsRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import <spawn.h>

@implementation Home26PrefsRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create the hero header view
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 220)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    // Retrieve the tweak icon from the preferences bundle
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *iconPath = [bundle pathForResource:@"header_icon@3x" ofType:@"png"];
    UIImage *icon = [UIImage imageWithContentsOfFile:iconPath];

    // Shadow container for the icon
    UIView *shadowContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 86, 86)];
    shadowContainer.center = CGPointMake(headerView.frame.size.width / 2.0, 90);
    shadowContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    shadowContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    shadowContainer.layer.shadowOpacity = 0.25;
    shadowContainer.layer.shadowOffset = CGSizeMake(0, 8);
    shadowContainer.layer.shadowRadius = 14;
    [headerView addSubview:shadowContainer];

    // The actual icon view
    UIImageView *iconView = [[UIImageView alloc] initWithImage:icon];
    iconView.frame = shadowContainer.bounds;
    iconView.layer.cornerRadius = 19; // ~22.37% of 86
    if (@available(iOS 13.0, *)) {
        iconView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    iconView.clipsToBounds = YES;
    [shadowContainer addSubview:iconView];

    // Main Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 150, headerView.frame.size.width, 36)];
    titleLabel.text = @"26Home";
    titleLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightHeavy];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:titleLabel];

    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 186, headerView.frame.size.width, 20)];
    subtitleLabel.text = @"iOS 26 Home screen customization tweak";
    subtitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor systemGrayColor];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [headerView addSubview:subtitleLabel];

    // Assign the custom view to the top of the PSListController table
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
    
    // Tell SpringBoard to dump its memory & disk caches and refresh icons
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
    posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
}

@end
