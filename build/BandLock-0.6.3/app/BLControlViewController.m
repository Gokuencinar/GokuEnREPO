#import "BLControlViewController.h"
#import "BLTelephonyManager.h"
#import "BLBandPickerViewController.h"
#import "BLCommon.h"

typedef NS_ENUM(NSInteger, BLControlSection) {
    BLControlSectionStatus = 0,
    BLControlSectionNetworkMode,
    BLControlSectionBands,
    BLControlSectionTools,
    BLControlSectionInfo,
    BLControlSectionCount
};

@interface BLControlViewController ()
@property (nonatomic, strong) BLTelephonyManager *manager;
@end

@implementation BLControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"BandLock";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.manager = BLTelephonyManager.sharedManager;
    self.tableView.rowHeight = 54.0;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return BLControlSectionCount; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case BLControlSectionStatus: return 5;
        case BLControlSectionNetworkMode: return 2;
        case BLControlSectionBands: return 5;
        case BLControlSectionTools: return 2;
        case BLControlSectionInfo: return 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case BLControlSectionStatus: return BLT(@"Estado", @"Status");
        case BLControlSectionNetworkMode: return BLT(@"Modo de red", @"Network mode");
        case BLControlSectionBands: return BLT(@"Bandas LTE", @"LTE bands");
        case BLControlSectionTools: return BLT(@"Herramientas", @"Tools");
        case BLControlSectionInfo: return BLT(@"Información", @"Information");
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == BLControlSectionStatus) {
        return BLT(@"La app no cambia el módem al abrirse. Pulsa Actualizar cuando quieras releer el estado real.",
                   @"Opening the app does not change the modem. Tap Refresh whenever you want to read the real modem state again.");
    }
    if (section == BLControlSectionBands) {
        return BLT(@"Editar o elegir un país solo prepara una selección. El módem no cambia hasta que confirmes Aplicar selección.",
                   @"Editing bands or choosing a country only prepares a selection. The modem is not changed until you confirm Apply selection.");
    }
    return nil;
}

- (UITableViewCell *)valueCellWithTitle:(NSString *)title value:(NSString *)value {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = value ?: @"—";
    cell.detailTextLabel.numberOfLines = 2;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)buttonCellWithTitle:(NSString *)title symbol:(NSString *)symbol destructive:(BOOL)destructive {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.textLabel.textColor = destructive ? UIColor.systemRedColor : UIColor.systemBlueColor;
    if (symbol.length) {
        cell.imageView.image = [UIImage systemImageNamed:symbol];
        cell.imageView.tintColor = cell.textLabel.textColor;
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == BLControlSectionStatus) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [self buttonCellWithTitle:self.manager.busy ? BLT(@"Actualizando…", @"Refreshing…") : BLT(@"Actualizar estado", @"Refresh status") symbol:@"arrow.clockwise" destructive:NO];
            cell.userInteractionEnabled = !self.manager.busy;
            if (self.manager.busy) {
                UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
                [spinner startAnimating];
                cell.accessoryView = spinner;
            }
            return cell;
        }
        if (indexPath.row == 1) return [self valueCellWithTitle:BLT(@"Red actual", @"Current network") value:self.manager.radioAccessTechnology];
        if (indexPath.row == 2) return [self valueCellWithTitle:BLT(@"Banda conectada", @"Serving band") value:self.manager.servingBand];
        if (indexPath.row == 3) return [self valueCellWithTitle:BLT(@"Bandas permitidas", @"Allowed bands") value:BLBandList(self.manager.activeBands)];
        return [self valueCellWithTitle:BLT(@"Resultado", @"Result") value:self.manager.detailText];
    }

    if (indexPath.section == BLControlSectionNetworkMode) {
        NSString *automatic = BLT(@"Automático", @"Automatic");
        NSString *lte = BLT(@"Solo LTE / 4G", @"LTE / 4G only");
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = indexPath.row == 0 ? automatic : lte;
        BOOL selected = [self.manager.networkMode isEqualToString:cell.textLabel.text];
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.imageView.image = [UIImage systemImageNamed:indexPath.row == 0 ? @"antenna.radiowaves.left.and.right" : @"4g.lte"];
        cell.imageView.tintColor = UIColor.systemOrangeColor;
        return cell;
    }

    if (indexPath.section == BLControlSectionBands) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.textLabel.text = BLT(@"Editar bandas", @"Edit bands");
            cell.detailTextLabel.text = self.manager.supportedBands.count ? [NSString stringWithFormat:BLT(@"%lu soportadas", @"%lu supported"), (unsigned long)self.manager.supportedBands.count] : BLT(@"Actualiza primero", @"Refresh first");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
            return cell;
        }
        if (indexPath.row == 1) return [self valueCellWithTitle:BLT(@"Selección pendiente", @"Pending selection") value:BLBandList(self.manager.pendingBands)];
        if (indexPath.row == 2) return [self buttonCellWithTitle:BLT(@"Aplicar selección", @"Apply selection") symbol:@"checkmark.circle.fill" destructive:NO];
        if (indexPath.row == 3) return [self buttonCellWithTitle:BLT(@"Restaurar selección anterior", @"Restore previous selection") symbol:@"arrow.uturn.backward" destructive:NO];
        return [self buttonCellWithTitle:BLT(@"Restaurar todas las soportadas", @"Restore all supported") symbol:@"arrow.counterclockwise.circle" destructive:NO];
    }

    if (indexPath.section == BLControlSectionTools) {
        if (indexPath.row == 0) return [self buttonCellWithTitle:BLT(@"Abrir Field Test", @"Open Field Test") symbol:@"wave.3.right.circle" destructive:NO];
        return [self valueCellWithTitle:BLT(@"Registro", @"Log") value:@"/var/mobile/Library/Logs/BandLockGlobal/BandLock-last.txt"];
    }

    return [self valueCellWithTitle:BLT(@"Versión", @"Version") value:@"0.6.3 Global App · LaunchDaemon"];
}

- (void)showResult:(BOOL)success message:(NSString *)message {
    [self.tableView reloadData];
    if (!success && message.length) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"BandLock", @"BandLock") message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)refreshStatus {
    [self.tableView reloadData];
    __weak typeof(self) weakSelf = self;
    [self.manager refreshWithCompletion:^(BOOL success, NSString *message) { [weakSelf showResult:success message:message]; }];
}

- (void)confirmLTEOnly {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Solo LTE / 4G", @"LTE / 4G only")
                                                                    message:BLT(@"El módem no podrá bajar a 3G/EDGE. Si LTE no está disponible, puedes perder temporalmente servicio o llamadas sin VoLTE.", @"The modem will not fall back to 3G/EDGE. If LTE is unavailable, you may temporarily lose service or calls without VoLTE.")
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Activar", @"Enable") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager setNetworkModeLTEOnly:^(BOOL success, NSString *message) { [weakSelf showResult:success message:message]; }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmApply {
    NSArray *bands = self.manager.pendingBands;
    NSString *message = [NSString stringWithFormat:BLT(@"Se permitirán únicamente estas bandas LTE:\n\n%@\n\nLa selección actual se guardará para poder restaurarla.", @"Only these LTE bands will be allowed:\n\n%@\n\nThe current selection will be saved so it can be restored."), BLBandList(bands)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Aplicar selección", @"Apply selection") message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aplicar", @"Apply") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [weakSelf.manager applyPendingBandsWithCompletion:^(BOOL success, NSString *message) { [weakSelf showResult:success message:message]; }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.manager.busy) return;
    if (indexPath.section == BLControlSectionStatus && indexPath.row == 0) { [self refreshStatus]; return; }

    if (indexPath.section == BLControlSectionNetworkMode) {
        __weak typeof(self) weakSelf = self;
        if (indexPath.row == 0) [self.manager setNetworkModeAutomatic:^(BOOL success, NSString *message) { [weakSelf showResult:success message:message]; }];
        else [self confirmLTEOnly];
        return;
    }

    if (indexPath.section == BLControlSectionBands) {
        if (indexPath.row == 0) {
            if (!self.manager.supportedBands.count) {
                [self showResult:NO message:BLT(@"Pulsa «Actualizar estado» antes de editar bandas. Editar bandas ya no ejecuta CoreTelephony implícitamente.", @"Tap “Refresh status” before editing bands. Edit bands no longer invokes CoreTelephony implicitly.")];
                return;
            }
            BLBandPickerViewController *picker = [[BLBandPickerViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
            [self.navigationController pushViewController:picker animated:YES];
        } else if (indexPath.row == 2) {
            [self confirmApply];
        } else if (indexPath.row == 3) {
            __weak typeof(self) weakSelf = self;
            [self.manager restorePreviousBandsWithCompletion:^(BOOL success, NSString *message) { [weakSelf showResult:success message:message]; }];
        } else if (indexPath.row == 4) {
            __weak typeof(self) weakSelf = self;
            [self.manager restoreAllSupportedBandsWithCompletion:^(BOOL success, NSString *message) { [weakSelf showResult:success message:message]; }];
        }
        return;
    }

    if (indexPath.section == BLControlSectionTools && indexPath.row == 0) {
        __weak typeof(self) weakSelf = self;
        [self.manager openFieldTestWithCompletion:^(BOOL success, NSString *message) {
            [weakSelf showResult:success message:message];
        }];
    }
}

@end
