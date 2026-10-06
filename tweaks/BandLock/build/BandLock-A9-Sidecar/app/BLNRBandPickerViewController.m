#import "BLNRBandPickerViewController.h"
#import "BLTelephonyManager.h"
#import "BLCommon.h"
#import "BLGBandMetadata.h"

@interface BLNRBandPickerViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selected;
@property (nonatomic, copy) NSArray<NSNumber *> *fddBands;
@property (nonatomic, copy) NSArray<NSNumber *> *tddBands;
@property (nonatomic, copy) NSArray<NSNumber *> *sdlBands;
@property (nonatomic, copy) NSArray<NSNumber *> *otherBands;
@end

@implementation BLNRBandPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Editar bandas 5G NR", @"Edit 5G NR bands");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.manager = BLTelephonyManager.sharedManager;
    self.selected = [NSMutableSet setWithArray:self.manager.pendingNRBands.count ? self.manager.pendingNRBands : self.manager.activeNRBands];
    [self rebuildGroups];
}

- (void)rebuildGroups {
    NSMutableArray *fdd = [NSMutableArray array], *tdd = [NSMutableArray array], *sdl = [NSMutableArray array], *other = [NSMutableArray array];
    for (NSNumber *band in self.manager.supportedNRBands ?: @[]) {
        NSString *duplex = [BLGNRDuplexForBand(band) uppercaseString];
        if ([duplex hasPrefix:@"FDD"]) [fdd addObject:band];
        else if ([duplex hasPrefix:@"TDD"]) [tdd addObject:band];
        else if ([duplex hasPrefix:@"SDL"]) [sdl addObject:band];
        else [other addObject:band];
    }
    self.fddBands = BLSortedBands(fdd);
    self.tddBands = BLSortedBands(tdd);
    self.sdlBands = BLSortedBands(sdl);
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
    if (section == 2) return @"TDD / FR2";
    if (section == 3) return @"SDL";
    return BLT(@"Otras", @"Other");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Aquí solo preparas la selección 5G. Volver a Control y pulsar Aplicar selección 5G es lo que modifica el módem.", @"This only prepares the 5G selection. Returning to Control and tapping Apply 5G selection is what changes the modem.");
    if (section == 3 && self.sdlBands.count) return BLT(@"Las bandas SDL son solo de bajada y no deben usarse como única selección.", @"SDL bands are downlink-only and should not be used as the only selection.");
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
        NSArray *titles = @[BLT(@"Selección 5G activa actual", @"Current active 5G selection"), BLT(@"Todas las 5G soportadas", @"All supported 5G bands"), @"FDD", @"TDD / FR2", BLT(@"Desmarcar todas", @"Clear all")];
        NSArray *icons = @[@"antenna.radiowaves.left.and.right", @"checkmark.circle", @"arrow.left.and.right", @"waveform.path", @"xmark.circle"];
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
        [NSLayoutConstraint activateConstraints:@[[button.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16], [button.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16], [button.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor], [button.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor], [button.heightAnchor constraintGreaterThanOrEqualToConstant:48]]];
        return cell;
    }
    NSNumber *band = [self bandsForSection:indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = BLGNRBandTitle(band);
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", BLGNRFrequencyForBand(band).length ? BLGNRFrequencyForBand(band) : BLT(@"Frecuencia sin catalogar", @"Frequency not catalogued"), BLGNRDuplexForBand(band)];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = [self.selected containsObject:band] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)commitSelection { [self.manager setPendingNRBands:BLSortedBands(self.selected)]; }
- (void)setSelectedBands:(NSArray<NSNumber *> *)bands {
    self.selected = [NSMutableSet setWithArray:BLIntersectBands(self.manager.supportedNRBands, bands ?: @[])];
    [self commitSelection];
    [self.tableView reloadData];
}
- (void)quickActionTapped:(UIButton *)sender {
    if (sender.tag == 0) [self setSelectedBands:self.manager.activeNRBands];
    else if (sender.tag == 1) [self setSelectedBands:self.manager.supportedNRBands];
    else if (sender.tag == 2) [self setSelectedBands:self.fddBands];
    else if (sender.tag == 3) [self setSelectedBands:self.tddBands];
    else [self setSelectedBands:@[]];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;
    NSArray<NSNumber *> *sectionBands = [self bandsForSection:indexPath.section];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)sectionBands.count) return;
    NSNumber *band = sectionBands[(NSUInteger)indexPath.row];
    if ([self.selected containsObject:band]) [self.selected removeObject:band];
    else [self.selected addObject:band];
    [self commitSelection];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end
