#import "BLFrequencyGlossaryViewController.h"
#import "BLCommon.h"

@interface BLFrequencyGlossaryViewController ()
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *entries;
@end

@implementation BLFrequencyGlossaryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = BLT(@"Información de frecuencias", @"Frequency information");
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 92;
    self.entries = @[
        @{@"term": @"LTE / 4G", @"detail": BLT(@"Tecnología móvil de cuarta generación. BandLock 0.6.x modifica únicamente la selección de bandas LTE/4G.", @"Fourth-generation mobile technology. BandLock 0.6.x only changes LTE/4G band selection.")},
        @{@"term": @"B1, B3, B20…", @"detail": BLT(@"Cada B identifica una banda LTE estandarizada. El número no es una frecuencia concreta por sí solo: cada banda define rangos de subida y bajada.", @"Each B identifies a standardized LTE band. The number is not a single frequency by itself: each band defines uplink and downlink ranges.")},
        @{@"term": @"MHz / GHz", @"detail": BLT(@"Unidades de frecuencia. 1000 MHz equivalen a 1 GHz. Las bandas bajas suelen ofrecer más cobertura; las altas suelen aportar más capacidad.", @"Frequency units. 1000 MHz equals 1 GHz. Lower bands generally provide wider coverage; higher bands generally provide more capacity.")},
        @{@"term": @"FDD", @"detail": BLT(@"Frequency Division Duplex. Usa bloques de frecuencia separados para subida y bajada al mismo tiempo.", @"Frequency Division Duplex. It uses separate frequency blocks for uplink and downlink at the same time.")},
        @{@"term": @"TDD", @"detail": BLT(@"Time Division Duplex. Subida y bajada comparten el mismo bloque de frecuencia y se alternan en el tiempo.", @"Time Division Duplex. Uplink and downlink share the same frequency block and alternate over time.")},
        @{@"term": @"SDL", @"detail": BLT(@"Supplemental Downlink. Es espectro adicional solo para bajada; normalmente complementa otra banda y no conviene usarlo como única selección.", @"Supplemental Downlink. It is extra downlink-only spectrum; it normally complements another band and should not be used as the only selection.")},
        @{@"term": @"APT 700", @"detail": BLT(@"Plan de frecuencias de 700 MHz de Asia-Pacific Telecommunity. En LTE suele aparecer asociado a la banda 28 y variantes regionales.", @"Asia-Pacific Telecommunity 700 MHz frequency plan. In LTE it is commonly associated with Band 28 and regional variants.")},
        @{@"term": @"AWS", @"detail": BLT(@"Advanced Wireless Services. Nombre usado en Norteamérica para varios bloques emparejados, por ejemplo AWS-1 o AWS-3.", @"Advanced Wireless Services. A North American name for several paired spectrum blocks, such as AWS-1 or AWS-3.")},
        @{@"term": @"PCS", @"detail": BLT(@"Personal Communications Service. Denominación habitual de espectro celular alrededor de 1900 MHz en Norteamérica.", @"Personal Communications Service. A common name for cellular spectrum around 1900 MHz in North America.")},
        @{@"term": @"WCS", @"detail": BLT(@"Wireless Communications Service. Bloques de espectro alrededor de 2,3 GHz usados, entre otros, por LTE Band 30.", @"Wireless Communications Service. Spectrum blocks around 2.3 GHz used, among others, by LTE Band 30.")},
        @{@"term": @"CBRS", @"detail": BLT(@"Citizens Broadband Radio Service. Espectro compartido alrededor de 3,5 GHz en EE. UU.; LTE Band 48 es una de sus aplicaciones.", @"Citizens Broadband Radio Service. Shared spectrum around 3.5 GHz in the United States; LTE Band 48 is one of its uses.")},
        @{@"term": @"LAA", @"detail": BLT(@"Licensed Assisted Access. LTE que agrega espectro sin licencia, normalmente en 5 GHz, junto con una portadora LTE licenciada.", @"Licensed Assisted Access. LTE that aggregates unlicensed spectrum, usually at 5 GHz, with a licensed LTE carrier.")},
        @{@"term": @"CDMA", @"detail": BLT(@"Familia de tecnologías móviles anteriores a LTE. No es un modo FDD/TDD de una banda LTE y BandLock no bloquea bandas CDMA.", @"A family of mobile technologies predating LTE. It is not an LTE FDD/TDD mode and BandLock does not lock CDMA bands.")},
        @{@"term": @"WCDMA / UMTS / HSPA", @"detail": BLT(@"Tecnologías 3G. HSPA/HSDPA son evoluciones de UMTS. Pueden aparecer como red actual si el iPhone abandona LTE.", @"3G technologies. HSPA/HSDPA are evolutions of UMTS. They may appear as the current network if the iPhone leaves LTE.")},
        @{@"term": @"GSM / EDGE", @"detail": BLT(@"Tecnologías 2G. Pueden existir como fallback en redes antiguas; no forman parte del selector de bandas LTE de BandLock.", @"2G technologies. They may exist as fallback on older networks; they are not part of BandLock's LTE band selector.")},
        @{@"term": @"RAT", @"detail": BLT(@"Radio Access Technology. Indica la tecnología de acceso de radio usada por el teléfono, por ejemplo LTE, UMTS/HSDPA o EDGE.", @"Radio Access Technology. It identifies the radio technology used by the phone, such as LTE, UMTS/HSDPA or EDGE.")},
        @{@"term": @"NR / 5G", @"detail": BLT(@"New Radio es la tecnología 5G. La versión actual de BandLock controla LTE/4G y no declara bloqueo de bandas 5G NR.", @"New Radio is the 5G technology. The current BandLock version controls LTE/4G and does not claim 5G NR band locking.")}
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.entries.count; }

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return BLT(@"La frecuencia real usada en cada momento depende del operador, la zona, la red y la agregación de portadoras.",
               @"The frequency actually used at any moment depends on the carrier, location, network and carrier aggregation.");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *entry = self.entries[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = entry[@"term"];
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = entry[@"detail"];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
