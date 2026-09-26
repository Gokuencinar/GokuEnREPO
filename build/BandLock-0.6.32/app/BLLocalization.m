#import "BLLocalization.h"

NSString * const BLLanguageDidChangeNotification = @"BLLanguageDidChangeNotification";
static NSString * const BLLanguageDefaultsKey = @"BandLockLanguage";

static NSArray<NSString *> *BLSupportedLanguageCodes(void) {
    return @[@"es", @"en", @"fr", @"de", @"zh-Hant", @"zh-Hans", @"ja"];
}

static NSString *BLNormalizedLanguageCode(NSString *raw) {
    NSString *lower = raw.lowercaseString ?: @"";
    if ([lower hasPrefix:@"es"]) return @"es";
    if ([lower hasPrefix:@"fr"]) return @"fr";
    if ([lower hasPrefix:@"de"]) return @"de";
    if ([lower hasPrefix:@"ja"]) return @"ja";
    if ([lower hasPrefix:@"zh-hant"] || [lower hasPrefix:@"zh_tw"] || [lower hasPrefix:@"zh-tw"] ||
        [lower hasPrefix:@"zh_hk"] || [lower hasPrefix:@"zh-hk"] || [lower hasPrefix:@"zh_mo"] || [lower hasPrefix:@"zh-mo"]) {
        return @"zh-Hant";
    }
    if ([lower hasPrefix:@"zh"]) return @"zh-Hans";
    return @"en";
}

NSString *BLCurrentLanguageCode(void) {
    NSString *stored = [NSUserDefaults.standardUserDefaults stringForKey:BLLanguageDefaultsKey];
    if ([BLSupportedLanguageCodes() containsObject:stored]) return stored;
    return BLNormalizedLanguageCode(NSLocale.preferredLanguages.firstObject);
}

void BLSetLanguageCode(NSString *code) {
    if (![BLSupportedLanguageCodes() containsObject:code]) return;
    if ([[BLCurrentLanguageCode() lowercaseString] isEqualToString:code.lowercaseString] &&
        [[NSUserDefaults.standardUserDefaults stringForKey:BLLanguageDefaultsKey] isEqualToString:code]) return;
    [NSUserDefaults.standardUserDefaults setObject:code forKey:BLLanguageDefaultsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    [NSNotificationCenter.defaultCenter postNotificationName:BLLanguageDidChangeNotification object:nil];
}

NSArray<NSDictionary<NSString *, NSString *> *> *BLLanguageOptions(void) {
    return @[
        @{@"code": @"es", @"name": @"Español"},
        @{@"code": @"en", @"name": @"English"},
        @{@"code": @"fr", @"name": @"Français"},
        @{@"code": @"de", @"name": @"Deutsch"},
        @{@"code": @"zh-Hant", @"name": @"繁體中文 · Chino tradicional"},
        @{@"code": @"zh-Hans", @"name": @"简体中文 · Chino mandarín"},
        @{@"code": @"ja", @"name": @"日本語"}
    ];
}

NSLocale *BLLocaleForCurrentLanguage(void) {
    NSDictionary<NSString *, NSString *> *identifiers = @{
        @"es": @"es_ES",
        @"en": @"en_US",
        @"fr": @"fr_FR",
        @"de": @"de_DE",
        @"zh-Hant": @"zh_Hant_TW",
        @"zh-Hans": @"zh_Hans_CN",
        @"ja": @"ja_JP"
    };
    return [[NSLocale alloc] initWithLocaleIdentifier:identifiers[BLCurrentLanguageCode()] ?: @"en_US"];
}

static NSDictionary<NSString *, NSString *> *BLFrench(void) {
    static NSDictionary *map; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = @{
        @"Control": @"Contrôle", @"Countries": @"Pays", @"Info": @"Infos",
        @"Refresh status": @"Actualiser l’état", @"Refreshing…": @"Actualisation…", @"STATUS": @"ÉTAT",
        @"Current network": @"Réseau actuel", @"Serving band": @"Bande utilisée", @"Allowed bands": @"Bandes autorisées", @"Result": @"Résultat",
        @"NETWORK MODE": @"MODE RÉSEAU", @"Configuration": @"Configuration", @"Automatic mode": @"Mode automatique", @"LTE / 4G only": @"LTE / 4G uniquement",
        @"LTE BANDS": @"BANDES LTE", @"Pending selection": @"Sélection en attente", @"Edit bands": @"Modifier les bandes", @"Apply selection": @"Appliquer la sélection",
        @"Restore previous selection": @"Restaurer la sélection précédente", @"Restore all supported": @"Restaurer toutes les bandes prises en charge",
        @"TOOLS": @"OUTILS", @"Open Field Test": @"Ouvrir Field Test", @"OK": @"OK", @"Cancel": @"Annuler", @"Enable": @"Activer", @"Apply": @"Appliquer",
        @"Service may be temporarily lost if LTE is unavailable.": @"Le service peut être temporairement perdu si le LTE n’est pas disponible.",
        @"There are no pending bands to apply.": @"Aucune bande n’est en attente d’application.", @"Tap “Refresh status” before editing bands.": @"Touchez « Actualiser l’état » avant de modifier les bandes.",
        @"Only these LTE bands will be allowed:\n\n%@": @"Seules ces bandes LTE seront autorisées :\n\n%@",
        @"Quick selection": @"Sélection rapide", @"Current active selection": @"Sélection active actuelle", @"All supported": @"Toutes prises en charge",
        @"FDD only": @"FDD uniquement", @"TDD only": @"TDD uniquement", @"Clear all": @"Tout désélectionner", @"Other": @"Autres",
        @"This only prepares the selection. Returning to Control and tapping Apply is what changes the modem.": @"Cela prépare uniquement la sélection. Seul le bouton Appliquer dans Contrôle modifie le modem.",
        @"SDL is supplemental downlink. Avoid selecting only SDL bands.": @"SDL est une liaison descendante supplémentaire. Évitez de sélectionner uniquement des bandes SDL.",
        @"Frequency not catalogued": @"Fréquence non répertoriée", @"Search country": @"Rechercher un pays", @"%lu countries and territories": @"%lu pays et territoires",
        @"No verified LTE bands in the dataset": @"Aucune bande LTE vérifiée dans les données", @"Reference LTE bands": @"Bandes LTE de référence", @"Summary": @"Résumé", @"Prepare selection": @"Préparer la sélection",
        @"Country": @"Pays", @"Country bands": @"Bandes du pays", @"No data": @"Aucune donnée", @"Compatible with iPhone": @"Compatibles avec l’iPhone", @"Refresh Control first": @"Actualisez d’abord Contrôle",
        @"Prepare compatible bands": @"Préparer les bandes compatibles", @"Refresh from Control first": @"Actualiser d’abord depuis Contrôle",
        @"The button only copies the country ∩ iPhone intersection into the pending selection. It never applies changes automatically.": @"Le bouton copie uniquement l’intersection pays ∩ iPhone dans la sélection en attente. Aucun changement n’est appliqué automatiquement.",
        @"Selection prepared": @"Sélection préparée", @"Selection prepared: %@\n\nReview it and tap Apply from Control.": @"Sélection préparée : %@\n\nVérifiez-la puis touchez Appliquer dans Contrôle.",
        @"Stay here": @"Rester ici", @"Go to Control": @"Aller à Contrôle", @"Tap “Refresh status” in Control before preparing a country.": @"Touchez « Actualiser l’état » dans Contrôle avant de préparer un pays.",
        @"This iPhone does not report any of the LTE bands listed for this country.": @"Cet iPhone ne signale aucune des bandes LTE répertoriées pour ce pays.",
        @"Manage frequencies for %@": @"Gérer les fréquences de %@", @"Country frequencies": @"Fréquences du pays", @"Available for this iPhone": @"Disponibles pour cet iPhone",
        @"Changes here only update the pending selection. Tap Apply in Control to change the modem.": @"Les changements ici mettent seulement à jour la sélection en attente. Touchez Appliquer dans Contrôle pour modifier le modem.",
        @"Select all country bands": @"Sélectionner toutes les bandes du pays", @"Use current active country bands": @"Utiliser les bandes actives du pays",
        @"About": @"À propos", @"Credits": @"Crédits", @"Created by Gokuencinar · GokuEn": @"Créé par Gokuencinar · GokuEn", @"Updates": @"Mises à jour",
        @"Check for updates": @"Rechercher des mises à jour", @"Release notes": @"Notes de version", @"Resources": @"Ressources", @"Visit GokuEnREPO": @"Visiter GokuEnREPO",
        @"More information about frequencies": @"Plus d’informations sur les fréquences", @"Language": @"Langue", @"Change language": @"Changer de langue", @"Frequency glossary": @"Glossaire des fréquences",
        @"Checking for updates…": @"Recherche de mises à jour…", @"You are using the latest published version (%@).": @"Vous utilisez la dernière version publiée (%@).",
        @"A newer version is available: %@ (installed: %@). Open GokuEnREPO/Sileo to update.": @"Une version plus récente est disponible : %@ (installée : %@). Ouvrez GokuEnREPO/Sileo pour la mettre à jour.",
        @"Installed version %@ is newer than the currently published repository version %@.": @"La version installée %@ est plus récente que la version actuellement publiée %@.",
        @"Could not check for updates.": @"Impossible de rechercher les mises à jour.", @"Loading release notes…": @"Chargement des notes de version…", @"Could not load release notes.": @"Impossible de charger les notes de version.",
        @"BandLock uses a separate daemon for CoreTelephony. The main app does not spawn processes or execute modem private APIs.": @"BandLock utilise un daemon séparé pour CoreTelephony. L’app principale ne lance pas de processus et n’exécute pas les API privées du modem.",
        @"Not queried": @"Non consulté", @"Tap Refresh": @"Touchez Actualiser", @"Querying daemon…": @"Interrogation du daemon…", @"Ready": @"Prêt", @"Unavailable": @"Indisponible",
        @"An operation is already running.": @"Une opération est déjà en cours.", @"Select at least one LTE band.": @"Sélectionnez au moins une bande LTE.", @"No previous selection is saved.": @"Aucune sélection précédente n’est enregistrée.",
        @"Tap Refresh status first.": @"Touchez d’abord Actualiser l’état.", @"Modem state updated.": @"État du modem actualisé.", @"Network mode updated.": @"Mode réseau actualisé.", @"LTE selection applied.": @"Sélection LTE appliquée.", @"Field Test requested.": @"Field Test demandé."
    }; }); return map;
}

static NSDictionary<NSString *, NSString *> *BLGerman(void) {
    static NSDictionary *map; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = @{
        @"Control": @"Steuerung", @"Countries": @"Länder", @"Info": @"Info", @"Refresh status": @"Status aktualisieren", @"Refreshing…": @"Aktualisierung…", @"STATUS": @"STATUS",
        @"Current network": @"Aktuelles Netz", @"Serving band": @"Aktives Band", @"Allowed bands": @"Erlaubte Bänder", @"Result": @"Ergebnis", @"NETWORK MODE": @"NETZMODUS", @"Configuration": @"Konfiguration",
        @"Automatic mode": @"Automatischer Modus", @"LTE / 4G only": @"Nur LTE / 4G", @"LTE BANDS": @"LTE-BÄNDER", @"Pending selection": @"Ausstehende Auswahl", @"Edit bands": @"Bänder bearbeiten",
        @"Apply selection": @"Auswahl anwenden", @"Restore previous selection": @"Vorherige Auswahl wiederherstellen", @"Restore all supported": @"Alle unterstützten wiederherstellen", @"TOOLS": @"WERKZEUGE", @"Open Field Test": @"Field Test öffnen",
        @"OK": @"OK", @"Cancel": @"Abbrechen", @"Enable": @"Aktivieren", @"Apply": @"Anwenden", @"Service may be temporarily lost if LTE is unavailable.": @"Der Dienst kann vorübergehend ausfallen, wenn LTE nicht verfügbar ist.",
        @"There are no pending bands to apply.": @"Es gibt keine ausstehende Bandauswahl.", @"Tap “Refresh status” before editing bands.": @"Tippe vor dem Bearbeiten der Bänder auf „Status aktualisieren“.", @"Only these LTE bands will be allowed:\n\n%@": @"Nur diese LTE-Bänder werden zugelassen:\n\n%@",
        @"Quick selection": @"Schnellauswahl", @"Current active selection": @"Aktuell aktive Auswahl", @"All supported": @"Alle unterstützten", @"FDD only": @"Nur FDD", @"TDD only": @"Nur TDD", @"Clear all": @"Alle abwählen", @"Other": @"Andere",
        @"This only prepares the selection. Returning to Control and tapping Apply is what changes the modem.": @"Dies bereitet nur die Auswahl vor. Erst Anwenden unter Steuerung ändert das Modem.", @"SDL is supplemental downlink. Avoid selecting only SDL bands.": @"SDL ist zusätzlicher Downlink. Wähle nicht ausschließlich SDL-Bänder.",
        @"Frequency not catalogued": @"Frequenz nicht katalogisiert", @"Search country": @"Land suchen", @"%lu countries and territories": @"%lu Länder und Gebiete", @"No verified LTE bands in the dataset": @"Keine verifizierten LTE-Bänder im Datensatz",
        @"Reference LTE bands": @"LTE-Referenzbänder", @"Summary": @"Übersicht", @"Prepare selection": @"Auswahl vorbereiten", @"Country": @"Land", @"Country bands": @"Bänder des Landes", @"No data": @"Keine Daten", @"Compatible with iPhone": @"Mit iPhone kompatibel", @"Refresh Control first": @"Zuerst Steuerung aktualisieren",
        @"Prepare compatible bands": @"Kompatible Bänder vorbereiten", @"Refresh from Control first": @"Zuerst in Steuerung aktualisieren", @"Selection prepared": @"Auswahl vorbereitet", @"Selection prepared: %@\n\nReview it and tap Apply from Control.": @"Auswahl vorbereitet: %@\n\nPrüfe sie und tippe unter Steuerung auf Anwenden.",
        @"Stay here": @"Hier bleiben", @"Go to Control": @"Zu Steuerung", @"Tap “Refresh status” in Control before preparing a country.": @"Tippe in Steuerung auf „Status aktualisieren“, bevor du ein Land vorbereitest.", @"This iPhone does not report any of the LTE bands listed for this country.": @"Dieses iPhone meldet keines der für dieses Land aufgeführten LTE-Bänder.",
        @"Manage frequencies for %@": @"Frequenzen für %@ verwalten", @"Country frequencies": @"Länderfrequenzen", @"Available for this iPhone": @"Für dieses iPhone verfügbar", @"Changes here only update the pending selection. Tap Apply in Control to change the modem.": @"Änderungen hier aktualisieren nur die ausstehende Auswahl. Tippe in Steuerung auf Anwenden, um das Modem zu ändern.",
        @"Select all country bands": @"Alle Länderbänder auswählen", @"Use current active country bands": @"Aktive Länderbänder verwenden", @"About": @"Über", @"Credits": @"Credits", @"Created by Gokuencinar · GokuEn": @"Erstellt von Gokuencinar · GokuEn",
        @"Updates": @"Updates", @"Check for updates": @"Nach Updates suchen", @"Release notes": @"Versionshinweise", @"Resources": @"Ressourcen", @"Visit GokuEnREPO": @"GokuEnREPO besuchen", @"More information about frequencies": @"Mehr Informationen zu Frequenzen", @"Language": @"Sprache", @"Change language": @"Sprache ändern", @"Frequency glossary": @"Frequenz-Glossar",
        @"Checking for updates…": @"Suche nach Updates…", @"You are using the latest published version (%@).": @"Du verwendest die neueste veröffentlichte Version (%@).", @"A newer version is available: %@ (installed: %@). Open GokuEnREPO/Sileo to update.": @"Eine neuere Version ist verfügbar: %@ (installiert: %@). Öffne GokuEnREPO/Sileo zum Aktualisieren.",
        @"Installed version %@ is newer than the currently published repository version %@.": @"Die installierte Version %@ ist neuer als die derzeit veröffentlichte Repository-Version %@.", @"Could not check for updates.": @"Update-Prüfung fehlgeschlagen.", @"Loading release notes…": @"Versionshinweise werden geladen…", @"Could not load release notes.": @"Versionshinweise konnten nicht geladen werden.",
        @"Not queried": @"Nicht abgefragt", @"Tap Refresh": @"Aktualisieren tippen", @"Querying daemon…": @"Daemon wird abgefragt…", @"Ready": @"Bereit", @"Unavailable": @"Nicht verfügbar", @"An operation is already running.": @"Es läuft bereits ein Vorgang.", @"Select at least one LTE band.": @"Wähle mindestens ein LTE-Band.", @"No previous selection is saved.": @"Keine vorherige Auswahl gespeichert.", @"Tap Refresh status first.": @"Tippe zuerst auf Status aktualisieren.", @"Modem state updated.": @"Modemstatus aktualisiert.", @"Network mode updated.": @"Netzmodus aktualisiert.", @"LTE selection applied.": @"LTE-Auswahl angewendet.", @"Field Test requested.": @"Field Test angefordert."
    }; }); return map;
}

static NSDictionary<NSString *, NSString *> *BLTraditionalChinese(void) {
    static NSDictionary *map; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = @{
        @"Control": @"控制", @"Countries": @"國家/地區", @"Info": @"資訊", @"Refresh status": @"更新狀態", @"Refreshing…": @"更新中…", @"STATUS": @"狀態", @"Current network": @"目前網路", @"Serving band": @"目前頻段", @"Allowed bands": @"允許頻段", @"Result": @"結果",
        @"NETWORK MODE": @"網路模式", @"Configuration": @"設定", @"Automatic mode": @"自動模式", @"LTE / 4G only": @"僅 LTE / 4G", @"LTE BANDS": @"LTE 頻段", @"Pending selection": @"待套用選擇", @"Edit bands": @"編輯頻段", @"Apply selection": @"套用選擇", @"Restore previous selection": @"還原上一個選擇", @"Restore all supported": @"還原所有支援頻段", @"TOOLS": @"工具", @"Open Field Test": @"開啟 Field Test",
        @"OK": @"確定", @"Cancel": @"取消", @"Enable": @"啟用", @"Apply": @"套用", @"Service may be temporarily lost if LTE is unavailable.": @"若 LTE 無法使用，服務可能暫時中斷。", @"There are no pending bands to apply.": @"沒有待套用的頻段。", @"Tap “Refresh status” before editing bands.": @"編輯頻段前請先點選「更新狀態」。", @"Only these LTE bands will be allowed:\n\n%@": @"只會允許以下 LTE 頻段：\n\n%@",
        @"Quick selection": @"快速選擇", @"Current active selection": @"目前啟用選擇", @"All supported": @"全部支援", @"FDD only": @"僅 FDD", @"TDD only": @"僅 TDD", @"Clear all": @"全部取消", @"Other": @"其他", @"Frequency not catalogued": @"頻率尚未收錄", @"Search country": @"搜尋國家/地區", @"%lu countries and territories": @"%lu 個國家與地區", @"No verified LTE bands in the dataset": @"資料集中沒有已驗證的 LTE 頻段",
        @"Reference LTE bands": @"參考 LTE 頻段", @"Summary": @"摘要", @"Prepare selection": @"準備選擇", @"Country": @"國家/地區", @"Country bands": @"該地區頻段", @"No data": @"無資料", @"Compatible with iPhone": @"與 iPhone 相容", @"Refresh Control first": @"請先在控制頁更新", @"Prepare compatible bands": @"準備相容頻段", @"Refresh from Control first": @"請先從控制頁更新", @"Selection prepared": @"已準備選擇", @"Stay here": @"留在此頁", @"Go to Control": @"前往控制",
        @"Manage frequencies for %@": @"管理 %@ 的頻率", @"Country frequencies": @"國家/地區頻率", @"Available for this iPhone": @"此 iPhone 可用", @"Changes here only update the pending selection. Tap Apply in Control to change the modem.": @"此處的變更只會更新待套用選擇。請在控制頁點選套用才會更改數據機。", @"Select all country bands": @"選取該地區全部頻段", @"Use current active country bands": @"使用目前啟用的該地區頻段",
        @"About": @"關於", @"Credits": @"製作資訊", @"Created by Gokuencinar · GokuEn": @"由 Gokuencinar · GokuEn 製作", @"Updates": @"更新", @"Check for updates": @"檢查更新", @"Release notes": @"更新說明", @"Resources": @"資源", @"Visit GokuEnREPO": @"造訪 GokuEnREPO", @"More information about frequencies": @"更多頻率資訊", @"Language": @"語言", @"Change language": @"變更語言", @"Frequency glossary": @"頻率詞彙表", @"Checking for updates…": @"正在檢查更新…", @"You are using the latest published version (%@).": @"你正在使用最新公開版本（%@）。", @"Could not check for updates.": @"無法檢查更新。", @"Loading release notes…": @"正在載入更新說明…", @"Could not load release notes.": @"無法載入更新說明。",
        @"Not queried": @"尚未查詢", @"Tap Refresh": @"點選更新", @"Querying daemon…": @"正在查詢 daemon…", @"Ready": @"就緒", @"Unavailable": @"無法使用", @"Select at least one LTE band.": @"請至少選擇一個 LTE 頻段。", @"Tap Refresh status first.": @"請先點選更新狀態。", @"Modem state updated.": @"數據機狀態已更新。", @"Network mode updated.": @"網路模式已更新。", @"LTE selection applied.": @"LTE 選擇已套用。", @"Field Test requested.": @"已要求開啟 Field Test。"
    }; }); return map;
}

static NSDictionary<NSString *, NSString *> *BLSimplifiedChinese(void) {
    static NSDictionary *map; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = @{
        @"Control": @"控制", @"Countries": @"国家/地区", @"Info": @"信息", @"Refresh status": @"刷新状态", @"Refreshing…": @"刷新中…", @"STATUS": @"状态", @"Current network": @"当前网络", @"Serving band": @"当前频段", @"Allowed bands": @"允许频段", @"Result": @"结果",
        @"NETWORK MODE": @"网络模式", @"Configuration": @"配置", @"Automatic mode": @"自动模式", @"LTE / 4G only": @"仅 LTE / 4G", @"LTE BANDS": @"LTE 频段", @"Pending selection": @"待应用选择", @"Edit bands": @"编辑频段", @"Apply selection": @"应用选择", @"Restore previous selection": @"恢复上次选择", @"Restore all supported": @"恢复所有支持频段", @"TOOLS": @"工具", @"Open Field Test": @"打开 Field Test",
        @"OK": @"确定", @"Cancel": @"取消", @"Enable": @"启用", @"Apply": @"应用", @"Service may be temporarily lost if LTE is unavailable.": @"如果 LTE 不可用，服务可能暂时中断。", @"There are no pending bands to apply.": @"没有待应用的频段。", @"Tap “Refresh status” before editing bands.": @"编辑频段前请先点击“刷新状态”。", @"Only these LTE bands will be allowed:\n\n%@": @"仅允许以下 LTE 频段：\n\n%@",
        @"Quick selection": @"快速选择", @"Current active selection": @"当前活动选择", @"All supported": @"全部支持", @"FDD only": @"仅 FDD", @"TDD only": @"仅 TDD", @"Clear all": @"全部取消", @"Other": @"其他", @"Frequency not catalogued": @"频率未收录", @"Search country": @"搜索国家/地区", @"%lu countries and territories": @"%lu 个国家和地区", @"No verified LTE bands in the dataset": @"数据集中没有已验证的 LTE 频段",
        @"Reference LTE bands": @"参考 LTE 频段", @"Summary": @"摘要", @"Prepare selection": @"准备选择", @"Country": @"国家/地区", @"Country bands": @"该地区频段", @"No data": @"无数据", @"Compatible with iPhone": @"与 iPhone 兼容", @"Refresh Control first": @"请先在控制页刷新", @"Prepare compatible bands": @"准备兼容频段", @"Refresh from Control first": @"请先从控制页刷新", @"Selection prepared": @"选择已准备", @"Stay here": @"留在这里", @"Go to Control": @"前往控制",
        @"Manage frequencies for %@": @"管理 %@ 的频率", @"Country frequencies": @"国家/地区频率", @"Available for this iPhone": @"此 iPhone 可用", @"Changes here only update the pending selection. Tap Apply in Control to change the modem.": @"此处的更改只会更新待应用选择。请在控制页点击应用后才会修改基带。", @"Select all country bands": @"选择该地区全部频段", @"Use current active country bands": @"使用当前活动的该地区频段",
        @"About": @"关于", @"Credits": @"鸣谢", @"Created by Gokuencinar · GokuEn": @"由 Gokuencinar · GokuEn 制作", @"Updates": @"更新", @"Check for updates": @"检查更新", @"Release notes": @"更新说明", @"Resources": @"资源", @"Visit GokuEnREPO": @"访问 GokuEnREPO", @"More information about frequencies": @"更多频率信息", @"Language": @"语言", @"Change language": @"更改语言", @"Frequency glossary": @"频率术语表", @"Checking for updates…": @"正在检查更新…", @"You are using the latest published version (%@).": @"你正在使用最新发布版本（%@）。", @"Could not check for updates.": @"无法检查更新。", @"Loading release notes…": @"正在加载更新说明…", @"Could not load release notes.": @"无法加载更新说明。",
        @"Not queried": @"尚未查询", @"Tap Refresh": @"点击刷新", @"Querying daemon…": @"正在查询 daemon…", @"Ready": @"就绪", @"Unavailable": @"不可用", @"Select at least one LTE band.": @"请至少选择一个 LTE 频段。", @"Tap Refresh status first.": @"请先点击刷新状态。", @"Modem state updated.": @"基带状态已更新。", @"Network mode updated.": @"网络模式已更新。", @"LTE selection applied.": @"LTE 选择已应用。", @"Field Test requested.": @"已请求打开 Field Test。"
    }; }); return map;
}

static NSDictionary<NSString *, NSString *> *BLJapanese(void) {
    static NSDictionary *map; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = @{
        @"Control": @"コントロール", @"Countries": @"国/地域", @"Info": @"情報", @"Refresh status": @"状態を更新", @"Refreshing…": @"更新中…", @"STATUS": @"状態", @"Current network": @"現在のネットワーク", @"Serving band": @"接続中のバンド", @"Allowed bands": @"許可バンド", @"Result": @"結果",
        @"NETWORK MODE": @"ネットワークモード", @"Configuration": @"設定", @"Automatic mode": @"自動モード", @"LTE / 4G only": @"LTE / 4G のみ", @"LTE BANDS": @"LTE バンド", @"Pending selection": @"保留中の選択", @"Edit bands": @"バンドを編集", @"Apply selection": @"選択を適用", @"Restore previous selection": @"前の選択を復元", @"Restore all supported": @"対応バンドをすべて復元", @"TOOLS": @"ツール", @"Open Field Test": @"Field Test を開く",
        @"OK": @"OK", @"Cancel": @"キャンセル", @"Enable": @"有効にする", @"Apply": @"適用", @"Service may be temporarily lost if LTE is unavailable.": @"LTE が利用できない場合、一時的に通信できなくなることがあります。", @"There are no pending bands to apply.": @"適用待ちのバンドがありません。", @"Tap “Refresh status” before editing bands.": @"バンドを編集する前に「状態を更新」をタップしてください。", @"Only these LTE bands will be allowed:\n\n%@": @"次の LTE バンドのみを許可します：\n\n%@",
        @"Quick selection": @"クイック選択", @"Current active selection": @"現在の有効な選択", @"All supported": @"すべての対応バンド", @"FDD only": @"FDD のみ", @"TDD only": @"TDD のみ", @"Clear all": @"すべて解除", @"Other": @"その他", @"Frequency not catalogued": @"周波数未登録", @"Search country": @"国/地域を検索", @"%lu countries and territories": @"%lu の国と地域", @"No verified LTE bands in the dataset": @"データセットに確認済み LTE バンドがありません",
        @"Reference LTE bands": @"参考 LTE バンド", @"Summary": @"概要", @"Prepare selection": @"選択を準備", @"Country": @"国/地域", @"Country bands": @"国/地域のバンド", @"No data": @"データなし", @"Compatible with iPhone": @"iPhone 対応", @"Refresh Control first": @"先にコントロールを更新", @"Prepare compatible bands": @"対応バンドを準備", @"Refresh from Control first": @"先にコントロールから更新", @"Selection prepared": @"選択を準備しました", @"Stay here": @"ここに留まる", @"Go to Control": @"コントロールへ",
        @"Manage frequencies for %@": @"%@ の周波数を管理", @"Country frequencies": @"国/地域の周波数", @"Available for this iPhone": @"この iPhone で利用可能", @"Changes here only update the pending selection. Tap Apply in Control to change the modem.": @"ここでの変更は保留中の選択だけを更新します。モデムを変更するにはコントロールで適用をタップしてください。", @"Select all country bands": @"国/地域の全バンドを選択", @"Use current active country bands": @"現在有効な国/地域バンドを使用",
        @"About": @"このアプリについて", @"Credits": @"クレジット", @"Created by Gokuencinar · GokuEn": @"制作：Gokuencinar · GokuEn", @"Updates": @"アップデート", @"Check for updates": @"アップデートを確認", @"Release notes": @"リリースノート", @"Resources": @"リソース", @"Visit GokuEnREPO": @"GokuEnREPO を開く", @"More information about frequencies": @"周波数について詳しく", @"Language": @"言語", @"Change language": @"言語を変更", @"Frequency glossary": @"周波数用語集", @"Checking for updates…": @"アップデートを確認中…", @"You are using the latest published version (%@).": @"最新の公開版（%@）を使用しています。", @"Could not check for updates.": @"アップデートを確認できませんでした。", @"Loading release notes…": @"リリースノートを読み込み中…", @"Could not load release notes.": @"リリースノートを読み込めませんでした。",
        @"Not queried": @"未取得", @"Tap Refresh": @"更新をタップ", @"Querying daemon…": @"daemon に問い合わせ中…", @"Ready": @"準備完了", @"Unavailable": @"利用不可", @"Select at least one LTE band.": @"LTE バンドを少なくとも1つ選択してください。", @"Tap Refresh status first.": @"先に状態を更新してください。", @"Modem state updated.": @"モデム状態を更新しました。", @"Network mode updated.": @"ネットワークモードを更新しました。", @"LTE selection applied.": @"LTE 選択を適用しました。", @"Field Test requested.": @"Field Test を要求しました。"
    }; }); return map;
}

static NSDictionary<NSString *, NSString *> *BLSupplementalTranslations(NSString *code) {
    static NSDictionary *all; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        all = @{
            @"fr": @{
                @"Automatic": @"Automatique", @"Frequencies for %@": @"Fréquences de %@", @"Available frequencies": @"Fréquences disponibles",
                @"Select a country from the Countries tab first.": @"Sélectionnez d’abord un pays dans l’onglet Pays.",
                @"Tap “Refresh status” before managing country frequencies.": @"Touchez « Actualiser l’état » avant de gérer les fréquences du pays.",
                @"This iPhone does not report LTE bands compatible with the selected country.": @"Cet iPhone ne signale aucune bande LTE compatible avec le pays sélectionné.",
                @"Frequency information": @"Informations sur les fréquences",
                @"The language is applied immediately and saved for future BandLock launches.": @"La langue est appliquée immédiatement et enregistrée pour les prochains lancements de BandLock.",
                @"Fourth-generation mobile technology. BandLock 0.6.x only changes LTE/4G band selection.": @"Technologie mobile de quatrième génération. BandLock 0.6.x modifie uniquement la sélection des bandes LTE/4G.",
                @"Each B identifies a standardized LTE band. The number is not a single frequency by itself: each band defines uplink and downlink ranges.": @"Chaque B identifie une bande LTE normalisée. Le numéro n’est pas une fréquence unique : chaque bande définit des plages montantes et descendantes.",
                @"Frequency units. 1000 MHz equals 1 GHz. Lower bands generally provide wider coverage; higher bands generally provide more capacity.": @"Unités de fréquence. 1000 MHz valent 1 GHz. Les bandes basses offrent généralement plus de couverture et les bandes hautes davantage de capacité.",
                @"Frequency Division Duplex. It uses separate frequency blocks for uplink and downlink at the same time.": @"Frequency Division Duplex. Utilise des blocs de fréquences séparés simultanément pour la voie montante et descendante.",
                @"Time Division Duplex. Uplink and downlink share the same frequency block and alternate over time.": @"Time Division Duplex. La voie montante et descendante partagent le même bloc de fréquences et alternent dans le temps.",
                @"Supplemental Downlink. It is extra downlink-only spectrum; it normally complements another band and should not be used as the only selection.": @"Supplemental Downlink. Spectre supplémentaire réservé à la réception ; il complète normalement une autre bande et ne doit pas être la seule sélection.",
                @"Asia-Pacific Telecommunity 700 MHz frequency plan. In LTE it is commonly associated with Band 28 and regional variants.": @"Plan de fréquences 700 MHz de l’Asia-Pacific Telecommunity. En LTE, il est couramment associé à la bande 28 et à ses variantes régionales.",
                @"Advanced Wireless Services. A North American name for several paired spectrum blocks, such as AWS-1 or AWS-3.": @"Advanced Wireless Services. Nom nord-américain de plusieurs blocs de spectre appariés, comme AWS-1 ou AWS-3.",
                @"Personal Communications Service. A common name for cellular spectrum around 1900 MHz in North America.": @"Personal Communications Service. Nom courant du spectre cellulaire autour de 1900 MHz en Amérique du Nord.",
                @"Wireless Communications Service. Spectrum blocks around 2.3 GHz used, among others, by LTE Band 30.": @"Wireless Communications Service. Blocs de spectre autour de 2,3 GHz utilisés notamment par la bande LTE 30.",
                @"Citizens Broadband Radio Service. Shared spectrum around 3.5 GHz in the United States; LTE Band 48 is one of its uses.": @"Citizens Broadband Radio Service. Spectre partagé autour de 3,5 GHz aux États-Unis ; la bande LTE 48 en est un usage.",
                @"Licensed Assisted Access. LTE that aggregates unlicensed spectrum, usually at 5 GHz, with a licensed LTE carrier.": @"Licensed Assisted Access. LTE qui agrège du spectre sans licence, généralement à 5 GHz, avec une porteuse LTE licenciée.",
                @"A family of mobile technologies predating LTE. It is not an LTE FDD/TDD mode and BandLock does not lock CDMA bands.": @"Famille de technologies mobiles antérieures au LTE. Ce n’est pas un mode FDD/TDD LTE et BandLock ne verrouille pas les bandes CDMA.",
                @"3G technologies. HSPA/HSDPA are evolutions of UMTS. They may appear as the current network if the iPhone leaves LTE.": @"Technologies 3G. HSPA/HSDPA sont des évolutions d’UMTS et peuvent apparaître si l’iPhone quitte le LTE.",
                @"2G technologies. They may exist as fallback on older networks; they are not part of BandLock's LTE band selector.": @"Technologies 2G. Elles peuvent servir de repli sur d’anciens réseaux et ne font pas partie du sélecteur LTE de BandLock.",
                @"Radio Access Technology. It identifies the radio technology used by the phone, such as LTE, UMTS/HSDPA or EDGE.": @"Radio Access Technology. Indique la technologie radio utilisée par le téléphone, par exemple LTE, UMTS/HSDPA ou EDGE.",
                @"New Radio is the 5G technology. The current BandLock version controls LTE/4G and does not claim 5G NR band locking.": @"New Radio est la technologie 5G. La version actuelle de BandLock contrôle le LTE/4G et ne revendique pas le verrouillage des bandes 5G NR.",
                @"The frequency actually used at any moment depends on the carrier, location, network and carrier aggregation.": @"La fréquence réellement utilisée dépend de l’opérateur, de la zone, du réseau et de l’agrégation de porteuses."
            },
            @"de": @{
                @"Automatic": @"Automatisch", @"Frequencies for %@": @"Frequenzen für %@", @"Available frequencies": @"Verfügbare Frequenzen",
                @"Select a country from the Countries tab first.": @"Wähle zuerst ein Land im Tab Länder aus.",
                @"Tap “Refresh status” before managing country frequencies.": @"Tippe vor der Verwaltung der Länderfrequenzen auf „Status aktualisieren“.",
                @"This iPhone does not report LTE bands compatible with the selected country.": @"Dieses iPhone meldet keine LTE-Bänder, die mit dem ausgewählten Land kompatibel sind.",
                @"Frequency information": @"Frequenzinformationen", @"The language is applied immediately and saved for future BandLock launches.": @"Die Sprache wird sofort angewendet und für zukünftige BandLock-Starts gespeichert.",
                @"Fourth-generation mobile technology. BandLock 0.6.x only changes LTE/4G band selection.": @"Mobilfunktechnik der vierten Generation. BandLock 0.6.x ändert nur die LTE/4G-Bandauswahl.",
                @"Each B identifies a standardized LTE band. The number is not a single frequency by itself: each band defines uplink and downlink ranges.": @"Jedes B bezeichnet ein standardisiertes LTE-Band. Die Nummer ist keine einzelne Frequenz; jedes Band definiert Bereiche für Up- und Downlink.",
                @"Frequency units. 1000 MHz equals 1 GHz. Lower bands generally provide wider coverage; higher bands generally provide more capacity.": @"Frequenzeinheiten. 1000 MHz entsprechen 1 GHz. Niedrige Bänder bieten meist mehr Reichweite, hohe Bänder meist mehr Kapazität.",
                @"Frequency Division Duplex. It uses separate frequency blocks for uplink and downlink at the same time.": @"Frequency Division Duplex. Verwendet gleichzeitig getrennte Frequenzblöcke für Up- und Downlink.",
                @"Time Division Duplex. Uplink and downlink share the same frequency block and alternate over time.": @"Time Division Duplex. Up- und Downlink teilen denselben Frequenzblock und wechseln sich zeitlich ab.",
                @"Supplemental Downlink. It is extra downlink-only spectrum; it normally complements another band and should not be used as the only selection.": @"Supplemental Downlink. Zusätzlicher reiner Downlink; ergänzt normalerweise ein anderes Band und sollte nicht allein ausgewählt werden.",
                @"Asia-Pacific Telecommunity 700 MHz frequency plan. In LTE it is commonly associated with Band 28 and regional variants.": @"700-MHz-Frequenzplan der Asia-Pacific Telecommunity. Bei LTE ist er meist mit Band 28 und regionalen Varianten verbunden.",
                @"Advanced Wireless Services. A North American name for several paired spectrum blocks, such as AWS-1 or AWS-3.": @"Advanced Wireless Services. Nordamerikanische Bezeichnung für mehrere gepaarte Spektrumblöcke wie AWS-1 oder AWS-3.",
                @"Personal Communications Service. A common name for cellular spectrum around 1900 MHz in North America.": @"Personal Communications Service. Übliche Bezeichnung für Mobilfunkspektrum um 1900 MHz in Nordamerika.",
                @"Wireless Communications Service. Spectrum blocks around 2.3 GHz used, among others, by LTE Band 30.": @"Wireless Communications Service. Spektrumblöcke um 2,3 GHz, die unter anderem von LTE Band 30 genutzt werden.",
                @"Citizens Broadband Radio Service. Shared spectrum around 3.5 GHz in the United States; LTE Band 48 is one of its uses.": @"Citizens Broadband Radio Service. Geteiltes Spektrum um 3,5 GHz in den USA; LTE Band 48 ist eine Nutzung davon.",
                @"Licensed Assisted Access. LTE that aggregates unlicensed spectrum, usually at 5 GHz, with a licensed LTE carrier.": @"Licensed Assisted Access. LTE bündelt unlizenziertes Spektrum, meist bei 5 GHz, mit einem lizenzierten LTE-Träger.",
                @"A family of mobile technologies predating LTE. It is not an LTE FDD/TDD mode and BandLock does not lock CDMA bands.": @"Familie älterer Mobilfunktechniken vor LTE. Es ist kein LTE-FDD/TDD-Modus; BandLock sperrt keine CDMA-Bänder.",
                @"3G technologies. HSPA/HSDPA are evolutions of UMTS. They may appear as the current network if the iPhone leaves LTE.": @"3G-Technologien. HSPA/HSDPA sind Weiterentwicklungen von UMTS und können erscheinen, wenn das iPhone LTE verlässt.",
                @"2G technologies. They may exist as fallback on older networks; they are not part of BandLock's LTE band selector.": @"2G-Technologien. Sie können in älteren Netzen als Rückfall dienen und gehören nicht zum LTE-Bandwähler von BandLock.",
                @"Radio Access Technology. It identifies the radio technology used by the phone, such as LTE, UMTS/HSDPA or EDGE.": @"Radio Access Technology. Bezeichnet die vom Telefon verwendete Funktechnik, z. B. LTE, UMTS/HSDPA oder EDGE.",
                @"New Radio is the 5G technology. The current BandLock version controls LTE/4G and does not claim 5G NR band locking.": @"New Radio ist die 5G-Technik. Die aktuelle BandLock-Version steuert LTE/4G und beansprucht keine 5G-NR-Bandsperre.",
                @"The frequency actually used at any moment depends on the carrier, location, network and carrier aggregation.": @"Die tatsächlich verwendete Frequenz hängt von Anbieter, Standort, Netz und Carrier Aggregation ab."
            },
            @"zh-Hant": @{
                @"Automatic": @"自動", @"Frequencies for %@": @"%@ 的頻率", @"Available frequencies": @"可用頻率", @"Select a country from the Countries tab first.": @"請先在國家/地區分頁選擇一個地區。", @"Tap “Refresh status” before managing country frequencies.": @"管理地區頻率前請先點選「更新狀態」。", @"This iPhone does not report LTE bands compatible with the selected country.": @"此 iPhone 沒有回報與所選地區相容的 LTE 頻段。", @"Frequency information": @"頻率資訊", @"The language is applied immediately and saved for future BandLock launches.": @"語言會立即套用，並保存供之後啟動 BandLock 使用。",
                @"Fourth-generation mobile technology. BandLock 0.6.x only changes LTE/4G band selection.": @"第四代行動通訊技術。BandLock 0.6.x 只修改 LTE/4G 頻段選擇。", @"Each B identifies a standardized LTE band. The number is not a single frequency by itself: each band defines uplink and downlink ranges.": @"每個 B 代表一個標準 LTE 頻段。數字本身不是單一頻率；每個頻段都定義上行與下行範圍。", @"Frequency units. 1000 MHz equals 1 GHz. Lower bands generally provide wider coverage; higher bands generally provide more capacity.": @"頻率單位。1000 MHz 等於 1 GHz。較低頻段通常覆蓋較廣，較高頻段通常容量較大。", @"Frequency Division Duplex. It uses separate frequency blocks for uplink and downlink at the same time.": @"分頻雙工。上行與下行同時使用不同的頻率區塊。", @"Time Division Duplex. Uplink and downlink share the same frequency block and alternate over time.": @"分時雙工。上行與下行共用同一頻率區塊並按時間交替。", @"Supplemental Downlink. It is extra downlink-only spectrum; it normally complements another band and should not be used as the only selection.": @"補充下行。額外的純下行頻譜，通常搭配其他頻段，不應作為唯一選擇。",
                @"Asia-Pacific Telecommunity 700 MHz frequency plan. In LTE it is commonly associated with Band 28 and regional variants.": @"亞太電信組織的 700 MHz 頻率規劃。在 LTE 中通常與 Band 28 及其區域變體相關。", @"Advanced Wireless Services. A North American name for several paired spectrum blocks, such as AWS-1 or AWS-3.": @"Advanced Wireless Services。北美對多組成對頻譜的稱呼，例如 AWS-1、AWS-3。", @"Personal Communications Service. A common name for cellular spectrum around 1900 MHz in North America.": @"Personal Communications Service。北美約 1900 MHz 行動頻譜的常用名稱。", @"Wireless Communications Service. Spectrum blocks around 2.3 GHz used, among others, by LTE Band 30.": @"Wireless Communications Service。約 2.3 GHz 的頻譜區塊，LTE Band 30 等會使用。", @"Citizens Broadband Radio Service. Shared spectrum around 3.5 GHz in the United States; LTE Band 48 is one of its uses.": @"Citizens Broadband Radio Service。美國約 3.5 GHz 的共享頻譜，LTE Band 48 是其用途之一。", @"Licensed Assisted Access. LTE that aggregates unlicensed spectrum, usually at 5 GHz, with a licensed LTE carrier.": @"Licensed Assisted Access。將通常位於 5 GHz 的免授權頻譜與授權 LTE 載波聚合。", @"A family of mobile technologies predating LTE. It is not an LTE FDD/TDD mode and BandLock does not lock CDMA bands.": @"LTE 之前的一類行動通訊技術。它不是 LTE 的 FDD/TDD 模式，BandLock 也不鎖定 CDMA 頻段。", @"3G technologies. HSPA/HSDPA are evolutions of UMTS. They may appear as the current network if the iPhone leaves LTE.": @"3G 技術。HSPA/HSDPA 是 UMTS 的演進；iPhone 離開 LTE 時可能顯示為目前網路。", @"2G technologies. They may exist as fallback on older networks; they are not part of BandLock's LTE band selector.": @"2G 技術。舊網路可能用作備援，但不屬於 BandLock 的 LTE 頻段選擇器。", @"Radio Access Technology. It identifies the radio technology used by the phone, such as LTE, UMTS/HSDPA or EDGE.": @"無線接取技術。表示手機正在使用的無線技術，例如 LTE、UMTS/HSDPA 或 EDGE。", @"New Radio is the 5G technology. The current BandLock version controls LTE/4G and does not claim 5G NR band locking.": @"New Radio 是 5G 技術。目前 BandLock 控制 LTE/4G，不宣稱支援 5G NR 頻段鎖定。", @"The frequency actually used at any moment depends on the carrier, location, network and carrier aggregation.": @"實際使用的頻率取決於營運商、位置、網路與載波聚合。"
            },
            @"zh-Hans": @{
                @"Automatic": @"自动", @"Frequencies for %@": @"%@ 的频率", @"Available frequencies": @"可用频率", @"Select a country from the Countries tab first.": @"请先在国家/地区标签页选择一个地区。", @"Tap “Refresh status” before managing country frequencies.": @"管理地区频率前请先点击“刷新状态”。", @"This iPhone does not report LTE bands compatible with the selected country.": @"此 iPhone 没有报告与所选地区兼容的 LTE 频段。", @"Frequency information": @"频率信息", @"The language is applied immediately and saved for future BandLock launches.": @"语言会立即应用，并保存供以后启动 BandLock 使用。",
                @"Fourth-generation mobile technology. BandLock 0.6.x only changes LTE/4G band selection.": @"第四代移动通信技术。BandLock 0.6.x 只修改 LTE/4G 频段选择。", @"Each B identifies a standardized LTE band. The number is not a single frequency by itself: each band defines uplink and downlink ranges.": @"每个 B 表示一个标准 LTE 频段。数字本身不是单一频率；每个频段都定义上行和下行范围。", @"Frequency units. 1000 MHz equals 1 GHz. Lower bands generally provide wider coverage; higher bands generally provide more capacity.": @"频率单位。1000 MHz 等于 1 GHz。低频段通常覆盖更广，高频段通常容量更大。", @"Frequency Division Duplex. It uses separate frequency blocks for uplink and downlink at the same time.": @"频分双工。上行和下行同时使用不同的频率块。", @"Time Division Duplex. Uplink and downlink share the same frequency block and alternate over time.": @"时分双工。上行和下行共享同一频率块并按时间交替。", @"Supplemental Downlink. It is extra downlink-only spectrum; it normally complements another band and should not be used as the only selection.": @"补充下行。额外的纯下行频谱，通常配合其他频段，不应作为唯一选择。",
                @"Asia-Pacific Telecommunity 700 MHz frequency plan. In LTE it is commonly associated with Band 28 and regional variants.": @"亚太电信组织 700 MHz 频率规划。在 LTE 中通常与 Band 28 及地区变体相关。", @"Advanced Wireless Services. A North American name for several paired spectrum blocks, such as AWS-1 or AWS-3.": @"Advanced Wireless Services。北美对多组成对频谱块的称呼，例如 AWS-1、AWS-3。", @"Personal Communications Service. A common name for cellular spectrum around 1900 MHz in North America.": @"Personal Communications Service。北美约 1900 MHz 蜂窝频谱的常用名称。", @"Wireless Communications Service. Spectrum blocks around 2.3 GHz used, among others, by LTE Band 30.": @"Wireless Communications Service。约 2.3 GHz 的频谱块，LTE Band 30 等会使用。", @"Citizens Broadband Radio Service. Shared spectrum around 3.5 GHz in the United States; LTE Band 48 is one of its uses.": @"Citizens Broadband Radio Service。美国约 3.5 GHz 的共享频谱，LTE Band 48 是其用途之一。", @"Licensed Assisted Access. LTE that aggregates unlicensed spectrum, usually at 5 GHz, with a licensed LTE carrier.": @"Licensed Assisted Access。将通常位于 5 GHz 的免许可频谱与许可 LTE 载波聚合。", @"A family of mobile technologies predating LTE. It is not an LTE FDD/TDD mode and BandLock does not lock CDMA bands.": @"LTE 之前的一类移动通信技术。它不是 LTE 的 FDD/TDD 模式，BandLock 也不锁定 CDMA 频段。", @"3G technologies. HSPA/HSDPA are evolutions of UMTS. They may appear as the current network if the iPhone leaves LTE.": @"3G 技术。HSPA/HSDPA 是 UMTS 的演进；iPhone 离开 LTE 时可能显示为当前网络。", @"2G technologies. They may exist as fallback on older networks; they are not part of BandLock's LTE band selector.": @"2G 技术。旧网络可能用作回退，但不属于 BandLock 的 LTE 频段选择器。", @"Radio Access Technology. It identifies the radio technology used by the phone, such as LTE, UMTS/HSDPA or EDGE.": @"无线接入技术。表示手机正在使用的无线技术，例如 LTE、UMTS/HSDPA 或 EDGE。", @"New Radio is the 5G technology. The current BandLock version controls LTE/4G and does not claim 5G NR band locking.": @"New Radio 是 5G 技术。目前 BandLock 控制 LTE/4G，不声明支持 5G NR 频段锁定。", @"The frequency actually used at any moment depends on the carrier, location, network and carrier aggregation.": @"实际使用的频率取决于运营商、位置、网络和载波聚合。"
            },
            @"ja": @{
                @"Automatic": @"自動", @"Frequencies for %@": @"%@ の周波数", @"Available frequencies": @"利用可能な周波数", @"Select a country from the Countries tab first.": @"先に国/地域タブで国または地域を選択してください。", @"Tap “Refresh status” before managing country frequencies.": @"国/地域の周波数を管理する前に「状態を更新」をタップしてください。", @"This iPhone does not report LTE bands compatible with the selected country.": @"この iPhone では選択した国/地域に対応する LTE バンドが報告されていません。", @"Frequency information": @"周波数情報", @"The language is applied immediately and saved for future BandLock launches.": @"言語はすぐに適用され、次回以降の BandLock 起動時にも保持されます。",
                @"Fourth-generation mobile technology. BandLock 0.6.x only changes LTE/4G band selection.": @"第4世代の移動通信技術です。BandLock 0.6.x は LTE/4G のバンド選択のみを変更します。", @"Each B identifies a standardized LTE band. The number is not a single frequency by itself: each band defines uplink and downlink ranges.": @"各 B は標準化された LTE バンドを示します。番号自体が単一の周波数ではなく、各バンドには上りと下りの範囲があります。", @"Frequency units. 1000 MHz equals 1 GHz. Lower bands generally provide wider coverage; higher bands generally provide more capacity.": @"周波数の単位です。1000 MHz は 1 GHz です。低いバンドは一般に広い範囲を、高いバンドはより大きな容量を提供します。", @"Frequency Division Duplex. It uses separate frequency blocks for uplink and downlink at the same time.": @"周波数分割複信。上りと下りで別々の周波数ブロックを同時に使用します。", @"Time Division Duplex. Uplink and downlink share the same frequency block and alternate over time.": @"時分割複信。上りと下りで同じ周波数ブロックを共有し、時間で交互に使用します。", @"Supplemental Downlink. It is extra downlink-only spectrum; it normally complements another band and should not be used as the only selection.": @"補助ダウンリンク。下り専用の追加スペクトラムで、通常は別のバンドを補助するため、これだけを選択すべきではありません。",
                @"Asia-Pacific Telecommunity 700 MHz frequency plan. In LTE it is commonly associated with Band 28 and regional variants.": @"Asia-Pacific Telecommunity の 700 MHz 周波数計画です。LTE では一般に Band 28 と地域別の派生に関連します。", @"Advanced Wireless Services. A North American name for several paired spectrum blocks, such as AWS-1 or AWS-3.": @"Advanced Wireless Services。AWS-1 や AWS-3 など、北米の複数の対向スペクトラムブロックの呼称です。", @"Personal Communications Service. A common name for cellular spectrum around 1900 MHz in North America.": @"Personal Communications Service。北米の約 1900 MHz の携帯電話用スペクトラムの一般的な呼称です。", @"Wireless Communications Service. Spectrum blocks around 2.3 GHz used, among others, by LTE Band 30.": @"Wireless Communications Service。約 2.3 GHz のスペクトラムブロックで、LTE Band 30 などが利用します。", @"Citizens Broadband Radio Service. Shared spectrum around 3.5 GHz in the United States; LTE Band 48 is one of its uses.": @"Citizens Broadband Radio Service。米国の約 3.5 GHz の共有スペクトラムで、LTE Band 48 はその利用例の一つです。", @"Licensed Assisted Access. LTE that aggregates unlicensed spectrum, usually at 5 GHz, with a licensed LTE carrier.": @"Licensed Assisted Access。通常 5 GHz の免許不要スペクトラムを、免許済み LTE キャリアと組み合わせます。", @"A family of mobile technologies predating LTE. It is not an LTE FDD/TDD mode and BandLock does not lock CDMA bands.": @"LTE より前の移動通信技術群です。LTE の FDD/TDD モードではなく、BandLock は CDMA バンドをロックしません。", @"3G technologies. HSPA/HSDPA are evolutions of UMTS. They may appear as the current network if the iPhone leaves LTE.": @"3G 技術です。HSPA/HSDPA は UMTS の発展形で、iPhone が LTE を離れると現在のネットワークとして表示されることがあります。", @"2G technologies. They may exist as fallback on older networks; they are not part of BandLock's LTE band selector.": @"2G 技術です。古いネットワークではフォールバックとして使われることがありますが、BandLock の LTE バンド選択には含まれません。", @"Radio Access Technology. It identifies the radio technology used by the phone, such as LTE, UMTS/HSDPA or EDGE.": @"無線アクセス技術。LTE、UMTS/HSDPA、EDGE など、電話が使用している無線方式を示します。", @"New Radio is the 5G technology. The current BandLock version controls LTE/4G and does not claim 5G NR band locking.": @"New Radio は 5G 技術です。現在の BandLock は LTE/4G を制御し、5G NR のバンドロックには対応をうたっていません。", @"The frequency actually used at any moment depends on the carrier, location, network and carrier aggregation.": @"実際に使用される周波数は、通信事業者、場所、ネットワーク、キャリアアグリゲーションによって異なります。"
            }
        };
    });
    return all[code] ?: @{};
}

NSString *BLLocalizedPair(NSString *es, NSString *en) {
    NSString *code = BLCurrentLanguageCode();
    if ([code isEqualToString:@"es"]) return es ?: en ?: @"";
    if ([code isEqualToString:@"en"]) return en ?: es ?: @"";
    NSDictionary *map = nil;
    if ([code isEqualToString:@"fr"]) map = BLFrench();
    else if ([code isEqualToString:@"de"]) map = BLGerman();
    else if ([code isEqualToString:@"zh-Hant"]) map = BLTraditionalChinese();
    else if ([code isEqualToString:@"zh-Hans"]) map = BLSimplifiedChinese();
    else if ([code isEqualToString:@"ja"]) map = BLJapanese();
    NSString *translated = map[en ?: @""] ?: BLSupplementalTranslations(code)[en ?: @""];
    return translated ?: en ?: es ?: @"";
}
