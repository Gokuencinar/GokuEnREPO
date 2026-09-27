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
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.tag = indexPath.row;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        [button setTitle:titles[indexPath.row] forState:UIControlStateNormal];
        [button setImage:[UIImage systemImageNamed:icons[indexPath.row]] forState:UIControlStateNormal];
        button.tintColor = indexPath.row == 4 ? UIColor.systemRedColor : UIColor.systemBlueColor;
        [button setTitleColor:button.tintColor forState:UIControlStateNormal];
        [button addTarget:self action:@selector(quickActionTapped:) forControlEvents:UIControlEventTouchUpInside];
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

    NSNumber *band = [self bandsForSection:indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = BLGBandTitle(band);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", BLGFrequencyForBand(band).length ? BLGFrequencyForBand(band) : BLT(@"Frecuencia sin catalogar", @"Frequency not catalogued"), BLGDuplexForBand(band)];
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
    self.selected = [NSMutableSet setWithArray:bands ?: @[]];
    [self commitSelection];
    [self.tableView reloadData];
}

- (void)quickActionTapped:(UIButton *)sender {
    @try {
        if (sender.tag == 0) [self setSelectedBands:self.manager.activeBands];
        else if (sender.tag == 1) [self setSelectedBands:self.manager.supportedBands];
        else if (sender.tag == 2) [self setSelectedBands:self.fddBands];
        else if (sender.tag == 3) [self setSelectedBands:self.tddBands];
        else [self setSelectedBands:@[]];
    } @catch (NSException *exception) {
    }
}

- (void)bandSwitchChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 1000;
    NSInteger row = sender.tag % 1000;
    @try {
        NSArray<NSNumber *> *sectionBands = [self bandsForSection:section];
        if (row < 0 || row >= (NSInteger)sectionBands.count) return;
        NSNumber *band = sectionBands[(NSUInteger)row];
        if (sender.isOn) [self.selected addObject:band];
        else [self.selected removeObject:band];
        [self commitSelection];
    } @catch (NSException *exception) {
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
