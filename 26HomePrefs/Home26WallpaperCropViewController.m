#import "Home26WallpaperCropViewController.h"

@interface Home26WallpaperCropViewController ()

@property (nonatomic, strong) UIView *cropFrameContainer;
@property (nonatomic, strong) UIScrollView *wallpaperScrollView;
@property (nonatomic, strong) UIImageView *wallpaperImageView;
@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, assign) BOOL hasSetInitialOffset;

@end

@implementation Home26WallpaperCropViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"Adjust Wallpaper";

    [self setupNavBar];
    [self setupCropArea];
    [self setupBottomControls];
}

- (void)setupNavBar {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTapped)];

    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    doneItem.tintColor = [UIColor systemBlueColor];
    self.navigationItem.rightBarButtonItem = doneItem;
}

- (void)setupCropArea {

    UILabel *hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 80, self.view.bounds.size.width - 48, 40)];
    hintLabel.text = @"Drag upward or downward to reposition the wallpaper underneath your icons.";
    hintLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightMedium];
    hintLabel.textColor = [UIColor secondaryLabelColor];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.numberOfLines = 2;
    hintLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:hintLabel];

    CGFloat cardHeight = 205.0;
    CGFloat cardWidth = self.view.bounds.size.width - 32.0;
    CGFloat topY = 135.0;

    self.cropFrameContainer = [[UIView alloc] initWithFrame:CGRectMake(16, topY, cardWidth, cardHeight)];
    self.cropFrameContainer.layer.cornerRadius = 22.0;
    self.cropFrameContainer.layer.cornerCurve = kCACornerCurveContinuous;
    self.cropFrameContainer.clipsToBounds = YES;
    self.cropFrameContainer.layer.borderWidth = 2.0;
    self.cropFrameContainer.layer.borderColor = [UIColor systemBlueColor].CGColor;
    self.cropFrameContainer.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.cropFrameContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.cropFrameContainer];

    self.wallpaperScrollView = [[UIScrollView alloc] initWithFrame:self.cropFrameContainer.bounds];
    self.wallpaperScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.wallpaperScrollView.delegate = self;
    self.wallpaperScrollView.bounces = YES;
    self.wallpaperScrollView.alwaysBounceVertical = YES;
    self.wallpaperScrollView.showsVerticalScrollIndicator = NO;
    self.wallpaperScrollView.showsHorizontalScrollIndicator = NO;
    self.wallpaperScrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    [self.cropFrameContainer addSubview:self.wallpaperScrollView];

    CGFloat imgWidth = self.wallpaperImage ? self.wallpaperImage.size.width : 390.0;
    CGFloat imgHeight = self.wallpaperImage ? self.wallpaperImage.size.height : 844.0;
    if (imgWidth <= 0) imgWidth = 390.0;
    if (imgHeight <= 0) imgHeight = 844.0;

    CGFloat scaledHeight = cardWidth * (imgHeight / imgWidth);
    if (scaledHeight < cardHeight) scaledHeight = cardHeight;

    self.wallpaperImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cardWidth, scaledHeight)];
    self.wallpaperImageView.contentMode = UIViewContentModeScaleToFill;
    self.wallpaperImageView.image = self.wallpaperImage;
    [self.wallpaperScrollView addSubview:self.wallpaperImageView];
    self.wallpaperScrollView.contentSize = CGSizeMake(cardWidth, scaledHeight);

    self.dimmingView = [[UIView alloc] initWithFrame:self.cropFrameContainer.bounds];
    self.dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.dimmingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.12];
    self.dimmingView.userInteractionEnabled = NO;
    [self.cropFrameContainer addSubview:self.dimmingView];

    CGFloat iconSize = 68.0;
    CGFloat spacing = (cardWidth - (iconSize * 4)) / 5.0;
    CGFloat iconTopY = 40.0;
    NSArray *icons = @[
        self.lightIcon ?: [UIImage new],
        self.darkIcon ?: [UIImage new],
        self.clearIcon ?: [UIImage new],
        self.tintedIcon ?: [UIImage new]
    ];
    NSArray *labels = @[@"Light", @"Dark", @"Clear", @"Tinted"];

    for (int i = 0; i < 4; i++) {
        CGFloat x = spacing + i * (iconSize + spacing);
        UIView *colView = [[UIView alloc] initWithFrame:CGRectMake(x, iconTopY, iconSize, iconSize + 32)];
        colView.userInteractionEnabled = NO;
        colView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.cropFrameContainer addSubview:colView];

        UIView *iconBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, iconSize, iconSize)];
        iconBox.layer.cornerRadius = 16.0;
        iconBox.layer.cornerCurve = kCACornerCurveContinuous;
        iconBox.clipsToBounds = YES;
        iconBox.userInteractionEnabled = NO;
        [colView addSubview:iconBox];

        UIImageView *iv = [[UIImageView alloc] initWithFrame:iconBox.bounds];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.image = icons[i];
        iv.layer.cornerRadius = 16.0;
        iv.layer.cornerCurve = kCACornerCurveContinuous;
        iv.clipsToBounds = YES;
        iv.userInteractionEnabled = NO;
        [iconBox addSubview:iv];

        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(-8, iconSize + 6, iconSize + 16, 18)];
        titleLbl.text = labels[i];
        titleLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        titleLbl.textColor = [UIColor whiteColor];
        titleLbl.textAlignment = NSTextAlignmentCenter;
        titleLbl.layer.shadowColor = [UIColor blackColor].CGColor;
        titleLbl.layer.shadowOpacity = 0.6;
        titleLbl.layer.shadowOffset = CGSizeMake(0, 1);
        titleLbl.layer.shadowRadius = 2.0;
        titleLbl.userInteractionEnabled = NO;
        [colView addSubview:titleLbl];
    }
}

- (void)setupBottomControls {
    CGFloat topY = 360.0;

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resetButton.frame = CGRectMake((self.view.bounds.size.width - 170) / 2.0, topY, 170, 42);
    resetButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    resetButton.layer.cornerRadius = 21.0;
    resetButton.layer.cornerCurve = kCACornerCurveContinuous;
    resetButton.backgroundColor = [UIColor secondarySystemFillColor];
    [resetButton setTitle:@"  Reset to Center" forState:UIControlStateNormal];
    [resetButton setImage:[UIImage systemImageNamed:@"arrow.counterclockwise"] forState:UIControlStateNormal];
    resetButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [resetButton addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:resetButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    if (!self.hasSetInitialOffset) {
        self.hasSetInitialOffset = YES;
        CGFloat maxScrollY = self.wallpaperScrollView.contentSize.height - self.wallpaperScrollView.bounds.size.height;
        if (maxScrollY > 0) {
            CGFloat targetY = self.initialVerticalOffset;
            if (targetY < 0) targetY = maxScrollY * 0.25;
            if (targetY > maxScrollY) targetY = maxScrollY;
            self.wallpaperScrollView.contentOffset = CGPointMake(0, targetY);
        }
    }
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneTapped {
    CGFloat currentY = self.wallpaperScrollView.contentOffset.y;
    CGFloat maxScrollY = self.wallpaperScrollView.contentSize.height - self.wallpaperScrollView.bounds.size.height;
    if (currentY < 0) currentY = 0;
    if (maxScrollY > 0 && currentY > maxScrollY) currentY = maxScrollY;

    if (self.onCropFinished) {
        self.onCropFinished(currentY);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)resetTapped {
    CGFloat maxScrollY = self.wallpaperScrollView.contentSize.height - self.wallpaperScrollView.bounds.size.height;
    if (maxScrollY > 0) {
        CGFloat centerY = maxScrollY * 0.25;
        [self.wallpaperScrollView setContentOffset:CGPointMake(0, centerY) animated:YES];
    }
}

@end
