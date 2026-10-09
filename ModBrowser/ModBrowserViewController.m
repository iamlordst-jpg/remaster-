#import "ModBrowserViewController.h"
#import "PLProfiles.h"

@interface ModProjectCell : UITableViewCell
@property(nonatomic) UIImageView *modIcon;
@property(nonatomic) UILabel *nameLabel;
@property(nonatomic) UILabel *descriptionLabel;
@property(nonatomic) UILabel *downloadsLabel;
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
    self.nameLabel.text = nil;
    self.descriptionLabel.text = nil;
    self.downloadsLabel.text = nil;
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
    [spinner startAnimating];
    self.tableView.tableFooterView = spinner;
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray arrayWithObjects:
        [NSURLQueryItem queryItemWithName:@"loaders" value:[NSString stringWithFormat:@"[\"%@\"]", self.loader]],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"100"],
        [NSURLQueryItem queryItemWithName:@"offset" value:[NSString stringWithFormat:@"%ld", (long)self.offset]], nil];
    if (self.minecraftVersion.length) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"game_versions" value:[NSString stringWithFormat:@"[\"%@\"]", self.minecraftVersion]]];
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@/version", self.project[@"project_id"] ?: @""]];
    components.queryItems = items;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:components.URL];
    request.timeoutInterval = 30;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.1" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *page = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.loading = NO;
            [self.tableView.refreshControl endRefreshing];
            self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
            if (error || ![page isKindOfClass:NSArray.class]) {
                self.tableView.backgroundView = self.versions.count ? nil : [self messageView:@"Couldn’t load versions. Pull down to retry."];
                [self.tableView reloadData];
                return;
            }
            [self.versions addObjectsFromArray:page];
            self.offset += page.count;
            self.hasMore = page.count == 100;
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

@interface ModBrowserViewController ()
@property(nonatomic) UISearchController *searchController;
@property(nonatomic) NSMutableArray<NSDictionary *> *projects;
@property(nonatomic) NSString *loader;
@property(nonatomic) NSString *query;
@property(nonatomic) NSString *minecraftVersion;
@property(nonatomic) BOOL loading;
@property(nonatomic) NSInteger offset;
@property(nonatomic) NSInteger totalHits;
@property(nonatomic) NSUInteger searchGeneration;
@property(nonatomic) NSURLSessionDataTask *searchTask;
@property(nonatomic) UIActivityIndicatorView *activity;
@property(nonatomic) NSCache<NSString *, UIImage *> *iconCache;
@end

@implementation ModBrowserViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"Mod Browser";
        self.loader = @"fabric";
        self.query = @"";
        self.projects = [NSMutableArray array];
        self.iconCache = [[NSCache alloc] init];
        NSString *profileVersion = PLProfiles.current.selectedProfile[@"lastVersionId"] ?: @"";
        NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"\\d+\\.\\d+(?:\\.\\d+)?" options:0 error:nil];
        NSTextCheckingResult *match = [pattern firstMatchInString:profileVersion options:0 range:NSMakeRange(0, profileVersion.length)];
        if (match) self.minecraftVersion = [profileVersion substringWithRange:match.range];
        NSString *lowerProfile = profileVersion.lowercaseString;
        if ([lowerProfile containsString:@"neoforge"]) self.loader = @"neoforge";
        else if ([lowerProfile containsString:@"forge"]) self.loader = @"forge";
        else if ([lowerProfile containsString:@"quilt"]) self.loader = @"quilt";
        else if ([lowerProfile containsString:@"fabric"]) self.loader = @"fabric";
    }
    return self;
}

- (NSString *)imageName { return @"shippingbox"; }

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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"slider.horizontal.3"] style:UIBarButtonItemStylePlain target:self action:@selector(showFilters)];
    self.definesPresentationContext = YES;
    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self searchForProjectsReset:YES];
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
        [self.searchTask cancel];
        self.loading = NO;
        self.searchGeneration += 1;
        self.offset = 0;
        self.totalHits = NSIntegerMax;
        [self.projects removeAllObjects];
    } else if (self.loading) {
        return;
    }
    NSUInteger generation = self.searchGeneration;
    self.loading = YES;
    [self.activity startAnimating];
    self.tableView.tableFooterView = self.activity;
    [self.tableView reloadData];

    NSMutableArray<NSArray<NSString *> *> *facetGroups = [NSMutableArray arrayWithObject:@[@"project_type:mod"]];
    [facetGroups addObject:@[[NSString stringWithFormat:@"categories:%@", self.loader]]];
    if (self.minecraftVersion.length) [facetGroups addObject:@[[NSString stringWithFormat:@"versions:%@", self.minecraftVersion]]];
    NSData *facetData = [NSJSONSerialization dataWithJSONObject:facetGroups options:0 error:nil];
    NSString *facets = [[NSString alloc] initWithData:facetData encoding:NSUTF8StringEncoding] ?: @"[[\"project_type:mod\"],[\"categories:fabric\"]]";
    NSArray *items = @[
        [NSURLQueryItem queryItemWithName:@"query" value:self.query ?: @""],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"20"],
        [NSURLQueryItem queryItemWithName:@"offset" value:[NSString stringWithFormat:@"%ld", (long)self.offset]],
        [NSURLQueryItem queryItemWithName:@"index" value:@"relevance"],
        [NSURLQueryItem queryItemWithName:@"facets" value:facets]
    ];
    NSURL *url = [self URLForPath:@"/search" queryItems:items];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 25;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.1" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    self.searchTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || generation != self.searchGeneration) return;
            self.loading = NO;
            [self.activity stopAnimating];
            [self.refreshControl endRefreshing];
            self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
            if (error || ![json isKindOfClass:NSDictionary.class]) {
                if (!self.projects.count) self.tableView.backgroundView = [self messageView:@"Couldn’t load Modrinth. Check your connection and pull to retry."];
            } else {
                NSArray *hits = [json[@"hits"] isKindOfClass:NSArray.class] ? json[@"hits"] : @[];
                [self.projects addObjectsFromArray:hits];
                self.totalHits = [json[@"total_hits"] integerValue];
                self.offset = self.projects.count;
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
            toolbar.items = @[space, dot, space, done]; field.inputAccessoryView = toolbar; field.tag = 7312;
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
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:alert animated:YES completion:nil];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.projects.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ModProjectCell *cell = [tableView dequeueReusableCellWithIdentifier:@"modrinth-project"];
    if (!cell) cell = [[ModProjectCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"modrinth-project"];
    NSDictionary *project = self.projects[indexPath.row];
    NSString *projectID = project[@"project_id"] ?: @"";
    cell.nameLabel.text = project[@"title"] ?: @"Untitled mod";
    cell.descriptionLabel.text = project[@"description"] ?: @"";
    NSNumber *downloads = project[@"downloads"];
    cell.downloadsLabel.text = downloads ? [NSString stringWithFormat:@"%@ downloads", [NSNumberFormatter localizedStringFromNumber:downloads numberStyle:NSNumberFormatterDecimalStyle]] : @"";
    cell.modIcon.image = [UIImage systemImageNamed:@"shippingbox"];
    UIImage *cached = [self.iconCache objectForKey:projectID];
    if (cached) cell.modIcon.image = cached;
    else {
        NSString *iconURL = project[@"icon_url"];
        if (iconURL.length) {
            NSURL *url = [NSURL URLWithString:iconURL];
            if (url) {
                NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    UIImage *image = data ? [UIImage imageWithData:data] : nil;
                    if (!image) return;
                    CGSize target = CGSizeMake(96, 96);
                    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target];
                    UIImage *thumbnail = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
                        CGFloat scale = MIN(target.width / MAX(image.size.width, 1), target.height / MAX(image.size.height, 1));
                        CGSize fitted = CGSizeMake(image.size.width * scale, image.size.height * scale);
                        CGRect rect = CGRectMake((target.width - fitted.width) / 2.0, (target.height - fitted.height) / 2.0, fitted.width, fitted.height);
                        [image drawInRect:rect];
                    }];
                    [self.iconCache setObject:thumbnail forKey:projectID];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (ModProjectCell *visible in tableView.visibleCells) {
                            NSIndexPath *visiblePath = [tableView indexPathForCell:visible];
                            if (visiblePath && visiblePath.row < self.projects.count && [self.projects[visiblePath.row][@"project_id"] isEqualToString:projectID]) {
                                visible.modIcon.image = thumbnail;
                            }
                        }
                    });
                }];
                [task resume];
            }
        }
    }
    if (indexPath.row >= self.projects.count - 2 && self.offset < self.totalHits && !self.loading) [self searchForProjectsReset:NO];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *project = self.projects[indexPath.row];
    ModVersionListController *versions = [[ModVersionListController alloc] initWithProject:project loader:self.loader minecraftVersion:self.minecraftVersion];
    __weak typeof(self) weakSelf = self;
    versions.versionSelected = ^(NSDictionary *version) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self) [self dismissViewControllerAnimated:YES completion:^{ [self showDetailsForVersion:version project:project]; }];
    };
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:versions];
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
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.modrinth.com/v2/project/%@", projectID]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.timeoutInterval = 12;
        [request setValue:@"Amethyst-iOS-ModBrowser/1.1" forHTTPHeaderField:@"User-Agent"];
        [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSString *name = [json[@"title"] isKindOfClass:NSString.class] ? json[@"title"] : projectID;
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
    [alert addAction:[UIAlertAction actionWithTitle:@"Install .jar" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self downloadVersion:version project:project];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (NSString *)modsDirectoryForSelectedProfile {
    // Match the exact directory Amethyst passes to Minecraft, including its LiveContainer container.
    const char *gameDir = getenv("GAME_DIR");
    if (gameDir && gameDir[0] != '\0') {
        return [[NSString stringWithUTF8String:gameDir] stringByAppendingPathComponent:@"mods"];
    }
    NSString *applicationSupport = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    return [[applicationSupport stringByAppendingPathComponent:@"minecraft"] stringByAppendingPathComponent:@"mods"];
}
- (void)insertVersionDot:(UIBarButtonItem *)sender {
    UITextField *field = nil;
    for (UIView *view in self.presentedViewController.view.subviews) {
        if ([view isKindOfClass:UITextField.class] && ((UITextField *)view).tag == 7312) field = (UITextField *)view;
        for (UIView *child in view.subviews) if ([child isKindOfClass:UITextField.class] && ((UITextField *)child).tag == 7312) field = (UITextField *)child;
    }
    if (field) [field replaceRange:field.selectedTextRange withText:@"."];
}
- (void)dismissVersionKeyboard { [self.presentedViewController.view endEditing:YES]; }
- (void)showInstalledMods {
    NSString *directory = [self modsDirectoryForSelectedProfile];
    NSError *error = nil;
    NSArray<NSString *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:&error];
    if (error) { [self showMessage:[NSString stringWithFormat:@"Could not read mods folder:\n%@\n\nPath: %@", error.localizedDescription, directory] title:@"Manage Mods"]; return; }
    NSMutableArray<NSString *> *mods = [NSMutableArray array];
    for (NSString *name in files) {
        NSString *lower = name.lowercaseString;
        if ([lower hasSuffix:@".jar"] || [lower hasSuffix:@".jar.disabled"]) [mods addObject:name];
    }
    if (!mods.count) { [self showMessage:[NSString stringWithFormat:@"No mod JARs found.\n\nFolder checked:\n%@", directory] title:@"Manage Mods"]; return; }
    UIAlertController *list = [UIAlertController alertControllerWithTitle:@"Installed Mods" message:directory preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *name in mods) {
        BOOL disabled = [name.lowercaseString hasSuffix:@".jar.disabled"];
        [list addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ — %@", disabled ? @"Enable" : @"Disable", name] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *from = [directory stringByAppendingPathComponent:name];
            NSString *toName = disabled ? [name substringToIndex:name.length - @".disabled".length] : [name stringByAppendingString:@".disabled"];
            NSError *moveError = nil;
            if (![NSFileManager.defaultManager moveItemAtPath:from toPath:[directory stringByAppendingPathComponent:toName] error:&moveError]) [self showMessage:moveError.localizedDescription title:@"Could not change mod state"];
            else [self showInstalledMods];
        }]];
        [list addAction:[UIAlertAction actionWithTitle:[@"Delete " stringByAppendingString:name] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete mod?" message:name preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *confirmAction) {
                NSError *removeError = nil;
                if (![NSFileManager.defaultManager removeItemAtPath:[directory stringByAppendingPathComponent:name] error:&removeError]) [self showMessage:removeError.localizedDescription title:@"Could not delete mod"];
                else [self showInstalledMods];
            }]];
            [self presentViewController:confirm animated:YES completion:nil];
        }]];
    }
    [list addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    if (list.popoverPresentationController) list.popoverPresentationController.barButtonItem = self.navigationItem.leftBarButtonItem;
    [self presentViewController:list animated:YES completion:nil];
}

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
    if (!file) { [self showMessage:@"No downloadable .jar was found for this version." title:@"Cannot install mod"]; return; }
    NSURL *url = [NSURL URLWithString:file[@"url"] ?: @""];
    if (!url || !url.scheme.length) { [self showMessage:@"Modrinth returned an invalid download URL." title:@"Download failed"]; return; }
    NSString *directory = [self modsDirectoryForSelectedProfile];
    NSError *directoryError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        [self showMessage:directoryError.localizedDescription ?: @"Could not create the mods folder." title:@"Cannot create mods folder"];
        return;
    }
    NSString *filename = file[@"filename"] ?: url.lastPathComponent;
    NSString *destination = [directory stringByAppendingPathComponent:filename];
    if ([NSFileManager.defaultManager fileExistsAtPath:destination]) {
        [self showMessage:[NSString stringWithFormat:@"%@ is already installed.", filename] title:@"Already installed"];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Downloading mod…" message:[NSString stringWithFormat:@"%@\n\nThe file will be placed in the Minecraft mods folder.", filename] preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.defaultSessionConfiguration;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.timeoutIntervalForResource = 180;
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
            if (!moveError) {
                if (![NSFileManager.defaultManager moveItemAtPath:temporaryDestination toPath:destination error:&moveError]) {
                    [NSFileManager.defaultManager removeItemAtPath:temporaryDestination error:nil];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:^{
                if (error || moveError) [self showMessage:(error ?: moveError).localizedDescription title:@"Install failed"];
                else [self showMessage:[NSString stringWithFormat:@"%@ was downloaded to:\n%@", filename, directory] title:@"Mod installed"];
            }];
        });
    }];
    [task resume];
}
- (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
