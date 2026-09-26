#import "BLLanguageViewController.h"
#import "BLLocalization.h"
#import "BLCommon.h"

@interface BLLanguageViewController ()
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *languages;
@end

@implementation BLLanguageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Idioma", @"Language");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.languages = BLLanguageOptions();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.languages.count; }

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return BLT(@"El idioma se aplica inmediatamente y queda guardado para próximos inicios de BandLock.",
               @"The language is applied immediately and saved for future BandLock launches.");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *language = self.languages[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = language[@"name"];
    cell.accessoryType = [language[@"code"] isEqualToString:BLCurrentLanguageCode()] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.languages.count) return;
    BLSetLanguageCode(self.languages[indexPath.row][@"code"]);
}

@end
