#import "BLCountriesViewController.h"
#import "BLCountryDetailViewController.h"
#import "BLCommon.h"
#import "BLDiagnostics.h"

@interface BLCountriesViewController () <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<NSDictionary *> *countries;
@property (nonatomic, copy) NSArray<NSDictionary *> *filteredCountries;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSString *datasetDate;
@property (nonatomic, copy) NSString *sourceName;
@end

@implementation BLCountriesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Países", @"Countries");
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.tableView.rowHeight = 62.0;
    [self loadDataset];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = BLT(@"Buscar país", @"Search country");
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (NSString *)localizedNameForCountry:(NSDictionary *)country {
    NSString *iso = country[@"iso2"];
    if ([iso isKindOfClass:[NSString class]] && iso.length == 2) {
        NSString *localized = [NSLocale.currentLocale localizedStringForCountryCode:iso];
        if (localized.length) return localized;
    }
    return country[@"name"] ?: @"—";
}

- (void)loadDataset {
    NSString *path = [NSBundle.mainBundle pathForResource:@"countries" ofType:@"json"];
    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    NSDictionary *root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSArray *countries = [root[@"countries"] isKindOfClass:[NSArray class]] ? root[@"countries"] : @[];
    self.datasetDate = [root[@"last_updated"] isKindOfClass:[NSString class]] ? root[@"last_updated"] : @"—";
    NSDictionary *source = [root[@"source"] isKindOfClass:[NSDictionary class]] ? root[@"source"] : @{};
    self.sourceName = [source[@"name"] isKindOfClass:[NSString class]] ? source[@"name"] : @"—";
    self.countries = [countries sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [[self localizedNameForCountry:a] localizedCaseInsensitiveCompare:[self localizedNameForCountry:b]];
    }];
    self.filteredCountries = self.countries;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!query.length) self.filteredCountries = self.countries;
    else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *country, NSDictionary *bindings) {
            NSString *localized = [self localizedNameForCountry:country];
            NSString *english = country[@"name"] ?: @"";
            NSString *iso = country[@"iso2"] ?: @"";
            return [localized rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound ||
                   [english rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound ||
                   [iso rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }];
        self.filteredCountries = [self.countries filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.filteredCountries.count; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:BLT(@"%lu países y territorios", @"%lu countries and territories"), (unsigned long)self.filteredCountries.count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [NSString stringWithFormat:BLT(@"Datos de referencia LTE · %@ · actualización %@. Las bandas reales dependen del operador, región, roaming y fecha.", @"LTE reference data · %@ · updated %@. Actual bands vary by carrier, region, roaming and time."), self.sourceName ?: @"—", self.datasetDate ?: @"—"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *country = self.filteredCountries[indexPath.row];
    NSArray *bands = BLSortedBands(country[@"bands"]);
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = [self localizedNameForCountry:country];
    cell.detailTextLabel.text = bands.count ? BLBandList(bands) : BLT(@"Sin bandas LTE verificadas en el conjunto de datos", @"No verified LTE bands in the dataset");
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    BLDiagLog([NSString stringWithFormat:@"country row tap %ld", (long)indexPath.row]);
    @try {
        if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.filteredCountries.count) return;
        NSDictionary *country = self.filteredCountries[(NSUInteger)indexPath.row];
        BLCountryDetailViewController *detail = [[BLCountryDetailViewController alloc] initWithStyle:UITableViewStyleInsetGrouped country:country datasetDate:self.datasetDate sourceName:self.sourceName];
        [self.navigationController pushViewController:detail animated:YES];
    } @catch (NSException *exception) {
        BLDiagLog([NSString stringWithFormat:@"country navigation exception %@ %@", exception.name, exception.reason]);
    }
}

@end
