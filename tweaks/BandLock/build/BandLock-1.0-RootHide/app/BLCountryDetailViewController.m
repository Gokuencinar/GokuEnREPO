#import "BLCountryDetailViewController.h"
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"
#import "BLCountryProfile.h"

@interface BLCountryDetailViewController ()
@property (nonatomic, copy) NSDictionary *country;
@property (nonatomic, copy) NSString *datasetDate;
@property (nonatomic, copy) NSString *sourceName;
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, copy) NSArray<NSNumber *> *country2GFrequencies;
@property (nonatomic, copy) NSArray<NSNumber *> *country3GFrequencies;
@property (nonatomic, copy) NSArray<NSNumber *> *countryBands;
@property (nonatomic, copy) NSArray<NSNumber *> *countryNRBands;
@end

@implementation BLCountryDetailViewController

- (instancetype)initWithStyle:(UITableViewStyle)style country:(NSDictionary *)country datasetDate:(NSString *)datasetDate sourceName:(NSString *)sourceName {
    self = [super initWithStyle:style];
    if (self) {
        _country = [country copy];
        _datasetDate = [datasetDate copy];
        _sourceName = [sourceName copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.manager = BLTelephonyManager.sharedManager;
    self.country2GFrequencies = BLCountryFrequenciesForRAT(self.country, @"2G");
    self.country3GFrequencies = BLCountryFrequenciesForRAT(self.country, @"3G");
    self.countryBands = BLSortedBands(self.country[@"bands"]);
    self.countryNRBands = BLSortedBands(self.country[@"nr_bands"]);
    self.title = [self localizedCountryName];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }

- (NSString *)localizedCountryName {
    return BLLocalizedCountryName(self.country);
}

- (NSString *)frequencyList:(NSArray<NSNumber *> *)values {
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:values.count];
    for (NSNumber *value in values) {
        if ([value isKindOfClass:NSNumber.class]) [parts addObject:value.stringValue];
    }
    return [parts componentsJoinedByString:@", "];
}

- (NSArray<NSNumber *> *)compatibleBands {
    return BLIntersectBands(self.manager.supportedBands, self.countryBands);
}

- (NSArray<NSNumber *> *)compatibleNRBands {
    return BLIntersectBands(self.manager.supportedNRBands, self.countryNRBands);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 6; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 9;
    if (section == 1) return self.country2GFrequencies.count;
    if (section == 2) return self.country3GFrequencies.count;
    if (section == 3) return self.countryBands.count;
    if (section == 4) return self.countryNRBands.count;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Resumen", @"Summary");
    if (section == 1) return BLT(@"Frecuencias 2G de referencia", @"Reference 2G frequencies");
    if (section == 2) return BLT(@"Frecuencias 3G de referencia", @"Reference 3G frequencies");
    if (section == 3) return BLT(@"Bandas LTE de referencia", @"Reference LTE bands");
    if (section == 4) return BLT(@"Bandas 5G NR de referencia", @"Reference 5G NR bands");
    return BLT(@"Preparar selección", @"Prepare selection");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1 || section == 2)
        return BLT(@"Referencia agregada de redes del país; no demuestra que la frecuencia siga activa en tu ubicación.",
                   @"Aggregated country network reference; it does not prove the frequency is still active at your location.");
    if (section == 3 || section == 4) return BLT(@"✓ Compatible con este iPhone.", @"✓ Compatible with this iPhone.");
    if (section == 5) return BLT(@"Cambios pendientes hasta pulsar Aplicar.", @"Changes pending until Apply.");
    return nil;
}

- (UITableViewCell *)summaryCell:(NSString *)title value:(NSString *)value {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = value ?: @"—";
    cell.detailTextLabel.numberOfLines = 2;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) return [self summaryCell:BLT(@"País", @"Country") value:[self localizedCountryName]];
        if (indexPath.row == 1) return [self summaryCell:@"2G" value:self.country2GFrequencies.count ? [NSString stringWithFormat:@"%@ MHz", [self frequencyList:self.country2GFrequencies]] : BLT(@"Sin datos", @"No data")];
        if (indexPath.row == 2) return [self summaryCell:@"3G" value:self.country3GFrequencies.count ? [NSString stringWithFormat:@"%@ MHz", [self frequencyList:self.country3GFrequencies]] : BLT(@"Sin datos", @"No data")];
        if (indexPath.row == 3) return [self summaryCell:BLT(@"Bandas LTE del país", @"Country LTE bands") value:self.countryBands.count ? BLBandList(self.countryBands) : BLT(@"Sin datos exactos", @"No exact data")];
        if (indexPath.row == 4) return [self summaryCell:BLT(@"LTE compatibles con iPhone", @"LTE compatible with iPhone") value:self.manager.hasReadState ? BLBandList([self compatibleBands]) : BLT(@"Actualiza Control primero", @"Refresh Control first")];
        if (indexPath.row == 5) return [self summaryCell:BLT(@"Bandas 5G del país", @"Country 5G bands") value:self.countryNRBands.count ? BLNRBandList(self.countryNRBands) : BLT(@"Sin datos 5G exactos", @"No exact 5G data")];
        if (indexPath.row == 6) return [self summaryCell:BLT(@"5G compatibles con iPhone", @"5G compatible with iPhone") value:self.manager.hasReadState ? BLNRBandList([self compatibleNRBands]) : BLT(@"Actualiza Control primero", @"Refresh Control first")];
        if (indexPath.row == 7) return [self summaryCell:BLT(@"Fuente", @"Source") value:self.sourceName ?: @"—"];
        return [self summaryCell:BLT(@"Datos actualizados", @"Data updated") value:self.datasetDate ?: @"—"];
    }

    if (indexPath.section == 1) {
        NSNumber *mhz = self.country2GFrequencies[indexPath.row];
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = [NSString stringWithFormat:@"GSM %@ MHz", mhz];
        cell.detailTextLabel.text = BLT(@"2G · referencia nacional", @"2G · country reference");
        return cell;
    }

    if (indexPath.section == 2) {
        NSNumber *mhz = self.country3GFrequencies[indexPath.row];
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = [NSString stringWithFormat:@"UMTS %@ MHz", mhz];
        cell.detailTextLabel.text = BLT(@"3G · referencia nacional", @"3G · country reference");
        return cell;
    }

    if (indexPath.section == 3) {
        NSNumber *band = self.countryBands[indexPath.row];
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = BLGBandTitle(band);
        NSString *frequency = BLGFrequencyForBand(band);
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", frequency.length ? frequency : BLT(@"Frecuencia sin catalogar", @"Frequency not catalogued"), BLGDuplexForBand(band)];
        if ([self.manager.supportedBands containsObject:band]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.tintColor = UIColor.systemGreenColor;
        }
        return cell;
    }

    if (indexPath.section == 4) {
        NSNumber *band = self.countryNRBands[indexPath.row];
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        cell.textLabel.text = BLGNRBandTitle(band);
        NSString *frequency = BLGNRFrequencyForBand(band);
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", frequency.length ? frequency : BLT(@"Frecuencia sin catalogar", @"Frequency not catalogued"), BLGNRDuplexForBand(band)];
        if ([self.manager.supportedNRBands containsObject:band]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.tintColor = UIColor.systemGreenColor;
        }
        return cell;
    }

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    BOOL ready = self.manager.hasReadState && ([self compatibleBands].count > 0 || [self compatibleNRBands].count > 0);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [button setTitle:(ready ? BLT(@"Preparar bandas compatibles", @"Prepare compatible bands") : BLT(@"Actualizar desde Control primero", @"Refresh from Control first")) forState:UIControlStateNormal];
    [button addTarget:self action:@selector(prepareButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [button.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [button.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [button.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:48]
    ]];
    return cell;
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)prepareCompatibleBands {
    @try {
        NSArray *compatibleLTE = [self compatibleBands];
        NSArray *compatibleNR = [self compatibleNRBands];
        if (!compatibleLTE.count && !compatibleNR.count) {
            [self showAlert:BLT(@"Este iPhone no reporta ninguna banda LTE o 5G NR compatible con las listadas para este país.", @"This iPhone does not report any LTE or 5G NR band compatible with those listed for this country.")];
            return;
        }
        BLSetSelectedCountry(self.country);
        if (compatibleLTE.count) [self.manager setPendingBands:compatibleLTE];
        if (compatibleNR.count) [self.manager setPendingNRBands:compatibleNR];
        NSString *message = [NSString stringWithFormat:BLT(@"LTE: %@\n5G NR: %@\n\nRevísalas y aplícalas por separado desde Control.", @"LTE: %@\n5G NR: %@\n\nReview and apply them separately from Control."), BLBandList(compatibleLTE), BLNRBandList(compatibleNR)];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Selección preparada", @"Selection prepared") message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Seguir aquí", @"Stay here") style:UIAlertActionStyleCancel handler:nil]];
        __weak typeof(self) weakSelf = self;
        [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Ir a Control", @"Go to Control") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            weakSelf.tabBarController.selectedIndex = 0;
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    @catch (NSException *exception) {
        [self showAlert:exception.reason ?: exception.name ?: @"NSException"];
    }
}

- (void)prepareButtonTapped:(UIButton *)sender {
    if (!self.manager.hasReadState) {
        [self showAlert:BLT(@"Pulsa «Actualizar estado» en Control antes de preparar un país.", @"Tap “Refresh status” in Control before preparing a country.")];
        return;
    }
    [self prepareCompatibleBands];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
