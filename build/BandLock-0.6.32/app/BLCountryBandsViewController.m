#import "BLCountryBandsViewController.h"
#import "BLTelephonyManager.h"
#import "BLCountryProfile.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"

@interface BLCountryBandsViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, copy) NSDictionary *country;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selected;
@property (nonatomic, copy) NSArray<NSNumber *> *availableBands;
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

    NSArray *pending = BLIntersectBands(self.manager.pendingBands, self.availableBands);
    NSArray *active = BLIntersectBands(self.manager.activeBands, self.availableBands);
    NSArray *initial = pending.count ? pending : (active.count ? active : self.availableBands);
    self.selected = [NSMutableSet setWithArray:initial];
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 5; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return self.fddBands.count;
    if (section == 2) return self.tddBands.count;
    if (section == 3) return self.sdlBands.count;
    return self.otherBands.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Frecuencias disponibles", @"Available frequencies");
    if (section == 1) return @"FDD";
    if (section == 2) return @"TDD";
    if (section == 3) return @"SDL";
    return BLT(@"Otras", @"Other");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return BLT(@"AquÃ­ solo cambias la selecciÃ³n pendiente. Pulsa Aplicar en Control para modificar el mÃ³dem.",
                   @"Changes here only update the pending selection. Tap Apply in Control to change the modem.");
    }
    if (section == 3 && self.sdlBands.count) return BLT(@"SDL es bajada suplementaria. No conviene usar Ãºnicamente bandas SDL.", @"SDL is supplemental downlink. Avoid selecting only SDL bands.");
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
            BLT(@"Seleccionar todas las del paÃ­s", @"Select all country bands"),
            BLT(@"Usar las activas actuales del paÃ­s", @"Use current active country bands")
        ];
        NSArray *symbols = @[@"checkmark.circle", @"antenna.radiowaves.left.and.right"];
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = titles[indexPath.row];
        cell.imageView.image = [UIImage systemImageNamed:symbols[indexPath.row]];
        cell.textLabel.textColor = UIColor.systemBlueColor;
        cell.imageView.tintColor = UIColor.systemBlueColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    NSNumber *band = [self bandsForSection:indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = BLGBandTitle(band);
    NSString *frequency = BLGFrequencyForBand(band);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ Â· %@", frequency.length ? frequency : BLT(@"Frecuencia sin catalogar", @"Frequency not catalogued"), BLGDuplexForBand(band)];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = [self.selected containsObject:band];
    toggle.tag = indexPath.section * 1000 + indexPath.row;
    [toggle addTarget:self action:@selector(bandSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)commitSelection {
    [self.manager setPendingBands:BLSortedBands(self.selected)];
}

- (void)setSelectedBands:(NSArray<NSNumber *> *)bands {
    NSArray *safe = BLIntersectBands(self.availableBands, bands);
    self.selected = [NSMutableSet setWithArray:safe];
    [self commitSelection];
    [self.tableView reloadData];
}

- (void)bandSwitchChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 1000;
    NSInteger row = sender.tag % 1000;
    NSArray *bands = [self bandsForSection:section];
    if (row < 0 || row >= (NSInteger)bands.count) return;
    NSNumber *band = bands[(NSUInteger)row];
    if (sender.isOn) [self.selected addObject:band]; else [self.selected removeObject:band];
    [self commitSelection];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 0) return;
    if (indexPath.row == 0) [self setSelectedBands:self.availableBands];
    else [self setSelectedBands:BLIntersectBands(self.manager.activeBands, self.availableBands)];
}

@end
