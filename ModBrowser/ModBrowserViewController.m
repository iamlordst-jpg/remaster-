#include <stdlib.h>
#import <CommonCrypto/CommonDigest.h>
#import "ModBrowserViewController.h"
#import "PLProfiles.h"
#import "LauncherPreferences.h"

@interface ModProjectCell : UITableViewCell
@property(nonatomic) UIImageView *modIcon;
@property(nonatomic) UILabel *nameLabel;
@property(nonatomic) UILabel *descriptionLabel;
@property(nonatomic) UILabel *downloadsLabel;
@property(nonatomic) NSString *projectID;
@end

@implementation ModProjectCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.modIcon = [[UIImageView alloc] init];
    self.modIcon.translatesAutoresizingMaskIntoConstraints = NO;
    self.modIcon.contentMode = UIViewContentModeScaleAspectFit;
    self.modIcon.clipsToBounds = YES;
    self.modIcon.layer.cornerRadius = 9;
    self.modIcon.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.nameLabel.numberOfLines = 2;
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.descriptionLabel.textColor = UIColor.secondaryLabelColor;
    self.descriptionLabel.numberOfLines = 2;
    self.downloadsLabel = [[UILabel alloc] init];
    self.downloadsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.downloadsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.downloadsLabel.textColor = UIColor.tertiaryLabelColor;
    UIStackView *labels = [[UIStackView alloc] initWithArrangedSubviews:@[self.nameLabel, self.descriptionLabel, self.downloadsLabel]];
    labels.translatesAutoresizingMaskIntoConstraints = NO;
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 3;
    labels.alignment = UIStackViewAlignmentFill;
    [self.contentView addSubview:self.modIcon];
    [self.contentView addSubview:labels];
    [NSLayoutConstraint activateConstraints:@[
        [self.modIcon.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
        [self.modIcon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.modIcon.widthAnchor constraintEqualToConstant:48],
        [self.modIcon.heightAnchor constraintEqualToConstant:48],
        [labels.leadingAnchor constraintEqualToAnchor:self.modIcon.trailingAnchor constant:12],
        [labels.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        [labels.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [labels.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10]
    ]];
    return self;
}
- (void)prepareForReuse {
    [super prepareForReuse];
    self.modIcon.image = [UIImage systemImageNamed:@"shippingbox"];
    self.projectID = nil;
    self.nameLabel.text = nil;
    self.descriptionLabel.text = nil;
    self.downloadsLabel.text = nil;
}
@end

@interface ModManagerViewController : UITableViewController
@property(nonatomic) NSString *modsDirectory;
@property(nonatomic) NSMutableArray<NSString *> *modFiles;
- (instancetype)initWithDirectory:(NSString *)directory;
@end

@implementation ModManagerViewController
- (instancetype)initWithDirectory:(NSString *)directory {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) { _modsDirectory = directory; _modFiles = [NSMutableArray array]; self.title = @"Manage Mods"; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    [self reloadMods];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)reloadMods {
    NSError *error = nil;
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.modsDirectory error:&error];
    [self.modFiles removeAllObjects];
    if (!error) for (NSString *name in files) {
        NSString *lower = name.lowercaseString;
        if ([lower hasSuffix:@".jar"] || [lower hasSuffix:@".jar.disabled"]) [self.modFiles addObject:name];
    }
    [self.modFiles sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    self.tableView.backgroundView = error ? [self messageLabel:[NSString stringWithFormat:@"Could not read folder:\n%@", error.localizedDescription]] :
        (self.modFiles.count ? nil : [self messageLabel:@"No mods found in this Minecraft directory."]);
    [self.tableView reloadData];
}
- (UIView *)messageLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    label.text = text; label.textAlignment = NSTextAlignmentCenter; label.textColor = UIColor.secondaryLabelColor;
    label.numberOfLines = 0; label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return label;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.modFiles.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"installed-mod"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"installed-mod"];
    NSString *name = self.modFiles[indexPath.row];
    BOOL disabled = [name.lowercaseString hasSuffix:@".jar.disabled"];
    cell.textLabel.text = name;
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = disabled ? @"Disabled — won't load next launch" : @"Enabled";
    cell.detailTextLabel.textColor = disabled ? UIColor.secondaryLabelColor : UIColor.systemGreenColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *name = self.modFiles[indexPath.row];
    BOOL disabled = [name.lowercaseString hasSuffix:@".jar.disabled"];
    UIAlertController *actions = [UIAlertController alertControllerWithTitle:name message:disabled ? @"This mod is disabled." : @"This mod is enabled." preferredStyle:UIAlertControllerStyleActionSheet];
    [actions addAction:[UIAlertAction actionWithTitle:disabled ? @"Enable mod" : @"Disable mod" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newName = disabled ? [name substringToIndex:name.length - @".disabled".length] : [name stringByAppendingString:@".disabled"];
        NSError *error = nil;
        if (![NSFileManager.defaultManager moveItemAtPath:[self.modsDirectory stringByAppendingPathComponent:name] toPath:[self.modsDirectory stringByAppendingPathComponent:newName] error:&error]) {
            [self presentError:error.localizedDescription ?: @"Could not change mod state"];
        } else [self reloadMods];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:@"Delete mod…" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete mod?" message:@"This removes the JAR from this mods folder." preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *confirmAction) {
            NSError *error = nil;
            if (![NSFileManager.defaultManager removeItemAtPath:[self.modsDirectory stringByAppendingPathComponent:name] error:&error]) [self presentError:error.localizedDescription ?: @"Could not delete mod"];
            else [self reloadMods];
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];
    [actions addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (actions.popoverPresentationController) { actions.popoverPresentationController.sourceView = tableView; actions.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath]; }
    [self presentViewController:actions animated:YES completion:nil];
}
- (void)presentError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mod manager" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@interface ModVersionListController : UITableViewController
@property(nonatomic) NSDictionary *project;
@property(nonatomic) NSString *loader;
@property(nonatomic) NSString *minecraftVersion;
@property(nonatomic) NSMutableArray<NSDictionary *> *versions;
@property(nonatomic) BOOL loading;
@property(nonatomic) BOOL hasMore;
@property(nonatomic) NSInteger offset;
@property(nonatomic, copy) void (^versionSelected)(NSDictionary *version);
- (instancetype)initWithProject:(NSDictionary *)project loader:(NSString *)loader minecraftVersion:(NSString *)minecraftVersion;
@end

@implementation ModVersionListController
- (instancetype)initWithProject:(NSDictionary *)project loader:(NSString *)loader minecraftVersion:(NSString *)minecraftVersion {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        _project = project;
        _loader = loader;
        _minecraftVersion = minecraftVersion;
        _versions = [NSMutableArray array];
        _hasMore = YES;
        self.title = @"Mod Versions";
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 86;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    self.tableView.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView.refreshControl addTarget:self action:@selector(refreshVersions) forControlEvents:UIControlEventValueChanged];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self loadNextPage];
}
- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)refreshVersions {
    [self.versions removeAllObjects];
    self.offset = 0;
    self.hasMore = YES;
    self.loading = NO;
    [self loadNextPage];
}
- (void)loadNextPage {
    if (self.loading || !self.hasMore) return;
    self.loading = YES;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [spinner startAnimating]; self.tableView.tableFooterView = spinner;
    NSMutableURLRequest *request = nil;
    if ([self.project[@"source"] isEqual:@"curseforge"]) {
        NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray arrayWithObjects:
            [NSURLQueryItem queryItemWithName:@"pageSize" value:@"50"],
            [NSURLQueryItem queryItemWithName:@"index" value:[NSString stringWithFormat:@"%ld", (long)self.offset]], nil];
        NSDictionary *loaderIDs = @{@"forge":@"1", @"fabric":@"4", @"quilt":@"5", @"neoforge":@"6"};
        if (![self.project[@"project_type"] isKindOfClass:NSString.class] || [self.project[@"project_type"] isEqualToString:@"mod"]) [items addObject:[NSURLQueryItem queryItemWithName:@"modLoaderType" value:loaderIDs[self.loader] ?: @"1"]];
        if (self.minecraftVersion.length) [items addObject:[NSURLQueryItem queryItemWithName:@"gameVersion" value:self.minecraftVersion]];
        NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"https://api.curseforge.com/v1/mods/%@/files", self.project[@"project_id"] ?: @""]];
        components.queryItems = items;
        request = [NSMutableURLRequest requestWithURL:components.URL];
        [request setValue:[NSUserDefaults.standardUserDefaults stringForKey:@"AmethystCurseForgeAPIKey"] ?: @"" forHTTPHeaderField:@"x-api-key"];
    } else {
        NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray arrayWithObjects:
            [NSURLQueryItem queryItemWithName:@"limit" value:@"100"],
            [NSURLQueryItem queryItemWithName:@"offset" value:[NSString stringWithFormat:@"%ld", (long)self.offset]], nil];
        if ([self.project[@"project_type"] isEqualToString:@"mod"]) [items addObject:[NSURLQueryItem queryItemWithName:@"loaders" value:[NSString stringWithFormat:@"[\"%@\"]", self.loader]]];
        if (self.minecraftVersion.length) [items addObject:[NSURLQueryItem queryItemWithName:@"game_versions" value:[NSString stringWithFormat:@"[\"%@\"]", self.minecraftVersion]]];
        NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/version", self.project[@"project_id"] ?: @""]];
        components.queryItems = items;
        request = [NSMutableURLRequest requestWithURL:components.URL];
    }
    request.timeoutInterval = 30;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.2" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.loading = NO; [self.tableView.refreshControl endRefreshing]; self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
            NSArray *page = nil;
            if (!error && [self.project[@"source"] isEqual:@"curseforge"]) {
                NSArray *rawFiles = [json[@"data"] isKindOfClass:NSArray.class] ? json[@"data"] : @[];
                NSMutableArray *normalized = [NSMutableArray array];
                NSDictionary *loaderNames = @{@"1":@"forge", @"4":@"fabric", @"5":@"quilt", @"6":@"neoforge"};
                for (NSDictionary *file in rawFiles) {
                    NSString *loaderName = loaderNames[[file[@"modLoader"] description]] ?: self.loader;
                    NSString *gameVersion = self.minecraftVersion ?: ([file[@"gameVersions"] isKindOfClass:NSArray.class] ? [file[@"gameVersions"] firstObject] : @"");
                    NSString *downloadURL = file[@"downloadUrl"] ?: @"";
                    NSString *filename = file[@"fileName"] ?: @"mod.jar";
                    NSMutableArray *dependencies = [NSMutableArray array];
                    for (NSDictionary *dep in ([file[@"dependencies"] isKindOfClass:NSArray.class] ? file[@"dependencies"] : @[])) {
                        // CurseForge relationType 3 = required dependency.
                        [dependencies addObject:@{@"project_id":[dep[@"modId"] description] ?: @"", @"dependency_type":[dep[@"relationType"] integerValue] == 3 ? @"required" : @"optional"}];
                    }
                    [normalized addObject:@{
                        @"name":file[@"displayName"] ?: filename,
                        @"version_number":[file[@"id"] description] ?: @"",
                        @"game_versions":gameVersion.length ? @[gameVersion] : @[],
                        @"loaders":@[loaderName],
                        @"version_type":[file[@"releaseType"] integerValue] == 1 ? @"release" : ([file[@"releaseType"] integerValue] == 2 ? @"beta" : @"alpha"),
                        @"date_published":file[@"fileDate"] ?: @"",
                        @"dependencies":dependencies,
                        @"files":@[@{@"filename":filename, @"url":downloadURL, @"primary":@YES}]
                    }];
                }
                page = normalized;
                NSInteger total = [json[@"pagination"][@"totalCount"] integerValue];
                self.hasMore = self.offset + rawFiles.count < total;
            } else if (!error && [json isKindOfClass:NSArray.class]) {
                page = (NSArray *)json;
                self.hasMore = page.count == 100;
            } else {
                self.tableView.backgroundView = self.versions.count ? nil : [self messageView:@"Couldn’t load versions. Check your connection and pull down to retry."];
                [self.tableView reloadData];
                return;
            }
            [self.versions addObjectsFromArray:page ?: @[]];
            self.offset += page.count;
            if (![self.project[@"source"] isEqual:@"curseforge"]) self.hasMore = page.count == 100;
            self.tableView.backgroundView = self.versions.count ? nil : [self messageView:@"No versions match this loader and Minecraft version. Change the filters to see more."];
            [self.tableView reloadData];
        });
    }] resume];
}

- (UIView *)messageView:(NSString *)message {
    UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    label.text = message;
    label.textColor = UIColor.secondaryLabelColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return label;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.versions.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"mod-version"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"mod-version"];
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.numberOfLines = 3;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSDictionary *version = self.versions[indexPath.row];
    NSString *name = version[@"name"] ?: version[@"version_number"] ?: @"Version";
    cell.textLabel.text = name;
    NSArray *gameVersions = [version[@"game_versions"] isKindOfClass:NSArray.class] ? version[@"game_versions"] : @[];
    NSString *date = version[@"date_published"] ?: @"";
    if (date.length >= 10) date = [date substringToIndex:10];
    NSString *channel = version[@"version_type"] ?: @"release";
    NSArray *loaders = [version[@"loaders"] isKindOfClass:NSArray.class] ? version[@"loaders"] : @[self.loader];
    NSString *loaderText = [loaders componentsJoinedByString:@", "];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  •  %@\n%@  •  %@",
        [gameVersions componentsJoinedByString:@", "], loaderText, channel.capitalizedString, date];
    if (indexPath.row >= self.versions.count - 3) [self loadNextPage];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.versionSelected) self.versionSelected(self.versions[indexPath.row]);
}
@end


@interface ModProjectDetailsController : UIViewController
@property(nonatomic) NSDictionary *project;
@property(nonatomic) NSString *loader;
@property(nonatomic) NSString *minecraftVersion;
@property(nonatomic, copy) void (^versionsAction)(NSDictionary *project);
@property(nonatomic) UIStackView *contentStack;
@property(nonatomic) UILabel *statusLabel;
@property(nonatomic) UIScrollView *galleryScroll;
@property(nonatomic) NSMutableArray<NSString *> *galleryURLs;
@property(nonatomic) UIBarButtonItem *favoriteButton;
@property(nonatomic) UIBarButtonItem *collectionButton;
- (instancetype)initWithProject:(NSDictionary *)project loader:(NSString *)loader minecraftVersion:(NSString *)minecraftVersion versionsAction:(void (^)(NSDictionary *project))versionsAction;
@end

@implementation ModProjectDetailsController
- (instancetype)initWithProject:(NSDictionary *)project loader:(NSString *)loader minecraftVersion:(NSString *)minecraftVersion versionsAction:(void (^)(NSDictionary *))versionsAction {
    self = [super init];
    if (self) {
        _project = project;
        _loader = loader ?: @"fabric";
        _minecraftVersion = minecraftVersion;
        _versionsAction = [versionsAction copy];
        _galleryURLs = [NSMutableArray array];
        self.title = @"Mod Details";
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:@"STLauncherExperimentalMode"] && [defaults boolForKey:@"STLauncherExperimentalFavoritesCollections"]) {
        self.favoriteButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"star"] style:UIBarButtonItemStylePlain target:self action:@selector(toggleFavorite)];
        self.navigationItem.leftBarButtonItem = self.favoriteButton;
        self.collectionButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"folder.badge.plus"] style:UIBarButtonItemStylePlain target:self action:@selector(manageCollections)];
        self.navigationItem.rightBarButtonItems = @[self.navigationItem.rightBarButtonItem, self.collectionButton];
        [self updateFavoriteButton];
    }
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 16;
    self.contentStack.layoutMargins = UIEdgeInsetsMake(18, 16, 28, 16);
    self.contentStack.layoutMarginsRelativeArrangement = YES;
    [scroll addSubview:self.contentStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [self.contentStack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];
    [self buildHeader];
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Loading full project information…";
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.statusLabel.numberOfLines = 0;
    [self.contentStack addArrangedSubview:self.statusLabel];
    UIButton *versionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    versionsButton.translatesAutoresizingMaskIntoConstraints = NO;
    versionsButton.backgroundColor = UIColor.systemBlueColor;
    [versionsButton setTitle:@"View versions & download" forState:UIControlStateNormal];
    [versionsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    versionsButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    versionsButton.layer.cornerRadius = 12;
    versionsButton.contentEdgeInsets = UIEdgeInsetsMake(14, 18, 14, 18);
    [versionsButton addTarget:self action:@selector(openVersions) forControlEvents:UIControlEventTouchUpInside];
    [self.contentStack addArrangedSubview:versionsButton];
    [NSLayoutConstraint activateConstraints:@[[versionsButton.heightAnchor constraintGreaterThanOrEqualToConstant:50]]];
    [self loadProjectDetails];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSString *)currentProjectID {
    id value = self.project[@"project_id"] ?: self.project[@"id"];
    return [value isKindOfClass:NSString.class] ? value : [value description] ?: @"";
}
- (NSMutableArray<NSDictionary *> *)favoriteProjects {
    NSArray *stored = [NSUserDefaults.standardUserDefaults arrayForKey:@"STLauncherFavoriteProjects"];
    return stored ? [stored mutableCopy] : [NSMutableArray array];
}
- (void)updateFavoriteButton {
    if (!self.favoriteButton) return;
    NSString *projectID = [self currentProjectID];
    BOOL isFavorite = NO;
    for (NSDictionary *item in [self favoriteProjects]) {
        NSString *savedID = [item[@"project_id"] description] ?: [item[@"id"] description] ?: @"";
        if ([savedID isEqualToString:projectID]) { isFavorite = YES; break; }
    }
    self.favoriteButton.image = [UIImage systemImageNamed:isFavorite ? @"star.fill" : @"star"];
    self.favoriteButton.tintColor = isFavorite ? UIColor.systemYellowColor : nil;
}
- (void)toggleFavorite {
    NSString *projectID = [self currentProjectID];
    if (!projectID.length) return;
    NSMutableArray<NSDictionary *> *favorites = [self favoriteProjects];
    NSInteger existing = NSNotFound;
    for (NSUInteger i = 0; i < favorites.count; i++) {
        NSString *savedID = [favorites[i][@"project_id"] description] ?: [favorites[i][@"id"] description] ?: @"";
        if ([savedID isEqualToString:projectID]) { existing = (NSInteger)i; break; }
    }
    if (existing != NSNotFound) [favorites removeObjectAtIndex:(NSUInteger)existing];
    else [favorites addObject:self.project];
    [NSUserDefaults.standardUserDefaults setObject:favorites forKey:@"STLauncherFavoriteProjects"];
    [self updateFavoriteButton];
}
- (void)manageCollections {
    NSString *projectID = [self currentProjectID];
    if (!projectID.length) return;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *collections = [[defaults dictionaryForKey:@"STLauncherCollections"] mutableCopy] ?: [NSMutableDictionary dictionary];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Save to collection" message:self.project[@"title"] ?: @"Choose a collection or create one." preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *name in [[collections allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
        [sheet addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSMutableArray *ids = [collections[name] mutableCopy] ?: [NSMutableArray array];
            if (![ids containsObject:projectID]) [ids addObject:projectID];
            collections[name] = ids;
            [defaults setObject:collections forKey:@"STLauncherCollections"];
            NSMutableArray *favorites = [self favoriteProjects];
            BOOL found = NO;
            for (NSDictionary *item in favorites) if ([[item[@"project_id"] description] isEqualToString:projectID] || [[item[@"id"] description] isEqualToString:projectID]) { found = YES; break; }
            if (!found) { [favorites addObject:self.project]; [defaults setObject:favorites forKey:@"STLauncherFavoriteProjects"]; }
            [self updateFavoriteButton];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"New collection…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIAlertController *input = [UIAlertController alertControllerWithTitle:@"New collection" message:@"Give this collection a name." preferredStyle:UIAlertControllerStyleAlert];
        [input addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"e.g. Performance mods"; field.autocapitalizationType = UITextAutocapitalizationTypeWords; }];
        [input addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [input addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(UIAlertAction *createAction) {
            NSString *name = [input.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!name.length) return;
            NSMutableDictionary *latest = [[defaults dictionaryForKey:@"STLauncherCollections"] mutableCopy] ?: [NSMutableDictionary dictionary];
            NSMutableArray *ids = [latest[name] mutableCopy] ?: [NSMutableArray array];
            if (![ids containsObject:projectID]) [ids addObject:projectID];
            latest[name] = ids;
            [defaults setObject:latest forKey:@"STLauncherCollections"];
            NSMutableArray *favorites = [self favoriteProjects];
            BOOL found = NO;
            for (NSDictionary *item in favorites) if ([[item[@"project_id"] description] isEqualToString:projectID] || [[item[@"id"] description] isEqualToString:projectID]) { found = YES; break; }
            if (!found) { [favorites addObject:self.project]; [defaults setObject:favorites forKey:@"STLauncherFavoriteProjects"]; }
            [self updateFavoriteButton];
        }]];
        [self presentViewController:input animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) sheet.popoverPresentationController.barButtonItem = self.collectionButton;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)openVersions {
    if (self.versionsAction) self.versionsAction(self.project);
}
- (UILabel *)sectionTitle:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    label.textColor = UIColor.labelColor;
    return label;
}
- (UILabel *)bodyLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    label.textColor = UIColor.secondaryLabelColor;
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}
- (void)buildHeader {
    UIStackView *header = [[UIStackView alloc] init];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.spacing = 14;
    header.alignment = UIStackViewAlignmentTop;
    UIImageView *icon = [[UIImageView alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.clipsToBounds = YES;
    icon.layer.cornerRadius = 14;
    icon.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    [NSLayoutConstraint activateConstraints:@[[icon.widthAnchor constraintEqualToConstant:76], [icon.heightAnchor constraintEqualToConstant:76]]];
    NSString *iconURL = self.project[@"icon_url"];
    if (iconURL.length) [self loadImageURL:iconURL completion:^(UIImage *image) { if (image) icon.image = image; }];
    UIStackView *labels = [[UIStackView alloc] init];
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 5;
    UILabel *name = [self bodyLabel:self.project[@"title"] ?: @"Untitled mod"];
    name.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    name.textColor = UIColor.labelColor;
    UILabel *shortDescription = [self bodyLabel:self.project[@"description"] ?: @""];
    UILabel *author = [self bodyLabel:[NSString stringWithFormat:@"by %@", self.project[@"author"] ?: @"Unknown author"]];
    author.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [labels addArrangedSubview:name];
    [labels addArrangedSubview:shortDescription];
    [labels addArrangedSubview:author];
    [header addArrangedSubview:icon];
    [header addArrangedSubview:labels];
    [self.contentStack addArrangedSubview:header];
    [self.contentStack addArrangedSubview:[self sectionTitle:@"Overview"]];
    NSNumber *downloads = self.project[@"downloads"];
    NSNumber *followers = self.project[@"follows"] ?: self.project[@"followers"];
    NSString *stats = [NSString stringWithFormat:@"%@ downloads  •  %@ followers",
        downloads ? [NSNumberFormatter localizedStringFromNumber:downloads numberStyle:NSNumberFormatterDecimalStyle] : @"—",
        followers ? [NSNumberFormatter localizedStringFromNumber:followers numberStyle:NSNumberFormatterDecimalStyle] : @"—"];
    [self.contentStack addArrangedSubview:[self bodyLabel:stats]];
}
- (void)loadProjectDetails {
    NSString *projectID = self.project[@"project_id"] ?: self.project[@"id"] ?: @"";
    if (!projectID.length) { self.statusLabel.text = @"Full project details are unavailable."; return; }
    BOOL curseForge = [self.project[@"source"] isEqual:@"curseforge"];
    NSString *urlString = curseForge
        ? [NSString stringWithFormat:@"https://api.curseforge.com/v1/mods/%@", projectID]
        : [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@", projectID];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.timeoutInterval = 25;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.3" forHTTPHeaderField:@"User-Agent"];
    if (curseForge) [request setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"AmethystCurseForgeAPIKey"] ?: @"" forHTTPHeaderField:@"x-api-key"];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSDictionary *detail = curseForge && [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : json;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (error || ![detail isKindOfClass:NSDictionary.class] || !detail.count) {
                self.statusLabel.text = @"Couldn’t load the full description. You can still view available versions.";
                return;
            }
            if (!curseForge) {
                self.project = [self.project mutableCopy];
                NSMutableDictionary *merged = [self.project mutableCopy];
                [merged addEntriesFromDictionary:detail];
                self.project = merged;
            }
            self.statusLabel.text = nil;
            [self.statusLabel removeFromSuperview];
            [self addGalleryFromProject:detail curseForge:curseForge];
            NSArray *categories = [detail[@"categories"] isKindOfClass:NSArray.class] ? detail[@"categories"] : (detail[@"classifiers"] ?: @[]);
            if ([categories isKindOfClass:NSArray.class] && [categories count]) {
                [self.contentStack addArrangedSubview:[self sectionTitle:@"Categories"]];
                NSMutableArray *categoryNames = [NSMutableArray array];
                for (id item in categories) {
                    if ([item isKindOfClass:NSString.class]) [categoryNames addObject:item];
                    else if ([item isKindOfClass:NSDictionary.class] && item[@"name"]) [categoryNames addObject:item[@"name"]];
                }
                if (categoryNames.count) [self.contentStack addArrangedSubview:[self bodyLabel:[categoryNames componentsJoinedByString:@"  •  "]]];
            }
            NSArray *loaders = [detail[@"loaders"] isKindOfClass:NSArray.class] ? detail[@"loaders"] : @[];
            NSArray *gameVersions = [detail[@"game_versions"] isKindOfClass:NSArray.class] ? detail[@"game_versions"] : @[];
            if (loaders.count || gameVersions.count) {
                [self.contentStack addArrangedSubview:[self sectionTitle:@"Compatibility"]];
                if (loaders.count) [self.contentStack addArrangedSubview:[self bodyLabel:[NSString stringWithFormat:@"Loaders: %@", [loaders componentsJoinedByString:@", "]]]];
                if (gameVersions.count) {
                    NSArray *displayVersions = gameVersions.count > 30 ? [gameVersions subarrayWithRange:NSMakeRange(0, 30)] : gameVersions;
                    NSString *versionText = [displayVersions componentsJoinedByString:@", "];
                    if (gameVersions.count > displayVersions.count) versionText = [versionText stringByAppendingString:@"…"];
                    [self.contentStack addArrangedSubview:[self bodyLabel:[NSString stringWithFormat:@"Minecraft: %@", versionText]]];
                }
            }
            NSString *license = [detail[@"license"] isKindOfClass:NSDictionary.class] ? (detail[@"license"][@"name"] ?: detail[@"license"][@"id"]) : detail[@"license"];
            if ([license isKindOfClass:NSString.class] && license.length) {
                [self.contentStack addArrangedSubview:[self sectionTitle:@"License"]];
                [self.contentStack addArrangedSubview:[self bodyLabel:license]];
            }
            NSString *body = [detail[@"body"] isKindOfClass:NSString.class] ? detail[@"body"] : @"";
            if (body.length) {
                [self.contentStack addArrangedSubview:[self sectionTitle:@"Description"]];
                [self.contentStack addArrangedSubview:[self bodyLabel:[self readableMarkdown:body]]];
            }
            NSMutableArray<NSDictionary *> *links = [NSMutableArray array];
            for (NSArray *pair in @[
                @[@"Source code", @"source_url"], @[@"Wiki", @"wiki_url"],
                @[@"Issue tracker", @"issues_url"], @[@"Discord", @"discord_url"]
            ]) {
                NSString *url = [detail[pair[1]] isKindOfClass:NSString.class] ? detail[pair[1]] : @"";
                if (url.length && [NSURL URLWithString:url]) [links addObject:@{@"title":pair[0], @"url":url}];
            }
            if (links.count) {
                [self.contentStack addArrangedSubview:[self sectionTitle:@"Links"]];
                for (NSDictionary *link in links) {
                    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
                    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
                    [button setTitle:[NSString stringWithFormat:@"↗  %@", link[@"title"]] forState:UIControlStateNormal];
                    button.titleLabel.numberOfLines = 1;
                    button.accessibilityHint = link[@"url"];
                    [button addTarget:self action:@selector(openProjectLink:) forControlEvents:UIControlEventTouchUpInside];
                    [self.contentStack addArrangedSubview:button];
                }
            }
            NSString *updated = detail[@"updated"] ?: detail[@"dateModified"] ?: @"";
            if ([updated isKindOfClass:NSString.class] && updated.length >= 10) {
                [self.contentStack addArrangedSubview:[self bodyLabel:[NSString stringWithFormat:@"Last updated: %@", [updated substringToIndex:10]]]];
            }
        });
    }] resume];
}
- (NSString *)readableMarkdown:(NSString *)markdown {
    NSString *text = [markdown stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    // Strip raw or escaped iframe embeds; native labels cannot render HTML.
    NSArray<NSString *> *embedPatterns = @[
        @"(?is)<iframe\\b[^>]*>.*?</iframe\\s*>",
        @"(?is)<iframe\\b[^>]*>(?:(?!</?iframe\\b).)*$",
        @"(?is)&lt;iframe\\b.*?(?:&lt;/iframe\\s*&gt;|$)"
    ];
    for (NSString *pattern in embedPatterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        text = [regex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"\n"];
    }
    // Remove common HTML tags but retain the text between them.
    NSRegularExpression *html = [NSRegularExpression regularExpressionWithPattern:@"(?is)</?(?:div|span|p|br|hr|h[1-6]|ul|ol|li|a|img|video|source|figure|figcaption|details|summary|table|thead|tbody|tr|td|th|pre|code|blockquote)\\b[^>]*>" options:0 error:nil];
    text = [html stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@" "];
    NSArray<NSString *> *patterns = @[
        @"!\\[([^\\]]*)\\]\\((https?://[^\\s\\)]+)\\)",
        @"\\[([^\\]]+)\\]\\((https?://[^\\s\\)]+)\\)",
        @"\\*\\*(.+?)\\*\\*",
        @"__(.+?)__",
        @"(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)",
        @"(?<!_)_([^_\\n]+)_(?!_)",
        @"`([^`]+)`"
    ];
    NSArray<NSString *> *replacements = @[@"$1", @"$1 — $2", @"$1", @"$1", @"$1", @"$1", @"$1"];
    for (NSUInteger i = 0; i < patterns.count; i++) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:patterns[i] options:NSRegularExpressionDotMatchesLineSeparators error:nil];
        text = [regex stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:replacements[i]];
    }
    // Put Markdown headings on separate lines and make lists easy to scan.
    NSRegularExpression *heading = [NSRegularExpression regularExpressionWithPattern:@"(?m)^\\s{0,3}#{1,6}\\s*(.+?)\\s*#*\\s*$" options:0 error:nil];
    text = [heading stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"\n\n$1\n"];
    NSRegularExpression *list = [NSRegularExpression regularExpressionWithPattern:@"(?m)^\\s*(?:[-*+] |\\d+\\. )" options:0 error:nil];
    text = [list stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"• "];
    NSRegularExpression *quote = [NSRegularExpression regularExpressionWithPattern:@"(?m)^\\s*>\\s?" options:0 error:nil];
    text = [quote stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"“"];
    NSRegularExpression *spaces = [NSRegularExpression regularExpressionWithPattern:@"[ \\t]{2,}" options:0 error:nil];
    text = [spaces stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@" "];
    NSRegularExpression *blankLines = [NSRegularExpression regularExpressionWithPattern:@"\\n[ \\t]*\\n(?:[ \\t]*\\n)+" options:0 error:nil];
    text = [blankLines stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"\n\n"];
    return [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
- (void)openProjectLink:(UIButton *)sender {
    NSURL *url = [NSURL URLWithString:sender.accessibilityHint ?: @""];
    if (url && url.scheme.length) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}
- (void)addGalleryFromProject:(NSDictionary *)detail curseForge:(BOOL)curseForge {
    NSArray *gallery = [detail[@"gallery"] isKindOfClass:NSArray.class] ? detail[@"gallery"] : @[];
    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    for (id item in gallery) {
        NSString *url = [item isKindOfClass:NSString.class] ? item : ([item isKindOfClass:NSDictionary.class] ? (item[@"url"] ?: item[@"thumbnailUrl"]) : nil);
        if (url.length && ![urls containsObject:url]) [urls addObject:url];
    }
    if (curseForge && !urls.count) {
        NSArray *screenshots = [detail[@"screenshots"] isKindOfClass:NSArray.class] ? detail[@"screenshots"] : @[];
        for (NSDictionary *item in screenshots) if ([item[@"url"] isKindOfClass:NSString.class]) [urls addObject:item[@"url"]];
    }
    // Some projects put showcase images directly in their Markdown description
    // instead of uploading them to the gallery. Include those images too.
    NSString *body = [detail[@"body"] isKindOfClass:NSString.class] ? detail[@"body"] : @"";
    NSRegularExpression *imagePattern = [NSRegularExpression regularExpressionWithPattern:@"!\\[[^\\]]*\\]\\((https?://[^\\s\\)]+)\\)" options:0 error:nil];
    for (NSTextCheckingResult *match in [imagePattern matchesInString:body options:0 range:NSMakeRange(0, body.length)]) {
        if (match.numberOfRanges > 1) {
            NSString *url = [body substringWithRange:[match rangeAtIndex:1]];
            if (![urls containsObject:url]) [urls addObject:url];
        }
    }
    self.galleryURLs = urls;
    if (!urls.count) return;
    [self.contentStack addArrangedSubview:[self sectionTitle:@"Screenshots"]];
    UIScrollView *horizontal = [[UIScrollView alloc] init];
    horizontal.translatesAutoresizingMaskIntoConstraints = NO;
    horizontal.showsHorizontalScrollIndicator = YES;
    horizontal.alwaysBounceHorizontal = YES;
    UIStackView *row = [[UIStackView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    [horizontal addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:horizontal.contentLayoutGuide.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:horizontal.contentLayoutGuide.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:horizontal.contentLayoutGuide.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:horizontal.contentLayoutGuide.bottomAnchor],
        [row.heightAnchor constraintEqualToAnchor:horizontal.frameLayoutGuide.heightAnchor]
    ]];
    [NSLayoutConstraint activateConstraints:@[[horizontal.heightAnchor constraintEqualToConstant:190]]];
    [self.contentStack insertArrangedSubview:horizontal atIndex:2];
    for (NSUInteger index = 0; index < urls.count; index++) {
        NSString *url = urls[index];
        UIButton *imageButton = [UIButton buttonWithType:UIButtonTypeCustom];
        imageButton.translatesAutoresizingMaskIntoConstraints = NO;
        imageButton.tag = (NSInteger)index;
        imageButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageButton.clipsToBounds = YES;
        imageButton.layer.cornerRadius = 10;
        imageButton.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        [NSLayoutConstraint activateConstraints:@[[imageButton.widthAnchor constraintEqualToConstant:270], [imageButton.heightAnchor constraintEqualToConstant:170]]];
        [imageButton addTarget:self action:@selector(openGalleryImage:) forControlEvents:UIControlEventTouchUpInside];
        [row addArrangedSubview:imageButton];
        [self loadImageURL:url completion:^(UIImage *image) {
            if (image) [imageButton setImage:image forState:UIControlStateNormal];
            else [imageButton setTitle:@"Image unavailable" forState:UIControlStateNormal];
        }];
    }
}
- (void)loadImageURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    if (!url) { if (completion) completion(nil); return; }
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data && !error ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(image); });
    }] resume];
}
- (void)openGalleryImage:(UIButton *)sender {
    if (sender.tag < 0 || sender.tag >= self.galleryURLs.count) return;
    UIViewController *viewer = [[UIViewController alloc] init];
    viewer.view.backgroundColor = UIColor.blackColor;
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:viewer.view.bounds];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [viewer.view addSubview:imageView];
    [self loadImageURL:self.galleryURLs[sender.tag] completion:^(UIImage *image) { imageView.image = image; }];
    viewer.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:viewer animated:YES completion:nil];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissGalleryViewer)];
    [viewer.view addGestureRecognizer:tap];
}
- (void)dismissGalleryViewer {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end


@interface ModBrowserViewController ()
@property(nonatomic) UISearchController *searchController;
@property(nonatomic) NSMutableArray<NSDictionary *> *projects;
@property(nonatomic) NSString *loader;
@property(nonatomic) NSString *query;
@property(nonatomic) NSString *minecraftVersion;
@property(nonatomic) NSString *sortOrder;
@property(nonatomic) BOOL loading;
@property(nonatomic) NSInteger offset;
@property(nonatomic) NSInteger totalHits;
@property(nonatomic) NSUInteger searchGeneration;
@property(nonatomic) NSURLSessionDataTask *searchTask;
@property(nonatomic) UIActivityIndicatorView *activity;
@property(nonatomic) NSCache<NSString *, UIImage *> *iconCache;
@property(nonatomic) NSMutableDictionary<NSString *, NSURLSessionDataTask *> *iconTasks;
@property(nonatomic) UISegmentedControl *sourceControl;
@property(nonatomic) BOOL curseForgeSource;
@property(nonatomic) NSString *curseForgeAPIKey;
@property(nonatomic) UITextField *customVersionField;
@property(nonatomic) UILabel *browserHeaderTitle;
@property(nonatomic) UILabel *browserHeaderSubtitle;
@property(nonatomic) BOOL showFavoritesOnly;
@property(nonatomic) NSString *selectedCollectionName;
@property(nonatomic) NSString *environmentFilter;
@property(nonatomic) NSString *projectType;
@property(nonatomic) NSTimer *downloadProgressTimer;
@property(nonatomic) UIAlertController *activeDownloadAlert;
@property(nonatomic) NSURLSessionDownloadTask *activeDownloadTask;
@property(nonatomic) NSDate *activeDownloadStartedAt;
@property(nonatomic) NSString *activeDownloadFilename;
@end

@implementation ModBrowserViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"Mod Browser";
        self.loader = @"fabric";
        self.query = @"";
        self.sortOrder = @"relevance";
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        self.environmentFilter = [defaults stringForKey:@"STLauncherSearchEnvironment"] ?: @"any";
        self.projectType = [defaults boolForKey:@"STLauncherExperimentalMode"] ? ([defaults stringForKey:@"STLauncherProjectType"] ?: @"mod") : @"mod";
        self.projects = [NSMutableArray array];
        self.iconCache = [[NSCache alloc] init];
        self.iconCache.countLimit = 250;
        self.iconTasks = [NSMutableDictionary dictionary];
        NSString *profileVersion = PLProfiles.current.selectedProfile[@"lastVersionId"] ?: @"";
        NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"\\d+\\.\\d+(?:\\.\\d+)?" options:0 error:nil];
        NSTextCheckingResult *match = [pattern firstMatchInString:profileVersion options:0 range:NSMakeRange(0, profileVersion.length)];
        if (match) self.minecraftVersion = [profileVersion substringWithRange:match.range];
        NSString *lowerProfile = profileVersion.lowercaseString;
        if ([lowerProfile containsString:@"neoforge"]) self.loader = @"neoforge";
        else if ([lowerProfile containsString:@"forge"]) self.loader = @"forge";
        else if ([lowerProfile containsString:@"quilt"]) self.loader = @"quilt";
        else if ([lowerProfile containsString:@"fabric"]) self.loader = @"fabric";
        if ([defaults boolForKey:@"STLauncherExperimentalMode"]) {
            NSString *savedLoader = [defaults stringForKey:@"STLauncherDefaultLoader"];
            if ([@[@"forge", @"fabric", @"quilt", @"neoforge"] containsObject:savedLoader]) self.loader = savedLoader;
        }
    }
    return self;
}

- (NSString *)imageName { return @"shippingbox"; }
- (BOOL)isSTLauncherMode { return [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalMode"]; }
- (BOOL)isExperimentalUIEnabled { return [self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalUI"]; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self isSTLauncherMode]) {
        self.overrideUserInterfaceStyle = [self isExperimentalUIEnabled] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleUnspecified;
        if ([self isExperimentalUIEnabled]) {
            self.tableView.backgroundColor = [UIColor colorWithRed:0.045 green:0.035 blue:0.075 alpha:1.0];
            self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.09];
            self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.75 green:0.55 blue:1.0 alpha:1.0];
        } else {
            self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
            self.tableView.separatorColor = nil;
            self.navigationController.navigationBar.tintColor = nil;
        }
    }
    [self layoutSourceControl];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshProjects) forControlEvents:UIControlEventValueChanged];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 94;
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search Modrinth mods";
    self.navigationItem.searchController = self.searchController;
    self.curseForgeAPIKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"AmethystCurseForgeAPIKey"] ?: @"";
    self.sourceControl = [[UISegmentedControl alloc] initWithItems:@[@"Modrinth", @"CurseForge"]];
    self.sourceControl.selectedSegmentIndex = 0;
    [self.sourceControl addTarget:self action:@selector(sourceChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"slider.horizontal.3"] style:UIBarButtonItemStylePlain target:self action:@selector(showFilters)];
    self.definesPresentationContext = YES;
    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self layoutSourceControl];
    [self searchForProjectsReset:YES];
}

- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self layoutSourceControl]; }
- (void)layoutSourceControl {
    CGFloat width = self.tableView.bounds.size.width;
    BOOL stMode = [self isSTLauncherMode];
    CGFloat height = stMode ? 116 : 52;
    UIView *header = self.tableView.tableHeaderView;
    if (!header || ![header.subviews containsObject:self.sourceControl] || (stMode && !self.browserHeaderTitle) || (!stMode && self.browserHeaderTitle)) {
        header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        if (stMode) {
            self.browserHeaderTitle = [[UILabel alloc] initWithFrame:CGRectZero];
            self.browserHeaderTitle.text = @"Discover mods";
            self.browserHeaderTitle.font = [UIFont systemFontOfSize:23 weight:UIFontWeightBold];
            self.browserHeaderTitle.textColor = [self isExperimentalUIEnabled] ? UIColor.whiteColor : UIColor.labelColor;
            self.browserHeaderSubtitle = [[UILabel alloc] initWithFrame:CGRectZero];
            self.browserHeaderSubtitle.text = @"Browse projects • filter by loader and Minecraft version";
            self.browserHeaderSubtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
            self.browserHeaderSubtitle.textColor = [self isExperimentalUIEnabled] ? [UIColor colorWithWhite:0.72 alpha:1.0] : UIColor.secondaryLabelColor;
            self.browserHeaderSubtitle.numberOfLines = 1;
            [header addSubview:self.browserHeaderTitle];
            [header addSubview:self.browserHeaderSubtitle];
        } else {
            self.browserHeaderTitle = nil;
            self.browserHeaderSubtitle = nil;
        }
        [header addSubview:self.sourceControl];
        self.tableView.tableHeaderView = header;
    }
    header.frame = CGRectMake(0, 0, width, height);
    if (stMode) {
        self.browserHeaderTitle.frame = CGRectMake(16, 7, MAX(0, width - 32), 29);
        self.browserHeaderSubtitle.frame = CGRectMake(16, 36, MAX(0, width - 32), 19);
        self.sourceControl.frame = CGRectMake(16, 62, MAX(0, width - 32), 36);
        self.sourceControl.selectedSegmentTintColor = [self isExperimentalUIEnabled] ? [UIColor colorWithRed:0.43 green:0.22 blue:0.70 alpha:1.0] : nil;
    } else {
        self.sourceControl.frame = CGRectMake(16, 8, MAX(0, width - 32), 36);
    }
}

- (void)sourceChanged:(UISegmentedControl *)sender {
    self.curseForgeSource = sender.selectedSegmentIndex == 1;
    self.searchController.searchBar.placeholder = self.curseForgeSource ? @"Search CurseForge mods" : @"Search Modrinth mods";
    if (self.curseForgeSource && !self.curseForgeAPIKey.length) [self promptForCurseForgeKeyThenSearch];
    else [self searchForProjectsReset:YES];
}
- (void)promptForCurseForgeKeyThenSearch {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CurseForge API key required" message:@"CurseForge requires an API key. It is stored locally on this device." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"CurseForge API key"; field.secureTextEntry = YES; field.autocorrectionType = UITextAutocorrectionTypeNo; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { self.sourceControl.selectedSegmentIndex = 0; self.curseForgeSource = NO; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (key.length) { self.curseForgeAPIKey = key; [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"AmethystCurseForgeAPIKey"]; [self searchForProjectsReset:YES]; }
        else { self.sourceControl.selectedSegmentIndex = 0; self.curseForgeSource = NO; }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(debouncedSearch) object:nil];
    [self performSelector:@selector(debouncedSearch) withObject:nil afterDelay:0.35];
}
- (void)debouncedSearch {
    self.query = self.searchController.searchBar.text ?: @"";
    [self searchForProjectsReset:YES];
}
- (void)refreshProjects {
    [self.searchTask cancel];
    self.loading = NO;
    [self searchForProjectsReset:YES];
}
- (NSURL *)URLForPath:(NSString *)path queryItems:(NSArray<NSURLQueryItem *> *)queryItems {
    NSURLComponents *components = [NSURLComponents componentsWithString:[@"https://api.modrinth.com/v2" stringByAppendingString:path]];
    components.queryItems = queryItems;
    return components.URL;
}
- (void)searchForProjectsReset:(BOOL)reset {
    if (reset) {
        [self.searchTask cancel]; self.loading = NO; self.searchGeneration += 1;
        self.offset = 0; self.totalHits = NSIntegerMax; [self.projects removeAllObjects];
    } else if (self.loading) return;
    NSUInteger generation = self.searchGeneration;
    self.loading = YES; [self.activity startAnimating]; self.tableView.tableFooterView = self.activity; [self.tableView reloadData];

    if ([self isSTLauncherMode] && self.showFavoritesOnly) {
        NSArray<NSDictionary *> *favorites = [[NSUserDefaults.standardUserDefaults arrayForKey:@"STLauncherFavoriteProjects"] isKindOfClass:NSArray.class]
            ? [NSUserDefaults.standardUserDefaults arrayForKey:@"STLauncherFavoriteProjects"] : @[];
        NSDictionary *allCollections = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"STLauncherCollections"] ?: @{};
        NSArray *collectionIDs = self.selectedCollectionName.length && [allCollections[self.selectedCollectionName] isKindOfClass:NSArray.class]
            ? allCollections[self.selectedCollectionName] : nil;
        NSString *needle = (self.query ?: @"").lowercaseString;
        [self.projects removeAllObjects];
        for (NSDictionary *favorite in favorites) {
            NSString *projectID = [favorite[@"project_id"] description] ?: [favorite[@"id"] description] ?: @"";
            NSString *title = [favorite[@"title"] isKindOfClass:NSString.class] ? favorite[@"title"] : @"";
            NSString *description = [favorite[@"description"] isKindOfClass:NSString.class] ? favorite[@"description"] : @"";
            if (collectionIDs && ![collectionIDs containsObject:projectID]) continue;
            if (needle.length && ![[title lowercaseString] containsString:needle] && ![[description lowercaseString] containsString:needle]) continue;
            [self.projects addObject:favorite];
        }
        self.totalHits = self.projects.count;
        self.offset = self.projects.count;
        self.loading = NO;
        [self.activity stopAnimating];
        self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        self.tableView.backgroundView = self.projects.count ? nil : [self messageView:self.selectedCollectionName.length ? @"This collection is empty. Add mods from a project's details page." : @"No saved favorites match this search yet."];
        [self.tableView reloadData];
        return;
    }

    NSMutableURLRequest *request = nil;
    if (self.curseForgeSource) {
        if (!self.curseForgeAPIKey.length) { self.loading = NO; [self.activity stopAnimating]; [self promptForCurseForgeKeyThenSearch]; return; }
        NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray arrayWithObjects:
            [NSURLQueryItem queryItemWithName:@"gameId" value:@"432"],
            [NSURLQueryItem queryItemWithName:@"classId" value:([self.projectType isEqualToString:@"resourcepack"] ? @"12" : ([self.projectType isEqualToString:@"shader"] ? @"6552" : ([self.projectType isEqualToString:@"datapack"] ? @"6945" : @"6"))) ],
            [NSURLQueryItem queryItemWithName:@"searchFilter" value:self.query ?: @""],
            [NSURLQueryItem queryItemWithName:@"pageSize" value:@"20"],
            [NSURLQueryItem queryItemWithName:@"index" value:[NSString stringWithFormat:@"%ld", (long)self.offset]],
            [NSURLQueryItem queryItemWithName:@"sortField" value:([self.sortOrder isEqualToString:@"downloads"] ? @"6" : ([self.sortOrder isEqualToString:@"updated"] ? @"3" : @"2"))],
            [NSURLQueryItem queryItemWithName:@"sortOrder" value:@"desc"], nil];
        NSDictionary *loaderIDs = @{@"forge":@"1", @"fabric":@"4", @"quilt":@"5", @"neoforge":@"6"};
        if ([self.projectType isEqualToString:@"mod"]) [items addObject:[NSURLQueryItem queryItemWithName:@"modLoaderType" value:loaderIDs[self.loader] ?: @"1"]];
        if (self.minecraftVersion.length) [items addObject:[NSURLQueryItem queryItemWithName:@"gameVersion" value:self.minecraftVersion]];
        NSURLComponents *components = [NSURLComponents componentsWithString:@"https://api.curseforge.com/v1/mods/search"];
        components.queryItems = items;
        request = [NSMutableURLRequest requestWithURL:components.URL];
        [request setValue:self.curseForgeAPIKey forHTTPHeaderField:@"x-api-key"];
    } else {
        NSMutableArray<NSArray<NSString *> *> *facetGroups = [NSMutableArray arrayWithObject:@[[NSString stringWithFormat:@"project_type:%@", self.projectType ?: @"mod"]]];
        if ([self.projectType isEqualToString:@"mod"]) [facetGroups addObject:@[[NSString stringWithFormat:@"categories:%@", self.loader]]];
        if (self.minecraftVersion.length) [facetGroups addObject:@[[NSString stringWithFormat:@"versions:%@", self.minecraftVersion]]];
        if ([self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalAdvancedSearch"]) {
            if ([self.environmentFilter isEqualToString:@"client"]) [facetGroups addObject:@[@"client_side:required"]];
            else if ([self.environmentFilter isEqualToString:@"server"]) [facetGroups addObject:@[@"server_side:required"]];
        }
        NSData *facetData = [NSJSONSerialization dataWithJSONObject:facetGroups options:0 error:nil];
        NSString *facets = [[NSString alloc] initWithData:facetData encoding:NSUTF8StringEncoding] ?: @"[[\"project_type:mod\"],[\"categories:fabric\"]]";
        NSArray *items = @[
            [NSURLQueryItem queryItemWithName:@"query" value:self.query ?: @""],
            [NSURLQueryItem queryItemWithName:@"limit" value:@"20"],
            [NSURLQueryItem queryItemWithName:@"offset" value:[NSString stringWithFormat:@"%ld", (long)self.offset]],
            [NSURLQueryItem queryItemWithName:@"index" value:self.sortOrder ?: @"relevance"],
            [NSURLQueryItem queryItemWithName:@"facets" value:facets]
        ];
        request = [NSMutableURLRequest requestWithURL:[self URLForPath:@"/search" queryItems:items]];
    }
    request.timeoutInterval = 30;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.2" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    self.searchTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.searchGeneration) return;
            self.loading = NO; [self.activity stopAnimating]; [self.refreshControl endRefreshing]; self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
            NSArray *hits = nil;
            NSInteger total = 0;
            if (!error && [json isKindOfClass:NSDictionary.class]) {
                if (self.curseForgeSource) {
                    hits = [json[@"data"] isKindOfClass:NSArray.class] ? json[@"data"] : @[];
                    total = [json[@"pagination"][@"totalCount"] integerValue];
                    NSMutableArray *normalized = [NSMutableArray array];
                    for (NSDictionary *item in hits) {
                        NSDictionary *logo = [item[@"logo"] isKindOfClass:NSDictionary.class] ? item[@"logo"] : @{};
                        [normalized addObject:@{
                            @"project_id":[item[@"id"] description] ?: @"",
                            @"title":item[@"name"] ?: @"Untitled mod",
                            @"description":item[@"summary"] ?: @"",
                            @"downloads":item[@"downloadCount"] ?: @0,
                            @"icon_url":logo[@"url"] ?: @"",
                            @"source":@"curseforge",
                            @"project_type":self.projectType ?: @"mod"
                        }];
                    }
                    hits = normalized;
                } else {
                    hits = [json[@"hits"] isKindOfClass:NSArray.class] ? json[@"hits"] : @[];
                    total = [json[@"total_hits"] integerValue];
                }
            }
            if (error || ![json isKindOfClass:NSDictionary.class]) {
                if (!self.projects.count) self.tableView.backgroundView = [self messageView:self.curseForgeSource ? @"Couldn’t load CurseForge. Check the API key and connection, then pull to retry." : @"Couldn’t load Modrinth. Check your connection and pull to retry."];
            } else {
                [self.projects addObjectsFromArray:hits ?: @[]];
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalPrefetchThumbnails"] ||
                    ([[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalInstantThumbnails"] && [self isSTLauncherMode])) {
                    NSUInteger prefetchCount = MIN(self.projects.count, self.offset + 8);
                    for (NSUInteger i = self.offset; i < prefetchCount; i++) [self prefetchThumbnailForProject:self.projects[i]];
                }
                self.totalHits = total; self.offset = self.projects.count;
                self.tableView.backgroundView = self.projects.count ? nil : [self messageView:@"No mods found. Try another search or change your loader/version filters."];
            }
            [self.tableView reloadData];
        });
    }];
    [self.searchTask resume];
}

- (UIView *)messageView:(NSString *)message {
    UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    label.text = message;
    label.textColor = UIColor.secondaryLabelColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return label;
}
- (void)showFilters {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mod Browser Filters"
        message:[NSString stringWithFormat:@"Loader: %@\nMinecraft version: %@", self.loader.capitalizedString, self.minecraftVersion ?: @"Any"]
        preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *loader in @[@"forge", @"fabric", @"quilt", @"neoforge"]) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@%@", loader.capitalizedString, [loader isEqualToString:self.loader] ? @" ✓" : @""]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                self.loader = loader;
                [self searchForProjectsReset:YES];
            }]];
    }
    if ([self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalAdvancedSearch"]) {
        for (NSString *type in @[@"mod", @"resourcepack", @"shader", @"datapack"]) {
            NSString *label = [type isEqualToString:@"mod"] ? @"Content: Mods" : ([type isEqualToString:@"resourcepack"] ? @"Content: Resource packs" : ([type isEqualToString:@"shader"] ? @"Content: Shaders" : @"Content: Data packs"));
            if ([self.projectType isEqualToString:type]) label = [label stringByAppendingString:@" ✓"];
            [alert addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                self.projectType = type;
                [[NSUserDefaults standardUserDefaults] setObject:type forKey:@"STLauncherProjectType"];
                if (![type isEqualToString:@"mod"]) self.showFavoritesOnly = NO;
                [self searchForProjectsReset:YES];
            }]];
        }
    }
    if ([self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalAdvancedSearch"] && !self.curseForgeSource) {
        for (NSString *environment in @[@"any", @"client", @"server"]) {
            NSString *label = [environment isEqualToString:@"any"] ? @"Environment: Any" : ([environment isEqualToString:@"client"] ? @"Environment: Client-side" : @"Environment: Server-side");
            if ([self.environmentFilter isEqualToString:environment]) label = [label stringByAppendingString:@" ✓"];
            [alert addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                self.environmentFilter = environment;
                [[NSUserDefaults standardUserDefaults] setObject:environment forKey:@"STLauncherSearchEnvironment"];
                [self searchForProjectsReset:YES];
            }]];
        }
    }
    if ([self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalFavoritesCollections"]) {
        [alert addAction:[UIAlertAction actionWithTitle:self.showFavoritesOnly ? @"Browse all mods" : @"Show saved favorites" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.showFavoritesOnly = !self.showFavoritesOnly;
            if (!self.showFavoritesOnly) self.selectedCollectionName = nil;
            [self searchForProjectsReset:YES];
        }]];
        NSDictionary *collections = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"STLauncherCollections"] ?: @{};
        for (NSString *name in [[collections allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
            [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Collection: %@", name] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                self.showFavoritesOnly = YES;
                self.selectedCollectionName = name;
                [self searchForProjectsReset:YES];
            }]];
        }
    }
    for (NSString *sort in @[@"relevance", @"downloads", @"updated"]) {
        NSString *label = [sort isEqualToString:@"relevance"] ? @"Sort: Relevance" : ([sort isEqualToString:@"downloads"] ? @"Sort: Most downloads" : @"Sort: Recently updated");
        if ([self.sortOrder isEqualToString:sort]) label = [label stringByAppendingString:@" ✓"];
        [alert addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.sortOrder = sort;
            [self searchForProjectsReset:YES];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Match selected profile version" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *version = PLProfiles.current.selectedProfile[@"lastVersionId"] ?: @"";
        NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"\\d+\\.\\d+(?:\\.\\d+)?" options:0 error:nil];
        NSTextCheckingResult *match = [pattern firstMatchInString:version options:0 range:NSMakeRange(0, version.length)];
        self.minecraftVersion = match ? [version substringWithRange:match.range] : nil;
        [self searchForProjectsReset:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Choose Minecraft version…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIAlertController *input = [UIAlertController alertControllerWithTitle:@"Minecraft version" message:@"For example, enter 1.20.1 to show only mods supporting that version." preferredStyle:UIAlertControllerStyleAlert];
        [input addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"1.20.1";
            field.text = self.minecraftVersion;
            field.autocapitalizationType = UITextAutocapitalizationTypeNone;
            field.keyboardType = UIKeyboardTypeNumberPad;
            UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 0, 44)];
            UIBarButtonItem *dot = [[UIBarButtonItem alloc] initWithTitle:@"." style:UIBarButtonItemStylePlain target:self action:@selector(insertVersionDot:)];
            UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissVersionKeyboard)];
            toolbar.items = @[space, dot, space, done]; field.inputAccessoryView = toolbar; field.tag = 7312; self.customVersionField = field;
        }];
        [input addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [input addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(UIAlertAction *apply) {
            NSString *value = [input.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSRegularExpression *valid = [NSRegularExpression regularExpressionWithPattern:@"^\\d+\\.\\d+(?:\\.\\d+)?$" options:0 error:nil];
            self.minecraftVersion = [valid numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] ? value : nil;
            [self searchForProjectsReset:YES];
        }]];
        [self presentViewController:input animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Any Minecraft version" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.minecraftVersion = nil;
        [self searchForProjectsReset:YES];
    }]];
    if ([self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalDownloadDiagnostics"]) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Last download diagnostics" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *report = [[NSUserDefaults standardUserDefaults] stringForKey:@"STLauncherLastDownloadDiagnostics"] ?: @"No download has been recorded yet.";
            [self showMessage:report title:@"Download diagnostics"];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)prefetchThumbnailForProject:(NSDictionary *)project {
    NSString *iconURL = [project[@"icon_url"] isKindOfClass:NSString.class] ? project[@"icon_url"] : @"";
    if (!iconURL.length || [self.iconCache objectForKey:iconURL] || self.iconTasks[iconURL]) return;
    NSURL *url = [NSURL URLWithString:iconURL];
    if (!url) return;
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data && !error ? [UIImage imageWithData:data] : nil;
        UIImage *thumbnail = nil;
        if (image) {
            CGSize target = CGSizeMake(96, 96);
            UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
            format.scale = 1.0;
            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target format:format];
            thumbnail = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
                CGFloat scale = MIN(target.width / MAX(image.size.width, 1), target.height / MAX(image.size.height, 1));
                CGSize fitted = CGSizeMake(image.size.width * scale, image.size.height * scale);
                CGRect rect = CGRectMake((target.width - fitted.width) / 2.0, (target.height - fitted.height) / 2.0, fitted.width, fitted.height);
                [image drawInRect:rect];
            }];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.iconTasks removeObjectForKey:iconURL];
            if (!thumbnail) return;
            [self.iconCache setObject:thumbnail forKey:iconURL];
            for (ModProjectCell *visible in self.tableView.visibleCells) {
                NSIndexPath *path = [self.tableView indexPathForCell:visible];
                if (path && path.row < self.projects.count && [self.projects[path.row][@"icon_url"] isEqualToString:iconURL]) visible.modIcon.image = thumbnail;
            }
        });
    }];
    self.iconTasks[iconURL] = task;
    [task resume];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.projects.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModProjectCell *cell = [tableView dequeueReusableCellWithIdentifier:@"modrinth-project"];
    if (!cell) cell = [[ModProjectCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"modrinth-project"];
    NSDictionary *project = self.projects[indexPath.row];
    NSString *projectID = project[@"project_id"] ?: @"";
    cell.projectID = projectID;
    if ([self isExperimentalUIEnabled]) {
        cell.backgroundColor = [UIColor colorWithRed:0.075 green:0.06 blue:0.12 alpha:1.0];
        cell.contentView.backgroundColor = [UIColor colorWithRed:0.075 green:0.06 blue:0.12 alpha:1.0];
        cell.nameLabel.textColor = UIColor.whiteColor;
        cell.descriptionLabel.textColor = [UIColor colorWithWhite:0.76 alpha:1.0];
        cell.downloadsLabel.textColor = [UIColor colorWithWhite:0.58 alpha:1.0];
        cell.modIcon.backgroundColor = [UIColor colorWithRed:0.13 green:0.10 blue:0.20 alpha:1.0];
    }
    cell.nameLabel.text = project[@"title"] ?: @"Untitled mod";
    cell.descriptionLabel.text = project[@"description"] ?: @"";
    NSNumber *downloads = project[@"downloads"];
    cell.downloadsLabel.text = downloads ? [NSString stringWithFormat:@"%@ downloads", [NSNumberFormatter localizedStringFromNumber:downloads numberStyle:NSNumberFormatterDecimalStyle]] : @"";
    cell.modIcon.image = [UIImage systemImageNamed:@"shippingbox"];

    NSString *iconURL = [project[@"icon_url"] isKindOfClass:NSString.class] ? project[@"icon_url"] : @"";
    UIImage *cached = iconURL.length ? [self.iconCache objectForKey:iconURL] : nil;
    if (cached) {
        cell.modIcon.image = cached;
    } else if (iconURL.length) {
        NSURL *url = [NSURL URLWithString:iconURL];
        if (url && !self.iconTasks[iconURL]) {
            // Coalesce requests so fast scrolling does not download the same icon repeatedly.
            __weak typeof(self) weakSelf = self;
            NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                UIImage *image = data && !error ? [UIImage imageWithData:data] : nil;
                UIImage *thumbnail = nil;
                if (image) {
                    CGSize target = CGSizeMake(96, 96);
                    UIGraphicsImageRendererFormat *format = [[UIGraphicsImageRendererFormat alloc] init];
                    format.scale = 1.0;
                    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target format:format];
                    thumbnail = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
                        CGFloat scale = MIN(target.width / MAX(image.size.width, 1), target.height / MAX(image.size.height, 1));
                        CGSize fitted = CGSizeMake(image.size.width * scale, image.size.height * scale);
                        CGRect rect = CGRectMake((target.width - fitted.width) / 2.0, (target.height - fitted.height) / 2.0, fitted.width, fitted.height);
                        [image drawInRect:rect];
                    }];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self) return;
                    [self.iconTasks removeObjectForKey:iconURL];
                    if (!thumbnail) return;
                    [self.iconCache setObject:thumbnail forKey:iconURL];
                    for (ModProjectCell *visible in tableView.visibleCells) {
                        NSIndexPath *visiblePath = [tableView indexPathForCell:visible];
                        if (visiblePath && visiblePath.row < self.projects.count) {
                            NSDictionary *visibleProject = self.projects[visiblePath.row];
                            if ([visible.projectID isEqualToString:visibleProject[@"project_id"]] &&
                                [visibleProject[@"icon_url"] isEqualToString:iconURL]) {
                                visible.modIcon.image = thumbnail;
                            }
                        }
                    }
                });
            }];
            self.iconTasks[iconURL] = task;
            [task resume];
        }
    }
    if ([self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalCompactResults"]) {
        cell.descriptionLabel.numberOfLines = 1;
    } else {
        cell.descriptionLabel.numberOfLines = 2;
    }
    if (indexPath.row >= self.projects.count - 2 && self.offset < self.totalHits && !self.loading) [self searchForProjectsReset:NO];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *project = self.projects[indexPath.row];
    __weak typeof(self) weakSelf = self;
    ModProjectDetailsController *details = [[ModProjectDetailsController alloc] initWithProject:project loader:self.loader minecraftVersion:self.minecraftVersion versionsAction:^(NSDictionary *updatedProject) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self dismissViewControllerAnimated:YES completion:^{
            ModVersionListController *versions = [[ModVersionListController alloc] initWithProject:updatedProject loader:self.loader minecraftVersion:self.minecraftVersion];
            versions.versionSelected = ^(NSDictionary *version) {
                [self dismissViewControllerAnimated:YES completion:^{ [self showDetailsForVersion:version project:updatedProject]; }];
            };
            UINavigationController *versionNavigation = [[UINavigationController alloc] initWithRootViewController:versions];
            versionNavigation.modalPresentationStyle = UIModalPresentationPageSheet;
            [self presentViewController:versionNavigation animated:YES completion:nil];
        }];
    }];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:details];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)showDetailsForVersion:(NSDictionary *)version project:(NSDictionary *)project {
    NSArray *dependencies = [version[@"dependencies"] isKindOfClass:NSArray.class] ? version[@"dependencies"] : @[];
    if (!dependencies.count) {
        [self presentInstallPromptForVersion:version project:project dependencySummary:@"No dependencies listed."];
        return;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    for (NSDictionary *dependency in dependencies) {
        NSString *projectID = dependency[@"project_id"];
        NSString *type = dependency[@"dependency_type"] ?: @"optional";
        if (![projectID isKindOfClass:NSString.class] || !projectID.length) {
            NSString *versionID = dependency[@"version_id"] ?: @"";
            [lines addObject:[NSString stringWithFormat:@"%@ dependency: %@", type.capitalizedString, versionID.length ? versionID : @"specified version"]];
            continue;
        }
        dispatch_group_enter(group);
        BOOL curseForge = [project[@"source"] isEqual:@"curseforge"];
        NSURL *url = [NSURL URLWithString:curseForge
            ? [NSString stringWithFormat:@"https://api.curseforge.com/v1/mods/%@", projectID]
            : [NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@", projectID]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.timeoutInterval = 12;
        [request setValue:@"Amethyst-iOS-ModBrowser/1.2" forHTTPHeaderField:@"User-Agent"];
        if (curseForge) [request setValue:self.curseForgeAPIKey ?: @"" forHTTPHeaderField:@"x-api-key"];
        [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSDictionary *dependencyInfo = curseForge && [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : json;
            NSString *name = [dependencyInfo[@"title"] isKindOfClass:NSString.class] ? dependencyInfo[@"title"] :
                ([dependencyInfo[@"name"] isKindOfClass:NSString.class] ? dependencyInfo[@"name"] : projectID);
            @synchronized (lines) { [lines addObject:[NSString stringWithFormat:@"%@: %@", type.capitalizedString, name]]; }
            dispatch_group_leave(group);
        }] resume];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSString *summary = lines.count ? [lines componentsJoinedByString:@"\n"] : @"Dependency details unavailable.";
        [self presentInstallPromptForVersion:version project:project dependencySummary:summary];
    });
}
- (void)presentInstallPromptForVersion:(NSDictionary *)version project:(NSDictionary *)project dependencySummary:(NSString *)dependencySummary {
    NSString *name = version[@"name"] ?: version[@"version_number"] ?: @"Mod version";
    NSArray *gameVersions = [version[@"game_versions"] isKindOfClass:NSArray.class] ? version[@"game_versions"] : @[];
    NSString *message = [NSString stringWithFormat:@"%@\nMinecraft: %@\nLoader: %@\n\nDependencies:\n%@", name, [gameVersions componentsJoinedByString:@", "], self.loader.capitalizedString, dependencySummary];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:project[@"title"] ?: @"Mod details" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:([self.projectType isEqualToString:@"mod"] ? @"Download .jar" : @"Download archive") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self downloadVersion:version project:project];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (NSString *)modsDirectoryForSelectedProfile {
    // Dedicated folder visible in Files as:
    // On My iPhone > LiveContainer > data > application > <container UUID> > Documents > ST Mod Browser
    // Keep it directly inside Documents, not inside Minecraft's folders.
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ST Mod Browser"]
        stringByAppendingPathComponent:@"mods"];
}
- (void)insertVersionDot:(UIBarButtonItem *)sender {
    UITextField *field = self.customVersionField;
    if (field) [field replaceRange:field.selectedTextRange withText:@"."];
}
- (void)dismissVersionKeyboard { [self.customVersionField resignFirstResponder]; }
- (void)downloadVersion:(NSDictionary *)version project:(NSDictionary *)project {
    NSDictionary *file = nil;
    NSArray *files = [version[@"files"] isKindOfClass:NSArray.class] ? version[@"files"] : @[];
    for (NSDictionary *candidate in files) {
        NSString *filename = candidate[@"filename"] ?: @"";
        if ([filename.lowercaseString hasSuffix:@".jar"] && [candidate[@"primary"] boolValue]) { file = candidate; break; }
    }
    if (!file) for (NSDictionary *candidate in files) {
        if ([[candidate[@"filename"] lowercaseString] hasSuffix:@".jar"]) { file = candidate; break; }
    }
    NSString *targetExtension = [self.projectType isEqualToString:@"mod"] ? @".jar" : @".zip";
    if (!file || ![[file[@"filename"] lowercaseString] hasSuffix:targetExtension]) {
        file = nil;
        for (NSDictionary *candidate in files) if ([[candidate[@"filename"] lowercaseString] hasSuffix:targetExtension]) { file = candidate; break; }
    }
    if (!file) { [self showMessage:[NSString stringWithFormat:@"No downloadable %@ file was found for this version.", targetExtension] title:@"Download unavailable"]; return; }
    NSURL *url = [NSURL URLWithString:file[@"url"] ?: @""];
    if (!url || !url.scheme.length) { [self showMessage:@"This version has no accessible download URL." title:@"Download failed"]; return; }
    NSString *directory = [self modsDirectoryForSelectedProfile];
    NSError *directoryError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        [self showMessage:directoryError.localizedDescription ?: @"Could not create the mods folder." title:@"Cannot create mods folder"];
        return;
    }
    NSString *filename = file[@"filename"] ?: url.lastPathComponent;
    NSString *destination = [directory stringByAppendingPathComponent:filename];
    if ([NSFileManager.defaultManager fileExistsAtPath:destination]) {
        [self showMessage:[NSString stringWithFormat:@"%@ is already installed.", filename] title:@"Already downloaded"];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Downloading mod…" message:[NSString stringWithFormat:@"%@\n\nPreparing download…\nSaving to ST Mod Browser/mods.", filename] preferredStyle:UIAlertControllerStyleAlert];
    self.activeDownloadAlert = alert;
    self.activeDownloadFilename = filename;
    [self presentViewController:alert animated:YES completion:nil];
    NSDate *downloadStartedAt = [NSDate date];
    self.activeDownloadStartedAt = downloadStartedAt;
    BOOL turboDownloads = [self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalTurboDownloads"];
    BOOL smartInstaller = [self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalSmartInstaller"];
    BOOL diagnosticsEnabled = [self isSTLauncherMode] && [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalDownloadDiagnostics"];
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.defaultSessionConfiguration;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.timeoutIntervalForResource = turboDownloads ? 240 : 180;
    NSInteger configuredConnections = [[NSUserDefaults standardUserDefaults] integerForKey:@"STLauncherDownloadConcurrency"];
    if (configuredConnections < 2) configuredConnections = 6;
    configuration.HTTPMaximumConnectionsPerHost = turboDownloads ? 12 : MIN(12, MAX(2, configuredConnections));
    configuration.URLCache = nil;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 45;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.1" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSError *moveError = nil;
        if (!error && location) {
            NSString *temporaryDestination = [destination stringByAppendingString:@".download"];
            [NSFileManager.defaultManager removeItemAtPath:temporaryDestination error:nil];
            [NSFileManager.defaultManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:temporaryDestination] error:&moveError];
            NSString *expectedSHA1 = [file[@"hashes"][@"sha1"] isKindOfClass:NSString.class] ? file[@"hashes"][@"sha1"] : @"";
            if (!moveError && smartInstaller && expectedSHA1.length) {
                NSData *downloadedData = [NSData dataWithContentsOfFile:temporaryDestination options:NSDataReadingMappedIfSafe error:nil];
                unsigned char digest[CC_SHA1_DIGEST_LENGTH];
                if (downloadedData) {
                    CC_SHA1(downloadedData.bytes, (CC_LONG)downloadedData.length, digest);
                    NSMutableString *actualSHA1 = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
                    for (NSUInteger i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [actualSHA1 appendFormat:@"%02x", digest[i]];
                    if (![actualSHA1.lowercaseString isEqualToString:expectedSHA1.lowercaseString]) {
                        moveError = [NSError errorWithDomain:@"STLauncherDownload" code:3 userInfo:@{NSLocalizedDescriptionKey:@"The downloaded file failed its SHA-1 integrity check. The file was discarded."}];
                        [NSFileManager.defaultManager removeItemAtPath:temporaryDestination error:nil];
                    }
                } else {
                    moveError = [NSError errorWithDomain:@"STLauncherDownload" code:4 userInfo:@{NSLocalizedDescriptionKey:@"Could not verify the downloaded file's integrity. The file was discarded."}];
                    [NSFileManager.defaultManager removeItemAtPath:temporaryDestination error:nil];
                }
            }
            if (!moveError) {
                if (![NSFileManager.defaultManager moveItemAtPath:temporaryDestination toPath:destination error:&moveError]) {
                    [NSFileManager.defaultManager removeItemAtPath:temporaryDestination error:nil];
                }
            }
        }
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:downloadStartedAt];
        NSHTTPURLResponse *httpResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:destination error:nil];
        unsigned long long bytes = [attributes[NSFileSize] unsignedLongLongValue];
        NSString *diagnostic = [NSString stringWithFormat:@"HTTP status: %ld\nFile size: %llu bytes\nElapsed: %.2f seconds\nAverage: %.2f KB/s",
            (long)httpResponse.statusCode, bytes, elapsed, elapsed > 0 ? ((double)bytes / 1024.0 / elapsed) : 0.0];
        [[NSUserDefaults standardUserDefaults] setObject:diagnostic forKey:@"STLauncherLastDownloadDiagnostics"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.downloadProgressTimer invalidate];
            self.downloadProgressTimer = nil;
            self.activeDownloadTask = nil;
            self.activeDownloadAlert = nil;
            self.activeDownloadStartedAt = nil;
            NSMutableArray *history = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"STLauncherDownloadHistory"] mutableCopy] ?: [NSMutableArray array];
            BOOL downloadSucceeded = !(error || moveError);
            [history insertObject:@{
                @"filename": filename ?: @"mod.jar",
                @"project": project[@"title"] ?: filename ?: @"Mod",
                @"path": destination ?: @"",
                @"date": @([[NSDate date] timeIntervalSince1970]),
                @"size": @(bytes),
                @"success": @(downloadSucceeded),
                @"diagnostics": diagnostic ?: @""
            } atIndex:0];
            if (history.count > 30) [history removeObjectsInRange:NSMakeRange(30, history.count - 30)];
            [[NSUserDefaults standardUserDefaults] setObject:history forKey:@"STLauncherDownloadHistory"];
            [alert dismissViewControllerAnimated:YES completion:^{
                if (error || moveError) {
                    NSString *message = (error ?: moveError).localizedDescription ?: @"Download failed.";
                    if (diagnosticsEnabled) message = [message stringByAppendingFormat:@"\n\n%@", diagnostic];
                    [self showMessage:message title:@"Download failed"];
                } else {
                    NSString *message = [NSString stringWithFormat:@"%@ was downloaded to:\n%@", filename, directory];
                    if (diagnosticsEnabled) message = [message stringByAppendingFormat:@"\n\n%@", diagnostic];
                    [self showMessage:message title:@"Download complete"];
                }
            }];
        });
    }];
    self.activeDownloadTask = task;
    self.downloadProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(updateDownloadProgress) userInfo:nil repeats:YES];
    if (turboDownloads) task.priority = NSURLSessionTaskPriorityHigh;
    [task resume];
}
- (void)updateDownloadProgress {
    NSURLSessionDownloadTask *task = self.activeDownloadTask;
    UIAlertController *alert = self.activeDownloadAlert;
    if (!task || !alert || !alert.presentingViewController) return;
    int64_t received = task.countOfBytesReceived;
    int64_t expected = task.countOfBytesExpectedToReceive;
    NSTimeInterval elapsed = self.activeDownloadStartedAt ? [[NSDate date] timeIntervalSinceDate:self.activeDownloadStartedAt] : 0;
    double speedKB = elapsed > 0 ? ((double)received / 1024.0 / elapsed) : 0;
    NSString *progress = expected > 0
        ? [NSString stringWithFormat:@"%.0f%%  •  %@ / %@", MIN(100.0, ((double)received / (double)expected) * 100.0),
            [NSByteCountFormatter stringFromByteCount:received countStyle:NSByteCountFormatterCountStyleFile],
            [NSByteCountFormatter stringFromByteCount:expected countStyle:NSByteCountFormatterCountStyleFile]]
        : [NSString stringWithFormat:@"%@ received", [NSByteCountFormatter stringFromByteCount:received countStyle:NSByteCountFormatterCountStyleFile]];
    NSString *eta = expected > received && speedKB > 0
        ? [NSString stringWithFormat:@"\nETA: %@", [NSString stringWithFormat:@"%.0f sec", ((double)(expected - received) / 1024.0) / speedKB]]
        : @"";
    alert.message = [NSString stringWithFormat:@"%@\n\n%@\nSpeed: %.1f KB/s%@\nSaving to ST Mod Browser/mods.", self.activeDownloadFilename ?: @"Mod", progress, speedKB, eta];
}
- (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end


#pragma mark - Experimental STLauncher screens

static NSString * const STLauncherModeKey = @"STLauncherExperimentalMode";

@interface STLauncherModeViewController ()
@property(nonatomic) UISegmentedControl *modeControl;
@property(nonatomic) UILabel *summaryLabel;
@end

@implementation STLauncherModeViewController
- (instancetype)init {
    self = [super init];
    if (self) self.title = @"Launcher";
    return self;
}
- (NSString *)imageName { return @"switch.2"; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Launcher";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UILabel *title = [[UILabel alloc] init];
    title.text = @"Choose your launcher";
    title.font = [UIFont systemFontOfSize:25 weight:UIFontWeightBold];
    title.numberOfLines = 0;
    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"Amethyst stays the default. STLauncher is experimental and can be switched back at any time.";
    subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    subtitle.textColor = UIColor.secondaryLabelColor;
    subtitle.numberOfLines = 0;
    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Amethyst (Default)", @"STLauncher (Experimental)"]];
    self.modeControl.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] boolForKey:STLauncherModeKey] ? 1 : 0;
    [self.modeControl addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    self.summaryLabel = [[UILabel alloc] init];
    self.summaryLabel.numberOfLines = 0;
    self.summaryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.summaryLabel.textColor = UIColor.secondaryLabelColor;
    [self updateSummary];
    UIButton *features = [UIButton buttonWithType:UIButtonTypeSystem];
    [features setTitle:@"Experimental Features  ›" forState:UIControlStateNormal];
    features.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    features.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [features addTarget:self action:@selector(openFeatures) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle, self.modeControl, self.summaryLabel, features]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 18;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:22],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-22],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:28]
    ]];
}
- (void)updateSummary {
    self.summaryLabel.text = self.modeControl.selectedSegmentIndex == 1
        ? @"STLauncher is selected. Its purple home screen and optional experimental browser features are available. Existing Amethyst screens and the Mod Browser are preserved."
        : @"Amethyst is selected. The original launcher and its existing Mod Browser remain available.";
}
- (void)modeChanged:(UISegmentedControl *)sender {
    BOOL experimental = sender.selectedSegmentIndex == 1;
    [[NSUserDefaults standardUserDefaults] setBool:experimental forKey:STLauncherModeKey];
    [self updateSummary];
    UIViewController *target = nil;
    if (experimental) {
        target = [[STLauncherHomeViewController alloc] init];
    } else {
        Class newsClass = NSClassFromString(@"LauncherNewsViewController");
        target = newsClass ? [[newsClass alloc] init] : nil;
    }
    if (target && self.navigationController) {
        [self.navigationController setViewControllers:@[target] animated:YES];
    }
}
- (void)openFeatures {
    STLauncherExperimentalFeaturesViewController *features = [[STLauncherExperimentalFeaturesViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:features animated:YES];
}
@end

@interface STLauncherHomeViewController ()
@property(nonatomic) UIStackView *buttonStack;
@property(nonatomic) UIButton *playButton;
@end

@implementation STLauncherHomeViewController
- (instancetype)init {
    self = [super init];
    if (self) self.title = @"STLauncher";
    return self;
}
- (NSString *)imageName { return @"sparkles"; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"STLauncher";
    self.view.backgroundColor = [UIColor colorWithRed:0.055 green:0.045 blue:0.085 alpha:1.0];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.75 green:0.55 blue:1.0 alpha:1.0];
    UILabel *eyebrow = [[UILabel alloc] init];
    eyebrow.text = @"ST  •  EXPERIMENTAL";
    eyebrow.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    eyebrow.textColor = [UIColor colorWithRed:0.75 green:0.55 blue:1.0 alpha:1.0];
    UILabel *title = [[UILabel alloc] init];
    title.text = @"STLauncher";
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    UILabel *subtitle = [[UILabel alloc] init];
    NSString *selectedVersion = PLProfiles.current.selectedProfile[@"lastVersionId"] ?: @"No version selected";
    subtitle.text = [NSString stringWithFormat:@"Selected version: %@\nYour Minecraft Java launcher, with a cleaner interface.", selectedVersion];
    subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    subtitle.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
    subtitle.numberOfLines = 0;
    UIStackView *intro = [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow, title, subtitle]];
    intro.axis = UILayoutConstraintAxisVertical;
    intro.spacing = 8;
    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.playButton setTitle:@"▶   Play Minecraft" forState:UIControlStateNormal];
    self.playButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.playButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.playButton.backgroundColor = [UIColor colorWithRed:0.43 green:0.22 blue:0.70 alpha:1.0];
    self.playButton.layer.cornerRadius = 16;
    self.playButton.contentEdgeInsets = UIEdgeInsetsMake(17, 18, 17, 18);
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playButton addTarget:self action:@selector(launchMinecraftFromHome:) forControlEvents:UIControlEventTouchUpInside];
    NSMutableArray *buttons = [NSMutableArray array];
    NSArray *items = @[
        @[@"Browse Mods", @"shippingbox", @"ModBrowserViewController"],
        @[@"Downloads & History", @"arrow.down.circle", @"STLauncherDownloadsViewController"],
        @[@"Library & Favorites", @"books.vertical", @"ModBrowserViewController"],
        @[@"Minecraft Profiles", @"person.crop.square", @"LauncherProfilesViewController"],
        @[@"STLauncher Settings", @"slider.horizontal.3", @"STLauncherSettingsViewController"],
        @[@"Amethyst Settings", @"gearshape", @"LauncherPreferencesViewController"]
    ];
    for (NSArray *item in items) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:[NSString stringWithFormat:@"   %@", item[0]] forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:item[1]] forState:UIControlStateNormal];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        button.tintColor = UIColor.whiteColor;
        button.backgroundColor = [UIColor colorWithRed:0.15 green:0.105 blue:0.23 alpha:1.0];
        button.layer.cornerRadius = 14;
        button.contentEdgeInsets = UIEdgeInsetsMake(16, 16, 16, 16);
        button.tag = [items indexOfObject:item];
        [button addTarget:self action:@selector(openDestination:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addObject:button];
    }
    UIButton *switchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [switchButton setTitle:@"Switch to Amethyst (Default)" forState:UIControlStateNormal];
    switchButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    switchButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    switchButton.tintColor = [UIColor colorWithRed:0.8 green:0.7 blue:1.0 alpha:1.0];
    switchButton.contentEdgeInsets = UIEdgeInsetsMake(12, 4, 12, 4);
    [switchButton addTarget:self action:@selector(switchToAmethyst) forControlEvents:UIControlEventTouchUpInside];
    [buttons addObject:switchButton];
    self.buttonStack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    self.buttonStack.axis = UILayoutConstraintAxisVertical;
    self.buttonStack.spacing = 12;
    self.buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    intro.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:intro];
    [self.view addSubview:self.playButton];
    [self.view addSubview:self.buttonStack];
    [NSLayoutConstraint activateConstraints:@[
        [intro.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:22],
        [intro.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-22],
        [intro.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:34],
        [self.playButton.leadingAnchor constraintEqualToAnchor:intro.leadingAnchor],
        [self.playButton.trailingAnchor constraintEqualToAnchor:intro.trailingAnchor],
        [self.playButton.topAnchor constraintEqualToAnchor:intro.bottomAnchor constant:24],
        [self.playButton.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        [self.buttonStack.leadingAnchor constraintEqualToAnchor:intro.leadingAnchor],
        [self.buttonStack.trailingAnchor constraintEqualToAnchor:intro.trailingAnchor],
        [self.buttonStack.topAnchor constraintEqualToAnchor:self.playButton.bottomAnchor constant:22]
    ]];
}
- (void)openDestination:(UIButton *)sender {
    NSArray *names = @[@"ModBrowserViewController", @"STLauncherDownloadsViewController", @"ModBrowserViewController", @"LauncherProfilesViewController", @"STLauncherSettingsViewController", @"LauncherPreferencesViewController"];
    if (sender.tag < 0 || sender.tag >= names.count) return;
    Class cls = NSClassFromString(names[sender.tag]);
    if (!cls) return;
    UIViewController *destination = [[cls alloc] init];
    if (sender.tag == 2 && [destination isKindOfClass:ModBrowserViewController.class]) {
        ((ModBrowserViewController *)destination).showFavoritesOnly = YES;
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:STLauncherModeKey] &&
        [names[sender.tag] isEqualToString:@"ModBrowserViewController"] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalUI"]) {
        destination.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    [self.navigationController pushViewController:destination animated:YES];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:STLauncherModeKey] &&
        [names[sender.tag] isEqualToString:@"ModBrowserViewController"] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"STLauncherExperimentalUI"]) {
        destination.view.tintColor = [UIColor colorWithRed:0.68 green:0.42 blue:1.0 alpha:1.0];
    }
}
- (void)launchMinecraftFromHome:(UIButton *)sender {
    SEL launchSelector = NSSelectorFromString(@"performInstallOrShowDetails:");
    if ([self.navigationController respondsToSelector:launchSelector]) {
        [self.navigationController performSelector:launchSelector withObject:sender];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Play unavailable" message:@"Use the Play button in the launcher toolbar to start Minecraft." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
- (void)switchToAmethyst {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:STLauncherModeKey];
    Class newsClass = NSClassFromString(@"LauncherNewsViewController");
    if (newsClass) [self.navigationController setViewControllers:@[[[newsClass alloc] init]] animated:YES];
}
@end

@interface STLauncherSettingsViewController : UITableViewController
@property(nonatomic) UISegmentedControl *appearanceControl;
@property(nonatomic) UISegmentedControl *loaderControl;
@property(nonatomic) UISegmentedControl *sortControl;
@property(nonatomic) UILabel *connectionCountLabel;
@property(nonatomic) UIStepper *connectionStepper;
@end

@implementation STLauncherSettingsViewController
- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"STLauncher Settings";
    return self;
}
- (NSString *)imageName { return @"slider.horizontal.3"; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"STLauncher Settings";
    self.tableView.rowHeight = 84;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.appearanceControl = [[UISegmentedControl alloc] initWithItems:@[@"System", @"Light", @"Dark", @"Purple"]];
    self.appearanceControl.tag = 0;
    [self.appearanceControl addTarget:self action:@selector(settingChanged:) forControlEvents:UIControlEventValueChanged];
    self.loaderControl = [[UISegmentedControl alloc] initWithItems:@[@"Forge", @"Fabric", @"Quilt", @"Neo"]];
    self.loaderControl.tag = 1;
    [self.loaderControl addTarget:self action:@selector(settingChanged:) forControlEvents:UIControlEventValueChanged];
    self.sortControl = [[UISegmentedControl alloc] initWithItems:@[@"Relevant", @"Downloads", @"Updated"]];
    self.sortControl.tag = 2;
    [self.sortControl addTarget:self action:@selector(settingChanged:) forControlEvents:UIControlEventValueChanged];
    self.connectionStepper = [[UIStepper alloc] init];
    self.connectionStepper.minimumValue = 2;
    self.connectionStepper.maximumValue = 12;
    self.connectionStepper.stepValue = 1;
    [self.connectionStepper addTarget:self action:@selector(connectionChanged:) forControlEvents:UIControlEventValueChanged];
    self.connectionCountLabel = [[UILabel alloc] init];
    self.connectionCountLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.connectionCountLabel.textAlignment = NSTextAlignmentRight;
    [self reloadSettings];
}
- (void)reloadSettings {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *appearance = [defaults stringForKey:@"STLauncherAppearance"] ?: @"system";
    NSArray *appearances = @[@"system", @"light", @"dark", @"purple"];
    self.appearanceControl.selectedSegmentIndex = MAX(0, (NSInteger)[appearances indexOfObject:appearance]);
    NSString *loader = [defaults stringForKey:@"STLauncherDefaultLoader"] ?: @"fabric";
    NSArray *loaders = @[@"forge", @"fabric", @"quilt", @"neoforge"];
    self.loaderControl.selectedSegmentIndex = MAX(0, (NSInteger)[loaders indexOfObject:loader]);
    NSString *sort = [defaults stringForKey:@"STLauncherDefaultSort"] ?: @"relevance";
    NSArray *sorts = @[@"relevance", @"downloads", @"updated"];
    self.sortControl.selectedSegmentIndex = MAX(0, (NSInteger)[sorts indexOfObject:sort]);
    NSInteger connections = [defaults integerForKey:@"STLauncherDownloadConcurrency"];
    if (connections < 2) connections = 6;
    self.connectionStepper.value = MIN(12, MAX(2, connections));
    self.connectionCountLabel.text = [NSString stringWithFormat:@"%ld", (long)self.connectionStepper.value];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Appearance", @"Default browser filters", @"Download performance"][section];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"st-settings-cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"st-settings-cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.detailTextLabel.numberOfLines = 0;
    if (indexPath.section == 0) {
        cell.textLabel.text = @"Appearance";
        cell.detailTextLabel.text = @"Choose System, Light, Dark, or ST's purple theme.";
        cell.accessoryView = self.appearanceControl;
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @"Default loader & sorting";
        cell.detailTextLabel.text = @"Used when opening the STLauncher browser. Filters can still be changed at any time.";
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.loaderControl, self.sortControl]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 6;
        stack.frame = CGRectMake(0, 0, 280, 64);
        cell.accessoryView = stack;
    } else {
        cell.textLabel.text = @"Concurrent connections";
        cell.detailTextLabel.text = @"Affects concurrent transfers only; it does not make a single server-limited file download faster.";
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.connectionCountLabel, self.connectionStepper]];
        stack.axis = UILayoutConstraintAxisHorizontal;
        stack.spacing = 8;
        [self.connectionCountLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        stack.frame = CGRectMake(0, 0, 100, 32);
        cell.accessoryView = stack;
    }
    return cell;
}
- (void)settingChanged:(UISegmentedControl *)sender {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (sender.tag == 0) {
        NSArray *values = @[@"system", @"light", @"dark", @"purple"];
        NSString *value = values[sender.selectedSegmentIndex];
        [defaults setObject:value forKey:@"STLauncherAppearance"];
        [defaults setBool:[value isEqualToString:@"purple"] forKey:@"STLauncherExperimentalUI"];
        self.overrideUserInterfaceStyle = [value isEqualToString:@"dark"] || [value isEqualToString:@"purple"] ? UIUserInterfaceStyleDark : ([value isEqualToString:@"light"] ? UIUserInterfaceStyleLight : UIUserInterfaceStyleUnspecified);
        [self.tableView reloadData];
    } else if (sender.tag == 1) {
        NSArray *values = @[@"forge", @"fabric", @"quilt", @"neoforge"];
        [defaults setObject:values[sender.selectedSegmentIndex] forKey:@"STLauncherDefaultLoader"];
    } else if (sender.tag == 2) {
        NSArray *values = @[@"relevance", @"downloads", @"updated"];
        [defaults setObject:values[sender.selectedSegmentIndex] forKey:@"STLauncherDefaultSort"];
    }
}
- (void)connectionChanged:(UIStepper *)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)sender.value forKey:@"STLauncherDownloadConcurrency"];
    self.connectionCountLabel.text = [NSString stringWithFormat:@"%ld", (long)sender.value];
}
@end

@interface STLauncherDownloadsViewController ()
@property(nonatomic) NSArray<NSDictionary *> *history;
@end

@implementation STLauncherDownloadsViewController
- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) self.title = @"Downloads";
    return self;
}
- (NSString *)imageName { return @"arrow.down.circle"; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Downloads & History";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 68;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStylePlain target:self action:@selector(clearHistory)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.history = [[NSUserDefaults.standardUserDefaults arrayForKey:@"STLauncherDownloadHistory"] copy] ?: @[];
    self.tableView.backgroundView = self.history.count ? nil : [self emptyState];
    [self.tableView reloadData];
}
- (UIView *)emptyState {
    UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    label.text = @"No downloads yet. Mods you download from the browser will appear here.";
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = UIColor.secondaryLabelColor;
    label.numberOfLines = 0;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return label;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.history.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"st-download-history"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"st-download-history"];
    NSDictionary *item = self.history[indexPath.row];
    BOOL success = [item[@"success"] boolValue];
    cell.textLabel.text = item[@"filename"] ?: @"Mod download";
    cell.textLabel.numberOfLines = 2;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[item[@"date"] doubleValue]];
    NSString *size = [NSByteCountFormatter stringFromByteCount:[item[@"size"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@ • %@", success ? @"Completed" : @"Failed", size, [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle]];
    cell.detailTextLabel.textColor = success ? UIColor.secondaryLabelColor : UIColor.systemRedColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.history[indexPath.row];
    NSString *message = [NSString stringWithFormat:@"%@\n\nPath: %@\n\n%@", [item[@"success"] boolValue] ? @"Download completed." : @"Download failed.", item[@"path"] ?: @"Unavailable", item[@"diagnostics"] ?: @"No diagnostics recorded."];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item[@"project"] ?: @"Download details" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)clearHistory {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Clear download history?" message:@"This removes the history list only. Downloaded files will stay in the ST Mod Browser folder." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STLauncherDownloadHistory"];
        self.history = @[];
        self.tableView.backgroundView = [self emptyState];
        [self.tableView reloadData];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}
@end

@implementation STLauncherExperimentalFeaturesViewController
- (NSString *)imageName { return @"flask"; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Experimental Features";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 78;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}
- (NSArray<NSDictionary *> *)features {
    return @[
        @{@"title":@"Turbo Downloads", @"detail":@"Prioritizes downloads and raises the connection limit for concurrent transfers. It cannot bypass the host or network's speed limit.", @"key":@"STLauncherExperimentalTurboDownloads"},
        @{@"title":@"Instant Thumbnails", @"detail":@"Prefetches the next batch of mod icons so they are ready before you scroll. Uses extra data.", @"key":@"STLauncherExperimentalInstantThumbnails"},
        @{@"title":@"Smart Mod Installer", @"detail":@"Checks the downloaded JAR against the source's SHA-1 hash when one is provided. Invalid files are discarded.", @"key":@"STLauncherExperimentalSmartInstaller"},
        @{@"title":@"Advanced Mod Search", @"detail":@"Adds client-side and server-side environment filters to Modrinth search.", @"key":@"STLauncherExperimentalAdvancedSearch"},
        @{@"title":@"Favorites & Collections", @"detail":@"Save projects with the star button and group saved projects into named collections.", @"key":@"STLauncherExperimentalFavoritesCollections"},
        @{@"title":@"Experimental UI", @"detail":@"Applies the dark purple STLauncher styling to the mod browser. Amethyst's default appearance is unchanged.", @"key":@"STLauncherExperimentalUI"},
        @{@"title":@"Download Diagnostics", @"detail":@"Shows HTTP status, file size, elapsed time and average transfer rate for the latest download.", @"key":@"STLauncherExperimentalDownloadDiagnostics"},
        @{@"title":@"Compact Browser Cards", @"detail":@"Uses shorter mod descriptions to fit more results on screen.", @"key":@"STLauncherExperimentalCompactResults"}
    ];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.features.count; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"st-experimental-feature"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"st-experimental-feature"];
    NSDictionary *feature = [self features][indexPath.row];
    cell.textLabel.text = feature[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = feature[@"detail"];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:feature[@"key"]];
    toggle.tag = indexPath.row;
    [toggle addTarget:self action:@selector(toggleFeature:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (void)toggleFeature:(UISwitch *)sender {
    NSDictionary *feature = [self features][sender.tag];
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:feature[@"key"]];
    if ([feature[@"key"] isEqualToString:@"STLauncherExperimentalInstantThumbnails"]) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"STLauncherExperimentalPrefetchThumbnails"];
    }
    if ([feature[@"key"] isEqualToString:@"STLauncherExperimentalUI"]) {
        self.navigationController.topViewController.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    }
}
@end
