#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIContentModule-Protocol.h>
#import <ControlCenterUIKit/CCUIContentModuleContentViewController-Protocol.h>

@interface BLCCContentViewController : UIViewController <CCUIContentModuleContentViewController>
@end

@interface BLCCModule : NSObject <CCUIContentModule>
@property (nonatomic, strong, readonly) BLCCContentViewController *contentViewController;
@property (nonatomic, strong, readonly) UIViewController *backgroundViewController;
@end
