#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIContentModule-Protocol.h>
#import <ControlCenterUIKit/CCUIContentModuleContentViewController-Protocol.h>

@interface CCUIMenuModuleItem : NSObject
@property (getter=isBusy, nonatomic) BOOL busy;
@property (nonatomic, copy) id handler;
@property (nonatomic, copy) NSString *identifier;
@property (getter=isSelected, nonatomic) BOOL selected;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *title;
- (instancetype)initWithTitle:(NSString *)title identifier:(NSString *)identifier handler:(id)handler;
@end

@interface CCUIMenuModuleViewController : UIViewController <CCUIContentModuleContentViewController>
@property (getter=isBusy, nonatomic) BOOL busy;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) BOOL hideGlyphInHeader;
@property (nonatomic) BOOL useTallLayout;
@property (nonatomic) BOOL useTrailingCheckmarkLayout;
@property (nonatomic) BOOL useTrailingInset;
@property (nonatomic) double visibleMenuItems;
@property (nonatomic) unsigned long long minimumMenuItems;
- (void)setGlyphImage:(UIImage *)image;
- (void)setMenuItems:(NSArray *)items;
- (BOOL)shouldBeginTransitionToExpandedContentModule;
@end

@interface BLCCMenuViewController : CCUIMenuModuleViewController
@end

@interface BLCCModule : NSObject <CCUIContentModule>
@property (nonatomic, strong, readonly) BLCCMenuViewController *contentViewController;
@property (nonatomic, strong, readonly) UIViewController *backgroundViewController;
@end
