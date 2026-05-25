import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as infinityMagicMath;
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart'
    show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, SystemUiOverlayStyle, SystemChrome;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as infinityMagicTimezoneData;
import 'package:timezone/timezone.dart' as infinityMagicTimezone;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Если эти классы есть в main.dart – оставь импорт.
import 'main.dart' show MafiaHarbor, CaptainHarbor, BillHarbor;

// ============================================================================
// NCUP инфраструктура (бывшая Dress Retro инфраструктура)
// ============================================================================

class InfinityMagicLogger {
  const InfinityMagicLogger();

  void infinityMagicLogInfo(Object infinityMagicMessage) =>
      debugPrint('[DressRetroLogger] $infinityMagicMessage');

  void infinityMagicLogWarn(Object infinityMagicMessage) =>
      debugPrint('[DressRetroLogger/WARN] $infinityMagicMessage');

  void infinityMagicLogError(Object infinityMagicMessage) =>
      debugPrint('[DressRetroLogger/ERR] $infinityMagicMessage');
}

class InfinityMagicVault {
  static final InfinityMagicVault sharedInstance =
  InfinityMagicVault._internalConstructor();
  InfinityMagicVault._internalConstructor();
  factory InfinityMagicVault() => sharedInstance;

  final InfinityMagicLogger infinityMagicLoggerInstance =
  const InfinityMagicLogger();
}

// ============================================================================
// Константы (статистика/кеш) — строки в кавычках не меняем
// ============================================================================

const String metrLoadedOnceKey = 'wheel_loaded_once';
const String metrStatEndpoint = 'https://getgame.portalroullete.bar/stat';
const String metrCachedFcmKey = 'wheel_cached_fcm';

// НОВОЕ: ключи для сохранения SafeArea и цвета в SharedPreferences
const String infinityMagicSafeAreaEnabledKey = 'safearea_enabled';
const String infinityMagicSafeAreaColorKey = 'safearea_color';

// ---------------- Bank constants (из первого main.dart) ----------------

const Set<String> kBankSchemes = {
  'td',
  'rbc',
  'cibc',
  'scotiabank',
  'bmo',
  'bmodigitalbanking',
  'desjardins',
  'tangerine',
  'nationalbank',
  'simplii',
  'dominotoronto',
};

const Set<String> kBankDomains = {
  'td.com',
  'tdcanadatrust.com',
  'easyweb.td.com',
  'rbc.com',
  'royalbank.com',
  'online.royalbank.com',
  'cibc.com',
  'cibc.ca',
  'online.cibc.com',
  'scotiabank.com',
  'scotiaonline.scotiabank.com',
  'bmo.com',
  'bmo.ca',
  'bmodigitalbanking.com',
  'desjardins.com',
  'tangerine.ca',
  'nbc.ca',
  'nationalbank.ca',
  'simplii.com',
  'simplii.ca',
  'dominotoronto.com',
  'dominobank.com',
};

// ============================================================================
// Утилиты: InfinityMagicKit (бывший DressRetroKit)
// ============================================================================

class InfinityMagicKit {
  static bool infinityMagicLooksLikeBareMail(Uri infinityMagicUri) {
    final String infinityMagicScheme = infinityMagicUri.scheme;
    if (infinityMagicScheme.isNotEmpty) return false;
    final String infinityMagicRaw = infinityMagicUri.toString();
    return infinityMagicRaw.contains('@') && !infinityMagicRaw.contains(' ');
  }

  static Uri infinityMagicToMailto(Uri infinityMagicUri) {
    final String infinityMagicFull = infinityMagicUri.toString();
    final List<String> infinityMagicBits = infinityMagicFull.split('?');
    final String infinityMagicWho = infinityMagicBits.first;
    final Map<String, String> infinityMagicQuery =
    infinityMagicBits.length > 1
        ? Uri.splitQueryString(infinityMagicBits[1])
        : <String, String>{};
    return Uri(
      scheme: 'mailto',
      path: infinityMagicWho,
      queryParameters:
      infinityMagicQuery.isEmpty ? null : infinityMagicQuery,
    );
  }

  static Uri infinityMagicGmailize(Uri infinityMagicMailUri) {
    final Map<String, String> infinityMagicQp =
        infinityMagicMailUri.queryParameters;
    final Map<String, String> infinityMagicParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (infinityMagicMailUri.path.isNotEmpty)
        'to': infinityMagicMailUri.path,
      if ((infinityMagicQp['subject'] ?? '').isNotEmpty)
        'su': infinityMagicQp['subject']!,
      if ((infinityMagicQp['body'] ?? '').isNotEmpty)
        'body': infinityMagicQp['body']!,
      if ((infinityMagicQp['cc'] ?? '').isNotEmpty)
        'cc': infinityMagicQp['cc']!,
      if ((infinityMagicQp['bcc'] ?? '').isNotEmpty)
        'bcc': infinityMagicQp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', infinityMagicParams);
  }

  static String infinityMagicDigitsOnly(String infinityMagicSource) =>
      infinityMagicSource.replaceAll(RegExp(r'[^0-9+]'), '');
}

// ============================================================================
// Сервис открытия ссылок: InfinityMagicLinker (бывший DressRetroLinker)
// ============================================================================

class InfinityMagicLinker {
  static Future<bool> infinityMagicOpen(Uri infinityMagicUri) async {
    try {
      if (await launchUrl(
        infinityMagicUri,
        mode: LaunchMode.inAppBrowserView,
      )) {
        return true;
      }
      return await launchUrl(
        infinityMagicUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (infinityMagicError) {
      debugPrint('DressRetroLinker error: $infinityMagicError; url=$infinityMagicUri');
      try {
        return await launchUrl(
          infinityMagicUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }
}

// ============================================================================
// Bank helpers (из первого main.dart)
// ============================================================================

bool infinityMagicIsBankScheme(Uri uri) {
  final String scheme = uri.scheme.toLowerCase();
  return kBankSchemes.contains(scheme);
}

bool infinityMagicIsBankDomain(Uri uri) {
  final String host = uri.host.toLowerCase();
  if (host.isEmpty) return false;

  for (final String bank in kBankDomains) {
    final String bankHost = bank.toLowerCase();
    if (host == bankHost || host.endsWith('.$bankHost')) {
      return true;
    }
  }
  return false;
}

Future<bool> infinityMagicOpenBank(Uri uri) async {
  try {
    if (infinityMagicIsBankScheme(uri)) {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return ok;
    }

    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        infinityMagicIsBankDomain(uri)) {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return ok;
    }
  } catch (e) {
    debugPrint('infinityMagicOpenBank error: $e; url=$uri');
  }
  return false;
}

// ============================================================================
// FCM Background Handler
// ============================================================================

@pragma('vm:entry-point')
Future<void> infinityMagicFcmBackgroundHandler(
    RemoteMessage infinityMagicMessage) async {
  debugPrint("Spin ID: ${infinityMagicMessage.messageId}");
  debugPrint("Spin Data: ${infinityMagicMessage.data}");
}

// ============================================================================
// InfinityMagicDeviceProfile (бывший DressRetroDeviceProfile)
// ============================================================================

class InfinityMagicDeviceProfile {
  String? infinityMagicDeviceId;
  String? infinityMagicSessionId = 'wheel-one-off';
  String? infinityMagicPlatformKind;
  String? infinityMagicOsBuild;
  String? infinityMagicAppVersion;
  String? infinityMagicLocaleCode;
  String? infinityMagicTimezoneName;
  bool infinityMagicPushEnabled = true;

  // Новый UA из WebView
  String? infinityMagicBaseUserAgent;

  // Для SafeArea
  bool infinityMagicSafeAreaEnabled = false;
  String? infinityMagicSafeAreaColor;

  Future<void> infinityMagicInitialize() async {
    try {
      infinityMagicTimezoneData.initializeTimeZones();
    } catch (_) {}

    final DeviceInfoPlugin infinityMagicInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo infinityMagicAndroidInfo =
      await infinityMagicInfoPlugin.androidInfo;
      infinityMagicDeviceId = infinityMagicAndroidInfo.id;
      infinityMagicPlatformKind = 'android';
      infinityMagicOsBuild = infinityMagicAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo infinityMagicIosInfo =
      await infinityMagicInfoPlugin.iosInfo;
      infinityMagicDeviceId = infinityMagicIosInfo.identifierForVendor;
      infinityMagicPlatformKind = 'ios';
      infinityMagicOsBuild = infinityMagicIosInfo.systemVersion;
    }

    final PackageInfo infinityMagicPackageInfo =
    await PackageInfo.fromPlatform();
    infinityMagicAppVersion = infinityMagicPackageInfo.version;
    infinityMagicLocaleCode = Platform.localeName.split('_').first;
    infinityMagicTimezoneName = infinityMagicTimezone.local.name;
    infinityMagicSessionId =
    'wheel-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> infinityMagicAsMap({String? infinityMagicFcmToken}) =>
      <String, dynamic>{
        'fcm_token': infinityMagicFcmToken ?? 'missing_token',
        'device_id': infinityMagicDeviceId ?? 'missing_id',
        'app_name': 'joiler',
        'instance_id': infinityMagicSessionId ?? 'missing_session',
        'platform': infinityMagicPlatformKind ?? 'missing_system',
        'os_version': infinityMagicOsBuild ?? 'missing_build',
        'app_version': infinityMagicAppVersion ?? 'missing_app',
        'language': infinityMagicLocaleCode ?? 'en',
        'timezone': infinityMagicTimezoneName ?? 'UTC',
        'push_enabled': infinityMagicPushEnabled,
        'fthcashier': 'true',
        'safearea': infinityMagicSafeAreaEnabled,
        'safearea_color': infinityMagicSafeAreaColor ?? '',
        'base_ua': infinityMagicBaseUserAgent ?? '',
      };
}

// ============================================================================
// AppsFlyer шпион: InfinityMagicSpy (бывший DressRetroSpy)
// ============================================================================

class InfinityMagicSpy {
  AppsFlyerOptions? infinityMagicOptions;
  AppsflyerSdk? infinityMagicSdk;

  String infinityMagicAppsFlyerUid = '';
  String infinityMagicAppsFlyerData = '';

  void infinityMagicStart({VoidCallback? infinityMagicOnUpdate}) {
    final AppsFlyerOptions infinityMagicOpts = AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6756072063',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    infinityMagicOptions = infinityMagicOpts;
    infinityMagicSdk = AppsflyerSdk(infinityMagicOpts);

    infinityMagicSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    infinityMagicSdk?.startSDK(
      onSuccess: () => InfinityMagicVault()
          .infinityMagicLoggerInstance
          .infinityMagicLogInfo('WheelSpy started'),
      onError: (infinityMagicCode, infinityMagicMsg) => InfinityMagicVault()
          .infinityMagicLoggerInstance
          .infinityMagicLogError(
          'WheelSpy error $infinityMagicCode: $infinityMagicMsg'),
    );

    infinityMagicSdk?.onInstallConversionData((infinityMagicValue) {
      infinityMagicAppsFlyerData = infinityMagicValue.toString();
      infinityMagicOnUpdate?.call();
    });

    infinityMagicSdk?.getAppsFlyerUID().then((infinityMagicValue) {
      infinityMagicAppsFlyerUid = infinityMagicValue.toString();
      infinityMagicOnUpdate?.call();
    });
  }
}

// ============================================================================
// Мост для FCM токена: InfinityMagicFcmBridge (бывший DressRetroFcmBridge)
// ============================================================================

class InfinityMagicFcmBridge {
  final InfinityMagicLogger infinityMagicLog =
  const InfinityMagicLogger();
  String? infinityMagicToken;
  final List<void Function(String)> infinityMagicWaiters =
  <void Function(String)>[];

  String? get infinityMagicCurrentToken => infinityMagicToken;

  InfinityMagicFcmBridge() {
    const MethodChannel('com.example.fcm/token')
        .setMethodCallHandler((MethodCall infinityMagicCall) async {
      if (infinityMagicCall.method == 'setToken') {
        final String infinityMagicTokenString =
        infinityMagicCall.arguments as String;
        if (infinityMagicTokenString.isNotEmpty) {
          infinityMagicSetToken(infinityMagicTokenString);
        }
      }
    });

    infinityMagicRestoreToken();
  }

  Future<void> infinityMagicRestoreToken() async {
    try {
      final SharedPreferences infinityMagicPrefs =
      await SharedPreferences.getInstance();
      final String? infinityMagicCached =
      infinityMagicPrefs.getString(metrCachedFcmKey);
      if (infinityMagicCached != null && infinityMagicCached.isNotEmpty) {
        infinityMagicSetToken(infinityMagicCached, infinityMagicNotify: false);
      }
    } catch (_) {}
  }

  Future<void> infinityMagicPersistToken(
      String infinityMagicNewToken) async {
    try {
      final SharedPreferences infinityMagicPrefs =
      await SharedPreferences.getInstance();
      await infinityMagicPrefs.setString(
          metrCachedFcmKey, infinityMagicNewToken);
    } catch (_) {}
  }

  void infinityMagicSetToken(
      String infinityMagicNewToken, {
        bool infinityMagicNotify = true,
      }) {
    infinityMagicToken = infinityMagicNewToken;
    infinityMagicPersistToken(infinityMagicNewToken);
    if (infinityMagicNotify) {
      for (final void Function(String) infinityMagicCallback
      in List<void Function(String)>.from(infinityMagicWaiters)) {
        try {
          infinityMagicCallback(infinityMagicNewToken);
        } catch (infinityMagicErr) {
          infinityMagicLog.infinityMagicLogWarn(
              'fcm waiter error: $infinityMagicErr');
        }
      }
      infinityMagicWaiters.clear();
    }
  }

  Future<void> infinityMagicWaitForToken(
      Function(String infinityMagicTokenValue) infinityMagicOnToken,
      ) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if ((infinityMagicToken ?? '').isNotEmpty) {
        infinityMagicOnToken(infinityMagicToken!);
        return;
      }

      infinityMagicWaiters.add(infinityMagicOnToken);
    } catch (infinityMagicErr) {
      infinityMagicLog.infinityMagicLogError(
          'wheelWaitToken error: $infinityMagicErr');
    }
  }
}

// ============================================================================
// InfinityMagicLoader (новый лоадер)
// ============================================================================

class InfinityMagicLoader extends StatefulWidget {
  const InfinityMagicLoader({Key? key}) : super(key: key);

  @override
  State<InfinityMagicLoader> createState() => _InfinityMagicLoaderState();
}

class _InfinityMagicLoaderState extends State<InfinityMagicLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController infinityMagicController;

  static const Color infinityMagicBackgroundColor = Color(0xFF05071B);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    infinityMagicController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    infinityMagicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: infinityMagicBackgroundColor,
      child: AnimatedBuilder(
        animation: infinityMagicController,
        builder: (BuildContext context, Widget? child) {
          final double infinityMagicPhase =
              infinityMagicController.value * 2 * infinityMagicMath.pi;
          return CircularProgressIndicator();
        },
      ),
    );
  }
}


// ============================================================================
// Статистика (InfinityMagicFinalUrl / InfinityMagicPostStat) — строки не меняем
// ============================================================================

Future<String> infinityMagicFinalUrl(
    String infinityMagicStartUrl, {
      int infinityMagicMaxHops = 10,
    }) async {
  final HttpClient infinityMagicClient = HttpClient();

  try {
    Uri infinityMagicCurrentUri = Uri.parse(infinityMagicStartUrl);

    for (int infinityMagicI = 0;
    infinityMagicI < infinityMagicMaxHops;
    infinityMagicI++) {
      final HttpClientRequest infinityMagicRequest =
      await infinityMagicClient.getUrl(infinityMagicCurrentUri);
      infinityMagicRequest.followRedirects = false;
      final HttpClientResponse infinityMagicResponse =
      await infinityMagicRequest.close();

      if (infinityMagicResponse.isRedirect) {
        final String? infinityMagicLoc = infinityMagicResponse.headers
            .value(HttpHeaders.locationHeader);
        if (infinityMagicLoc == null || infinityMagicLoc.isEmpty) break;

        final Uri infinityMagicNextUri = Uri.parse(infinityMagicLoc);
        infinityMagicCurrentUri = infinityMagicNextUri.hasScheme
            ? infinityMagicNextUri
            : infinityMagicCurrentUri.resolveUri(infinityMagicNextUri);
        continue;
      }

      return infinityMagicCurrentUri.toString();
    }

    return infinityMagicCurrentUri.toString();
  } catch (infinityMagicError) {
    debugPrint('wheelFinalUrl error: $infinityMagicError');
    return infinityMagicStartUrl;
  } finally {
    infinityMagicClient.close(force: true);
  }
}

Future<void> infinityMagicPostStat({
  required String infinityMagicEvent,
  required int infinityMagicTimeStart,
  required String infinityMagicUrl,
  required int infinityMagicTimeFinish,
  required String infinityMagicAppSid,
  int? infinityMagicFirstPageTs,
}) async {
  try {
    final String infinityMagicResolvedUrl =
    await infinityMagicFinalUrl(infinityMagicUrl);
    final Map<String, dynamic> infinityMagicPayload =
    <String, dynamic>{
      'event': infinityMagicEvent,
      'timestart': infinityMagicTimeStart,
      'timefinsh': infinityMagicTimeFinish,
      'url': infinityMagicResolvedUrl,
      'appleID': '6755681349',
      'open_count':
      '$infinityMagicAppSid/$infinityMagicTimeStart',
    };

    debugPrint('wheelStat $infinityMagicPayload');

    final http.Response infinityMagicResp = await http.post(
      Uri.parse('$metrStatEndpoint/$infinityMagicAppSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(infinityMagicPayload),
    );

    debugPrint(
        'wheelStat resp=${infinityMagicResp.statusCode} body=${infinityMagicResp.body}');
  } catch (infinityMagicError) {
    debugPrint('wheelPostStat error: $infinityMagicError');
  }
}

// ============================================================================
// WebView-экран: InfinityMagicTableView (бывший DressRetroTableView)
// SafeArea + SafeArea color + localStorage подхватываются из SharedPreferences
// ============================================================================

class InfinityMagicTableView extends StatefulWidget
    with WidgetsBindingObserver {
  String infinityMagicStartingUrl;
  InfinityMagicTableView(this.infinityMagicStartingUrl, {super.key});

  @override
  State<InfinityMagicTableView> createState() =>
      _InfinityMagicTableViewState(infinityMagicStartingUrl);
}

class _InfinityMagicTableViewState extends State<InfinityMagicTableView>
    with WidgetsBindingObserver {
  _InfinityMagicTableViewState(this.infinityMagicCurrentUrl);

  final InfinityMagicVault infinityMagicVaultInstance =
  InfinityMagicVault();

  late InAppWebViewController infinityMagicWebViewController;
  String? infinityMagicPushToken;
  final InfinityMagicDeviceProfile infinityMagicDeviceProfileInstance =
  InfinityMagicDeviceProfile();
  final InfinityMagicSpy infinityMagicSpyInstance = InfinityMagicSpy();

  bool infinityMagicOverlayBusy = false;
  String infinityMagicCurrentUrl;
  DateTime? infinityMagicLastPausedAt;

  bool infinityMagicLoadedOnceSent = false;
  int? infinityMagicFirstPageTimestamp;
  int infinityMagicStartLoadTimestamp = 0;

  // --------- Социальные / внешние хосты / схемы ---------

  final Set<String> infinityMagicExternalHosts = <String>{
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'bnl.com',
    'www.bnl.com',
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'instagram.com',
    'www.instagram.com',
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'www.x.com',
  };

  final Set<String> infinityMagicExternalSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'bnl',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
  };

  final Set<String> infinityMagicSpecialSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'viber',
    'skype',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
    'bnl',
  };

  // --------- UserAgent + SafeArea ---------

  String? _baseUserAgent;
  String _currentUserAgent = '';
  String? _serverUserAgent;
  bool _isInGoogleAuth = false;

  bool _safeAreaEnabled = false;
  Color _safeAreaBackgroundColor = Colors.black;

  // --------- POPUP (window.open) ---------

  InAppWebViewController? _popupWebViewController;
  bool _isPopupVisible = false;
  String? _popupUrl;
  CreateWindowAction? _popupCreateAction;
  bool _popupCanGoBack = false;
  String? _popupCurrentUrl;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onBackgroundMessage(
        infinityMagicFcmBackgroundHandler);

    infinityMagicFirstPageTimestamp =
        DateTime.now().millisecondsSinceEpoch;

    // 1) SafeArea state (enabled + color) подхватываем из SharedPreferences
    _loadSafeAreaFromPrefs();

    // 2) Push
    infinityMagicInitPushAndGetToken();

    // 3) Профиль устройства -> localStorage + SharedPreferences (app_data)
    infinityMagicDeviceProfileInstance
        .infinityMagicInitialize()
        .then((_) async {
      if (!mounted) return;
      await _updateLocalStorage();
    });

    // 4) FCM + AppsFlyer
    infinityMagicWireForegroundPushHandlers();
    infinityMagicBindPlatformNotificationTap();
    infinityMagicSpyInstance.infinityMagicStart(
      infinityMagicOnUpdate: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState infinityMagicState) {
    if (infinityMagicState == AppLifecycleState.paused) {
      infinityMagicLastPausedAt = DateTime.now();
    }
    if (infinityMagicState == AppLifecycleState.resumed) {
      if (Platform.isIOS && infinityMagicLastPausedAt != null) {
        final DateTime infinityMagicNow = DateTime.now();
        final Duration infinityMagicDrift =
        infinityMagicNow.difference(infinityMagicLastPausedAt!);
        if (infinityMagicDrift > const Duration(minutes: 25)) {
          infinityMagicForceReloadToLobby();
        }
      }
      infinityMagicLastPausedAt = null;
    }
  }

  void infinityMagicForceReloadToLobby() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((Duration infinityMagicDuration) {
      if (!mounted) return;
      // здесь можно вернуть в MafiaHarbor/CaptainHarbor/BillHarbor при необходимости
    });
  }

  // --------------------------------------------------------------------------
  // Push / FCM
  // --------------------------------------------------------------------------

  void infinityMagicWireForegroundPushHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage infinityMagicMsg) {
      if (infinityMagicMsg.data['uri'] != null) {
        infinityMagicNavigateTo(
            infinityMagicMsg.data['uri'].toString());
      } else {
        infinityMagicReturnToCurrentUrl();
      }
    });

    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage infinityMagicMsg) {
      if (infinityMagicMsg.data['uri'] != null) {
        infinityMagicNavigateTo(
            infinityMagicMsg.data['uri'].toString());
      } else {
        infinityMagicReturnToCurrentUrl();
      }
    });
  }

  void infinityMagicNavigateTo(String infinityMagicNewUrl) async {
    await infinityMagicWebViewController.loadUrl(
      urlRequest: URLRequest(url: WebUri(infinityMagicNewUrl)),
    );
  }

  void infinityMagicReturnToCurrentUrl() async {
    Future<void>.delayed(const Duration(seconds: 3), () {
      infinityMagicWebViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(infinityMagicCurrentUrl)),
      );
    });
  }

  Future<void> infinityMagicInitPushAndGetToken() async {
    final FirebaseMessaging infinityMagicFm = FirebaseMessaging.instance;
    await infinityMagicFm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    infinityMagicPushToken = await infinityMagicFm.getToken();
  }

  // --------------------------------------------------------------------------
  // Привязка канала: тап по уведомлению из native
  // --------------------------------------------------------------------------

  void infinityMagicBindPlatformNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall infinityMagicCall) async {
      if (infinityMagicCall.method == "onNotificationTap") {
        final Map<String, dynamic> infinityMagicPayload =
        Map<String, dynamic>.from(infinityMagicCall.arguments);
        debugPrint("URI from platform tap: ${infinityMagicPayload['uri']}");
        final String? infinityMagicUriString =
        infinityMagicPayload["uri"]?.toString();
        if (infinityMagicUriString != null &&
            !infinityMagicUriString.contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext infinityMagicContext) =>
                  InfinityMagicTableView(infinityMagicUriString),
            ),
                (Route<dynamic> infinityMagicRoute) => false,
          );
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // localStorage + SharedPreferences: профиль устройства
  // --------------------------------------------------------------------------

  /// Обновляем app_data в localStorage И синхронно сохраняем JSON в SharedPreferences
  Future<void> _updateLocalStorage() async {
    try {
      final Map<String, dynamic> infinityMagicData =
      infinityMagicDeviceProfileInstance.infinityMagicAsMap(
          infinityMagicFcmToken: infinityMagicPushToken);

      final String infinityMagicJson = jsonEncode(infinityMagicData);

      // 1) В localStorage WebView
      await infinityMagicWebViewController.evaluateJavascript(
        source:
        "localStorage.setItem('app_data', JSON.stringify($infinityMagicJson));",
      );

      // 2) В SharedPreferences (чтобы при следующем запуске можно было восстановить)
      final SharedPreferences infinityMagicPrefs =
      await SharedPreferences.getInstance();
      await infinityMagicPrefs.setString('app_data', infinityMagicJson);

      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogInfo(
          'app_data saved to localStorage & SharedPreferences: $infinityMagicJson');
    } catch (e, st) {
      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogError(
          'updateLocalStorage error: $e\n$st');
    }
  }

  /// Восстанавливаем app_data из SharedPreferences обратно в localStorage
  Future<void> _restoreAppDataFromPrefsToLocalStorage() async {
    try {
      final SharedPreferences infinityMagicPrefs =
      await SharedPreferences.getInstance();
      final String? infinityMagicSavedJson =
      infinityMagicPrefs.getString('app_data');
      if (infinityMagicSavedJson == null ||
          infinityMagicSavedJson.isEmpty) {
        return;
      }

      final String infinityMagicJs =
          "localStorage.setItem('app_data', JSON.stringify($infinityMagicSavedJson));";

      await infinityMagicWebViewController.evaluateJavascript(
          source: infinityMagicJs);

      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogInfo(
          'app_data restored from SharedPreferences to localStorage: $infinityMagicSavedJson');
    } catch (e, st) {
      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogError(
          '_restoreAppDataFromPrefsToLocalStorage error: $e\n$st');
    }
  }

  // --------------------------------------------------------------------------
  // UserAgent / SafeArea helpers
  // --------------------------------------------------------------------------

  bool _isGoogleUrl(Uri uri) {
    final String full = uri.toString().toLowerCase();
    return full.contains('google');
  }

  Future<void> _applyUserAgent({
    String? fullua,
    String? uatail,
  }) async {
    if (_baseUserAgent == null || _baseUserAgent!.trim().isEmpty) {
      try {
        final infinityMagicUa =
        await infinityMagicWebViewController.evaluateJavascript(
          source: "navigator.userAgent",
        );
        if (infinityMagicUa is String &&
            infinityMagicUa.trim().isNotEmpty) {
          _baseUserAgent = infinityMagicUa.trim();
          _currentUserAgent = _baseUserAgent!;
          infinityMagicDeviceProfileInstance.infinityMagicBaseUserAgent =
              _baseUserAgent;
          infinityMagicVaultInstance.infinityMagicLoggerInstance
              .infinityMagicLogInfo(
              'Base User-Agent detected: $_baseUserAgent');
        }
      } catch (e) {
        infinityMagicVaultInstance.infinityMagicLoggerInstance
            .infinityMagicLogWarn(
            'Failed to get base userAgent from JS: $e');
      }
    }

    if (_baseUserAgent == null || _baseUserAgent!.trim().isEmpty) {
      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogWarn(
          'Base User-Agent is null, skip UA update');
      return;
    }

    String infinityMagicNewUa;
    if (fullua != null && fullua.trim().isNotEmpty) {
      infinityMagicNewUa = fullua.trim();
    } else if (uatail != null && uatail.trim().isNotEmpty) {
      infinityMagicNewUa = "${_baseUserAgent!}/${uatail.trim()}";
    } else {
      infinityMagicNewUa = _baseUserAgent!;
    }

    _serverUserAgent = infinityMagicNewUa;
    infinityMagicVaultInstance.infinityMagicLoggerInstance
        .infinityMagicLogInfo('Server UA calculated: $_serverUserAgent');
  }

  Future<void> _updateUserAgentFromServerPayload(
      Map<dynamic, dynamic> infinityMagicRoot) async {
    String? fullua;
    String? uatail;

    final dynamic infinityMagicContent = infinityMagicRoot['content'];
    if (infinityMagicContent is Map) {
      if (infinityMagicContent['fullua'] != null &&
          infinityMagicContent['fullua']
              .toString()
              .trim()
              .isNotEmpty) {
        fullua = infinityMagicContent['fullua']
            .toString()
            .trim();
      }
      if (infinityMagicContent['uatail'] != null &&
          infinityMagicContent['uatail']
              .toString()
              .trim()
              .isNotEmpty) {
        uatail = infinityMagicContent['uatail']
            .toString()
            .trim();
      }
    }

    if (fullua == null &&
        infinityMagicRoot['fullua'] != null &&
        infinityMagicRoot['fullua'].toString().trim().isNotEmpty) {
      fullua =
          infinityMagicRoot['fullua'].toString().trim();
    }
    if (uatail == null &&
        infinityMagicRoot['uatail'] != null &&
        infinityMagicRoot['uatail'].toString().trim().isNotEmpty) {
      uatail =
          infinityMagicRoot['uatail'].toString().trim();
    }

    if (uatail == null) {
      final dynamic infinityMagicAdata =
      infinityMagicRoot['adata'];
      if (infinityMagicAdata is Map &&
          infinityMagicAdata['uatail'] != null &&
          infinityMagicAdata['uatail']
              .toString()
              .trim()
              .isNotEmpty) {
        uatail = infinityMagicAdata['uatail']
            .toString()
            .trim();
      }
    }

    await _applyUserAgent(fullua: fullua, uatail: uatail);
  }

  Future<void> _applyNormalUserAgentIfNeeded() async {
    if (_isInGoogleAuth) {
      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogInfo(
          'Skip normal UA apply because we are in Google auth');
      return;
    }

    final String infinityMagicTargetUa =
        _serverUserAgent ?? _baseUserAgent ?? 'random';

    if (infinityMagicTargetUa == _currentUserAgent) return;

    try {
      await infinityMagicWebViewController.setSettings(
        settings: InAppWebViewSettings(userAgent: infinityMagicTargetUa),
      );
      _currentUserAgent = infinityMagicTargetUa;
      debugPrint('[UA] NORMAL WEBVIEW USER AGENT: $_currentUserAgent');
    } catch (e) {
      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogError(
          'Error while setting UA "$infinityMagicTargetUa": $e');
    }
  }

  Future<void> _addRandomToUserAgentForGoogle() async {
    const String infinityMagicTargetUa = 'random';
    if (_currentUserAgent == infinityMagicTargetUa &&
        _isInGoogleAuth) return;

    try {
      await infinityMagicWebViewController.setSettings(
        settings:
        InAppWebViewSettings(userAgent: infinityMagicTargetUa),
      );
      _currentUserAgent = infinityMagicTargetUa;
      _isInGoogleAuth = true;
      debugPrint('[UA] GOOGLE RANDOM USER AGENT: $_currentUserAgent');
    } catch (e) {
      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogError(
          'Error setting RANDOM UA for Google: $e');
    }
  }

  Future<void> _restoreUserAgentAfterGoogleIfNeeded() async {
    if (!_isInGoogleAuth) return;
    _isInGoogleAuth = false;
    await _applyNormalUserAgentIfNeeded();
  }

  // Хелпер для парсинга HEX‑цвета (общий для SafeArea и prefs)
  Color _parseHexColor(
      String infinityMagicHex, {
        Color fallback = const Color(0xFF1A1A22),
      }) {
    String infinityMagicValue = infinityMagicHex.trim();
    if (infinityMagicValue.startsWith('#')) {
      infinityMagicValue = infinityMagicValue.substring(1);
    }
    if (infinityMagicValue.length == 6) {
      infinityMagicValue = 'FF$infinityMagicValue';
    }
    final int? infinityMagicIntColor =
    int.tryParse(infinityMagicValue, radix: 16);
    if (infinityMagicIntColor == null) return fallback;
    return Color(infinityMagicIntColor);
  }

  // НОВОЕ: загрузка SafeArea из SharedPreferences при старте
  Future<void> _loadSafeAreaFromPrefs() async {
    try {
      final SharedPreferences infinityMagicPrefs =
      await SharedPreferences.getInstance();
      final bool infinityMagicEnabled =
          infinityMagicPrefs.getBool(infinityMagicSafeAreaEnabledKey) ??
              false;
      final String infinityMagicColorHex =
          infinityMagicPrefs.getString(infinityMagicSafeAreaColorKey) ??
              '';

      Color infinityMagicBg = Colors.black;
      if (infinityMagicEnabled) {
        if (infinityMagicColorHex.isNotEmpty) {
          infinityMagicBg = _parseHexColor(
            infinityMagicColorHex,
            fallback: const Color(0xFF1A1A22),
          );
        } else {
          infinityMagicBg = const Color(0xFF1A1A22);
        }
      }

      if (!mounted) return;

      setState(() {
        _safeAreaEnabled = infinityMagicEnabled;
        _safeAreaBackgroundColor = infinityMagicBg;
        infinityMagicDeviceProfileInstance.infinityMagicSafeAreaEnabled =
            infinityMagicEnabled;
        infinityMagicDeviceProfileInstance.infinityMagicSafeAreaColor =
        infinityMagicEnabled
            ? (infinityMagicColorHex.isNotEmpty
            ? infinityMagicColorHex
            : '#1A1A22')
            : '';
      });

      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogInfo(
          'SafeArea loaded from prefs: enabled=$infinityMagicEnabled, color="$infinityMagicColorHex"');
    } catch (e, st) {
      infinityMagicVaultInstance.infinityMagicLoggerInstance
          .infinityMagicLogError(
          '_loadSafeAreaFromPrefs error: $e\n$st');
    }
  }

  void _updateSafeAreaFromServerPayload(
      Map<dynamic, dynamic> infinityMagicRoot) {
    bool? infinityMagicSafeArea;
    String? infinityMagicBgLightHex;
    String? infinityMagicBgDarkHex;

    final dynamic infinityMagicContent = infinityMagicRoot['content'];
    if (infinityMagicContent is Map) {
      if (infinityMagicContent['safearea'] != null) {
        final dynamic infinityMagicRaw =
        infinityMagicContent['safearea'];
        if (infinityMagicRaw is bool) {
          infinityMagicSafeArea = infinityMagicRaw;
        } else if (infinityMagicRaw is String) {
          final String infinityMagicV =
          infinityMagicRaw.toLowerCase().trim();
          if (infinityMagicV == 'true' ||
              infinityMagicV == '1' ||
              infinityMagicV == 'yes') {
            infinityMagicSafeArea = true;
          }
          if (infinityMagicV == 'false' ||
              infinityMagicV == '0' ||
              infinityMagicV == 'no') {
            infinityMagicSafeArea = false;
          }
        } else if (infinityMagicRaw is num) {
          infinityMagicSafeArea = infinityMagicRaw != 0;
        }
      }

      if (infinityMagicContent['safearea_color'] != null &&
          infinityMagicContent['safearea_color']
              .toString()
              .trim()
              .isNotEmpty) {
        infinityMagicBgLightHex =
            infinityMagicContent['safearea_color']
                .toString()
                .trim();
        infinityMagicBgDarkHex = infinityMagicBgLightHex;
      }
    }

    final dynamic infinityMagicAdata = infinityMagicRoot['adata'];
    if (infinityMagicAdata is Map) {
      if (infinityMagicSafeArea == null &&
          infinityMagicAdata['safearea'] != null) {
        final dynamic infinityMagicRaw =
        infinityMagicAdata['safearea'];
        if (infinityMagicRaw is bool) {
          infinityMagicSafeArea = infinityMagicRaw;
        } else if (infinityMagicRaw is String) {
          final String infinityMagicV =
          infinityMagicRaw.toLowerCase().trim();
          if (infinityMagicV == 'true' ||
              infinityMagicV == '1' ||
              infinityMagicV == 'yes') {
            infinityMagicSafeArea = true;
          }
          if (infinityMagicV == 'false' ||
              infinityMagicV == '0' ||
              infinityMagicV == 'no') {
            infinityMagicSafeArea = false;
          }
        } else if (infinityMagicRaw is num) {
          infinityMagicSafeArea = infinityMagicRaw != 0;
        }
      }

      if (infinityMagicAdata['bgsareaw'] != null &&
          infinityMagicAdata['bgsareaw']
              .toString()
              .trim()
              .isNotEmpty) {
        infinityMagicBgLightHex =
            infinityMagicAdata['bgsareaw'].toString().trim();
      }
      if (infinityMagicAdata['bgsareab'] != null &&
          infinityMagicAdata['bgsareab']
              .toString()
              .trim()
              .isNotEmpty) {
        infinityMagicBgDarkHex =
            infinityMagicAdata['bgsareab'].toString().trim();
      }
    }

    if (infinityMagicSafeArea == null &&
        infinityMagicRoot['safearea'] != null) {
      final dynamic infinityMagicRaw =
      infinityMagicRoot['safearea'];
      if (infinityMagicRaw is bool) {
        infinityMagicSafeArea = infinityMagicRaw;
      } else if (infinityMagicRaw is String) {
        final String infinityMagicV =
        infinityMagicRaw.toLowerCase().trim();
        if (infinityMagicV == 'true' ||
            infinityMagicV == '1' ||
            infinityMagicV == 'yes') {
          infinityMagicSafeArea = true;
        }
        if (infinityMagicV == 'false' ||
            infinityMagicV == '0' ||
            infinityMagicV == 'no') {
          infinityMagicSafeArea = false;
        }
      } else if (infinityMagicRaw is num) {
        infinityMagicSafeArea = infinityMagicRaw != 0;
      }
    }

    if (infinityMagicSafeArea == null) return;

    final Brightness infinityMagicPlatformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    String? infinityMagicChosenHex;
    if (infinityMagicPlatformBrightness == Brightness.light) {
      infinityMagicChosenHex =
          infinityMagicBgLightHex ?? infinityMagicBgDarkHex;
    } else {
      infinityMagicChosenHex =
          infinityMagicBgDarkHex ?? infinityMagicBgLightHex;
    }

    Color infinityMagicBackground = infinityMagicSafeArea
        ? const Color(0xFF1A1A22)
        : Colors.black;

    if (infinityMagicSafeArea &&
        infinityMagicChosenHex != null &&
        infinityMagicChosenHex.isNotEmpty) {
      infinityMagicBackground = _parseHexColor(
        infinityMagicChosenHex,
        fallback: const Color(0xFF1A1A22),
      );
    }

    setState(() {
      _safeAreaEnabled = infinityMagicSafeArea!;
      _safeAreaBackgroundColor = infinityMagicBackground;
      infinityMagicDeviceProfileInstance.infinityMagicSafeAreaEnabled =
          infinityMagicSafeArea;
      infinityMagicDeviceProfileInstance.infinityMagicSafeAreaColor =
      infinityMagicSafeArea
          ? (infinityMagicChosenHex ?? '#1A1A22')
          : '';
    });

    // НОВОЕ: сохраняем SafeArea в SharedPreferences при каждом обновлении
    () async {
      try {
        final SharedPreferences infinityMagicPrefs =
            await SharedPreferences.getInstance();
        await infinityMagicPrefs.setBool(
            infinityMagicSafeAreaEnabledKey, infinityMagicSafeArea!);
        await infinityMagicPrefs.setString(
          infinityMagicSafeAreaColorKey,
          infinityMagicDeviceProfileInstance
              .infinityMagicSafeAreaColor ??
              '',
        );
        infinityMagicVaultInstance.infinityMagicLoggerInstance
            .infinityMagicLogInfo(
          'SafeArea saved to prefs: enabled=$infinityMagicSafeArea, color="${infinityMagicDeviceProfileInstance.infinityMagicSafeAreaColor}"',
        );
      } catch (e, st) {
        infinityMagicVaultInstance.infinityMagicLoggerInstance
            .infinityMagicLogError(
            'Error saving SafeArea to prefs: $e\n$st');
      }
    }();
  }

  // --------------------------------------------------------------------------
  // POPUP helpers
  // --------------------------------------------------------------------------

  InAppWebViewSettings _popupSettings() {
    return  InAppWebViewSettings(
      javaScriptEnabled: true,
      disableDefaultErrorPage: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      allowsPictureInPictureMediaPlayback: true,
      useOnDownloadStart: true,
      javaScriptCanOpenWindowsAutomatically: true,
      useShouldOverrideUrlLoading: true,
      supportMultipleWindows: true,
      transparentBackground: false,
      thirdPartyCookiesEnabled: true,
      sharedCookiesEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      allowsBackForwardNavigationGestures: true,
    );
  }

  void _openPopup(
      CreateWindowAction infinityMagicReq, {
        String? urlString,
      }) {
    setState(() {
      _popupCreateAction = infinityMagicReq;
      _popupUrl = (urlString != null && urlString.isNotEmpty)
          ? urlString
          : infinityMagicReq.request.url?.toString();
      _popupCurrentUrl = _popupUrl;
      _isPopupVisible = true;
      _popupCanGoBack = false;
    });
  }

  void _closePopup() {
    setState(() {
      _isPopupVisible = false;
      _popupUrl = null;
      _popupCurrentUrl = null;
      _popupCreateAction = null;
      _popupCanGoBack = false;
      _popupWebViewController = null;
    });
  }

  Future<void> _refreshPopupCanGoBack() async {
    final InAppWebViewController? infinityMagicC =
        _popupWebViewController;
    if (infinityMagicC == null) {
      if (_popupCanGoBack && mounted) {
        setState(() {
          _popupCanGoBack = false;
        });
      }
      return;
    }
    try {
      final bool infinityMagicCan = await infinityMagicC.canGoBack();
      if (!mounted) return;
      if (infinityMagicCan != _popupCanGoBack) {
        setState(() {
          _popupCanGoBack = infinityMagicCan;
        });
      }
    } catch (_) {}
  }

  Future<void> _handlePopupBackPressed() async {
    final InAppWebViewController? infinityMagicC =
        _popupWebViewController;
    if (infinityMagicC == null) {
      _closePopup();
      return;
    }
    try {
      if (await infinityMagicC.canGoBack()) {
        await infinityMagicC.goBack();
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          _refreshPopupCanGoBack();
        });
      } else {
        _closePopup();
      }
    } catch (_) {
      _closePopup();
    }
  }

  Widget _buildPopupOverlay() {
    if (!_isPopupVisible &&
        (_popupUrl == null && _popupCreateAction == null)) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.96),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Container(
                color: Colors.black,
                height: 48,
                child: Row(
                  children: [
                    if (_popupCanGoBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: _handlePopupBackPressed,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white),
                        onPressed: _closePopup,
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: InAppWebView(
                windowId: _popupCreateAction?.windowId,
                initialUrlRequest:
                (_popupCreateAction?.windowId == null &&
                    _popupUrl != null)
                    ? URLRequest(url: WebUri(_popupUrl!))
                    : null,
                initialSettings: _popupSettings(),
                onWebViewCreated:
                    (InAppWebViewController infinityMagicController) async {
                  _popupWebViewController =
                      infinityMagicController;
                },
                onLoadStart:
                    (infinityMagicController, infinityMagicUri) async {
                  if (infinityMagicUri != null) {
                    setState(() {
                      _popupCurrentUrl =
                          infinityMagicUri.toString();
                    });
                  }
                  await _refreshPopupCanGoBack();
                },
                onPermissionRequest:
                    (infinityMagicController, infinityMagicRequest) async {
                  return PermissionResponse(
                    resources: infinityMagicRequest.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onLoadStop:
                    (infinityMagicController, infinityMagicUri) async {
                  if (infinityMagicUri != null) {
                    setState(() {
                      _popupCurrentUrl =
                          infinityMagicUri.toString();
                    });
                  }
                  await _refreshPopupCanGoBack();
                },
                onUpdateVisitedHistory:
                    (infinityMagicController, infinityMagicUrl,
                    infinityMagicIsReload) async {
                  if (infinityMagicUrl != null) {
                    setState(() {
                      _popupCurrentUrl =
                          infinityMagicUrl.toString();
                    });
                  }
                  await _refreshPopupCanGoBack();
                },
                shouldOverrideUrlLoading: (
                    InAppWebViewController infinityMagicController,
                    NavigationAction infinityMagicNav,
                    ) async {
                  final Uri? infinityMagicUri =
                      infinityMagicNav.request.url;
                  if (infinityMagicUri == null) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  final String infinityMagicScheme =
                  infinityMagicUri.scheme.toLowerCase();

                  if (InfinityMagicKit.infinityMagicLooksLikeBareMail(
                      infinityMagicUri)) {
                    final Uri infinityMagicMailto =
                    InfinityMagicKit.infinityMagicToMailto(
                        infinityMagicUri);
                    await InfinityMagicLinker.infinityMagicOpen(
                      InfinityMagicKit.infinityMagicGmailize(
                          infinityMagicMailto),
                    );
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (infinityMagicScheme == 'mailto') {
                    await InfinityMagicLinker.infinityMagicOpen(
                      InfinityMagicKit.infinityMagicGmailize(
                          infinityMagicUri),
                    );
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (infinityMagicScheme == 'tel') {
                    await launchUrl(
                      infinityMagicUri,
                      mode: LaunchMode.externalApplication,
                    );
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (infinityMagicIsBankScheme(infinityMagicUri) ||
                      ((infinityMagicScheme == 'http' ||
                          infinityMagicScheme == 'https') &&
                          infinityMagicIsBankDomain(
                              infinityMagicUri))) {
                    await infinityMagicOpenBank(infinityMagicUri);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (infinityMagicScheme != 'http' &&
                      infinityMagicScheme != 'https') {
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onCloseWindow:
                    (InAppWebViewController infinityMagicController) {
                  _closePopup();
                },
                onDownloadStartRequest:
                    (infinityMagicController, infinityMagicReq) async {
                  await InfinityMagicLinker.infinityMagicOpen(
                      infinityMagicReq.url);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    infinityMagicBindPlatformNotificationTap();

    final bool infinityMagicIsDark =
        MediaQuery.of(context).platformBrightness ==
            Brightness.dark;

    final Color infinityMagicBgColor = _safeAreaEnabled
        ? _safeAreaBackgroundColor
        : (infinityMagicIsDark ? Colors.black : Colors.white);

    final Widget infinityMagicWebView = InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        disableDefaultErrorPage: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        allowsPictureInPictureMediaPlayback: true,
        useOnDownloadStart: true,
        javaScriptCanOpenWindowsAutomatically: true,
        useShouldOverrideUrlLoading: true,
        supportMultipleWindows: true,
      ),
      initialUrlRequest: URLRequest(
        url: WebUri(infinityMagicCurrentUrl),
      ),
      onWebViewCreated:
          (InAppWebViewController infinityMagicController) async {
        infinityMagicWebViewController = infinityMagicController;

        // Инициализация UA
        try {
          final infinityMagicUa =
          await infinityMagicController.evaluateJavascript(
            source: "navigator.userAgent",
          );
          if (infinityMagicUa is String &&
              infinityMagicUa.trim().isNotEmpty) {
            _baseUserAgent = infinityMagicUa.trim();
            _currentUserAgent = _baseUserAgent!;
            infinityMagicDeviceProfileInstance
                .infinityMagicBaseUserAgent = _baseUserAgent;
            debugPrint('[UA] INITIAL: $_baseUserAgent');
          }
        } catch (e) {
          infinityMagicVaultInstance.infinityMagicLoggerInstance
              .infinityMagicLogWarn(
              'Failed to read navigator.userAgent: $e');
        }

        await _applyNormalUserAgentIfNeeded();

        // После создания WebView — актуализируем localStorage
        await _updateLocalStorage();

        // Через 6 секунд после открытия экрана — восстановление app_data из SharedPreferences
        Future<void>.delayed(const Duration(seconds: 6), () async {
          if (!mounted) return;
          await _restoreAppDataFromPrefsToLocalStorage();
        });

        infinityMagicWebViewController.addJavaScriptHandler(
          handlerName: 'onServerResponse',
          callback: (List<dynamic> infinityMagicArgs) {
            infinityMagicVaultInstance.infinityMagicLoggerInstance
                .infinityMagicLogInfo(
                "JS Args: $infinityMagicArgs");

            try {
              dynamic infinityMagicFirst =
              infinityMagicArgs.isNotEmpty
                  ? infinityMagicArgs[0]
                  : null;

              if (infinityMagicFirst is List &&
                  infinityMagicFirst.isNotEmpty) {
                infinityMagicFirst = infinityMagicFirst.first;
              }

              if (infinityMagicFirst is Map) {
                final Map<dynamic, dynamic> infinityMagicRoot =
                    infinityMagicFirst;

                // safearea + userAgent из сервера
                _updateSafeAreaFromServerPayload(
                    infinityMagicRoot);
                _updateUserAgentFromServerPayload(
                    infinityMagicRoot);
                _applyNormalUserAgentIfNeeded();

                // При каждом ответе сервера можно обновлять localStorage
                _updateLocalStorage();
              }

              try {
                return infinityMagicArgs.reduce(
                        (dynamic infinityMagicV,
                        dynamic infinityMagicE) =>
                    infinityMagicV + infinityMagicE);
              } catch (_) {
                return infinityMagicArgs.toString();
              }
            } catch (e) {
              return infinityMagicArgs.toString();
            }
          },
        );
      },
      onLoadStart: (
          InAppWebViewController infinityMagicController,
          Uri? infinityMagicUri,
          ) async {
        infinityMagicStartLoadTimestamp =
            DateTime.now().millisecondsSinceEpoch;

        if (infinityMagicUri != null) {
          if (_isGoogleUrl(infinityMagicUri)) {
            await _addRandomToUserAgentForGoogle();
          } else {
            await _restoreUserAgentAfterGoogleIfNeeded();
            await _applyNormalUserAgentIfNeeded();
          }

          if (InfinityMagicKit.infinityMagicLooksLikeBareMail(
              infinityMagicUri)) {
            try {
              await infinityMagicController.stopLoading();
            } catch (_) {}
            final Uri infinityMagicMailto =
            InfinityMagicKit.infinityMagicToMailto(
                infinityMagicUri);
            await InfinityMagicLinker.infinityMagicOpen(
              InfinityMagicKit.infinityMagicGmailize(
                  infinityMagicMailto),
            );
            return;
          }

          // банки
          if (infinityMagicIsBankScheme(infinityMagicUri) ||
              ((infinityMagicUri.scheme == 'http' ||
                  infinityMagicUri.scheme == 'https') &&
                  infinityMagicIsBankDomain(infinityMagicUri))) {
            try {
              await infinityMagicController.stopLoading();
            } catch (_) {}
            await infinityMagicOpenBank(infinityMagicUri);
            return;
          }

          final String infinityMagicScheme =
          infinityMagicUri.scheme.toLowerCase();
          if (infinityMagicScheme != 'http' &&
              infinityMagicScheme != 'https') {
            try {
              await infinityMagicController.stopLoading();
            } catch (_) {}
          }
        }
      },
      onLoadStop: (
          InAppWebViewController infinityMagicController,
          Uri? infinityMagicUri,
          ) async {
        await infinityMagicController.evaluateJavascript(
          source: "console.log('Hello from Roulette JS!');",
        );

        setState(() {
          infinityMagicCurrentUrl =
              infinityMagicUri?.toString() ?? infinityMagicCurrentUrl;
        });

        await _restoreUserAgentAfterGoogleIfNeeded();
        await _applyNormalUserAgentIfNeeded();

        // После полной загрузки страницы обновляем localStorage
        await _updateLocalStorage();

        // И сразу тянем app_data из SharedPreferences в localStorage
        await _restoreAppDataFromPrefsToLocalStorage();

        Future<void>.delayed(const Duration(seconds: 20), () {
          infinityMagicSendLoadedOnce();
        });
      },
      shouldOverrideUrlLoading: (
          InAppWebViewController infinityMagicController,
          NavigationAction infinityMagicNav,
          ) async {
        final Uri? infinityMagicUri =
            infinityMagicNav.request.url;
        if (infinityMagicUri == null) {
          return NavigationActionPolicy.ALLOW;
        }

        if (_isGoogleUrl(infinityMagicUri)) {
          await _addRandomToUserAgentForGoogle();
        } else {
          await _restoreUserAgentAfterGoogleIfNeeded();
          await _applyNormalUserAgentIfNeeded();
        }

        if (InfinityMagicKit.infinityMagicLooksLikeBareMail(
            infinityMagicUri)) {
          final Uri infinityMagicMailto =
          InfinityMagicKit.infinityMagicToMailto(
              infinityMagicUri);
          await InfinityMagicLinker.infinityMagicOpen(
            InfinityMagicKit.infinityMagicGmailize(
                infinityMagicMailto),
          );
          return NavigationActionPolicy.CANCEL;
        }

        final String infinityMagicScheme =
        infinityMagicUri.scheme.toLowerCase();

        if (infinityMagicScheme == 'mailto') {
          await InfinityMagicLinker.infinityMagicOpen(
            InfinityMagicKit.infinityMagicGmailize(
                infinityMagicUri),
          );
          return NavigationActionPolicy.CANCEL;
        }

        if (infinityMagicIsBankScheme(infinityMagicUri) ||
            ((infinityMagicScheme == 'http' ||
                infinityMagicScheme == 'https') &&
                infinityMagicIsBankDomain(infinityMagicUri))) {
          await infinityMagicOpenBank(infinityMagicUri);
          return NavigationActionPolicy.CANCEL;
        }

        if (infinityMagicScheme == 'tel') {
          await launchUrl(
            infinityMagicUri,
            mode: LaunchMode.externalApplication,
          );
          return NavigationActionPolicy.CANCEL;
        }

        final String infinityMagicHost =
        infinityMagicUri.host.toLowerCase();
        final bool infinityMagicIsSocial =
            infinityMagicHost.endsWith('facebook.com') ||
                infinityMagicHost.endsWith('instagram.com') ||
                infinityMagicHost.endsWith('twitter.com') ||
                infinityMagicHost.endsWith('x.com');

        if (infinityMagicIsSocial) {
          await InfinityMagicLinker.infinityMagicOpen(
              infinityMagicUri);
          return NavigationActionPolicy.CANCEL;
        }

        if (infinityMagicIsExternalDestination(
            infinityMagicUri)) {
          final Uri infinityMagicMapped =
          infinityMagicMapExternalToHttp(
              infinityMagicUri);
          await InfinityMagicLinker.infinityMagicOpen(
              infinityMagicMapped);
          return NavigationActionPolicy.CANCEL;
        }

        if (infinityMagicScheme != 'http' &&
            infinityMagicScheme != 'https') {
          return NavigationActionPolicy.CANCEL;
        }

        return NavigationActionPolicy.ALLOW;
      },
      onCreateWindow: (
          InAppWebViewController infinityMagicController,
          CreateWindowAction infinityMagicReq,
          ) async {
        final Uri? infinityMagicUrl =
            infinityMagicReq.request.url;
        if (infinityMagicUrl == null) return false;

        if (_isGoogleUrl(infinityMagicUrl)) {
          await _addRandomToUserAgentForGoogle();
        } else {
          await _restoreUserAgentAfterGoogleIfNeeded();
          await _applyNormalUserAgentIfNeeded();
        }

        if (InfinityMagicKit.infinityMagicLooksLikeBareMail(
            infinityMagicUrl)) {
          final Uri infinityMagicMail =
          InfinityMagicKit.infinityMagicToMailto(
              infinityMagicUrl);
          await InfinityMagicLinker.infinityMagicOpen(
            InfinityMagicKit.infinityMagicGmailize(
                infinityMagicMail),
          );
          return false;
        }

        final String infinityMagicScheme =
        infinityMagicUrl.scheme.toLowerCase();

        if (infinityMagicScheme == 'mailto') {
          await InfinityMagicLinker.infinityMagicOpen(
            InfinityMagicKit.infinityMagicGmailize(
                infinityMagicUrl),
          );
          return false;
        }

        if (infinityMagicIsBankScheme(infinityMagicUrl) ||
            ((infinityMagicScheme == 'http' ||
                infinityMagicScheme == 'https') &&
                infinityMagicIsBankDomain(infinityMagicUrl))) {
          await infinityMagicOpenBank(infinityMagicUrl);
          return false;
        }

        if (infinityMagicScheme == 'tel') {
          await launchUrl(
            infinityMagicUrl,
            mode: LaunchMode.externalApplication,
          );
          return false;
        }

        final String infinityMagicHost =
        infinityMagicUrl.host.toLowerCase();
        final bool infinityMagicIsSocial =
            infinityMagicHost.endsWith('facebook.com') ||
                infinityMagicHost.endsWith('instagram.com') ||
                infinityMagicHost.endsWith('twitter.com') ||
                infinityMagicHost.endsWith('x.com');

        if (infinityMagicIsSocial) {
          await InfinityMagicLinker.infinityMagicOpen(
              infinityMagicUrl);
          return false;
        }

        if (infinityMagicIsExternalDestination(
            infinityMagicUrl)) {
          final Uri infinityMagicMapped =
          infinityMagicMapExternalToHttp(
              infinityMagicUrl);
          await InfinityMagicLinker.infinityMagicOpen(
              infinityMagicMapped);
          return false;
        }

        // popup-логика: всё, что осталось http/https — открываем во всплывающем WebView
        if (infinityMagicScheme == 'http' ||
            infinityMagicScheme == 'https') {
          _openPopup(
            infinityMagicReq,
            urlString: infinityMagicUrl.toString(),
          );
          return true; // говорим WebView, что создаём окно сами
        }

        return false;
      },
    );

    final Widget infinityMagicBody = Stack(
      children: <Widget>[
        infinityMagicWebView,
        if (infinityMagicOverlayBusy)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black87,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        _buildPopupOverlay(),
      ],
    );

    final Widget infinityMagicWrapped =
    _safeAreaEnabled ? SafeArea(child: infinityMagicBody) : infinityMagicBody;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: infinityMagicBgColor,
        body: infinityMagicWrapped,
      ),
    );
  }

  // ========================================================================
  // Внешние “столы” (протоколы/мессенджеры/соцсети)
  // ========================================================================

  bool infinityMagicIsExternalDestination(Uri infinityMagicUri) {
    final String infinityMagicScheme =
    infinityMagicUri.scheme.toLowerCase();
    if (infinityMagicExternalSchemes.contains(
        infinityMagicScheme)) {
      return true;
    }

    if (infinityMagicScheme == 'http' ||
        infinityMagicScheme == 'https') {
      final String infinityMagicHost =
      infinityMagicUri.host.toLowerCase();
      if (infinityMagicExternalHosts.contains(infinityMagicHost)) {
        return true;
      }
      if (infinityMagicHost.endsWith('t.me')) return true;
      if (infinityMagicHost.endsWith('wa.me')) return true;
      if (infinityMagicHost.endsWith('m.me')) return true;
      if (infinityMagicHost.endsWith('signal.me')) return true;
      if (infinityMagicHost.endsWith('facebook.com')) return true;
      if (infinityMagicHost.endsWith('instagram.com')) return true;
      if (infinityMagicHost.endsWith('twitter.com')) return true;
      if (infinityMagicHost.endsWith('x.com')) return true;
    }

    return false;
  }

  Uri infinityMagicMapExternalToHttp(Uri infinityMagicUri) {
    final String infinityMagicScheme =
    infinityMagicUri.scheme.toLowerCase();

    if (infinityMagicScheme == 'tg' ||
        infinityMagicScheme == 'telegram') {
      final Map<String, String> infinityMagicQp =
          infinityMagicUri.queryParameters;
      final String? infinityMagicDomain =
      infinityMagicQp['domain'];
      if (infinityMagicDomain != null &&
          infinityMagicDomain.isNotEmpty) {
        return Uri.https(
          't.me',
          '/$infinityMagicDomain',
          <String, String>{
            if (infinityMagicQp['start'] != null)
              'start': infinityMagicQp['start']!,
          },
        );
      }
      final String infinityMagicPath =
      infinityMagicUri.path.isNotEmpty
          ? infinityMagicUri.path
          : '';
      return Uri.https(
        't.me',
        '/$infinityMagicPath',
        infinityMagicUri.queryParameters.isEmpty
            ? null
            : infinityMagicUri.queryParameters,
      );
    }

    if (infinityMagicScheme == 'whatsapp') {
      final Map<String, String> infinityMagicQp =
          infinityMagicUri.queryParameters;
      final String? infinityMagicPhone =
      infinityMagicQp['phone'];
      final String? infinityMagicText =
      infinityMagicQp['text'];
      if (infinityMagicPhone != null &&
          infinityMagicPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${InfinityMagicKit.infinityMagicDigitsOnly(infinityMagicPhone)}',
          <String, String>{
            if (infinityMagicText != null &&
                infinityMagicText.isNotEmpty)
              'text': infinityMagicText,
          },
        );
      }
      return Uri.https(
        'wa.me',
        '/',
        <String, String>{
          if (infinityMagicText != null &&
              infinityMagicText.isNotEmpty)
            'text': infinityMagicText,
        },
      );
    }

    if (infinityMagicScheme == 'bnl') {
      final String infinityMagicNewPath =
      infinityMagicUri.path.isNotEmpty
          ? infinityMagicUri.path
          : '';
      return Uri.https(
        'bnl.com',
        '/$infinityMagicNewPath',
        infinityMagicUri.queryParameters.isEmpty
            ? null
            : infinityMagicUri.queryParameters,
      );
    }

    return infinityMagicUri;
  }

  Future<void> infinityMagicSendLoadedOnce() async {
    if (infinityMagicLoadedOnceSent) {
      debugPrint('Wheel Loaded already sent, skip');
      return;
    }

    final int infinityMagicNow =
        DateTime.now().millisecondsSinceEpoch;

    await infinityMagicPostStat(
      infinityMagicEvent: 'Loaded',
      infinityMagicTimeStart: infinityMagicStartLoadTimestamp,
      infinityMagicTimeFinish: infinityMagicNow,
      infinityMagicUrl: infinityMagicCurrentUrl,
      infinityMagicAppSid:
      infinityMagicSpyInstance.infinityMagicAppsFlyerUid,
      infinityMagicFirstPageTs: infinityMagicFirstPageTimestamp,
    );

    infinityMagicLoadedOnceSent = true;
  }
}