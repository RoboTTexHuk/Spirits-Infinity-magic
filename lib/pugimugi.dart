import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as infinitySpiritMath;
import 'dart:ui';

import 'package:appsflyer_sdk/appsflyer_sdk.dart'
    show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as infinitySpiritTimezoneData;
import 'package:timezone/timezone.dart' as infinitySpiritTimezone;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Если эти классы есть в main.dart – оставь импорт.
import 'main.dart' show MafiaHarbor, CaptainHarbor, BillHarbor;

// ============================================================================
// InfinitySpirit инфраструктура (бывшая Dress Retro инфраструктура / Ncup)
// ============================================================================

class InfinitySpiritLogger {
  const InfinitySpiritLogger();

  void infinitySpiritLogInfo(Object infinitySpiritMessage) =>
      debugPrint('[DressRetroLogger] $infinitySpiritMessage');

  void infinitySpiritLogWarn(Object infinitySpiritMessage) =>
      debugPrint('[DressRetroLogger/WARN] $infinitySpiritMessage');

  void infinitySpiritLogError(Object infinitySpiritMessage) =>
      debugPrint('[DressRetroLogger/ERR] $infinitySpiritMessage');
}

class InfinitySpiritVault {
  static final InfinitySpiritVault sharedInstance =
  InfinitySpiritVault._internalConstructor();
  InfinitySpiritVault._internalConstructor();
  factory InfinitySpiritVault() => sharedInstance;

  final InfinitySpiritLogger loggerInstance = const InfinitySpiritLogger();
}

// ============================================================================
// Константы (статистика/кеш) — строки в кавычках не меняем
// ============================================================================

const String metrLoadedOnceKey = 'wheel_loaded_once';
const String metrStatEndpoint = 'https://getgame.portalroullete.bar/stat';
const String metrCachedFcmKey = 'wheel_cached_fcm';

// ============================================================================
// Утилиты: InfinitySpiritKit (бывший DressRetroKit / NcupKit)
// ============================================================================

class InfinitySpiritKit {
  static bool infinitySpiritLooksLikeBareMail(Uri infinitySpiritUri) {
    final String infinitySpiritScheme = infinitySpiritUri.scheme;
    if (infinitySpiritScheme.isNotEmpty) return false;
    final String infinitySpiritRaw = infinitySpiritUri.toString();
    return infinitySpiritRaw.contains('@') && !infinitySpiritRaw.contains(' ');
  }

  static Uri infinitySpiritToMailto(Uri infinitySpiritUri) {
    final String infinitySpiritFull = infinitySpiritUri.toString();
    final List<String> infinitySpiritBits = infinitySpiritFull.split('?');
    final String infinitySpiritWho = infinitySpiritBits.first;
    final Map<String, String> infinitySpiritQuery = infinitySpiritBits.length > 1
        ? Uri.splitQueryString(infinitySpiritBits[1])
        : <String, String>{};
    return Uri(
      scheme: 'mailto',
      path: infinitySpiritWho,
      queryParameters:
      infinitySpiritQuery.isEmpty ? null : infinitySpiritQuery,
    );
  }

  static Uri infinitySpiritGmailize(Uri infinitySpiritMailUri) {
    final Map<String, String> infinitySpiritQp =
        infinitySpiritMailUri.queryParameters;
    final Map<String, String> infinitySpiritParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (infinitySpiritMailUri.path.isNotEmpty)
        'to': infinitySpiritMailUri.path,
      if ((infinitySpiritQp['subject'] ?? '').isNotEmpty)
        'su': infinitySpiritQp['subject']!,
      if ((infinitySpiritQp['body'] ?? '').isNotEmpty)
        'body': infinitySpiritQp['body']!,
      if ((infinitySpiritQp['cc'] ?? '').isNotEmpty)
        'cc': infinitySpiritQp['cc']!,
      if ((infinitySpiritQp['bcc'] ?? '').isNotEmpty)
        'bcc': infinitySpiritQp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', infinitySpiritParams);
  }

  static String infinitySpiritDigitsOnly(String infinitySpiritSource) =>
      infinitySpiritSource.replaceAll(RegExp(r'[^0-9+]'), '');
}

// ============================================================================
// Сервис открытия ссылок: InfinitySpiritLinker (бывший DressRetroLinker)
// ============================================================================

class InfinitySpiritLinker {
  static Future<bool> infinitySpiritOpen(Uri infinitySpiritUri) async {
    try {
      if (await launchUrl(
        infinitySpiritUri,
        mode: LaunchMode.inAppBrowserView,
      )) {
        return true;
      }
      return await launchUrl(
        infinitySpiritUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (infinitySpiritError) {
      debugPrint(
          'DressRetroLinker error: $infinitySpiritError; url=$infinitySpiritUri');
      try {
        return await launchUrl(
          infinitySpiritUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }
}

// ============================================================================
// FCM Background Handler
// ============================================================================

@pragma('vm:entry-point')
Future<void> infinitySpiritFcmBackgroundHandler(
    RemoteMessage infinitySpiritMessage) async {
  debugPrint("Spin ID: ${infinitySpiritMessage.messageId}");
  debugPrint("Spin Data: ${infinitySpiritMessage.data}");
}

// ============================================================================
// InfinitySpiritDeviceProfile (бывший DressRetroDeviceProfile / NcupDeviceProfile)
// ============================================================================

class InfinitySpiritDeviceProfile {
  String? infinitySpiritDeviceId;
  String? infinitySpiritSessionId = 'wheel-one-off';
  String? infinitySpiritPlatformKind;
  String? infinitySpiritOsBuild;
  String? infinitySpiritAppVersion;
  String? infinitySpiritLocaleCode;
  String? infinitySpiritTimezoneName;
  bool infinitySpiritPushEnabled = true;

  Future<void> infinitySpiritInitialize() async {
    final DeviceInfoPlugin infinitySpiritInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo infinitySpiritAndroidInfo =
      await infinitySpiritInfoPlugin.androidInfo;
      infinitySpiritDeviceId = infinitySpiritAndroidInfo.id;
      infinitySpiritPlatformKind = 'android';
      infinitySpiritOsBuild = infinitySpiritAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo infinitySpiritIosInfo =
      await infinitySpiritInfoPlugin.iosInfo;
      infinitySpiritDeviceId = infinitySpiritIosInfo.identifierForVendor;
      infinitySpiritPlatformKind = 'ios';
      infinitySpiritOsBuild = infinitySpiritIosInfo.systemVersion;
    }

    final PackageInfo infinitySpiritPackageInfo =
    await PackageInfo.fromPlatform();
    infinitySpiritAppVersion = infinitySpiritPackageInfo.version;
    infinitySpiritLocaleCode = Platform.localeName.split('_').first;
    infinitySpiritTimezoneName = infinitySpiritTimezone.local.name;
    infinitySpiritSessionId =
    'wheel-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> infinitySpiritAsMap({String? infinitySpiritFcmToken}) =>
      <String, dynamic>{
        'fcm_token': infinitySpiritFcmToken ?? 'missing_token',
        'device_id': infinitySpiritDeviceId ?? 'missing_id',
        'app_name': 'joiler',
        'instance_id': infinitySpiritSessionId ?? 'missing_session',
        'platform': infinitySpiritPlatformKind ?? 'missing_system',
        'os_version': infinitySpiritOsBuild ?? 'missing_build',
        'app_version': infinitySpiritAppVersion ?? 'missing_app',
        'language': infinitySpiritLocaleCode ?? 'en',
        'timezone': infinitySpiritTimezoneName ?? 'UTC',
        'push_enabled': infinitySpiritPushEnabled,
        "fthcashier": "true"
      };
}

// ============================================================================
// AppsFlyer шпион: InfinitySpiritSpy (бывший DressRetroSpy / NcupSpy)
// ============================================================================

class InfinitySpiritSpy {
  AppsFlyerOptions? infinitySpiritOptions;
  AppsflyerSdk? infinitySpiritSdk;

  String infinitySpiritAppsFlyerUid = '';
  String infinitySpiritAppsFlyerData = '';

  void infinitySpiritStart({VoidCallback? infinitySpiritOnUpdate}) {
    final AppsFlyerOptions infinitySpiritOpts = AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6756072063',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    infinitySpiritOptions = infinitySpiritOpts;
    infinitySpiritSdk = AppsflyerSdk(infinitySpiritOpts);

    infinitySpiritSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    infinitySpiritSdk?.startSDK(
      onSuccess: () => InfinitySpiritVault()
          .loggerInstance
          .infinitySpiritLogInfo('WheelSpy started'),
      onError: (infinitySpiritCode, infinitySpiritMsg) =>
          InfinitySpiritVault().loggerInstance.infinitySpiritLogError(
              'WheelSpy error $infinitySpiritCode: $infinitySpiritMsg'),
    );

    infinitySpiritSdk?.onInstallConversionData((infinitySpiritValue) {
      infinitySpiritAppsFlyerData = infinitySpiritValue.toString();
      infinitySpiritOnUpdate?.call();
    });

    infinitySpiritSdk?.getAppsFlyerUID().then((infinitySpiritValue) {
      infinitySpiritAppsFlyerUid = infinitySpiritValue.toString();
      infinitySpiritOnUpdate?.call();
    });
  }
}

// ============================================================================
// Мост для FCM токена: InfinitySpiritFcmBridge (бывший DressRetroFcmBridge)
// ============================================================================

class InfinitySpiritFcmBridge {
  final InfinitySpiritLogger infinitySpiritLog =
  const InfinitySpiritLogger();
  String? infinitySpiritToken;
  final List<void Function(String)> infinitySpiritWaiters =
  <void Function(String)>[];

  String? get infinitySpiritCurrentToken => infinitySpiritToken;

  InfinitySpiritFcmBridge() {
    const MethodChannel('com.example.fcm/token')
        .setMethodCallHandler((MethodCall infinitySpiritCall) async {
      if (infinitySpiritCall.method == 'setToken') {
        final String infinitySpiritTokenString =
        infinitySpiritCall.arguments as String;
        if (infinitySpiritTokenString.isNotEmpty) {
          infinitySpiritSetToken(infinitySpiritTokenString);
        }
      }
    });

    infinitySpiritRestoreToken();
  }

  Future<void> infinitySpiritRestoreToken() async {
    try {
      final SharedPreferences infinitySpiritPrefs =
      await SharedPreferences.getInstance();
      final String? infinitySpiritCached =
      infinitySpiritPrefs.getString(metrCachedFcmKey);
      if (infinitySpiritCached != null &&
          infinitySpiritCached.isNotEmpty) {
        infinitySpiritSetToken(infinitySpiritCached,
            infinitySpiritNotify: false);
      }
    } catch (_) {}
  }

  Future<void> infinitySpiritPersistToken(
      String infinitySpiritNewToken) async {
    try {
      final SharedPreferences infinitySpiritPrefs =
      await SharedPreferences.getInstance();
      await infinitySpiritPrefs.setString(
          metrCachedFcmKey, infinitySpiritNewToken);
    } catch (_) {}
  }

  void infinitySpiritSetToken(
      String infinitySpiritNewToken, {
        bool infinitySpiritNotify = true,
      }) {
    infinitySpiritToken = infinitySpiritNewToken;
    infinitySpiritPersistToken(infinitySpiritNewToken);
    if (infinitySpiritNotify) {
      for (final void Function(String) infinitySpiritCallback
      in List<void Function(String)>.from(infinitySpiritWaiters)) {
        try {
          infinitySpiritCallback(infinitySpiritNewToken);
        } catch (infinitySpiritErr) {
          infinitySpiritLog.infinitySpiritLogWarn(
              'fcm waiter error: $infinitySpiritErr');
        }
      }
      infinitySpiritWaiters.clear();
    }
  }

  Future<void> infinitySpiritWaitForToken(
      Function(String infinitySpiritTokenValue) infinitySpiritOnToken,
      ) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if ((infinitySpiritToken ?? '').isNotEmpty) {
        infinitySpiritOnToken(infinitySpiritToken!);
        return;
      }

      infinitySpiritWaiters.add(infinitySpiritOnToken);
    } catch (infinitySpiritErr) {
      infinitySpiritLog.infinitySpiritLogError(
          'wheelWaitToken error: $infinitySpiritErr');
    }
  }
}

// ============================================================================
// Лоадер: InfinitySpiritCenterLoaderScreen
// ============================================================================

class InfinitySpiritLoaderCore extends StatefulWidget {
  const InfinitySpiritLoaderCore({super.key});

  @override
  State<InfinitySpiritLoaderCore> createState() =>
      _InfinitySpiritLoaderCoreState();
}

class _InfinitySpiritLoaderCoreState extends State<InfinitySpiritLoaderCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _infinitySpiritController;

  @override
  void initState() {
    super.initState();
    _infinitySpiritController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _infinitySpiritController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: _infinitySpiritController,
            builder: (_, __) {
              return Transform.rotate(
                angle: _infinitySpiritController.value *
                    2 *
                    infinitySpiritMath.pi,
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: InfinitySpiritRaysPainter(),
                ),
              );
            },
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFFF5C86E),
                  Color(0xFFF28A3A),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.orange.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfinitySpiritRaysPainter extends CustomPainter {
  @override
  void paint(Canvas infinitySpiritCanvas, Size infinitySpiritSize) {
    final Paint infinitySpiritPaint = Paint()
      ..color = const Color(0xFFF5D18B)
      ..style = PaintingStyle.fill;

    final Offset infinitySpiritCenter = Offset(
      infinitySpiritSize.width / 2,
      infinitySpiritSize.height / 2,
    );

    const int infinitySpiritRaysCount = 12;
    final double infinitySpiritRadius =
        infinitySpiritSize.width * 0.45;
    const double infinitySpiritRayWidth = 10.0;
    const double infinitySpiritRayLength = 26.0;

    for (int infinitySpiritI = 0;
    infinitySpiritI < infinitySpiritRaysCount;
    infinitySpiritI++) {
      final double infinitySpiritAngle =
          (2 * infinitySpiritMath.pi / infinitySpiritRaysCount) *
              infinitySpiritI;
      final double infinitySpiritDx =
          infinitySpiritCenter.dx +
              infinitySpiritRadius *
                  infinitySpiritMath.cos(infinitySpiritAngle);
      final double infinitySpiritDy =
          infinitySpiritCenter.dy +
              infinitySpiritRadius *
                  infinitySpiritMath.sin(infinitySpiritAngle);

      infinitySpiritCanvas.save();
      infinitySpiritCanvas.translate(
          infinitySpiritDx, infinitySpiritDy);
      infinitySpiritCanvas.rotate(infinitySpiritAngle);

      final Rect infinitySpiritRect = Rect.fromCenter(
        center: Offset.zero,
        width: infinitySpiritRayWidth,
        height: infinitySpiritRayLength,
      );
      final RRect infinitySpiritRRect =
      RRect.fromRectAndRadius(
        infinitySpiritRect,
        const Radius.circular(20),
      );

      infinitySpiritCanvas.drawRRect(
          infinitySpiritRRect, infinitySpiritPaint);
      infinitySpiritCanvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Центровый лоадер-экран, который можно накладывать поверх любых экранов.
class InfinitySpiritCenterLoaderScreen extends StatelessWidget {
  const InfinitySpiritCenterLoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: InfinitySpiritLoaderCore(),
    );
  }
}

// ============================================================================
// Статистика (InfinitySpiritFinalUrl / InfinitySpiritPostStat)
// — строки не меняем
// ============================================================================

Future<String> infinitySpiritFinalUrl(
    String infinitySpiritStartUrl, {
      int infinitySpiritMaxHops = 10,
    }) async {
  final HttpClient infinitySpiritClient = HttpClient();

  try {
    Uri infinitySpiritCurrentUri = Uri.parse(infinitySpiritStartUrl);

    for (int infinitySpiritI = 0;
    infinitySpiritI < infinitySpiritMaxHops;
    infinitySpiritI++) {
      final HttpClientRequest infinitySpiritRequest =
      await infinitySpiritClient.getUrl(infinitySpiritCurrentUri);
      infinitySpiritRequest.followRedirects = false;
      final HttpClientResponse infinitySpiritResponse =
      await infinitySpiritRequest.close();

      if (infinitySpiritResponse.isRedirect) {
        final String? infinitySpiritLoc =
        infinitySpiritResponse.headers.value(
            HttpHeaders.locationHeader);
        if (infinitySpiritLoc == null ||
            infinitySpiritLoc.isEmpty) {
          break;
        }

        final Uri infinitySpiritNextUri =
        Uri.parse(infinitySpiritLoc);
        infinitySpiritCurrentUri =
        infinitySpiritNextUri.hasScheme
            ? infinitySpiritNextUri
            : infinitySpiritCurrentUri
            .resolveUri(infinitySpiritNextUri);
        continue;
      }

      return infinitySpiritCurrentUri.toString();
    }

    return infinitySpiritCurrentUri.toString();
  } catch (infinitySpiritError) {
    debugPrint('wheelFinalUrl error: $infinitySpiritError');
    return infinitySpiritStartUrl;
  } finally {
    infinitySpiritClient.close(force: true);
  }
}

Future<void> infinitySpiritPostStat({
  required String infinitySpiritEvent,
  required int infinitySpiritTimeStart,
  required String infinitySpiritUrl,
  required int infinitySpiritTimeFinish,
  required String infinitySpiritAppSid,
  int? infinitySpiritFirstPageTs,
}) async {
  try {
    final String infinitySpiritResolvedUrl =
    await infinitySpiritFinalUrl(infinitySpiritUrl);
    final Map<String, dynamic> infinitySpiritPayload =
    <String, dynamic>{
      'event': infinitySpiritEvent,
      'timestart': infinitySpiritTimeStart,
      'timefinsh': infinitySpiritTimeFinish,
      'url': infinitySpiritResolvedUrl,
      'appleID': '6755681349',
      'open_count':
      '$infinitySpiritAppSid/$infinitySpiritTimeStart',
    };

    debugPrint('wheelStat $infinitySpiritPayload');

    final http.Response infinitySpiritResp = await http.post(
      Uri.parse('$metrStatEndpoint/$infinitySpiritAppSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(infinitySpiritPayload),
    );

    debugPrint(
        'wheelStat resp=${infinitySpiritResp.statusCode} body=${infinitySpiritResp.body}');
  } catch (infinitySpiritError) {
    debugPrint('wheelPostStat error: $infinitySpiritError');
  }
}

// ============================================================================
// WebView-экран: InfinitySpiritTableView (бывший DressRetroTableView / NcupTableView)
// ============================================================================

class InfinitySpiritTableView extends StatefulWidget
    with WidgetsBindingObserver {
  String infinitySpiritStartingUrl;
  InfinitySpiritTableView(this.infinitySpiritStartingUrl, {super.key});

  @override
  State<InfinitySpiritTableView> createState() =>
      _InfinitySpiritTableViewState(infinitySpiritStartingUrl);
}

class _InfinitySpiritTableViewState extends State<InfinitySpiritTableView>
    with WidgetsBindingObserver {
  _InfinitySpiritTableViewState(this.infinitySpiritCurrentUrl);

  final InfinitySpiritVault infinitySpiritVaultInstance =
  InfinitySpiritVault();

  late InAppWebViewController infinitySpiritWebViewController;
  String? infinitySpiritPushToken;
  final InfinitySpiritDeviceProfile infinitySpiritDeviceProfileInstance =
  InfinitySpiritDeviceProfile();
  final InfinitySpiritSpy infinitySpiritSpyInstance =
  InfinitySpiritSpy();

  bool infinitySpiritOverlayBusy = false;
  String infinitySpiritCurrentUrl;
  DateTime? infinitySpiritLastPausedAt;

  bool infinitySpiritLoadedOnceSent = false;
  int? infinitySpiritFirstPageTimestamp;
  int infinitySpiritStartLoadTimestamp = 0;

  final Set<String> infinitySpiritExternalHosts = <String>{
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

  final Set<String> infinitySpiritExternalSchemes = <String>{
    'tg',
    'telegram',
    'whatsapp',
    'bnl',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onBackgroundMessage(
        infinitySpiritFcmBackgroundHandler);

    infinitySpiritFirstPageTimestamp =
        DateTime.now().millisecondsSinceEpoch;

    infinitySpiritInitPushAndGetToken();
    infinitySpiritDeviceProfileInstance.infinitySpiritInitialize();
    infinitySpiritWireForegroundPushHandlers();
    infinitySpiritBindPlatformNotificationTap();
    infinitySpiritSpyInstance.infinitySpiritStart(
      infinitySpiritOnUpdate: () {
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
      AppLifecycleState infinitySpiritState) {
    if (infinitySpiritState == AppLifecycleState.paused) {
      infinitySpiritLastPausedAt = DateTime.now();
    }
    if (infinitySpiritState == AppLifecycleState.resumed) {
      if (Platform.isIOS && infinitySpiritLastPausedAt != null) {
        final DateTime infinitySpiritNow = DateTime.now();
        final Duration infinitySpiritDrift =
        infinitySpiritNow
            .difference(infinitySpiritLastPausedAt!);
        if (infinitySpiritDrift >
            const Duration(minutes: 25)) {
          infinitySpiritForceReloadToLobby();
        }
      }
      infinitySpiritLastPausedAt = null;
    }
  }

  void infinitySpiritForceReloadToLobby() {
    if (!mounted) return;
    WidgetsBinding.instance
        .addPostFrameCallback((Duration infinitySpiritDuration) {
      if (!mounted) return;
      // Здесь можно вернуть в лобби (MafiaHarbor / CaptainHarbor / BillHarbor), если нужно.
    });
  }

  // --------------------------------------------------------------------------
  // Push / FCM
  // --------------------------------------------------------------------------

  void infinitySpiritWireForegroundPushHandlers() {
    FirebaseMessaging.onMessage
        .listen((RemoteMessage infinitySpiritMsg) {
      if (infinitySpiritMsg.data['uri'] != null) {
        infinitySpiritNavigateTo(
            infinitySpiritMsg.data['uri'].toString());
      } else {
        infinitySpiritReturnToCurrentUrl();
      }
    });

    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage infinitySpiritMsg) {
      if (infinitySpiritMsg.data['uri'] != null) {
        infinitySpiritNavigateTo(
            infinitySpiritMsg.data['uri'].toString());
      } else {
        infinitySpiritReturnToCurrentUrl();
      }
    });
  }

  void infinitySpiritNavigateTo(String infinitySpiritNewUrl) async {
    await infinitySpiritWebViewController.loadUrl(
      urlRequest: URLRequest(url: WebUri(infinitySpiritNewUrl)),
    );
  }

  void infinitySpiritReturnToCurrentUrl() async {
    Future<void>.delayed(const Duration(seconds: 3), () {
      infinitySpiritWebViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(infinitySpiritCurrentUrl)),
      );
    });
  }

  Future<void> infinitySpiritInitPushAndGetToken() async {
    final FirebaseMessaging infinitySpiritFm =
        FirebaseMessaging.instance;
    await infinitySpiritFm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    infinitySpiritPushToken = await infinitySpiritFm.getToken();
  }

  // --------------------------------------------------------------------------
  // Привязка канала: тап по уведомлению из native
  // --------------------------------------------------------------------------

  void infinitySpiritBindPlatformNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall infinitySpiritCall) async {
      if (infinitySpiritCall.method == "onNotificationTap") {
        final Map<String, dynamic> infinitySpiritPayload =
        Map<String, dynamic>.from(infinitySpiritCall.arguments);
        debugPrint(
            "URI from platform tap: ${infinitySpiritPayload['uri']}");
        final String? infinitySpiritUriString =
        infinitySpiritPayload["uri"]?.toString();
        if (infinitySpiritUriString != null &&
            !infinitySpiritUriString.contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext infinitySpiritContext) =>
                  InfinitySpiritTableView(infinitySpiritUriString),
            ),
                (Route<dynamic> infinitySpiritRoute) => false,
          );
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    infinitySpiritBindPlatformNotificationTap();

    final bool infinitySpiritIsDark =
        MediaQuery.of(context).platformBrightness ==
            Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: infinitySpiritIsDark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            InAppWebView(
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
                url: WebUri(infinitySpiritCurrentUrl),
              ),
              onWebViewCreated: (
                  InAppWebViewController infinitySpiritController,
                  ) {
                infinitySpiritWebViewController =
                    infinitySpiritController;

                infinitySpiritWebViewController
                    .addJavaScriptHandler(
                  handlerName: 'onServerResponse',
                  callback:
                      (List<dynamic> infinitySpiritArgs) {
                    infinitySpiritVaultInstance
                        .loggerInstance
                        .infinitySpiritLogInfo(
                        "JS Args: $infinitySpiritArgs");
                    try {
                      return infinitySpiritArgs.reduce(
                            (dynamic infinitySpiritV,
                            dynamic infinitySpiritE) =>
                        infinitySpiritV +
                            infinitySpiritE,
                      );
                    } catch (_) {
                      return infinitySpiritArgs.toString();
                    }
                  },
                );
              },
              onLoadStart: (
                  InAppWebViewController infinitySpiritController,
                  Uri? infinitySpiritUri,
                  ) async {
                infinitySpiritStartLoadTimestamp =
                    DateTime.now()
                        .millisecondsSinceEpoch;

                if (mounted) {
                  setState(() {
                    infinitySpiritOverlayBusy = true;
                  });
                }

                if (infinitySpiritUri != null) {
                  if (InfinitySpiritKit.infinitySpiritLooksLikeBareMail(
                      infinitySpiritUri)) {
                    try {
                      await infinitySpiritController
                          .stopLoading();
                    } catch (_) {}
                    final Uri infinitySpiritMailto =
                    InfinitySpiritKit
                        .infinitySpiritToMailto(
                        infinitySpiritUri);
                    await InfinitySpiritLinker
                        .infinitySpiritOpen(
                      InfinitySpiritKit.infinitySpiritGmailize(
                          infinitySpiritMailto),
                    );
                    return;
                  }

                  final String infinitySpiritScheme =
                  infinitySpiritUri.scheme
                      .toLowerCase();
                  if (infinitySpiritScheme != 'http' &&
                      infinitySpiritScheme != 'https') {
                    try {
                      await infinitySpiritController
                          .stopLoading();
                    } catch (_) {}
                  }
                }
              },
              onLoadStop: (
                  InAppWebViewController infinitySpiritController,
                  Uri? infinitySpiritUri,
                  ) async {
                await infinitySpiritController
                    .evaluateJavascript(
                  source:
                  "console.log('Hello from Roulette JS!');",
                );

                if (mounted) {
                  setState(() {
                    infinitySpiritOverlayBusy = false;
                    infinitySpiritCurrentUrl =
                        infinitySpiritUri?.toString() ??
                            infinitySpiritCurrentUrl;
                  });
                }

                Future<void>.delayed(
                  const Duration(seconds: 20),
                      () {
                    infinitySpiritSendLoadedOnce();
                  },
                );
              },
              shouldOverrideUrlLoading: (
                  InAppWebViewController infinitySpiritController,
                  NavigationAction infinitySpiritNav,
                  ) async {
                final Uri? infinitySpiritUri =
                    infinitySpiritNav.request.url;
                if (infinitySpiritUri == null) {
                  return NavigationActionPolicy.ALLOW;
                }

                if (InfinitySpiritKit.infinitySpiritLooksLikeBareMail(
                    infinitySpiritUri)) {
                  final Uri infinitySpiritMailto =
                  InfinitySpiritKit
                      .infinitySpiritToMailto(
                      infinitySpiritUri);
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                    InfinitySpiritKit.infinitySpiritGmailize(
                        infinitySpiritMailto),
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                final String infinitySpiritScheme =
                infinitySpiritUri.scheme.toLowerCase();

                if (infinitySpiritScheme == 'mailto') {
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                    InfinitySpiritKit.infinitySpiritGmailize(
                        infinitySpiritUri),
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                if (infinitySpiritScheme == 'tel') {
                  await launchUrl(
                    infinitySpiritUri,
                    mode: LaunchMode.externalApplication,
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                final String infinitySpiritHost =
                infinitySpiritUri.host
                    .toLowerCase();
                final bool infinitySpiritIsSocial =
                    infinitySpiritHost
                        .endsWith('facebook.com') ||
                        infinitySpiritHost
                            .endsWith('instagram.com') ||
                        infinitySpiritHost
                            .endsWith('twitter.com') ||
                        infinitySpiritHost.endsWith('x.com');

                if (infinitySpiritIsSocial) {
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                      infinitySpiritUri);
                  return NavigationActionPolicy.CANCEL;
                }

                if (infinitySpiritIsExternalDestination(
                    infinitySpiritUri)) {
                  final Uri infinitySpiritMapped =
                  infinitySpiritMapExternalToHttp(
                      infinitySpiritUri);
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                      infinitySpiritMapped);
                  return NavigationActionPolicy.CANCEL;
                }

                if (infinitySpiritScheme != 'http' &&
                    infinitySpiritScheme != 'https') {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (
                  InAppWebViewController infinitySpiritController,
                  CreateWindowAction infinitySpiritReq,
                  ) async {
                final Uri? infinitySpiritUrl =
                    infinitySpiritReq.request.url;
                if (infinitySpiritUrl == null) {
                  return false;
                }

                if (InfinitySpiritKit.infinitySpiritLooksLikeBareMail(
                    infinitySpiritUrl)) {
                  final Uri infinitySpiritMail =
                  InfinitySpiritKit
                      .infinitySpiritToMailto(
                      infinitySpiritUrl);
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                    InfinitySpiritKit.infinitySpiritGmailize(
                        infinitySpiritMail),
                  );
                  return false;
                }

                final String infinitySpiritScheme =
                infinitySpiritUrl.scheme
                    .toLowerCase();

                if (infinitySpiritScheme == 'mailto') {
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                    InfinitySpiritKit.infinitySpiritGmailize(
                        infinitySpiritUrl),
                  );
                  return false;
                }

                if (infinitySpiritScheme == 'tel') {
                  await launchUrl(
                    infinitySpiritUrl,
                    mode: LaunchMode.externalApplication,
                  );
                  return false;
                }

                final String infinitySpiritHost =
                infinitySpiritUrl.host
                    .toLowerCase();
                final bool infinitySpiritIsSocial =
                    infinitySpiritHost
                        .endsWith('facebook.com') ||
                        infinitySpiritHost
                            .endsWith('instagram.com') ||
                        infinitySpiritHost
                            .endsWith('twitter.com') ||
                        infinitySpiritHost.endsWith('x.com');

                if (infinitySpiritIsSocial) {
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                      infinitySpiritUrl);
                  return false;
                }

                if (infinitySpiritIsExternalDestination(
                    infinitySpiritUrl)) {
                  final Uri infinitySpiritMapped =
                  infinitySpiritMapExternalToHttp(
                      infinitySpiritUrl);
                  await InfinitySpiritLinker
                      .infinitySpiritOpen(
                      infinitySpiritMapped);
                  return false;
                }

                if (infinitySpiritScheme == 'http' ||
                    infinitySpiritScheme == 'https') {
                  infinitySpiritController.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(
                        infinitySpiritUrl.toString(),
                      ),
                    ),
                  );
                }

                return false;
              },
            ),

            // Лоадер по центру экрана поверх WebView
            if (infinitySpiritOverlayBusy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black87,
                  child: InfinitySpiritCenterLoaderScreen(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // Внешние “столы” (протоколы/мессенджеры/соцсети)
  // ========================================================================

  bool infinitySpiritIsExternalDestination(Uri infinitySpiritUri) {
    final String infinitySpiritScheme =
    infinitySpiritUri.scheme.toLowerCase();
    if (infinitySpiritExternalSchemes
        .contains(infinitySpiritScheme)) {
      return true;
    }

    if (infinitySpiritScheme == 'http' ||
        infinitySpiritScheme == 'https') {
      final String infinitySpiritHost =
      infinitySpiritUri.host.toLowerCase();
      if (infinitySpiritExternalHosts
          .contains(infinitySpiritHost)) {
        return true;
      }
      if (infinitySpiritHost.endsWith('t.me')) return true;
      if (infinitySpiritHost.endsWith('wa.me')) return true;
      if (infinitySpiritHost.endsWith('m.me')) return true;
      if (infinitySpiritHost.endsWith('signal.me')) return true;
      if (infinitySpiritHost.endsWith('facebook.com')) return true;
      if (infinitySpiritHost.endsWith('instagram.com')) return true;
      if (infinitySpiritHost.endsWith('twitter.com')) return true;
      if (infinitySpiritHost.endsWith('x.com')) return true;
    }

    return false;
  }

  Uri infinitySpiritMapExternalToHttp(Uri infinitySpiritUri) {
    final String infinitySpiritScheme =
    infinitySpiritUri.scheme.toLowerCase();

    if (infinitySpiritScheme == 'tg' ||
        infinitySpiritScheme == 'telegram') {
      final Map<String, String> infinitySpiritQp =
          infinitySpiritUri.queryParameters;
      final String? infinitySpiritDomain =
      infinitySpiritQp['domain'];
      if (infinitySpiritDomain != null &&
          infinitySpiritDomain.isNotEmpty) {
        return Uri.https(
          't.me',
          '/$infinitySpiritDomain',
          <String, String>{
            if (infinitySpiritQp['start'] != null)
              'start': infinitySpiritQp['start']!,
          },
        );
      }
      final String infinitySpiritPath =
      infinitySpiritUri.path.isNotEmpty
          ? infinitySpiritUri.path
          : '';
      return Uri.https(
        't.me',
        '/$infinitySpiritPath',
        infinitySpiritUri.queryParameters.isEmpty
            ? null
            : infinitySpiritUri.queryParameters,
      );
    }

    if (infinitySpiritScheme == 'whatsapp') {
      final Map<String, String> infinitySpiritQp =
          infinitySpiritUri.queryParameters;
      final String? infinitySpiritPhone =
      infinitySpiritQp['phone'];
      final String? infinitySpiritText =
      infinitySpiritQp['text'];
      if (infinitySpiritPhone != null &&
          infinitySpiritPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${InfinitySpiritKit.infinitySpiritDigitsOnly(
            infinitySpiritPhone,
          )}',
          <String, String>{
            if (infinitySpiritText != null &&
                infinitySpiritText.isNotEmpty)
              'text': infinitySpiritText,
          },
        );
      }
      return Uri.https(
        'wa.me',
        '/',
        <String, String>{
          if (infinitySpiritText != null &&
              infinitySpiritText.isNotEmpty)
            'text': infinitySpiritText,
        },
      );
    }

    if (infinitySpiritScheme == 'bnl') {
      final String infinitySpiritNewPath =
      infinitySpiritUri.path.isNotEmpty
          ? infinitySpiritUri.path
          : '';
      return Uri.https(
        'bnl.com',
        '/$infinitySpiritNewPath',
        infinitySpiritUri.queryParameters.isEmpty
            ? null
            : infinitySpiritUri.queryParameters,
      );
    }

    return infinitySpiritUri;
  }

  Future<void> infinitySpiritSendLoadedOnce() async {
    if (infinitySpiritLoadedOnceSent) {
      debugPrint('Wheel Loaded already sent, skip');
      return;
    }

    final int infinitySpiritNow =
        DateTime.now().millisecondsSinceEpoch;

    await infinitySpiritPostStat(
      infinitySpiritEvent: 'Loaded',
      infinitySpiritTimeStart: infinitySpiritStartLoadTimestamp,
      infinitySpiritTimeFinish: infinitySpiritNow,
      infinitySpiritUrl: infinitySpiritCurrentUrl,
      infinitySpiritAppSid:
      infinitySpiritSpyInstance.infinitySpiritAppsFlyerUid,
      infinitySpiritFirstPageTs: infinitySpiritFirstPageTimestamp,
    );

    infinitySpiritLoadedOnceSent = true;
  }
}