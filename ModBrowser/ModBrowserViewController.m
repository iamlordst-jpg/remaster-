#import "ModBrowserViewController.h"
#import "PLProfiles.h"

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
@end

@implementation ModBrowserViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"Mod Browser";
        self.loader = @"fabric";
        self.query = @"";
        self.projects = [NSMutableArray array];
        NSString *profileVersion = PLProfiles.current.selectedProfile[@"lastVersionId"];
        NSRegularExpression *versionPattern = [NSRegularExpression regularExpressionWithPattern:@"^\\d+\\.\\d+(?:\\.\\d+)?$" options:0 error:nil];
        if ([versionPattern numberOfMatchesInString:profileVersion ?: @"" options:0 range:NSMakeRange(0, (profileVersion ?: @"").length)] > 0) {
            self.minecraftVersion = profileVersion;
        }
    }
    return self;
}

- (NSString *)imageName {
    return @"shippingbox";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshProjects) forControlEvents:UIControlEventValueChanged];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 88;
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

    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray arrayWithArray:@[
        [NSURLQueryItem queryItemWithName:@"query" value:self.query ?: @""],
        [NSURLQueryItem queryItemWithName:@"limit" value:@"20"],
        [NSURLQueryItem queryItemWithName:@"offset" value:[NSString stringWithFormat:@"%ld", (long)self.offset]],
        [NSURLQueryItem queryItemWithName:@"index" value:@"relevance"],
        [NSURLQueryItem queryItemWithName:@"facets" value:@"[[\"project_type:mod\"]]"]
    ]];
    if (self.minecraftVersion.length) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"facets" value:[NSString stringWithFormat:@"[[\"project_type:mod\"],[\"versions:%@\"]]", self.minecraftVersion]]];
        [items removeObjectAtIndex:4];
    }
    NSURL *url = [self URLForPath:@"/search" queryItems:items];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"Amethyst-Offline/1.0 (https://github.com/iamlordst-jpg/remaster-)" forHTTPHeaderField:@"User-Agent"];
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
                if (self.projects.count == 0) {
                    self.tableView.backgroundView = [self messageView:@"Couldn’t load Modrinth. Check your connection and pull to retry."];
                }
            } else {
                NSArray *hits = [json[@"hits"] isKindOfClass:NSArray.class] ? json[@"hits"] : @[];
                [self.projects addObjectsFromArray:hits];
                self.totalHits = [json[@"total_hits"] integerValue];
                self.offset = self.projects.count;
                self.tableView.backgroundView = nil;
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mod Browser Filters" message:self.minecraftVersion.length ? [NSString stringWithFormat:@"Minecraft %@ • %@", self.minecraftVersion, self.loader] : [NSString stringWithFormat:@"Minecraft version: any • %@", self.loader] preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *loader in @[@"fabric", @"forge", @"quilt", @"neoforge"]) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@%@", [loader capitalizedString], [loader isEqualToString:self.loader] ? @" ✓" : @""] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.loader = loader;
            [self searchForProjectsReset:YES];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Use any Minecraft version" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.minecraftVersion = nil;
        [self searchForProjectsReset:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Use selected profile version" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *version = PLProfiles.current.selectedProfile[@"lastVersionId"];
        NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^\\d+\\.\\d+(?:\\.\\d+)?$" options:0 error:nil];
        self.minecraftVersion = [pattern numberOfMatchesInString:version ?: @"" options:0 range:NSMakeRange(0, (version ?: @"").length)] ? version : nil;
        [self searchForProjectsReset:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.projects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"modrinth-project"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"modrinth-project"];
        cell.textLabel.numberOfLines = 1;
        cell.detailTextLabel.numberOfLines = 3;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    NSDictionary *project = self.projects[indexPath.row];
    cell.textLabel.text = project[@"title"] ?: @"Untitled mod";
    NSString *description = project[@"description"] ?: @"";
    NSNumber *downloads = project[@"downloads"];
    cell.detailTextLabel.text = downloads ? [NSString stringWithFormat:@"%@\n%@ downloads", description, [NSNumberFormatter localizedStringFromNumber:downloads numberStyle:NSNumberFormatterDecimalStyle]] : description;
    cell.imageView.image = [UIImage systemImageNamed:@"shippingbox"];
    NSString *iconURL = project[@"icon_url"];
    if (iconURL.length) {
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:iconURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            UIImage *image = data ? [UIImage imageWithData:data] : nil;
            if (!image) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                UITableViewCell *visibleCell = [tableView cellForRowAtIndexPath:indexPath];
                if (visibleCell && [self.projects[indexPath.row][@"project_id"] isEqual:project[@"project_id"]]) visibleCell.imageView.image = image;
            });
        }];
        [task resume];
    }
    if (indexPath.row >= self.projects.count - 2 && self.offset < self.totalHits && !self.loading) {
        [self searchForProjectsReset:NO];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *project = self.projects[indexPath.row];
    [self loadVersionsForProject:project];
}

- (void)loadVersionsForProject:(NSDictionary *)project {
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    if (self.minecraftVersion.length) [items addObject:[NSURLQueryItem queryItemWithName:@"game_versions" value:[NSString stringWithFormat:@"[\"%@\"]", self.minecraftVersion]]];
    [items addObject:[NSURLQueryItem queryItemWithName:@"loaders" value:[NSString stringWithFormat:@"[\"%@\"]", self.loader]]];
    NSURL *url = [self URLForPath:[NSString stringWithFormat:@"/project/%@/version", project[@"project_id"]] queryItems:items];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"Amethyst-Offline/1.0 (https://github.com/iamlordst-jpg/remaster-)" forHTTPHeaderField:@"User-Agent"];
    [self.activity startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.activity];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *versions = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.activity stopAnimating];
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"slider.horizontal.3"] style:UIBarButtonItemStylePlain target:self action:@selector(showFilters)];
            if (error || ![versions isKindOfClass:NSArray.class] || versions.count == 0) {
                NSString *message = self.minecraftVersion.length ? [NSString stringWithFormat:@"No %@ versions found for Minecraft %@.", self.loader, self.minecraftVersion] : [NSString stringWithFormat:@"No %@ versions found for this mod.", self.loader];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:project[@"title"] ?: @"Mod" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }
            NSMutableArray<UIAlertAction *> *actions = [NSMutableArray array];
            for (NSDictionary *version in [versions subarrayWithRange:NSMakeRange(0, MIN(8, versions.count))]) {
                NSString *title = [NSString stringWithFormat:@"%@ • %@ • %@", version[@"name"] ?: version[@"version_number"] ?: @"Version", [version[@"game_versions"] componentsJoinedByString:@", "], [[version[@"loaders"] firstObject] capitalizedString] ?: self.loader];
                UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *selectedAction) {
                    [self downloadVersion:version project:project];
                }];
                [actions addObject:action];
            }
            UIAlertController *picker = [UIAlertController alertControllerWithTitle:project[@"title"] message:@"Choose a compatible version to install into the selected instance." preferredStyle:UIAlertControllerStyleActionSheet];
            for (UIAlertAction *action in actions) [picker addAction:action];
            [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            if (picker.popoverPresentationController) {
                picker.popoverPresentationController.sourceView = self.view;
                picker.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
            }
            [self presentViewController:picker animated:YES completion:nil];
        });
    }] resume];
}

- (NSString *)modsDirectoryForSelectedProfile {
    const char *gameDirC = getenv("GAME_DIR");
    NSString *base = gameDirC ? [NSString stringWithUTF8String:gameDirC] : NSHomeDirectory();
    NSString *profileDir = PLProfiles.current.selectedProfile[@"gameDir"];
    if (profileDir.length == 0) profileDir = @".";
    NSString *directory = profileDir.isAbsolutePath ? profileDir : [base stringByAppendingPathComponent:profileDir];
    return [directory stringByAppendingPathComponent:@"mods"];
}

- (void)downloadVersion:(NSDictionary *)version project:(NSDictionary *)project {
    NSDictionary *file = nil;
    for (NSDictionary *candidate in version[@"files"]) {
        NSString *filename = candidate[@"filename"] ?: @"";
        if ([filename.lowercaseString hasSuffix:@".jar"] && [candidate[@"primary"] boolValue]) { file = candidate; break; }
    }
    if (!file) {
        for (NSDictionary *candidate in version[@"files"]) {
            if ([[candidate[@"filename"] lowercaseString] hasSuffix:@".jar"]) { file = candidate; break; }
        }
    }
    if (!file) {
        [self showMessage:@"No downloadable .jar was found for this version." title:@"Cannot install mod"];
        return;
    }
    NSURL *url = [NSURL URLWithString:file[@"url"] ?: @""];
    if (!url) {
        [self showMessage:@"Modrinth returned an invalid download URL." title:@"Download failed"];
        return;
    }
    NSString *directory = [self modsDirectoryForSelectedProfile];
    NSError *directoryError = nil;
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&directoryError];
    if (directoryError) {
        [self showMessage:directoryError.localizedDescription title:@"Cannot create mods folder"];
        return;
    }
    NSString *filename = file[@"filename"] ?: [url lastPathComponent];
    NSString *destination = [directory stringByAppendingPathComponent:filename];
    if ([NSFileManager.defaultManager fileExistsAtPath:destination]) {
        [self showMessage:[NSString stringWithFormat:@"%@ is already installed.", filename] title:@"Already installed"];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Installing mod…" message:filename preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    NSURLSessionDownloadTask *task = [NSURLSession.sharedSession downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSError *moveError = nil;
        if (!error && location) {
            [NSFileManager.defaultManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&moveError];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:^{
                if (error || moveError) {
                    [self showMessage:(error ?: moveError).localizedDescription title:@"Install failed"];
                } else {
                    [self showMessage:[NSString stringWithFormat:@"%@ was installed to %@. Restart Minecraft to load it.", filename, directory.lastPathComponent] title:@"Mod installed"];
                }
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
