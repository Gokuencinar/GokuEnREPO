#import "BLCountryDetailViewController.h"
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"

@interface BLCountryDetailViewController ()
@property (nonatomic, copy) NSDictionary *country;
@property (nonatomic, copy) NSString *datasetDate;
@property (nonatomic, copy) NSString *sourceName;
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, copy) NSArray<NSNumber *> *countryBands;
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
    self.countryBands = BLSortedBands(self.country[@"bands"]);
    self.title = [self localizedCountryName];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }

- (NSString *)localizedCountryName {
    NSString *iso = self.country[@"iso2"];
    if ([iso isKindOfClass:[NSString class]] && iso.length == 2) {
        NSString *localized = [NSLocale.currentLocale localizedStringForCountryCode:iso];
        if (localized.length) return localized;
    }
    return self.country[@"name"] ?: @"—";
}

- (NSArray<NSNumber *> *)compatibleBands {
    return BLIntersectBands(self.manager.supportedBands, self.countryBands);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 3;
    if (section == 1) return self.countryBands.count;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Resumen", @"Summary");
    if (section == 1) return BLT(@"Bandas LTE de referencia", @"Reference LTE bands");
    return BLT(@"Preparar selección", @"Prepare selection");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return BLT(@"✓ indica que esa banda también aparece entre las soportadas por el módem de este iPhone. La lista del país es orientativa y puede variar por operador y zona.", @"✓ means that band is also reported as supported by this iPhone modem. Country data is a reference and may vary by carrier and location.");
    if (section == 2) return BLT(@"El botón solo copia la intersección país ∩ iPhone a la selección pendiente. No aplica ningún cambio automáticamente.", @"The button only copies the country ∩ iPhone intersection into the pending selection. It never applies changes automatically.");
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
        if (indexPath.row == 1) return [self summaryCell:BLT(@"Bandas del país", @"Country bands") value:self.countryBands.count ? BLBandList(self.countryBands) : BLT(@"Sin datos", @"No data")];
        return [self summaryCell:BLT(@"Compatibles con iPhone", @"Compatible with iPhone") value:self.manager.supportedBands.count ? BLBandList([self compatibleBands]) : BLT(@"Actualiza Control primero", @"Refresh Control first")];
    }

    if (indexPath.section == 1) {
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

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    BOOL ready = self.manager.supportedBands.count > 0 && [self compatibleBands].count > 0;
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
        NSArray *compatible = [self compatibleBands];
        if (!compatible.count) {
            [self showAlert:BLT(@"Este iPhone no reporta ninguna de las bandas LTE listadas para este país.", @"This iPhone does not report any of the LTE bands listed for this country.")];
            return;
        }
        [self.manager setPendingBands:compatible];
        NSString *message = [NSString stringWithFormat:BLT(@"Selección preparada: %@\n\nRevísala y pulsa Aplicar desde Control.", @"Selection prepared: %@\n\nReview it and tap Apply from Control."), BLBandList(compatible)];
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
    if (!self.manager.supportedBands.count) {
        [self showAlert:BLT(@"Pulsa «Actualizar estado» en Control antes de preparar un país.", @"Tap “Refresh status” in Control before preparing a country.")];
        return;
    }
    [self prepareCompatibleBands];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
