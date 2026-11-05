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

- (UIView *)compatibilityLegendView {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 66.0)];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIStackView *legend = [UIStackView new];
    legend.axis = UILayoutConstraintAxisVertical;
    legend.spacing = 4.0;
    legend.translatesAutoresizingMaskIntoConstraints = NO;

    NSArray<NSString *> *symbols = @[@"checkmark.circle.fill", @"xmark.circle.fill"];
    NSArray<UIColor *> *colors = @[UIColor.systemGreenColor, UIColor.systemRedColor];
    NSArray<NSString *> *texts = @[
        BLT(@"Compatible con este iPhone", @"Compatible with this iPhone"),
        BLT(@"No compatible con este iPhone", @"Not compatible with this iPhone")
    ];
    for (NSUInteger i = 0; i < symbols.count; i++) {
        UIStackView *row = [UIStackView new];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.alignment = UIStackViewAlignmentCenter;
        row.spacing = 7.0;

        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbols[i]]];
        icon.tintColor = colors[i];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [icon.widthAnchor constraintEqualToConstant:17.0],
            [icon.heightAnchor constraintEqualToConstant:17.0]
        ]];

        UILabel *label = [UILabel new];
        label.text = texts[i];
        label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        label.textColor = UIColor.secondaryLabelColor;
        [row addArrangedSubview:icon];
        [row addArrangedSubview:label];
        [legend addArrangedSubview:row];
    }

    [container addSubview:legend];
    [NSLayoutConstraint activateConstraints:@[
        [legend.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20.0],
        [legend.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-20.0],
        [legend.topAnchor constraintEqualToAnchor:container.topAnchor constant:8.0],
        [legend.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-8.0]
    ]];
    return container;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Países", @"Countries");
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.tableView.rowHeight = 62.0;
    if (!self.selectCountryOnly) self.tableView.tableHeaderView = [self compatibilityLegendView];
    [self loadDataset];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = BLT(@"Buscar país", @"Search country");
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
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
    NSString *iso = [country[@"iso2"] isKindOfClass:NSString.class] ? [country[@"iso2"] uppercaseString] : @"";
    BOOL selected = iso.length == 2 && [iso isEqualToString:BLSelectedCountryISO() ?: @""];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryDisclosureIndicator;
    cell.tintColor = UIColor.systemGreenColor;
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
