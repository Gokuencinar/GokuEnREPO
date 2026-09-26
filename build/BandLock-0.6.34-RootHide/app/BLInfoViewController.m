#import "BLInfoViewController.h"
#import "BLLanguageViewController.h"
#import "BLFrequencyGlossaryViewController.h"
#import "BLLocalization.h"
#import "BLCommon.h"

static NSString * const BLRepositoryURL = @"https://github.com/Gokuencinar/GokuEnREPO";
static NSString * const BLPackagesURL = @"https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/Packages";
static NSString * const BLChangelogRawURL = @"https://raw.githubusercontent.com/Gokuencinar/GokuEnREPO/main/changelogs/BandLock.md";
static NSString * const BLPackageIdentifier = @"com.gokuencinar.bandlock";

@interface BLReleaseNotesViewController : UIViewController
@property (nonatomic, strong) UITextView *textView;
@end


@implementation BLReleaseNotesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Notas de actualización", @"Release notes");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.textView = [[UITextView alloc] init];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.alwaysBounceVertical = YES;
    self.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textView.textContainerInset = UIEdgeInsetsMake(18, 16, 24, 16);
    self.textView.text = BLT(@"Cargando notas de actualización…", @"Loading release notes…");
    [self.view addSubview:self.textView];
    [NSLayoutConstraint activateConstraints:@[
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.textView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self loadNotes];
}

- (void)loadNotes {
    NSURL *url = [NSURL URLWithString:BLChangelogRawURL];
    if (!url) return;
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *text = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.textView.text = text.length ? text : BLT(@"No se pudieron cargar las notas de actualización.", @"Could not load release notes.");
        });
    }] resume];
}

@end


@interface BLInfoViewController ()
@end

@implementation BLInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Información", @"Info");
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return 2;
    if (section == 2) return 2;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return BLT(@"Acerca de", @"About");
    if (section == 1) return BLT(@"Actualizaciones", @"Updates");
    if (section == 2) return BLT(@"Recursos", @"Resources");
    return BLT(@"Idioma", @"Language");
}

- (NSString *)currentLanguageName {
    for (NSDictionary *language in BLLanguageOptions()) {
        if ([language[@"code"] isEqualToString:BLCurrentLanguageCode()]) return language[@"name"];
    }
    return BLCurrentLanguageCode();
}

- (UITableViewCell *)valueCell:(NSString *)title detail:(NSString *)detail symbol:(NSString *)symbol disclosure:(BOOL)disclosure {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.imageView.image = symbol.length ? [UIImage systemImageNamed:symbol] : nil;
    cell.imageView.tintColor = UIColor.systemBlueColor;
    cell.accessoryType = disclosure ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = disclosure ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}

- (UIImage *)creditsAvatarImage {
    NSString *avatarPath = [NSBundle.mainBundle pathForResource:@"CreditsAvatar" ofType:@"jpg"];
    UIImage *source = avatarPath.length ? [UIImage imageWithContentsOfFile:avatarPath] : nil;
    if (!source) return [UIImage systemImageNamed:@"person.crop.circle.fill"];

    CGSize size = CGSizeMake(44.0, 44.0);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect bounds = (CGRect){CGPointZero, size};
        [[UIBezierPath bezierPathWithOvalInRect:bounds] addClip];

        CGFloat scale = MAX(size.width / source.size.width, size.height / source.size.height);
        CGSize drawSize = CGSizeMake(source.size.width * scale, source.size.height * scale);
        CGRect drawRect = CGRectMake((size.width - drawSize.width) * 0.5,
                                     (size.height - drawSize.height) * 0.5,
                                     drawSize.width,
                                     drawSize.height);
        [source drawInRect:drawRect];
    }];
}

- (UITableViewCell *)creditsCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.imageView.image = [self creditsAvatarImage];
    cell.textLabel.text = @"Gokuencinar · GokuEn";
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = BLT(@"Créditos", @"Credits");
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"—";
    if (indexPath.section == 0 && indexPath.row == 0) return [self valueCell:@"BandLock Global" detail:[NSString stringWithFormat:@"%@ · RootHide", version] symbol:@"antenna.radiowaves.left.and.right" disclosure:NO];
    if (indexPath.section == 0) return [self creditsCell];
    if (indexPath.section == 1 && indexPath.row == 0) return [self valueCell:BLT(@"Buscar actualizaciones", @"Check for updates") detail:nil symbol:@"arrow.triangle.2.circlepath" disclosure:YES];
    if (indexPath.section == 1) return [self valueCell:BLT(@"Notas de actualización", @"Release notes") detail:nil symbol:@"doc.text" disclosure:YES];
    if (indexPath.section == 2 && indexPath.row == 0) return [self valueCell:BLT(@"Visitar GokuEnREPO", @"Visit GokuEnREPO") detail:nil symbol:@"link" disclosure:YES];
    if (indexPath.section == 2) return [self valueCell:BLT(@"Más información sobre las frecuencias", @"More information about frequencies") detail:nil symbol:@"info.circle" disclosure:YES];
    return [self valueCell:BLT(@"Cambiar idioma", @"Change language") detail:[self currentLanguageName] symbol:@"globe" disclosure:YES];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"BandLock" message:message ?: @"" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)publishedBandLockVersionFromPackages:(NSString *)packages {
    NSString *normalized = [(packages ?: @"") stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    NSArray *stanzas = [normalized componentsSeparatedByString:@"\n\n"];
    NSString *best = nil;
    for (NSString *stanza in stanzas) {
        NSArray<NSString *> *lines = [stanza componentsSeparatedByString:@"\n"];
        NSString *packageLine = [NSString stringWithFormat:@"Package: %@", BLPackageIdentifier];
        if (![lines containsObject:packageLine]) continue;
        __block NSString *version = nil;
        [lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL *stop) {
            if ([line hasPrefix:@"Version: "]) { version = [line substringFromIndex:9]; *stop = YES; }
        }];
        if (version.length && (!best || [version compare:best options:NSNumericSearch] == NSOrderedDescending)) best = version;
    }
    return best;
}

- (void)checkForUpdates {
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"BandLock"
                                                                      message:BLT(@"Buscando actualizaciones…", @"Checking for updates…")
                                                               preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];
    NSURL *url = [NSURL URLWithString:BLPackagesURL];
    if (!url) {
        [loading dismissViewControllerAnimated:YES completion:^{ [self showMessage:BLT(@"No se pudo comprobar si hay actualizaciones.", @"Could not check for updates.")]; }];
        return;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *raw = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSString *remote = [weakSelf publishedBandLockVersionFromPackages:raw];
        NSString *current = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
        NSString *message = nil;
        if (!remote.length || error) message = BLT(@"No se pudo comprobar si hay actualizaciones.", @"Could not check for updates.");
        else {
            NSComparisonResult comparison = [remote compare:current options:NSNumericSearch];
            if (comparison == NSOrderedDescending) {
                message = [NSString stringWithFormat:BLT(@"Hay una versión nueva disponible: %@ (instalada: %@). Abre GokuEnREPO/Sileo para actualizar.", @"A newer version is available: %@ (installed: %@). Open GokuEnREPO/Sileo to update."), remote, current];
            } else if (comparison == NSOrderedSame) {
                message = [NSString stringWithFormat:BLT(@"Estás usando la última versión publicada (%@).", @"You are using the latest published version (%@)."), current];
            } else {
                message = [NSString stringWithFormat:BLT(@"La versión instalada %@ es más reciente que la versión publicada actualmente en el repositorio %@.", @"Installed version %@ is newer than the currently published repository version %@."), current, remote];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:NO completion:^{ [weakSelf showMessage:message]; }];
        });
    }] resume];
}

- (void)openRepository {
    NSURL *url = [NSURL URLWithString:BLRepositoryURL];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == 0) { [self checkForUpdates]; return; }
    if (indexPath.section == 1 && indexPath.row == 1) {
        [self.navigationController pushViewController:[[BLReleaseNotesViewController alloc] init] animated:YES];
        return;
    }
    if (indexPath.section == 2 && indexPath.row == 0) { [self openRepository]; return; }
    if (indexPath.section == 2 && indexPath.row == 1) {
        [self.navigationController pushViewController:[[BLFrequencyGlossaryViewController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
        return;
    }
    if (indexPath.section == 3) {
        [self.navigationController pushViewController:[[BLLanguageViewController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
    }
}

@end
