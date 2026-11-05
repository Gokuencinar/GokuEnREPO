#import "BLAnalyzerCapturesViewController.h"
#import "BLAnalyzerCaptureStore.h"
#import "BLCommon.h"

static UIColor *BLCaptureInk(void) { return [UIColor colorWithRed:0.06 green:0.10 blue:0.19 alpha:1]; }
static UIColor *BLCapturePanel(void) { return [UIColor colorWithRed:0.10 green:0.16 blue:0.27 alpha:1]; }
static UIColor *BLCaptureTeal(void) { return [UIColor colorWithRed:0.05 green:0.72 blue:0.65 alpha:1]; }
static UIColor *BLCaptureMuted(void) { return [UIColor colorWithRed:0.78 green:0.82 blue:0.89 alpha:1]; }

@interface BLAnalyzerCaptureDetailViewController : UIViewController
- (instancetype)initWithCapture:(NSDictionary *)capture;
@end

@interface BLAnalyzerCapturesViewController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *captures;
@end

@implementation BLAnalyzerCapturesViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Capturas guardadas", @"Saved captures");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.view.backgroundColor = BLCaptureInk();
    self.tableView.backgroundColor = BLCaptureInk();
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.08];
    self.navigationController.navigationBar.tintColor = BLCaptureTeal();
    self.tableView.rowHeight = 68;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.captures = BLAnalyzerCaptureStore.captures;
    [self.tableView reloadData];
    if (!self.captures.count) {
        UIView *empty = [UIView new];
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"photo.on.rectangle.angled"]];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.tintColor = BLCaptureMuted();
        icon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:34 weight:UIImageSymbolWeightRegular];
        UILabel *label = [UILabel new];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.text = BLT(@"No hay capturas guardadas", @"No saved captures");
        label.textColor = BLCaptureMuted();
        label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [empty addSubview:icon];
        [empty addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [icon.centerXAnchor constraintEqualToAnchor:empty.centerXAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:empty.centerYAnchor constant:-24],
            [label.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
            [label.centerXAnchor constraintEqualToAnchor:empty.centerXAnchor]
        ]];
        self.tableView.backgroundView = empty;
    } else self.tableView.backgroundView = nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.captures.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"BandLockCaptureCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    NSDictionary *capture = self.captures[indexPath.row];
    cell.backgroundColor = BLCapturePanel();
    cell.textLabel.text = [BLAnalyzerCaptureStore displayTitleForCapture:capture];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.textLabel.textColor = UIColor.whiteColor;
    NSString *operatorName = [capture[@"operator_name"] isKindOfClass:NSString.class] ? capture[@"operator_name"] : nil;
    cell.detailTextLabel.text = operatorName.length
        ? [NSString stringWithFormat:BLT(@"Operador · %@", @"Operator · %@"), operatorName]
        : BLT(@"Sin operador registrado", @"No operator recorded");
    cell.detailTextLabel.textColor = BLCaptureMuted();
    cell.imageView.image = [UIImage systemImageNamed:@"photo.fill"];
    cell.imageView.tintColor = BLCaptureTeal();
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.captures.count) return;
    BLAnalyzerCaptureDetailViewController *detail =
        [[BLAnalyzerCaptureDetailViewController alloc] initWithCapture:self.captures[indexPath.row]];
    [self.navigationController pushViewController:detail animated:YES];
}

@end

@interface BLAnalyzerCaptureDetailViewController ()
@property (nonatomic, copy) NSDictionary *capture;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) NSLayoutConstraint *imageAspectConstraint;
@end

@implementation BLAnalyzerCaptureDetailViewController

- (instancetype)initWithCapture:(NSDictionary *)capture {
    self = [super init];
    if (self) _capture = [capture copy];
    return self;
}

- (UIButton *)buttonWithTitle:(NSString *)title symbol:(NSString *)symbol destructive:(BOOL)destructive action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 13;
    button.backgroundColor = destructive ? [UIColor.systemRedColor colorWithAlphaComponent:0.12]
                                         : [UIColor colorWithRed:0.05 green:0.72 blue:0.65 alpha:0.14];
    button.tintColor = destructive ? UIColor.systemRedColor : [UIColor colorWithRed:0.04 green:0.58 blue:0.53 alpha:1];
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.86;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Captura", @"Capture");
    self.view.backgroundColor = BLCaptureInk();
    self.navigationController.navigationBar.tintColor = BLCaptureTeal();
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    UILabel *title = [UILabel new];
    title.text = [BLAnalyzerCaptureStore displayTitleForCapture:self.capture];
    title.numberOfLines = 0;
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    [stack addArrangedSubview:title];

    NSString *operatorName = [self.capture[@"operator_name"] isKindOfClass:NSString.class] ? self.capture[@"operator_name"] : nil;
    if (operatorName.length) {
        UILabel *operatorLabel = [UILabel new];
        operatorLabel.text = [NSString stringWithFormat:BLT(@"Operador móvil · %@", @"Mobile operator · %@"), operatorName];
        operatorLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        operatorLabel.textColor = BLCaptureMuted();
        [stack addArrangedSubview:operatorLabel];
    }

    NSURL *url = [BLAnalyzerCaptureStore URLForCapture:self.capture];
    UIImage *image = url ? [UIImage imageWithContentsOfFile:url.path] : nil;
    self.imageView = [UIImageView new];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.backgroundColor = BLCapturePanel();
    self.imageView.layer.cornerRadius = 16;
    self.imageView.layer.masksToBounds = YES;
    self.imageView.image = image;
    [stack addArrangedSubview:self.imageView];
    CGFloat ratio = (image.size.width > 0) ? image.size.height / image.size.width : 1.0;
    self.imageAspectConstraint = [self.imageView.heightAnchor constraintEqualToAnchor:self.imageView.widthAnchor
                                                                           multiplier:MAX(0.35, ratio)];
    self.imageAspectConstraint.active = YES;

    if (!image) {
        UILabel *missing = [UILabel new];
        missing.text = BLT(@"La captura ya no está disponible.", @"This capture is no longer available.");
        missing.textColor = BLCaptureMuted();
        missing.textAlignment = NSTextAlignmentCenter;
        missing.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        missing.numberOfLines = 0;
        [stack addArrangedSubview:missing];
    }

    UIButton *share = [self buttonWithTitle:BLT(@"Compartir captura", @"Share capture")
        symbol:@"square.and.arrow.up" destructive:NO action:@selector(shareTapped:)];
    UIButton *delete = [self buttonWithTitle:BLT(@"Eliminar captura", @"Delete capture")
        symbol:@"trash" destructive:YES action:@selector(deleteTapped:)];
    [stack addArrangedSubview:share];
    [stack addArrangedSubview:delete];
}

- (void)shareTapped:(UIButton *)sender {
    NSURL *url = [BLAnalyzerCaptureStore URLForCapture:self.capture];
    if (!url || ![NSFileManager.defaultManager fileExistsAtPath:url.path]) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                           applicationActivities:nil];
    activity.popoverPresentationController.sourceView = sender;
    activity.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)deleteTapped:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BLT(@"Eliminar captura", @"Delete capture")
        message:BLT(@"Esta captura se eliminará del iPhone.", @"This capture will be deleted from the iPhone.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Cancelar", @"Cancel")
        style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BLT(@"Eliminar", @"Delete")
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            BLAnalyzerCaptureDetailViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            NSError *error = nil;
            if ([BLAnalyzerCaptureStore deleteCapture:strongSelf.capture error:&error])
                [strongSelf.navigationController popViewControllerAnimated:YES];
            else {
                UIAlertController *failure = [UIAlertController alertControllerWithTitle:BLT(@"No se pudo eliminar", @"Could not delete")
                    message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [failure addAction:[UIAlertAction actionWithTitle:BLT(@"Aceptar", @"OK")
                    style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:failure animated:YES completion:nil];
            }
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
