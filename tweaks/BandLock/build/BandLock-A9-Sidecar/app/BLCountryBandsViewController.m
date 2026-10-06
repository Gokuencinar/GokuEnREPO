#import "BLCountryBandsViewController.h"
#import "BLTelephonyManager.h"
#import "BLCountryProfile.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"

@interface BLCountryBandsViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, copy) NSDictionary *country;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selected;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selectedNR;
@property (nonatomic, copy) NSArray<NSNumber *> *availableBands;
@property (nonatomic, copy) NSArray<NSNumber *> *availableNRBands;
@property (nonatomic, copy) NSArray<NSNumber *> *fddBands;
@property (nonatomic, copy) NSArray<NSNumber *> *tddBands;
@property (nonatomic, copy) NSArray<NSNumber *> *sdlBands;
@property (nonatomic, copy) NSArray<NSNumber *> *otherBands;
@end

@implementation BLCountryBandsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.manager = BLTelephonyManager.sharedManager;
    self.country = BLSelectedCountryRecord();
    NSString *name = BLLocalizedCountryName(self.country);
    self.title = [NSString stringWithFormat:BLT(@"Frecuencias de %@", @"Frequencies for %@"), name];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    NSArray *countryBands = BLSortedBands(self.country[@"bands"]);
    self.availableBands = BLIntersectBands(self.manager.supportedBands, countryBands);
    NSArray *countryNRBands = BLSortedBands(self.country[@"nr_bands"]);
    self.availableNRBands = BLIntersectBands(self.manager.supportedNRBands, countryNRBands);

    NSArray *pending = BLIntersectBands(self.manager.pendingBands, self.availableBands);
    NSArray *active = BLIntersectBands(self.manager.activeBands, self.availableBands);
    NSArray *initial = pending.count ? pending : (active.count ? active : self.availableBands);
    self.selected = [NSMutableSet setWithArray:initial];
    NSArray *pendingNR = BLIntersectBands(self.manager.pendingNRBands, self.availableNRBands);
    NSArray *activeNR = BLIntersectBands(self.manager.activeNRBands, self.availableNRBands);
    NSArray *initialNR = pendingNR.count ? pendingNR : (activeNR.count ? activeNR : self.availableNRBands);
    self.selectedNR = [NSMutableSet setWithArray:initialNR];
    [self rebuildGroups];
}

- (void)rebuildGroups {
    self.fddBands = BLGBandsForDuplex(self.availableBands, @"FDD");
    self.tddBands = BLGBandsForDuplex(self.availableBands, @"TDD");
    self.sdlBands = BLGBandsForDuplex(self.availableBands, @"SDL");
    NSSet *known = [NSSet setWithArray:[self.fddBands arrayByAddingObjectsFromArray:[self.tddBands arrayByAddingObjectsFromArray:self.sdlBands]]];
    NSMutableArray *other = [NSMutableArray array];
    for (NSNumber *band in self.availableBands) if (![known containsObject:band]) [other addObject:band];
    self.otherBands = BLSortedBands(other);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 6; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return self.fddBands.count;
    if (section == 2) return self.tddBands.count;
    if (section == 3) return self.sdlBands.count;
    if (section == 4) return self.otherBands.count;
    return self.availableNRBands.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Frecuencias disponibles", @"Available frequencies");
    if (section == 1) return @"FDD";
    if (section == 2) return @"TDD";
    if (section == 3) return @"SDL";
    if (section == 4) return BLT(@"Otras LTE", @"Other LTE");
    return @"5G NR";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return BLT(@"Aquí solo cambias la selección pendiente. Pulsa Aplicar en Control para modificar el módem.",
                   @"Changes here only update the pending selection. Tap Apply in Control to change the modem.");
    }
    if (section == 3 && self.sdlBands.count) return BLT(@"SDL es bajada suplementaria. No conviene usar únicamente bandas SDL.", @"SDL is supplemental downlink. Avoid selecting only SDL bands.");
    if (section == 5 && self.availableNRBands.count) return BLT(@"Las bandas nXX se preparan como una selección 5G separada. Usa «Aplicar selección 5G» en Control para escribirlas.", @"The nXX bands are prepared as a separate 5G selection. Use “Apply 5G selection” in Control to write them.");
    return nil;
}

- (NSArray<NSNumber *> *)bandsForSection:(NSInteger)section {
    if (section == 1) return self.fddBands;
    if (section == 2) return self.tddBands;
    if (section == 3) return self.sdlBands;
    if (section == 4) return self.otherBands;
    return @[];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSArray *titles = @[
            BLT(@"Seleccionar todas las LTE del país", @"Select all country LTE bands"),
            BLT(@"Usar las LTE activas actuales", @"Use current active LTE bands"),
            BLT(@"Seleccionar todas las 5G del país", @"Select all country 5G bands"),
            BLT(@"Usar las 5G activas actuales", @"Use current active 5G bands")
        ];
        NSArray *symbols = @[@"checkmark.circle", @"4g.lte", @"checkmark.circle", @"5g"];
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = titles[indexPath.row];
        cell.imageView.image = [UIImage systemImageNamed:symbols[indexPath.row]];
        cell.textLabel.textColor = UIColor.systemBlueColor;
        cell.imageView.tintColor = UIColor.systemBlueColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    BOOL nr = indexPath.section == 5;
    NSNumber *band = nr ? self.availableNRBands[indexPath.row] : [self bandsForSection:indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = nr ? BLGNRBandTitle(band) : BLGBandTitle(band);
    NSString *frequency = nr ? BLGNRFrequencyForBand(band) : BLGFrequencyForBand(band);
    NSString *duplex = nr ? BLGNRDuplexForBand(band) : BLGDuplexForBand(band);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", frequency.length ? frequency : BLT(@"Frecuencia sin catalogar", @"Frequency not catalogued"), duplex];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    BOOL selected = nr ? [self.selectedNR containsObject:band] : [self.selected containsObject:band];
    cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)commitSelection {
    if (self.availableBands.count) [self.manager setPendingBands:BLSortedBands(self.selected)];
    if (self.availableNRBands.count) [self.manager setPendingNRBands:BLSortedBands(self.selectedNR)];
}

- (void)setSelectedNRBands:(NSArray<NSNumber *> *)bands {
    NSArray *safe = BLIntersectBands(self.availableNRBands, bands);
    self.selectedNR = [NSMutableSet setWithArray:safe];
    [self commitSelection];
    [self.tableView reloadData];
}

- (void)setSelectedBands:(NSArray<NSNumber *> *)bands {
    NSArray *safe = BLIntersectBands(self.availableBands, bands);
    self.selected = [NSMutableSet setWithArray:safe];
    [self commitSelection];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        if (indexPath.row == 0) [self setSelectedBands:self.availableBands];
        else if (indexPath.row == 1) [self setSelectedBands:BLIntersectBands(self.manager.activeBands, self.availableBands)];
        else if (indexPath.row == 2) [self setSelectedNRBands:self.availableNRBands];
        else [self setSelectedNRBands:BLIntersectBands(self.manager.activeNRBands, self.availableNRBands)];
        return;
    }
    NSArray<NSNumber *> *bands = indexPath.section == 5 ? self.availableNRBands : [self bandsForSection:indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)bands.count) return;
    NSNumber *band = bands[(NSUInteger)indexPath.row];
    NSMutableSet *target = indexPath.section == 5 ? self.selectedNR : self.selected;
    if ([target containsObject:band]) [target removeObject:band];
    else [target addObject:band];
    [self commitSelection];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end
