#import "AppDelegate.h"
#import "ChatViewController.h"

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.rootViewController = [[ChatViewController alloc] init];
	[self.window makeKeyAndVisible];
	return YES;
}
@end
