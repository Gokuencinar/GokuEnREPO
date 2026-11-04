#import "BLCountriesViewController.h"
#import "BLCountryDetailViewController.h"
#import "BLCommon.h"
#import "BLCountryProfile.h"

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
    return BLLocalizedCountryName(country);
}

- (void)loadDataset {
    NSArray *countries = BLAllCountryRecords();
    self.datasetDate = @"2026-10-21";
    self.sourceName = @"MCC-MNC.org + BandLock LTE/NR references";
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
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *country = self.filteredCountries[indexPath.row];
    NSArray *gsm = BLCountryFrequenciesForRAT(country, @"2G");
    NSArray *umts = BLCountryFrequenciesForRAT(country, @"3G");
    NSArray *bands = BLSortedBands(country[@"bands"]);
    NSArray *nrBands = BLSortedBands(country[@"nr_bands"]);
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = [self localizedNameForCountry:country];
    cell.detailTextLabel.text = [NSString stringWithFormat:
        BLT(@"2G: %lu frec. · 3G: %lu frec. · LTE: %lu · 5G: %lu",
            @"2G: %lu freq. · 3G: %lu freq. · LTE: %lu · 5G: %lu"),
        (unsigned long)gsm.count, (unsigned long)umts.count,
        (unsigned long)bands.count, (unsigned long)nrBands.count];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.selectCountryOnly) {
        BLSetSelectedCountry(self.filteredCountries[indexPath.row]);
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    @try {
        if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.filteredCountries.count) return;
        NSDictionary *country = self.filteredCountries[(NSUInteger)indexPath.row];
        BLCountryDetailViewController *detail = [[BLCountryDetailViewController alloc] initWithStyle:UITableViewStyleInsetGrouped country:country datasetDate:self.datasetDate sourceName:self.sourceName];
        [self.navigationController pushViewController:detail animated:YES];
    } @catch (NSException *exception) {
    }
}

@end
