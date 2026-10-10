#import <UIKit/UIKit.h>

@interface ModBrowserViewController : UITableViewController <UISearchResultsUpdating>
@end

@interface STLauncherModeViewController : UIViewController
- (NSString *)imageName;
@end

@interface STLauncherHomeViewController : UIViewController
- (NSString *)imageName;
@end

@interface STLauncherDownloadsViewController : UITableViewController
- (NSString *)imageName;
@end

@interface STLauncherSettingsViewController : UITableViewController
- (NSString *)imageName;
@end

@interface STLauncherExperimentalFeaturesViewController : UITableViewController
- (NSString *)imageName;
@end
