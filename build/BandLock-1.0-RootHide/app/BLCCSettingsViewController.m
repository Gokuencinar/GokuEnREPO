#import "BLCCSettingsViewController.h"
#import "BLCommon.h"
#import "BLCCPreferences.h"

typedef NS_ENUM(NSInteger, BLCCSwitchTag) {
    BLCCSwitchTag2G = 20,
    BLCCSwitchTag3G,
    BLCCSwitchTagLTE,
    BLCCSwitchTag5G,
    BLCCSwitchTagAdvanced5G
};

@implementation BLCCSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Centro de control", @"Control Center");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 4 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? BLT(@"Modos visibles", @"Visible modes") : @"5G";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return BLT(@"Automático siempre permanece visible para que puedas volver a la selección normal de iOS.",
                   @"Auto always remains visible so you can return to normal iOS network selection.");
    }
    return BLT(@"Desactivado: el módulo muestra un único botón 5G que usa 5G Auto. Activado: muestra 5G Auto, 5G NSA y 5G SA por separado.",
               @"Off: the module shows one 5G option using 5G Auto. On: it shows 5G Auto, 5G NSA and 5G SA separately.");
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title tag:(BLCCSwitchTag)tag enabled:(BOOL)enabled {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.tag = tag;
    toggle.on = enabled;
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) return [self switchCellWithTitle:@"2G" tag:BLCCSwitchTag2G enabled:BLCCShow2G()];
        if (indexPath.row == 1) return [self switchCellWithTitle:@"3G" tag:BLCCSwitchTag3G enabled:BLCCShow3G()];
        if (indexPath.row == 2) return [self switchCellWithTitle:@"4G / LTE" tag:BLCCSwitchTagLTE enabled:BLCCShowLTE()];
        return [self switchCellWithTitle:@"5G" tag:BLCCSwitchTag5G enabled:BLCCShow5G()];
    }
    return [self switchCellWithTitle:BLT(@"Modos 5G avanzados", @"Advanced 5G modes")
                                  tag:BLCCSwitchTagAdvanced5G
                              enabled:BLCCAdvanced5GModes()];
}

- (void)toggleChanged:(UISwitch *)sender {
    switch ((BLCCSwitchTag)sender.tag) {
        case BLCCSwitchTag2G: BLCCSetShow2G(sender.isOn); break;
        case BLCCSwitchTag3G: BLCCSetShow3G(sender.isOn); break;
        case BLCCSwitchTagLTE: BLCCSetShowLTE(sender.isOn); break;
        case BLCCSwitchTag5G: BLCCSetShow5G(sender.isOn); break;
        case BLCCSwitchTagAdvanced5G: BLCCSetAdvanced5GModes(sender.isOn); break;
    }
}

@end
