#include <stdlib.h>
#import "ModBrowserViewController.h"
#import "PLProfiles.h"


@interface STDownloadCoordinator : NSObject <NSURLSessionDownloadDelegate>
@property(nonatomic) NSURLSession *session;
+ (instancetype)shared;
- (void)startURL:(NSURL *)url destination:(NSString *)destination filename:(NSString *)filename title:(NSString *)title project:(NSDictionary *)project turbo:(BOOL)turbo;
- (NSArray<NSDictionary *> *)records;
- (void)deleteRecord:(NSDictionary *)record;
@end

@implementation STDownloadCoordinator
+ (instancetype)shared {
    static STDownloadCoordinator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[STDownloadCoordinator alloc] init]; });
    return instance;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.st.stlauncher.modbrowser.downloads"];
        configuration.sessionSendsLaunchEvents = YES;
        configuration.discretionary = NO;
        configuration.waitsForConnectivity = YES;
        configuration.timeoutIntervalForResource = 60 * 60 * 6;
        configuration.HTTPMaximumConnectionsPerHost = [[NSUserDefaults standardUserDefaults] boolForKey:@"ModBrowserTurboDownloadsEnabled"] ? 12 : 8;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    return self;
}
- (NSMutableArray<NSDictionary *> *)mutableRecords {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"STModDownloadRecords"];
    return saved ? [saved mutableCopy] : [NSMutableArray array];
}
- (NSArray<NSDictionary *> *)records {
    return [[self mutableRecords] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [([b[@"created"] description] ?: @"") compare:([a[@"created"] description] ?: @"")];
    }];
}
- (id)propertyListSafeValue:(id)value {
    if (!value || value == [NSNull null]) return @"";
    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSDate.class] || [value isKindOfClass:NSData.class]) return value;
    if ([value isKindOfClass:NSArray.class]) {
        NSMutableArray *safeArray = [NSMutableArray arrayWithCapacity:[value count]];
        for (id item in value) [safeArray addObject:[self propertyListSafeValue:item] ?: @""];
        return safeArray;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *safeDictionary = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if (![key isKindOfClass:NSString.class]) return;
            safeDictionary[key] = [self propertyListSafeValue:obj] ?: @"";
        }];
        return safeDictionary;
    }
    return [value description] ?: @"";
}
- (NSDictionary *)compactProjectRecord:(NSDictionary *)project {
    if (![project isKindOfClass:NSDictionary.class]) return @{};
    NSArray *keys = @[@"project_id", @"id", @"title", @"slug", @"icon_url", @"project_type", @"description", @"author", @"loaders", @"game_versions", @"client_side", @"server_side"];
    NSMutableDictionary *compact = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        id value = project[key];
        if (value && value != [NSNull null]) compact[key] = [self propertyListSafeValue:value] ?: @"";
    }
    return compact;
}
- (void)saveRecords:(NSArray<NSDictionary *> *)records {
    // Persist only the small set of fields the Download Manager actually uses.
    // Modrinth project objects contain arbitrary nested JSON and must never be
    // written wholesale to NSUserDefaults from background-session callbacks.
    NSMutableArray *safeRecords = [NSMutableArray arrayWithCapacity:records.count];
    NSArray<NSString *> *recordKeys = @[@"id", @"title", @"filename", @"destination",
                                         @"sourceURL", @"status", @"created", @"expected",
                                         @"received", @"error"];
    for (id item in records) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSMutableDictionary *safeRecord = [NSMutableDictionary dictionary];
        for (NSString *key in recordKeys) {
            id value = item[key];
            if (value && value != [NSNull null]) {
                id safeValue = [self propertyListSafeValue:value];
                if (safeValue) safeRecord[key] = safeValue;
            }
        }
        id project = item[@"project"];
        if ([project isKindOfClass:NSDictionary.class]) {
            NSDictionary *compact = [self compactProjectRecord:project];
            NSDictionary *safeProject = [self propertyListSafeValue:compact];
            if (safeProject) safeRecord[@"project"] = safeProject;
        }
        [safeRecords addObject:safeRecord];
    }
    [[NSUserDefaults standardUserDefaults] setObject:safeRecords forKey:@"STModDownloadRecords"];
}
- (void)updateRecord:(NSDictionary *)record {
    NSMutableArray *records = [self mutableRecords];
    NSString *identifier = [record[@"id"] description] ?: @"";
    NSUInteger found = NSNotFound;
    for (NSUInteger i = 0; i < records.count; i++) if ([[records[i][@"id"] description] isEqualToString:identifier]) { found = i; break; }
    if (found == NSNotFound) [records insertObject:record atIndex:0]; else records[found] = record;
    [self saveRecords:records];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"STModDownloadsChanged" object:nil];
}
- (void)startURL:(NSURL *)url destination:(NSString *)destination filename:(NSString *)filename title:(NSString *)title project:(NSDictionary *)project turbo:(BOOL)turbo {
    NSError *directoryError = nil;
    NSString *directory = [destination stringByDeletingLastPathComponent];
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        [self updateRecord:@{@"id":[NSUUID.UUID UUIDString], @"title":title ?: filename ?: @"Download", @"filename":filename ?: @"file", @"destination":destination ?: @"", @"status":@"Failed", @"error":directoryError.localizedDescription ?: @"Could not create download folder.", @"created":[NSDate date].description}];
        return;
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:destination]) {
        [self updateRecord:@{@"id":[NSUUID.UUID UUIDString], @"title":title ?: filename ?: @"Download", @"filename":filename ?: @"file", @"destination":destination ?: @"", @"status":@"Already downloaded", @"created":[NSDate date].description}];
        return;
    }
    NSString *identifier = [NSUUID.UUID UUIDString];
    NSMutableDictionary *record = [@{@"id":identifier, @"title":title ?: filename ?: @"Download", @"filename":filename ?: @"file", @"destination":destination, @"status":@"Downloading", @"received":@0, @"expected":@0, @"created":[NSDate date].description, @"project":project ?: @{}, @"sourceURL":url.absoluteString ?: @""} mutableCopy];
    NSData *descriptionData = [NSJSONSerialization dataWithJSONObject:record options:0 error:nil];
    NSString *taskDescription = descriptionData ? [[NSString alloc] initWithData:descriptionData encoding:NSUTF8StringEncoding] : identifier;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 60;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.4" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
    task.taskDescription = taskDescription;
    if (turbo) task.priority = NSURLSessionTaskPriorityHigh;
    record[@"taskIdentifier"] = @(task.taskIdentifier);
    [self updateRecord:record];
    [task resume];
}
- (NSDictionary *)recordForTask:(NSURLSessionTask *)task {
    if (!task.taskDescription.length) return nil;
    NSData *data = [task.taskDescription dataUsingEncoding:NSUTF8StringEncoding];
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSMutableDictionary *record = [[self recordForTask:downloadTask] mutableCopy];
    if (!record) return;
    record[@"received"] = @(totalBytesWritten);
    record[@"expected"] = @(totalBytesExpectedToWrite);
    record[@"status"] = @"Downloading";
    [self updateRecord:record];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSMutableDictionary *record = [[self recordForTask:downloadTask] mutableCopy];
    if (!record) return;
    NSHTTPURLResponse *response = [downloadTask.response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)downloadTask.response : nil;
    if (response && (response.statusCode < 200 || response.statusCode >= 300)) {
        record[@"status"] = @"Failed";
        record[@"error"] = [NSString stringWithFormat:@"Download server returned HTTP %ld.", (long)response.statusCode];
        [self updateRecord:record];
        return;
    }
    NSString *destination = record[@"destination"];
    NSError *error = nil;
    [NSFileManager.defaultManager createDirectoryAtPath:[destination stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
    if (!error && [NSFileManager.defaultManager fileExistsAtPath:destination]) {
        record[@"status"] = @"Failed";
        record[@"error"] = @"A file with this name already exists.";
    } else if (!error && ![NSFileManager.defaultManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&error]) {
        record[@"status"] = @"Failed";
        record[@"error"] = error.localizedDescription ?: @"Could not save the downloaded file.";
    } else if (error) {
        record[@"status"] = @"Failed";
        record[@"error"] = error.localizedDescription ?: @"Could not save the downloaded file.";
    } else {
        record[@"status"] = @"Downloaded";
        record[@"received"] = record[@"expected"] ?: record[@"received"] ?: @0;
        [record removeObjectForKey:@"error"];
    }
    [self updateRecord:record];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (!error) return;
    NSMutableDictionary *record = [[self recordForTask:task] mutableCopy];
    if (!record) return;
    record[@"status"] = [error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled ? @"Cancelled" : @"Failed";
    record[@"error"] = error.localizedDescription ?: @"Download failed.";
    [self updateRecord:record];
}
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"STModDownloadsChanged" object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"STBackgroundURLSessionDidFinishEvents" object:nil];
    });
}
- (void)deleteRecord:(NSDictionary *)record {
    NSString *identifier = [record[@"id"] description] ?: @"";
    NSNumber *taskIdentifier = record[@"taskIdentifier"];
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *dataTasks, NSArray<NSURLSessionUploadTask *> *uploadTasks, NSArray<NSURLSessionDownloadTask *> *downloadTasks) {
            for (NSURLSessionDownloadTask *task in downloadTasks) {
                NSDictionary *taskRecord = [self recordForTask:task];
                if ([[taskRecord[@"id"] description] isEqualToString:identifier] || task.taskIdentifier == taskIdentifier.integerValue) {
                    task.taskDescription = nil;
                    [task cancel];
                    break;
                }
            }
        }];
    NSString *destination = record[@"destination"];
    if (destination.length) [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
    NSMutableArray *records = [self mutableRecords];
    NSIndexSet *matches = [records indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
        return [[item[@"id"] description] isEqualToString:identifier];
    }];
    [records removeObjectsAtIndexes:matches];
    [self saveRecords:records];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"STModDownloadsChanged" object:nil];
}
@end

@interface STDownloadManagerViewController : UITableViewController
@end
@implementation STDownloadManagerViewController
- (instancetype)init { self = [super initWithStyle:UITableViewStyleInsetGrouped]; if (self) self.title = @"Download Manager"; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDownloads) name:@"STModDownloadsChanged" object:nil];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 70;
    [self reloadDownloads];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)reloadDownloads { [self.tableView reloadData]; }
- (NSArray<NSDictionary *> *)items {
    NSMutableArray<NSDictionary *> *items = [[[STDownloadCoordinator shared] records] mutableCopy];
    NSDictionary *mainMenuDownload = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"STMainMenuDownloadStatus"];
    if (mainMenuDownload) [items addObject:mainMenuDownload];
    NSMutableSet<NSString *> *knownPaths = [NSMutableSet set];
    for (NSDictionary *item in items) if ([item[@"destination"] isKindOfClass:NSString.class]) [knownPaths addObject:item[@"destination"]];
    NSString *base = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ST Mod Browser"];
    for (NSString *folder in @[@"mods", @"resourcepacks", @"shaderpacks", @"datapacks"]) {
        NSString *directory = [base stringByAppendingPathComponent:folder];
        NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil] ?: @[];
        for (NSString *filename in files) {
            NSString *path = [directory stringByAppendingPathComponent:filename];
            BOOL isDirectory = NO;
            if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory && ![knownPaths containsObject:path] && ![filename hasSuffix:@".download"]) {
                NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
                [items addObject:@{@"id":[@"file:" stringByAppendingString:path], @"title":filename, @"filename":filename, @"destination":path, @"status":@"Downloaded", @"created":[attributes[NSFileModificationDate] description] ?: @""}];
                [knownPaths addObject:path];
            }
        }
    }
    return [items sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [([b[@"created"] description] ?: @"") compare:([a[@"created"] description] ?: @"")];
    }];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self items].count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"st-download"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"st-download"];
    NSDictionary *item = [self items][indexPath.row];
    cell.textLabel.text = item[@"title"] ?: item[@"filename"] ?: @"Download";
    cell.textLabel.numberOfLines = 2;
    NSString *status = item[@"status"] ?: @"Unknown";
    int64_t received = [item[@"received"] longLongValue], expected = [item[@"expected"] longLongValue];
    if ([status isEqualToString:@"Downloading"] && expected > 0) status = [NSString stringWithFormat:@"Downloading · %.0f%%", MIN(100.0, (double)received * 100.0 / (double)expected)];
    else if ([status isEqualToString:@"Downloading"] && received > 0) status = [NSString stringWithFormat:@"Downloading · %@", [NSByteCountFormatter stringFromByteCount:received countStyle:NSByteCountFormatterCountStyleFile]];
    NSString *error = item[@"error"];
    cell.detailTextLabel.text = error.length ? [NSString stringWithFormat:@"%@ · %@", status, error] : [NSString stringWithFormat:@"%@ · %@", status, item[@"filename"] ?: @""];
    cell.detailTextLabel.numberOfLines = 3;
    cell.detailTextLabel.textColor = [status containsString:@"Failed"] ? UIColor.systemRedColor : UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = [self items][indexPath.row];
    NSString *status = item[@"status"] ?: @"";
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:item[@"filename"] ?: @"Download" message:[NSString stringWithFormat:@"%@\n%@", status, item[@"destination"] ?: @""] preferredStyle:UIAlertControllerStyleActionSheet];
    if ([status isEqualToString:@"Downloaded"] && [NSFileManager.defaultManager fileExistsAtPath:item[@"destination"] ?: @""]) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Delete downloaded file…" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete file?" message:@"This permanently removes the downloaded file from ST Mod Browser." preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [[STDownloadCoordinator shared] deleteRecord:item]; }]];
            [self presentViewController:confirm animated:YES completion:nil];
        }]];
    } else {
        [menu addAction:[UIAlertAction actionWithTitle:@"Remove from history" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            if ([item[@"id"] isEqual:@"main-menu-download"]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"STMainMenuDownloadStatus"];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"STModDownloadsChanged" object:nil];
                [self reloadDownloads];
            } else {
                [[STDownloadCoordinator shared] deleteRecord:item];
            }
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (menu.popoverPresentationController) { menu.popoverPresentationController.sourceView = tableView; menu.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath]; }
    [self presentViewController:menu animated:YES completion:nil];
}
@end

@interface STModLibraryViewController : UITableViewController
@property(nonatomic) NSArray<NSDictionary *> *projects;
@property(nonatomic) NSString *libraryMode;
@property(nonatomic) NSString *collectionName;
@end
@implementation STModLibraryViewController
- (instancetype)init { self = [super initWithStyle:UITableViewStyleInsetGrouped]; if (self) self.title = @"Favorites & Collections"; return self; }
- (void)viewDidLoad { [super viewDidLoad]; self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)]; [self reloadLibrary]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSMutableDictionary *)collections { NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"STModCollections"]; return saved ? [saved mutableCopy] : [NSMutableDictionary dictionary]; }
- (NSArray *)favorites { NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"STModFavorites"]; return saved ?: @[]; }
- (void)reloadLibrary {
    if (self.collectionName.length) {
        self.title = self.collectionName;
        self.projects = [self collections][self.collectionName] ?: @[];
    } else {
        self.title = @"Favorites & Collections";
        self.projects = [[self favorites] copy];
    }
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.collectionName.length ? 1 : 2; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { if (self.collectionName.length) return nil; return section == 0 ? @"Favorites" : @"Collections"; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.collectionName.length) return self.projects.count;
    if (section == 0) return [self favorites].count;
    return [self collections].count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"st-library"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"st-library"];
    if (self.collectionName.length || indexPath.section == 0) {
        NSDictionary *p = self.collectionName.length ? self.projects[indexPath.row] : [self favorites][indexPath.row];
        cell.textLabel.text = p[@"title"] ?: @"Untitled project";
        cell.detailTextLabel.text = p[@"description"] ?: p[@"source"] ?: @"";
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        NSString *name = [[self collections].allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)][indexPath.row];
        cell.textLabel.text = name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu saved projects", (unsigned long)[[self collections][name] count]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.textLabel.numberOfLines = 2; cell.detailTextLabel.numberOfLines = 2;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.collectionName.length && indexPath.section == 1) {
        NSArray *names = [[self collections].allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        if (indexPath.row >= names.count) return;
        STModLibraryViewController *detail = [[STModLibraryViewController alloc] init]; detail.collectionName = names[indexPath.row];
        detail.modalPresentationStyle = UIModalPresentationPageSheet;
        [self.navigationController pushViewController:detail animated:YES];
        return;
    }
    NSDictionary *p = self.collectionName.length ? self.projects[indexPath.row] : [self favorites][indexPath.row];
    NSString *key = p[@"project_id"] ?: @"";
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:p[@"title"] ?: @"Saved project" message:@"Manage this saved project." preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Remove from favorites" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSMutableArray *f = [[self favorites] mutableCopy];
        NSIndexSet *matches = [f indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) { return [[item[@"project_id"] description] isEqualToString:key]; }];
        [f removeObjectsAtIndexes:matches]; [[NSUserDefaults standardUserDefaults] setObject:f forKey:@"STModFavorites"]; [self reloadLibrary];
    }]];
    if (self.collectionName.length) [menu addAction:[UIAlertAction actionWithTitle:@"Remove from collection" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSMutableDictionary *c = [self collections]; NSMutableArray *arr = [c[self.collectionName] mutableCopy] ?: [NSMutableArray array];
        NSIndexSet *matches = [arr indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) { return [[item[@"project_id"] description] isEqualToString:key]; }];
        [arr removeObjectsAtIndexes:matches]; c[self.collectionName] = arr; [[NSUserDefaults standardUserDefaults] setObject:c forKey:@"STModCollections"]; [self reloadLibrary];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (menu.popoverPresentationController) { menu.popoverPresentationController.sourceView = tableView; menu.popoverPresentationController.sourceRect = [tableView rectForRowAtIndexPath:indexPath]; }
    [self presentViewController:menu animated:YES completion:nil];
}
@end

@interface STModCollectionPicker : NSObject
+ (void)presentFrom:(UIViewController *)controller project:(NSDictionary *)project;
@end
@implementation STModCollectionPicker
+ (void)presentFrom:(UIViewController *)controller project:(NSDictionary *)project {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *collections = [[defaults dictionaryForKey:@"STModCollections"] mutableCopy] ?: [NSMutableDictionary dictionary];
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Add to collection" message:@"Choose a collection or create a new one." preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = [collections.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *name in names) [picker addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSMutableArray *items = [collections[name] mutableCopy] ?: [NSMutableArray array];
        NSString *pid = project[@"project_id"] ?: @"";
        BOOL exists = NO; for (NSDictionary *item in items) if ([[item[@"project_id"] description] isEqualToString:pid]) exists = YES;
        if (!exists) [items addObject:project];
        collections[name] = items; [defaults setObject:collections forKey:@"STModCollections"];
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Saved to collection" message:name preferredStyle:UIAlertControllerStyleAlert]; [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [controller presentViewController:done animated:YES completion:nil];
    }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"＋ New collection…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        UIAlertController *create = [UIAlertController alertControllerWithTitle:@"New collection" message:@"Give this collection a name." preferredStyle:UIAlertControllerStyleAlert];
        [create addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"e.g. Performance mods"; field.autocapitalizationType = UITextAutocapitalizationTypeWords; }];
        [create addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [create addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *name = [create.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!name.length) return;
            NSMutableDictionary *latest = [[defaults dictionaryForKey:@"STModCollections"] mutableCopy] ?: [NSMutableDictionary dictionary];
            NSMutableArray *items = [latest[name] mutableCopy] ?: [NSMutableArray array];
            NSString *pid = project[@"project_id"] ?: @"";
            BOOL exists = NO; for (NSDictionary *item in items) if ([[item[@"project_id"] description] isEqualToString:pid]) exists = YES;
            if (!exists) [items addObject:project]; latest[name] = items; [defaults setObject:latest forKey:@"STModCollections"];
        }]];
        [controller presentViewController:create animated:YES completion:nil];
    }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [controller presentViewController:picker animated:YES completion:nil];
}
@end

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
        [self.modIcon.widthAnchor constraintEqualToConstant:64],
        [self.modIcon.heightAnchor constraintEqualToConstant:64],
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
@property(nonatomic) NSURLSession *iconSession;
@property(nonatomic) NSString *iconDiskCacheDirectory;
@property(nonatomic) NSMutableDictionary<NSString *, NSURLSessionDataTask *> *iconTasks;
@property(nonatomic) UISegmentedControl *sourceControl;
@property(nonatomic) BOOL curseForgeSource;
@property(nonatomic) NSString *curseForgeAPIKey;
@property(nonatomic) UITextField *customVersionField;
@property(nonatomic) UILabel *browserHeaderTitle;
@property(nonatomic) UILabel *browserHeaderSubtitle;
@property(nonatomic) NSString *environmentFilter;
@property(nonatomic) NSString *projectType;
@property(nonatomic) NSTimer *downloadProgressTimer;
@property(nonatomic) UIAlertController *activeDownloadAlert;
@property(nonatomic) NSURLSessionDownloadTask *activeDownloadTask;
@property(nonatomic) NSDate *activeDownloadStartedAt;
@property(nonatomic) NSString *activeDownloadFilename;
@property(nonatomic) NSString *activeDownloadFolderName;
@property(nonatomic) UIBarButtonItem *downloadManagerButton;
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
        self.environmentFilter = [defaults stringForKey:@"ModBrowserEnvironmentFilter"] ?: @"any";
        BOOL advancedSearchEnabled = [defaults boolForKey:@"ModBrowserAdvancedSearchEnabled"];
        NSString *savedProjectType = [defaults stringForKey:@"ModBrowserProjectType"];
        self.projectType = advancedSearchEnabled && [@[@"mod", @"resourcepack", @"shader", @"datapack"] containsObject:savedProjectType] ? savedProjectType : @"mod";
        NSString *savedSort = [defaults stringForKey:@"ModBrowserSortOrder"];
        if ([@[@"relevance", @"downloads", @"updated"] containsObject:savedSort]) self.sortOrder = savedSort;
        self.projects = [NSMutableArray array];
        self.iconCache = [[NSCache alloc] init];
        self.iconCache.countLimit = 400;
        self.iconTasks = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *iconConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        iconConfiguration.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
        iconConfiguration.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:12 * 1024 * 1024 diskCapacity:48 * 1024 * 1024 diskPath:@"st-mod-browser-icons"];
        iconConfiguration.HTTPMaximumConnectionsPerHost = 12;
        iconConfiguration.timeoutIntervalForRequest = 18;
        iconConfiguration.timeoutIntervalForResource = 35;
        self.iconSession = [NSURLSession sessionWithConfiguration:iconConfiguration];
        NSString *cacheRoot = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
        self.iconDiskCacheDirectory = [cacheRoot stringByAppendingPathComponent:@"STModBrowserIcons"];
        [NSFileManager.defaultManager createDirectoryAtPath:self.iconDiskCacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
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

- (UIBarButtonItem *)centeredIconBarButton:(NSString *)symbolName action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, 44, 44);
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [button setImage:[UIImage systemImageNamed:symbolName] forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeCenter;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}
- (NSString *)imageName { return @"shippingbox"; }
- (BOOL)advancedSearchEnabled { return [[NSUserDefaults standardUserDefaults] boolForKey:@"ModBrowserAdvancedSearchEnabled"]; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.separatorColor = nil;
    self.navigationController.navigationBar.tintColor = nil;
    [self layoutSourceControl];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshProjects) forControlEvents:UIControlEventValueChanged];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 104;
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Search Modrinth mods";
    self.navigationItem.searchController = self.searchController;
    self.curseForgeAPIKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"AmethystCurseForgeAPIKey"] ?: @"";
    self.sourceControl = [[UISegmentedControl alloc] initWithItems:@[@"Modrinth", @"CurseForge"]];
    self.sourceControl.selectedSegmentIndex = 0;
    NSString *initialTypeLabel = [self.projectType isEqualToString:@"resourcepack"] ? @"resource packs" : ([self.projectType isEqualToString:@"shader"] ? @"shaders" : ([self.projectType isEqualToString:@"datapack"] ? @"data packs" : @"mods"));
    self.searchController.searchBar.placeholder = [NSString stringWithFormat:@"Search %@ on Modrinth", initialTypeLabel];
    [self.sourceControl addTarget:self action:@selector(sourceChanged:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *filtersButton = [self centeredIconBarButton:@"slider.horizontal.3" action:@selector(showFilters)];
    UIBarButtonItem *settingsButton = [self centeredIconBarButton:@"gearshape" action:@selector(showModBrowserSettings)];
    UIBarButtonItem *downloadsButton = [[UIBarButtonItem alloc] initWithTitle:@"Downloads" style:UIBarButtonItemStylePlain target:self action:@selector(openDownloadManager)];
    self.navigationItem.rightBarButtonItems = @[filtersButton, settingsButton, downloadsButton];
    [[STDownloadCoordinator shared] records];
    self.definesPresentationContext = YES;
    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self layoutSourceControl];
    [self searchForProjectsReset:YES];
}

- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self layoutSourceControl]; }
- (void)layoutSourceControl {
    CGFloat width=self.tableView.bounds.size.width,height=88;
    UIView *header=self.tableView.tableHeaderView;
    if(!header||![header.subviews containsObject:self.sourceControl]||!self.browserHeaderTitle||!self.browserHeaderSubtitle){
        header=[[UIView alloc]initWithFrame:CGRectMake(0,0,width,height)];
        self.browserHeaderTitle=[[UILabel alloc]initWithFrame:CGRectZero];self.browserHeaderTitle.text=@"Mod Browser";
        self.browserHeaderTitle.font=[UIFont systemFontOfSize:22 weight:UIFontWeightBold];self.browserHeaderTitle.textColor=UIColor.labelColor;
        self.browserHeaderSubtitle=[[UILabel alloc]initWithFrame:CGRectZero];self.browserHeaderSubtitle.text=@"Search projects and filter by loader, version, and type";
        self.browserHeaderSubtitle.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];self.browserHeaderSubtitle.textColor=UIColor.secondaryLabelColor;
        [header addSubview:self.browserHeaderTitle];[header addSubview:self.browserHeaderSubtitle];[header addSubview:self.sourceControl];self.tableView.tableHeaderView=header;
    }
    header.frame=CGRectMake(0,0,width,height);
    self.browserHeaderTitle.frame=CGRectMake(16,3,MAX(0,width-32),26);
    self.browserHeaderSubtitle.frame=CGRectMake(16,29,MAX(0,width-32),18);
    self.sourceControl.frame=CGRectMake(16,52,MAX(0,width-32),32);self.sourceControl.selectedSegmentTintColor=nil;
}


- (void)openDownloadManager {
    STDownloadManagerViewController *manager = [[STDownloadManagerViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:manager];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)openLibrary {
    STModLibraryViewController *library = [[STModLibraryViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:library];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.projects.count) return [UISwipeActionsConfiguration configurationWithActions:@[]];
    NSDictionary *project = self.projects[indexPath.row];
    NSString *projectID = project[@"project_id"] ?: @"";
    UIContextualAction *favorite = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Favorite" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSMutableArray *items = [[defaults arrayForKey:@"STModFavorites"] mutableCopy] ?: [NSMutableArray array];
        NSUInteger found = NSNotFound;
        for (NSUInteger i=0;i<items.count;i++) if ([[items[i][@"project_id"] description] isEqualToString:projectID]) { found=i; break; }
        if (found == NSNotFound) [items addObject:project]; else [items removeObjectAtIndex:found];
        [defaults setObject:items forKey:@"STModFavorites"];
        completionHandler(YES);
    }];
    favorite.backgroundColor = UIColor.systemPinkColor;
    UIContextualAction *collection = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Collection" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [STModCollectionPicker presentFrom:self project:project];
        completionHandler(YES);
    }];
    collection.backgroundColor = UIColor.systemIndigoColor;
    return [UISwipeActionsConfiguration configurationWithActions:@[collection, favorite]];
}

- (void)sourceChanged:(UISegmentedControl *)sender {
    self.curseForgeSource = sender.selectedSegmentIndex == 1;
    if (![self advancedSearchEnabled]) self.projectType = @"mod";
    NSString *typeLabel = [self projectTypeLabel];
    self.searchController.searchBar.placeholder = [NSString stringWithFormat:@"Search %@ on %@", typeLabel, self.curseForgeSource ? @"CurseForge" : @"Modrinth"];
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
        if ([self.projectType isEqualToString:@"mod"] && ![self.loader isEqualToString:@"any"]) [items addObject:[NSURLQueryItem queryItemWithName:@"modLoaderType" value:loaderIDs[self.loader] ?: @"1"]];
        if (self.minecraftVersion.length) [items addObject:[NSURLQueryItem queryItemWithName:@"gameVersion" value:self.minecraftVersion]];
        NSURLComponents *components = [NSURLComponents componentsWithString:@"https://api.curseforge.com/v1/mods/search"];
        components.queryItems = items;
        request = [NSMutableURLRequest requestWithURL:components.URL];
        [request setValue:self.curseForgeAPIKey forHTTPHeaderField:@"x-api-key"];
    } else {
        NSMutableArray<NSArray<NSString *> *> *facetGroups = [NSMutableArray arrayWithObject:@[[NSString stringWithFormat:@"project_type:%@", self.projectType ?: @"mod"]]];
        if ([self.projectType isEqualToString:@"mod"] && ![self.loader isEqualToString:@"any"]) [facetGroups addObject:@[[NSString stringWithFormat:@"categories:%@", self.loader]]];
        if (self.minecraftVersion.length) [facetGroups addObject:@[[NSString stringWithFormat:@"versions:%@", self.minecraftVersion]]];
        if ([self advancedSearchEnabled] && [self.projectType isEqualToString:@"mod"] && !self.curseForgeSource) {
            if ([self.environmentFilter isEqualToString:@"client"]) [facetGroups addObject:@[@"client_side:required", @"client_side:optional"]];
            else if ([self.environmentFilter isEqualToString:@"server"]) [facetGroups addObject:@[@"server_side:required", @"server_side:optional"]];
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
- (BOOL)iconCachingEnabled {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSNumber *saved = [defaults objectForKey:@"STModBrowserIconCachingEnabled"];
    return saved ? saved.boolValue : YES;
}
- (void)clearIconCache {
    // Stop outstanding icon requests so they cannot repopulate the cache immediately after it is cleared.
    for (NSURLSessionDataTask *task in self.iconTasks.allValues) [task cancel];
    [self.iconTasks removeAllObjects];
    [self.iconCache removeAllObjects];
    [self.iconSession.configuration.URLCache removeAllCachedResponses];
    NSError *error = nil;
    if (self.iconDiskCacheDirectory.length) {
        [[NSFileManager defaultManager] removeItemAtPath:self.iconDiskCacheDirectory error:&error];
        if (error && error.code != NSFileNoSuchFileError) {
            [self showMessage:@"Some cached files could not be removed. Try again." title:@"Clear Image Cache"];
            return;
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:self.iconDiskCacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [self.tableView reloadData];
    [self showMessage:@"Cached mod images have been cleared. Images will download again when needed." title:@"Clear Image Cache"];
}
- (void)showFilters {
    UIAlertController *m=[UIAlertController alertControllerWithTitle:@"Mod Browser Filters" message:@"Choose what projects to show." preferredStyle:UIAlertControllerStyleActionSheet];
    BOOL advanced = [NSUserDefaults.standardUserDefaults boolForKey:@"ModBrowserAdvancedSearchEnabled"];
    if(advanced){[m addAction:[UIAlertAction actionWithTitle:@"Project type…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self showProjectTypeFilters];}]];
        if(!self.curseForgeSource&&[self.projectType isEqualToString:@"mod"])[m addAction:[UIAlertAction actionWithTitle:@"Environment…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self showEnvironmentFilters];}]];}
    if([self.projectType isEqualToString:@"mod"])[m addAction:[UIAlertAction actionWithTitle:@"Mod loader…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self showLoaderFilters];}]];
    [m addAction:[UIAlertAction actionWithTitle:@"Sort results…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self showSortFilters];}]];
    [m addAction:[UIAlertAction actionWithTitle:@"Minecraft version…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self showVersionFilters];}]];
    [m addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if(m.popoverPresentationController && self.navigationItem.rightBarButtonItems.count) m.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItems.firstObject;
    [self presentViewController:m animated:YES completion:nil];
}
- (void)showModBrowserSettings {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL advanced = [d boolForKey:@"ModBrowserAdvancedSearchEnabled"];
    BOOL background = [d boolForKey:@"STBackgroundDownloadsEnabled"];
    BOOL turbo = [d boolForKey:@"ModBrowserTurboDownloadsEnabled"];
    BOOL caching = [self iconCachingEnabled];
    UIAlertController *m = [UIAlertController alertControllerWithTitle:@"Mod Browser Settings" message:@"Optional features and cache controls." preferredStyle:UIAlertControllerStyleActionSheet];
    [m addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Advanced Mod Search: %@", advanced ? @"On" : @"Off"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        BOOL enabled = ![d boolForKey:@"ModBrowserAdvancedSearchEnabled"];
        [d setBool:enabled forKey:@"ModBrowserAdvancedSearchEnabled"];
        if (!enabled) {
            self.projectType = @"mod";
            self.environmentFilter = @"any";
            [d setObject:@"mod" forKey:@"ModBrowserProjectType"];
            [d setObject:@"any" forKey:@"ModBrowserEnvironmentFilter"];
        }
        self.searchController.searchBar.placeholder = [NSString stringWithFormat:@"Search %@ on %@", [self projectTypeLabel], self.curseForgeSource ? @"CurseForge" : @"Modrinth"];
        [self searchForProjectsReset:YES];
    }]];
    [m addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Background Downloads: %@", background ? @"On" : @"Off"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        BOOL enabled = ![d boolForKey:@"STBackgroundDownloadsEnabled"];
        [d setBool:enabled forKey:@"STBackgroundDownloadsEnabled"];
        [self showMessage:enabled ? @"Background downloads enabled. Transfers appear in Download Manager and can continue when you leave the browser." : @"Background downloads disabled. New downloads will use the in-screen downloader." title:@"Background Downloads"];
    }]];
    [m addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Turbo Downloads: %@", turbo ? @"On" : @"Off"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        BOOL enabled = ![d boolForKey:@"ModBrowserTurboDownloadsEnabled"];
        [d setBool:enabled forKey:@"ModBrowserTurboDownloadsEnabled"];
        [self showMessage:enabled ? @"Turbo Downloads enabled for future downloads. It cannot bypass host or network limits." : @"Turbo Downloads disabled." title:@"Download Settings"];
    }]];
    [m addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Image Cache: %@", caching ? @"On" : @"Off"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        BOOL enabled = ![self iconCachingEnabled];
        [d setBool:enabled forKey:@"STModBrowserIconCachingEnabled"];
        if (!enabled) {
            [self clearIconCache];
        } else {
            [self showMessage:@"Image caching enabled. Mod icons will be saved for faster repeat visits." title:@"Image Cache"];
        }
    }]];
    [m addAction:[UIAlertAction actionWithTitle:@"Clear Image Cache" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self clearIconCache];
    }]];
    [m addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (m.popoverPresentationController && self.navigationItem.rightBarButtonItems.count > 1) m.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems[1];
    [self presentViewController:m animated:YES completion:nil];
}
- (NSString *)projectTypeLabel {if([self.projectType isEqualToString:@"resourcepack"])return @"resource packs";if([self.projectType isEqualToString:@"shader"])return @"shaders";if([self.projectType isEqualToString:@"datapack"])return @"data packs";return @"mods";}
- (void)presentFilterMenu:(UIAlertController *)m {if(m.popoverPresentationController)m.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItem;[self presentViewController:m animated:YES completion:nil];}
- (void)showProjectTypeFilters {
    UIAlertController *m=[UIAlertController alertControllerWithTitle:@"Project Type" message:@"Choose the kind of Minecraft project." preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary *labels=@{@"mod":@"Mods",@"resourcepack":@"Resource packs",@"shader":@"Shaders",@"datapack":@"Data packs"};
    for(NSString *type in @[@"mod",@"resourcepack",@"shader",@"datapack"]){NSString *title=labels[type];if([self.projectType isEqualToString:type])title=[title stringByAppendingString:@" ✓"];
        [m addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){self.projectType=type;NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[d setObject:type forKey:@"ModBrowserProjectType"];if(![type isEqualToString:@"mod"]){self.environmentFilter=@"any";[d setObject:@"any" forKey:@"ModBrowserEnvironmentFilter"];}self.searchController.searchBar.placeholder=[NSString stringWithFormat:@"Search %@ on %@",[self projectTypeLabel],self.curseForgeSource?@"CurseForge":@"Modrinth"];[self searchForProjectsReset:YES];}]];}
    [m addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentFilterMenu:m];
}
- (void)showEnvironmentFilters {
    UIAlertController *m=[UIAlertController alertControllerWithTitle:@"Environment" message:@"Client/server filters include required or optional support." preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary *labels=@{@"any":@"Any environment",@"client":@"Client compatible",@"server":@"Server compatible"};
    for(NSString *v in @[@"any",@"client",@"server"]){NSString *title=labels[v];if([self.environmentFilter isEqualToString:v])title=[title stringByAppendingString:@" ✓"];
        [m addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){self.environmentFilter=v;[[NSUserDefaults standardUserDefaults] setObject:v forKey:@"ModBrowserEnvironmentFilter"];[self searchForProjectsReset:YES];}]];}
    [m addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentFilterMenu:m];
}
- (void)showLoaderFilters {
    UIAlertController *m=[UIAlertController alertControllerWithTitle:@"Mod Loader" message:@"Choose a loader or remove the loader filter." preferredStyle:UIAlertControllerStyleActionSheet];
    NSDictionary *labels=@{@"any":@"Any loader",@"fabric":@"Fabric",@"forge":@"Forge",@"neoforge":@"NeoForge",@"quilt":@"Quilt"};
    for(NSString *v in @[@"any",@"fabric",@"forge",@"neoforge",@"quilt"]){NSString *title=labels[v];if([self.loader isEqualToString:v])title=[title stringByAppendingString:@" ✓"];
        [m addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){self.loader=v;[self searchForProjectsReset:YES];}]];}
    [m addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentFilterMenu:m];
}
- (void)showSortFilters {
    UIAlertController *m=[UIAlertController alertControllerWithTitle:@"Sort Results" message:nil preferredStyle:UIAlertControllerStyleActionSheet];NSDictionary *labels=@{@"relevance":@"Most relevant",@"downloads":@"Most downloads",@"updated":@"Recently updated"};
    for(NSString *v in @[@"relevance",@"downloads",@"updated"]){NSString *title=labels[v];if([self.sortOrder isEqualToString:v])title=[title stringByAppendingString:@" ✓"];
        [m addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){self.sortOrder=v;[[NSUserDefaults standardUserDefaults] setObject:v forKey:@"ModBrowserSortOrder"];[self searchForProjectsReset:YES];}]];}
    [m addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentFilterMenu:m];
}
- (void)showVersionFilters {
    UIAlertController *m=[UIAlertController alertControllerWithTitle:@"Minecraft Version" message:[NSString stringWithFormat:@"Current filter: %@",self.minecraftVersion?:@"Any"] preferredStyle:UIAlertControllerStyleActionSheet];
    [m addAction:[UIAlertAction actionWithTitle:@"Match selected profile" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){NSString *v=PLProfiles.current.selectedProfile[@"lastVersionId"]?:@"";NSRegularExpression *p=[NSRegularExpression regularExpressionWithPattern:@"\\d+\\.\\d+(?:\\.\\d+)?" options:0 error:nil];NSTextCheckingResult *match=[p firstMatchInString:v options:0 range:NSMakeRange(0,v.length)];self.minecraftVersion=match?[v substringWithRange:match.range]:nil;[self searchForProjectsReset:YES];}]];
    [m addAction:[UIAlertAction actionWithTitle:@"Choose version…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){UIAlertController *input=[UIAlertController alertControllerWithTitle:@"Minecraft version" message:@"Enter a version such as 1.20.1." preferredStyle:UIAlertControllerStyleAlert];
        [input addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=@"1.20.1";f.text=self.minecraftVersion;f.keyboardType=UIKeyboardTypeNumberPad;UIToolbar *tb=[[UIToolbar alloc]initWithFrame:CGRectMake(0,0,0,44)];UIBarButtonItem *dot=[[UIBarButtonItem alloc]initWithTitle:@"." style:UIBarButtonItemStylePlain target:self action:@selector(insertVersionDot:)];UIBarButtonItem *sp=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];UIBarButtonItem *done=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissVersionKeyboard)];tb.items=@[sp,dot,sp,done];f.inputAccessoryView=tb;self.customVersionField=f;}];
        [input addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [input addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){NSString *v=[input.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];NSRegularExpression *p=[NSRegularExpression regularExpressionWithPattern:@"^\\d+\\.\\d+(?:\\.\\d+)?$" options:0 error:nil];self.minecraftVersion=[p numberOfMatchesInString:v options:0 range:NSMakeRange(0,v.length)]?v:nil;[self searchForProjectsReset:YES];}]];[self presentViewController:input animated:YES completion:nil];}]];
    [m addAction:[UIAlertAction actionWithTitle:@"Any version" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){self.minecraftVersion=nil;[self searchForProjectsReset:YES];}]];
    [m addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentFilterMenu:m];
}
- (void)requestIconURL:(NSString *)iconURL diskPath:(NSString *)diskPath tableView:(UITableView *)tableView attempt:(NSInteger)attempt {
    NSURL *url = [NSURL URLWithString:iconURL ?: @""];
    if (!url || !([url.scheme.lowercaseString isEqualToString:@"https"] || [url.scheme.lowercaseString isEqualToString:@"http"])) return;
    BOOL useCache = [self iconCachingEnabled];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
        cachePolicy:(useCache ? NSURLRequestReturnCacheDataElseLoad : NSURLRequestReloadIgnoringLocalCacheData)
        timeoutInterval:18];
    [request setValue:@"Amethyst-iOS-ModBrowser/1.4" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    __block NSURLSessionDataTask *task = nil;
    task = [self.iconSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        BOOL validStatus = !http || (http.statusCode >= 200 && http.statusCode < 300);
        UIImage *image = (data.length && !error && validStatus) ? [UIImage imageWithData:data] : nil;
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (image && [self iconCachingEnabled]) {
            NSData *jpeg = UIImageJPEGRepresentation(image, 0.82);
            if (jpeg.length) [jpeg writeToFile:diskPath options:NSDataWritingAtomic error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (self.iconTasks[iconURL] == task) [self.iconTasks removeObjectForKey:iconURL];
            if (!image) {
                // Retry transient network/server/image-decoding failures instead of leaving a random blank icon.
                if (attempt < 2 && [self iconTasks][iconURL] == nil) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (![self.iconTasks objectForKey:iconURL]) {
                            [self requestIconURL:iconURL diskPath:diskPath tableView:tableView attempt:attempt + 1];
                        }
                    });
                }
                return;
            }
            if ([self iconCachingEnabled]) [self.iconCache setObject:image forKey:iconURL];
            for (ModProjectCell *visible in tableView.visibleCells) {
                NSIndexPath *visiblePath = [tableView indexPathForCell:visible];
                if (visiblePath && visiblePath.row < self.projects.count) {
                    NSDictionary *visibleProject = self.projects[visiblePath.row];
                    if ([visible.projectID isEqualToString:visibleProject[@"project_id"]] &&
                        [visibleProject[@"icon_url"] isEqualToString:iconURL]) {
                        visible.modIcon.image = image;
                    }
                }
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
    NSNumber *downloads = project[@"downloads"];
    cell.downloadsLabel.text = downloads ? [NSString stringWithFormat:@"%@ downloads", [NSNumberFormatter localizedStringFromNumber:downloads numberStyle:NSNumberFormatterDecimalStyle]] : @"";
    cell.modIcon.image = [UIImage systemImageNamed:@"shippingbox"];
    NSString *iconURL = [project[@"icon_url"] isKindOfClass:NSString.class] ? project[@"icon_url"] : @"";
    BOOL iconCachingEnabled = [self iconCachingEnabled];
    UIImage *cached = (iconCachingEnabled && iconURL.length) ? [self.iconCache objectForKey:iconURL] : nil;
    if (cached) {
        cell.modIcon.image = cached;
    } else if (iconURL.length) {
        NSString *cacheKey = [[[iconURL dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        cacheKey = [cacheKey stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
        cacheKey = [cacheKey stringByReplacingOccurrencesOfString:@"=" withString:@""];
        NSString *diskPath = [self.iconDiskCacheDirectory stringByAppendingPathComponent:[cacheKey stringByAppendingString:@".jpg"]];
        UIImage *diskImage = iconCachingEnabled ? [UIImage imageWithContentsOfFile:diskPath] : nil;
        if (diskImage) {
            [self.iconCache setObject:diskImage forKey:iconURL];
            cell.modIcon.image = diskImage;
        }
        if (!self.iconTasks[iconURL]) {
            [self requestIconURL:iconURL diskPath:diskPath tableView:tableView attempt:0];
        }
    }
    cell.nameLabel.text = [project[@"title"] isKindOfClass:NSString.class] ? project[@"title"] : @"Untitled project";
    NSString *shortDescription = [project[@"description"] isKindOfClass:NSString.class] ? project[@"description"] : ([project[@"summary"] isKindOfClass:NSString.class] ? project[@"summary"] : @"");
    cell.descriptionLabel.text = shortDescription.length ? shortDescription : @"No description available.";
    cell.descriptionLabel.numberOfLines = 2;
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
    NSString *projectType = [project[@"project_type"] isKindOfClass:NSString.class] ? project[@"project_type"] : self.projectType;
    NSString *downloadActionTitle = [projectType isEqualToString:@"mod"] ? @"Download .jar" : @"Download archive";
    [alert addAction:[UIAlertAction actionWithTitle:downloadActionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
- (NSString *)downloadDirectoryForProjectType:(NSString *)projectType {
    NSString *base = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ST Mod Browser"];
    NSString *folder = [projectType isEqualToString:@"resourcepack"] ? @"resourcepacks" :
        ([projectType isEqualToString:@"shader"] ? @"shaderpacks" :
        ([projectType isEqualToString:@"datapack"] ? @"datapacks" : @"mods"));
    return [base stringByAppendingPathComponent:folder];
}
- (void)insertVersionDot:(UIBarButtonItem *)sender {
    UITextField *field = self.customVersionField;
    if (field) [field replaceRange:field.selectedTextRange withText:@"."];
}
- (void)dismissVersionKeyboard { [self.customVersionField resignFirstResponder]; }
- (void)downloadVersion:(NSDictionary *)version project:(NSDictionary *)project {
    NSDictionary *file = nil;
    NSArray *files = [version[@"files"] isKindOfClass:NSArray.class] ? version[@"files"] : @[];
    NSString *projectType = [project[@"project_type"] isKindOfClass:NSString.class] ? project[@"project_type"] : self.projectType;
    NSString *targetExtension = [projectType isEqualToString:@"mod"] ? @".jar" : @".zip";
    for (NSDictionary *candidate in files) if ([[candidate[@"filename"] lowercaseString] hasSuffix:targetExtension] && [candidate[@"primary"] boolValue]) { file = candidate; break; }
    if (!file) for (NSDictionary *candidate in files) if ([[candidate[@"filename"] lowercaseString] hasSuffix:targetExtension]) { file = candidate; break; }
    if (!file) { [self showMessage:[NSString stringWithFormat:@"No downloadable %@ file was found for this version.", targetExtension] title:@"Download unavailable"]; return; }
    NSURL *url = [NSURL URLWithString:file[@"url"] ?: @""];
    if (!url || !url.scheme.length) { [self showMessage:@"This version has no accessible download URL." title:@"Download failed"]; return; }
    NSString *directory = [self downloadDirectoryForProjectType:projectType];
    NSString *filename = file[@"filename"] ?: url.lastPathComponent;
    NSString *destination = [directory stringByAppendingPathComponent:filename];
    BOOL background = [[NSUserDefaults standardUserDefaults] boolForKey:@"STBackgroundDownloadsEnabled"];
    if (background) {
        [[STDownloadCoordinator shared] startURL:url destination:destination filename:filename title:project[@"title"] ?: filename project:project turbo:[[NSUserDefaults standardUserDefaults] boolForKey:@"ModBrowserTurboDownloadsEnabled"]];
        [self showMessage:[NSString stringWithFormat:@"%@ was added to the Download Manager. You can leave this screen while it downloads.", filename] title:@"Download started"];
        return;
    }
    NSError *directoryError = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        [self showMessage:directoryError.localizedDescription ?: @"Could not create the download folder." title:@"Cannot create folder"]; return;
    }
    if ([NSFileManager.defaultManager fileExistsAtPath:destination]) {
        [self showMessage:[NSString stringWithFormat:@"%@ is already downloaded.", filename] title:@"Already downloaded"]; return;
    }
    BOOL turbo = [[NSUserDefaults standardUserDefaults] boolForKey:@"ModBrowserTurboDownloadsEnabled"];
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration.defaultSessionConfiguration copy];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.timeoutIntervalForResource = turbo ? 240 : 180;
    configuration.HTTPMaximumConnectionsPerHost = turbo ? 12 : 8;
    configuration.URLCache = nil;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url]; request.timeoutInterval = 45;
    [request setValue:@"Amethyst-iOS-ModBrowser/1.4" forHTTPHeaderField:@"User-Agent"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Downloading…" message:filename preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSError *saveError = error;
        if (!saveError && [response isKindOfClass:NSHTTPURLResponse.class]) {
            NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
            if (code < 200 || code >= 300) saveError = [NSError errorWithDomain:@"ModBrowserDownload" code:code userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Download server returned HTTP %ld.", (long)code]}];
        }
        if (!saveError && location) {
            [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&saveError];
            if (!saveError && ![NSFileManager.defaultManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&saveError]) {}
        } else if (!saveError) saveError = [NSError errorWithDomain:@"ModBrowserDownload" code:5 userInfo:@{NSLocalizedDescriptionKey:@"The server did not return a file."}];
        dispatch_async(dispatch_get_main_queue(), ^{
            [session finishTasksAndInvalidate];
            [alert dismissViewControllerAnimated:YES completion:^{
                if (saveError) [self showMessage:saveError.localizedDescription ?: @"Download failed." title:@"Download failed"];
                else [self showMessage:[NSString stringWithFormat:@"%@ was downloaded to:\n%@", filename, directory] title:@"Download complete"];
            }];
        });
    }];
    if (turbo) task.priority = NSURLSessionTaskPriorityHigh;
    [task resume];
}
- (void)updateDownloadProgress {
    NSURLSessionDownloadTask *task = self.activeDownloadTask;
    UIAlertController *alert = self.activeDownloadAlert;
    if (!task || !alert || !alert.presentingViewController) return;
    int64_t received = task.countOfBytesReceived;
    int64_t expected = task.countOfBytesExpectedToReceive;
    alert.message = expected > 0 ? [NSString stringWithFormat:@"%@ · %.0f%%", self.activeDownloadFilename ?: @"File", MIN(100.0, (double)received * 100.0 / (double)expected)] : [NSString stringWithFormat:@"%@ · %@", self.activeDownloadFilename ?: @"File", [NSByteCountFormatter stringFromByteCount:received countStyle:NSByteCountFormatterCountStyleFile]];
}
- (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
