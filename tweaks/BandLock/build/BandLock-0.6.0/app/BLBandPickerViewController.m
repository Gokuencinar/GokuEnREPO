#import "BLBandPickerViewController.h"
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"

@interface BLBandPickerViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selected;
@property (nonatomic, copy) NSArray<NSNumber *> *fddBands;
@property (nonatomic, copy) NSArray<NSNumber *> *tddBands;
@property (nonatomic, copy) NSArray<NSNumber *> *sdlBands;
@property (nonatomic, copy) NSArray<NSNumber *> *otherBands;
@end

@implementation BLBandPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Editar bandas", @"Edit bands");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.manager = BLTelephonyManager.sharedManager;
    self.selected = [NSMutableSet setWithArray:self.manager.pendingBands.count ? self.manager.pendingBands : self.manager.activeBands];
    [self rebuildGroups];
}

- (void)rebuildGroups {
    NSArray *all = self.manager.supportedBands ?: @[];
    self.fddBands = BLGBandsForDuplex(all, @"FDD");
    self.tddBands = BLGBandsForDuplex(all, @"TDD");
    self.sdlBands = BLGBandsForDuplex(all, @"SDL");
    NSSet *known = [NSSet setWithArray:[self.fddBands arrayByAddingObjectsFromArray:[self.tddBands arrayByAddingObjectsFromArray:self.sdlBands]]];
    NSMutableArray *other = [NSMutableArray array];
    for (NSNumber *band in all) if (![known containsObject:band]) [other addObject:band];
    self.otherBands = BLSortedBands(other);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 5; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 5;
    if (section == 1) return self.fddBands.count;
    if (section == 2) return self.tddBands.count;
    if (section == 3) return self.sdlBands.count;
    return self.otherBands.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Selección rápida", @"Quick selection");
    if (section == 1) return @"FDD";
    if (section == 2) return @"TDD";
    if (section == 3) return @"SDL";
    return BLT(@"Otras", @"Other");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Aquí solo preparas la selección. Volver a Control y pulsar Aplicar es lo que modifica el módem.", @"This only prepares the selection. Returning to Control and tapping Apply is what changes the modem.");
    if (section == 3 && self.sdlBands.count) return BLT(@"SDL es bajada suplementaria. No conviene usar únicamente bandas SDL.", @"SDL is supplemental downlink. Avoid selecting only SDL bands.");
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
            BLT(@"Selección activa actual", @"Current active selection"),
            BLT(@"Todas las soportadas", @"All supported"),
            BLT(@"Solo FDD", @"FDD only"),
            BLT(@"Solo TDD", @"TDD only"),
            BLT(@"Desmarcar todas", @"Clear all")
        ];
        NSArray *icons = @[@"antenna.radiowaves.left.and.right", @"checkmark.circle", @"arrow.left.and.right", @"clock.arrow.2.circlepath", @"xmark.circle"];
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = titles[indexPath.row];
        cell.imageView.image = [UIImage systemImageNamed:icons[indexPath.row]];
        cell.imageView.tintColor = indexPath.row == 4 ? UIColor.systemRedColor : UIColor.systemOrangeColor;
        return cell;
    }

    NSNumber *band = [self bandsForSection:indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = BLGBandTitle(band);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", BLGFrequencyForBand(band).length ? BLGFrequencyForBand(band) : BLT(@"Frecuencia sin catalogar", @"Frequency not catalogued"), BLGDuplexForBand(band)];
    cell.accessoryType = [self.selected containsObject:band] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)commitSelection {
    [self.manager setPendingBands:BLSortedBands(self.selected)];
}

- (void)setSelectedBands:(NSArray<NSNumber *> *)bands {
    self.selected = [NSMutableSet setWithArray:bands ?: @[]];
    [self commitSelection];
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        if (indexPath.row == 0) [self setSelectedBands:self.manager.activeBands];
        else if (indexPath.row == 1) [self setSelectedBands:self.manager.supportedBands];
        else if (indexPath.row == 2) [self setSelectedBands:self.fddBands];
        else if (indexPath.row == 3) [self setSelectedBands:self.tddBands];
        else [self setSelectedBands:@[]];
        return;
    }

    NSNumber *band = [self bandsForSection:indexPath.section][indexPath.row];
    if ([self.selected containsObject:band]) [self.selected removeObject:band];
    else [self.selected addObject:band];
    [self commitSelection];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end
