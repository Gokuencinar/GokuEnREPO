#import <UIKit/UIKit.h>

@interface BLCountryDetailViewController : UITableViewController
- (instancetype)initWithStyle:(UITableViewStyle)style country:(NSDictionary *)country datasetDate:(NSString *)datasetDate sourceName:(NSString *)sourceName;
@end
