import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show Platform, HttpHeaders, HttpClient, HttpClientRequest, HttpClientResponse;
import 'dart:math' as math;

import 'package:appsflyer_sdk/appsflyer_sdk.dart' as appsflyer_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodChannel, SystemChrome, SystemUiOverlayStyle, MethodCall, VoidCallback;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:infinitymagic/pugimugi.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz_zone;

import 'loader.dart';

// ============================================================================
// Константы
// ============================================================================

const String infinitySpiritLoadedOnceKey = 'loaded_once';
const String infinitySpiritStatEndpoint = 'https://sus.spiritmagic.us/stat';
const String infinitySpiritCachedFcmKey = 'cached_fcm';
const String infinitySpiritCachedDeepKey = 'cached_deep_push_uri';

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
// Лёгкие сервисы
// ============================================================================

class InfinitySpiritLoggerService {
  static final InfinitySpiritLoggerService infinitySpiritSharedInstance =
  InfinitySpiritLoggerService._infinitySpiritInternalConstructor();

  InfinitySpiritLoggerService._infinitySpiritInternalConstructor();

  factory InfinitySpiritLoggerService() => infinitySpiritSharedInstance;

  final Connectivity infinitySpiritConnectivity = Connectivity();

  void infinitySpiritLogInfo(Object message) => print('[I] $message');
  void infinitySpiritLogWarn(Object message) => print('[W] $message');
  void infinitySpiritLogError(Object message) => print('[E] $message');
}

class InfinitySpiritNetworkService {
  final InfinitySpiritLoggerService infinitySpiritLogger = InfinitySpiritLoggerService();

  Future<void> infinitySpiritPostJson(
      String url,
      Map<String, dynamic> data,
      ) async {
    try {
      await http.post(
        Uri.parse(url),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
    } catch (error) {
      infinitySpiritLogger.infinitySpiritLogError('postJson error: $error');
    }
  }
}

// ============================================================================
// Профиль устройства
// ============================================================================

class InfinitySpiritDeviceProfile {
  String? infinitySpiritDeviceId;
  String? infinitySpiritSessionId = '';
  String? infinitySpiritPlatformName;
  String? infinitySpiritOsVersion;
  String? infinitySpiritAppVersion;
  String? infinitySpiritLanguageCode;
  String? infinitySpiritTimezoneName;
  bool infinitySpiritPushEnabled = false;

  bool infinitySpiritSafeAreaEnabled = false;
  String? infinitySpiritSafeAreaColor;
  bool infinitySpiritSafeCasher = true;
  String? infinitySpiritBaseUserAgent;

  Map<String, dynamic>? infinitySpiritLastPushData;

  Map<String, dynamic>? infinitySpiritSavels;

  Future<void> infinitySpiritInitialize() async {
    final DeviceInfoPlugin infinitySpiritDeviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo infinitySpiritAndroidInfo =
      await infinitySpiritDeviceInfoPlugin.androidInfo;
      infinitySpiritDeviceId = infinitySpiritAndroidInfo.id;
      infinitySpiritPlatformName = 'android';
      infinitySpiritOsVersion = infinitySpiritAndroidInfo.version.release;
    } else if (Platform.isIOS) {
      final IosDeviceInfo infinitySpiritIosInfo =
      await infinitySpiritDeviceInfoPlugin.iosInfo;
      infinitySpiritDeviceId = infinitySpiritIosInfo.identifierForVendor;
      infinitySpiritPlatformName = 'ios';
      infinitySpiritOsVersion = infinitySpiritIosInfo.systemVersion;
    }

    final PackageInfo infinitySpiritPackageInfo = await PackageInfo.fromPlatform();
    infinitySpiritAppVersion = infinitySpiritPackageInfo.version;
    infinitySpiritLanguageCode = Platform.localeName.split('_').first;
    infinitySpiritTimezoneName = tz_zone.local.name;
    infinitySpiritSessionId = 'test-${DateTime.now().millisecondsSinceEpoch}';
  }

  Map<String, dynamic> infinitySpiritToMap({String? infinitySpiritFcmToken}) =>
      <String, dynamic>{
        'fcm_token': infinitySpiritFcmToken ?? 'missing_token',
        'device_id': infinitySpiritDeviceId ?? 'missing_id',
        'app_name': 'spiritmagic',
        'instance_id': infinitySpiritSessionId ?? 'missing_session',
        'platform': infinitySpiritPlatformName ?? 'missing_system',
        'os_version': infinitySpiritOsVersion ?? 'missing_build',
        'app_version': "1.4.0" ?? 'missing_app',
        'language': infinitySpiritLanguageCode ?? 'en',
        'timezone': infinitySpiritTimezoneName ?? 'UTC',
        'push_enabled': infinitySpiritPushEnabled,
        'safe_area_native': infinitySpiritSafeAreaEnabled,
        'useragent': infinitySpiritBaseUserAgent ?? 'unknown_useragent',
        'savels': infinitySpiritSavels ?? <String, dynamic>{},
        'fpscashier': infinitySpiritSafeCasher,
      };
}

// ============================================================================
// AppsFlyer Spy
// ============================================================================

class InfinitySpiritAnalyticsSpyService {
  appsflyer_core.AppsFlyerOptions? infinitySpiritAppsFlyerOptions;
  appsflyer_core.AppsflyerSdk? infinitySpiritAppsFlyerSdk;

  String infinitySpiritAppsFlyerUid = '';
  String infinitySpiritAppsFlyerData = '';

  Map<String, dynamic>? infinitySpiritAppsFlyerOneLinkData;

  void infinitySpiritStartTracking({VoidCallback? infinitySpiritOnUpdate}) {
    final appsflyer_core.AppsFlyerOptions infinitySpiritConfig =
    appsflyer_core.AppsFlyerOptions(
      afDevKey: 'qsBLmy7dAXDQhowM8V3ca4',
      appId: '6763529951',
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );

    infinitySpiritAppsFlyerOptions = infinitySpiritConfig;
    infinitySpiritAppsFlyerSdk = appsflyer_core.AppsflyerSdk(infinitySpiritConfig);

    infinitySpiritAppsFlyerSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );

    infinitySpiritAppsFlyerSdk?.startSDK(
      onSuccess: () => InfinitySpiritLoggerService()
          .infinitySpiritLogInfo('RetroCarAnalyticsSpy started'),
      onError: (int infinitySpiritCode, String infinitySpiritMsg) =>
          InfinitySpiritLoggerService().infinitySpiritLogError(
              'RetroCarAnalyticsSpy error $infinitySpiritCode: $infinitySpiritMsg'),
    );

    infinitySpiritAppsFlyerSdk?.onInstallConversionData(
          (dynamic infinitySpiritValue) {
        infinitySpiritAppsFlyerData = infinitySpiritValue.toString();
        infinitySpiritOnUpdate?.call();
      },
    );

    infinitySpiritAppsFlyerSdk?.getAppsFlyerUID().then(
          (dynamic infinitySpiritValue) {
        infinitySpiritAppsFlyerUid = infinitySpiritValue.toString();
        infinitySpiritOnUpdate?.call();
      },
    );
  }

  void infinitySpiritSetOneLinkData(Map<String, dynamic> infinitySpiritData) {
    infinitySpiritAppsFlyerOneLinkData = infinitySpiritData;
    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'InfinitySpiritAnalyticsSpyService: OneLink data updated: $infinitySpiritData');
  }
}

// ============================================================================
// FCM фон
// ============================================================================

@pragma('vm:entry-point')
Future<void> infinitySpiritFcmBackgroundHandler(
    RemoteMessage infinitySpiritMessage) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  InfinitySpiritLoggerService()
      .infinitySpiritLogInfo('bg-fcm: ${infinitySpiritMessage.messageId}');
  InfinitySpiritLoggerService()
      .infinitySpiritLogInfo('bg-data: ${infinitySpiritMessage.data}');

  final dynamic infinitySpiritLink = infinitySpiritMessage.data['uri'];
  if (infinitySpiritLink != null) {
    try {
      final SharedPreferences infinitySpiritPrefs =
      await SharedPreferences.getInstance();
      await infinitySpiritPrefs.setString(
        infinitySpiritCachedDeepKey,
        infinitySpiritLink.toString(),
      );
    } catch (e) {
      InfinitySpiritLoggerService()
          .infinitySpiritLogError('bg-fcm save deep failed: $e');
    }
  }
}

// ============================================================================
// FCM Bridge — токен
// ============================================================================

class InfinitySpiritFcmBridge {
  final InfinitySpiritLoggerService infinitySpiritLogger =
  InfinitySpiritLoggerService();

  static const MethodChannel infinitySpiritTokenChannel =
  MethodChannel('com.example.fcm/token');

  String? infinitySpiritToken;
  final List<void Function(String)> infinitySpiritTokenWaiters =
  <void Function(String)>[];

  String? get infinitySpiritFcmToken => infinitySpiritToken;

  Timer? infinitySpiritRequestTimer;
  int infinitySpiritRequestAttempts = 0;
  final int infinitySpiritMaxAttempts = 10;

  InfinitySpiritFcmBridge() {
    infinitySpiritTokenChannel
        .setMethodCallHandler((MethodCall infinitySpiritCall) async {
      if (infinitySpiritCall.method == 'setToken') {
        final String infinitySpiritTokenString =
        infinitySpiritCall.arguments as String;
        infinitySpiritLogger.infinitySpiritLogInfo(
            'InfinitySpiritFcmBridge: got token from native channel = $infinitySpiritTokenString');
        if (infinitySpiritTokenString.isNotEmpty) {
          infinitySpiritSetToken(infinitySpiritTokenString);
        }
      }
    });

    infinitySpiritRestoreToken();
    infinitySpiritRequestNativeToken();
    infinitySpiritStartRequestTimer();
  }

  Future<void> infinitySpiritRequestNativeToken() async {
    try {
      infinitySpiritLogger.infinitySpiritLogInfo(
          'InfinitySpiritFcmBridge: request native getToken()');
      final String? infinitySpiritLocalToken =
      await infinitySpiritTokenChannel.invokeMethod<String>('getToken');
      if (infinitySpiritLocalToken != null && infinitySpiritLocalToken.isNotEmpty) {
        infinitySpiritLogger.infinitySpiritLogInfo(
            'InfinitySpiritFcmBridge: native getToken() returns $infinitySpiritLocalToken');
        infinitySpiritSetToken(infinitySpiritLocalToken);
      } else {
        infinitySpiritLogger.infinitySpiritLogWarn(
            'InfinitySpiritFcmBridge: native getToken() returned empty');
      }
    } catch (e) {
      infinitySpiritLogger.infinitySpiritLogWarn(
          'InfinitySpiritFcmBridge: getToken invoke error: $e');
    }
  }

  void infinitySpiritStartRequestTimer() {
    infinitySpiritRequestTimer?.cancel();
    infinitySpiritRequestAttempts = 0;

    infinitySpiritRequestTimer =
        Timer.periodic(const Duration(seconds: 5), (Timer infinitySpiritTimer) async {
          if ((infinitySpiritToken ?? '').isNotEmpty) {
            infinitySpiritLogger.infinitySpiritLogInfo(
                'InfinitySpiritFcmBridge: token already set, stop request timer');
            infinitySpiritTimer.cancel();
            return;
          }

          if (infinitySpiritRequestAttempts >= infinitySpiritMaxAttempts) {
            infinitySpiritLogger.infinitySpiritLogWarn(
                'InfinitySpiritFcmBridge: max getToken attempts reached, stop timer');
            infinitySpiritTimer.cancel();
            return;
          }

          infinitySpiritRequestAttempts++;
          infinitySpiritLogger.infinitySpiritLogInfo(
              'InfinitySpiritFcmBridge: retry getToken() attempt #$infinitySpiritRequestAttempts');
          await infinitySpiritRequestNativeToken();
        });
  }

  Future<void> infinitySpiritRestoreToken() async {
    try {
      final SharedPreferences infinitySpiritPrefs =
      await SharedPreferences.getInstance();
      final String? infinitySpiritCachedToken =
      infinitySpiritPrefs.getString(infinitySpiritCachedFcmKey);
      if (infinitySpiritCachedToken != null &&
          infinitySpiritCachedToken.isNotEmpty) {
        infinitySpiritLogger.infinitySpiritLogInfo(
            'InfinitySpiritFcmBridge: restored cached token = $infinitySpiritCachedToken');
        infinitySpiritSetToken(infinitySpiritCachedToken, infinitySpiritNotify: false);
      }
    } catch (e) {
      infinitySpiritLogger.infinitySpiritLogError(
          'infinitySpiritRestoreToken error: $e');
    }
  }

  Future<void> infinitySpiritPersistToken(String infinitySpiritNewToken) async {
    try {
      final SharedPreferences infinitySpiritPrefs =
      await SharedPreferences.getInstance();
      await infinitySpiritPrefs.setString(
          infinitySpiritCachedFcmKey, infinitySpiritNewToken);
    } catch (e) {
      infinitySpiritLogger.infinitySpiritLogError(
          'infinitySpiritPersistToken error: $e');
    }
  }

  void infinitySpiritSetToken(
      String infinitySpiritNewToken, {
        bool infinitySpiritNotify = true,
      }) {
    infinitySpiritToken = infinitySpiritNewToken;
    infinitySpiritPersistToken(infinitySpiritNewToken);

    if (infinitySpiritNotify) {
      for (final void Function(String) infinitySpiritCallback
      in List<void Function(String)>.from(infinitySpiritTokenWaiters)) {
        try {
          infinitySpiritCallback(infinitySpiritNewToken);
        } catch (error) {
          infinitySpiritLogger.infinitySpiritLogWarn('fcm waiter error: $error');
        }
      }
      infinitySpiritTokenWaiters.clear();
    }
  }

  Future<void> infinitySpiritWaitForToken(
      Function(String infinitySpiritToken) infinitySpiritOnToken,
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

      infinitySpiritTokenWaiters.add(infinitySpiritOnToken);
    } catch (error) {
      infinitySpiritLogger.infinitySpiritLogError(
          'infinitySpiritWaitForToken error: $error');
    }
  }

  void infinitySpiritDispose() {
    infinitySpiritRequestTimer?.cancel();
  }
}

// ============================================================================
// Splash / Hall
// ============================================================================

class InfinitySpiritHall extends StatefulWidget {
  const InfinitySpiritHall({Key? key}) : super(key: key);

  @override
  State<InfinitySpiritHall> createState() => _InfinitySpiritHallState();
}

class _InfinitySpiritHallState extends State<InfinitySpiritHall> {
  final InfinitySpiritFcmBridge infinitySpiritFcmBridgeInstance =
  InfinitySpiritFcmBridge();
  bool infinitySpiritNavigatedOnce = false;
  Timer? infinitySpiritFallbackTimer;
  bool infinitySpiritShowLoaderFlag = true;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    infinitySpiritFcmBridgeInstance.infinitySpiritWaitForToken(
          (String infinitySpiritToken) {
        infinitySpiritGoToHarbor(infinitySpiritToken);
      },
    );

    infinitySpiritFallbackTimer = Timer(
      const Duration(seconds: 8),
          () => infinitySpiritGoToHarbor(''),
    );

    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() {
        infinitySpiritShowLoaderFlag = false;
      });
    });
  }

  void infinitySpiritGoToHarbor(String infinitySpiritSignal) {
    if (infinitySpiritNavigatedOnce) return;
    infinitySpiritNavigatedOnce = true;
    infinitySpiritFallbackTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<Widget>(
        builder: (BuildContext context) =>
            InfinitySpiritHarbor(infinitySpiritSignal: infinitySpiritSignal),
      ),
    );
  }

  @override
  void dispose() {
    infinitySpiritFallbackTimer?.cancel();
    infinitySpiritFcmBridgeInstance.infinitySpiritDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(

        child: Container(
          color: Colors.black,
          child: Center(
            child:    Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: InfinitySpiritCenterLoaderScreen2(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ViewModel + Courier
// ============================================================================

class InfinitySpiritBosunViewModel {
  final InfinitySpiritDeviceProfile infinitySpiritDeviceProfileInstance;
  final InfinitySpiritAnalyticsSpyService infinitySpiritAnalyticsSpyInstance;

  InfinitySpiritBosunViewModel({
    required this.infinitySpiritDeviceProfileInstance,
    required this.infinitySpiritAnalyticsSpyInstance,
  });

  Map<String, dynamic> infinitySpiritDeviceMap(String? infinitySpiritFcmToken) =>
      infinitySpiritDeviceProfileInstance.infinitySpiritToMap(
          infinitySpiritFcmToken: infinitySpiritFcmToken);

  Map<String, dynamic> infinitySpiritAppsFlyerPayload(
      String? infinitySpiritToken, {
        String? infinitySpiritDeepLink,
      }) {
    final Map<String, dynamic> infinitySpiritOnelinkData =
        infinitySpiritAnalyticsSpyInstance.infinitySpiritAppsFlyerOneLinkData ??
            <String, dynamic>{};

    return <String, dynamic>{
      'content': <String, dynamic>{
        'af_data': infinitySpiritAnalyticsSpyInstance.infinitySpiritAppsFlyerData,
        'af_id': infinitySpiritAnalyticsSpyInstance.infinitySpiritAppsFlyerUid,
        'fb_app_name': 'spiritmagic',
        'app_name': 'spiritmagic',
        'onelink': infinitySpiritOnelinkData,
        'bundle_identifier': 'com.magicingif.infitnut.infinitymagic',
        'app_version': '1.4.0',
        'apple_id': '6763529951',
        'fcm_token': infinitySpiritToken ?? 'no_token',
        'device_id':
        infinitySpiritDeviceProfileInstance.infinitySpiritDeviceId ?? 'no_device',
        'instance_id':
        infinitySpiritDeviceProfileInstance.infinitySpiritSessionId ??
            'no_instance',
        'platform': infinitySpiritDeviceProfileInstance.infinitySpiritPlatformName ??
            'no_type',
        'os_version':
        infinitySpiritDeviceProfileInstance.infinitySpiritOsVersion ??
            'no_os',
        'language':
        infinitySpiritDeviceProfileInstance.infinitySpiritLanguageCode ??
            'en',
        'timezone':
        infinitySpiritDeviceProfileInstance.infinitySpiritTimezoneName ??
            'UTC',
        'push_enabled':
        infinitySpiritDeviceProfileInstance.infinitySpiritPushEnabled,
        'useruid': infinitySpiritAnalyticsSpyInstance.infinitySpiritAppsFlyerUid,
        'safearea':
        infinitySpiritDeviceProfileInstance.infinitySpiritSafeAreaEnabled,
        'safearea_color':
        infinitySpiritDeviceProfileInstance.infinitySpiritSafeAreaColor ?? '',
        'useragent':
        infinitySpiritDeviceProfileInstance.infinitySpiritBaseUserAgent ??
            'unknown_useragent',
        'push':
        infinitySpiritDeviceProfileInstance.infinitySpiritLastPushData ??
            <String, dynamic>{},
        'deep': infinitySpiritDeepLink,
      },
    };
  }
}

class InfinitySpiritCourierService {
  final InfinitySpiritBosunViewModel infinitySpiritBosun;
  final InAppWebViewController? Function() infinitySpiritGetWebViewController;

  InfinitySpiritCourierService({
    required this.infinitySpiritBosun,
    required this.infinitySpiritGetWebViewController,
  });

  Future<InAppWebViewController?> infinitySpiritWaitForController({
    Duration infinitySpiritTimeout = const Duration(seconds: 10),
    Duration infinitySpiritInterval = const Duration(milliseconds: 200),
  }) async {
    final InfinitySpiritLoggerService infinitySpiritLogger =
    InfinitySpiritLoggerService();
    final DateTime infinitySpiritStart = DateTime.now();

    while (DateTime.now().difference(infinitySpiritStart) <
        infinitySpiritTimeout) {
      final InAppWebViewController? infinitySpiritController =
      infinitySpiritGetWebViewController();
      if (infinitySpiritController != null) {
        return infinitySpiritController;
      }
      await Future<void>.delayed(infinitySpiritInterval);
    }

    infinitySpiritLogger.infinitySpiritLogWarn(
        'infinitySpiritWaitForController: timeout, controller is still null');
    return null;
  }

  Future<void> infinitySpiritPutDeviceToLocalStorage(
      String? infinitySpiritToken) async {
    final InAppWebViewController? infinitySpiritController =
    await infinitySpiritWaitForController();
    if (infinitySpiritController == null) return;

    final Map<String, dynamic> infinitySpiritMap =
    infinitySpiritBosun.infinitySpiritDeviceMap(infinitySpiritToken);
    InfinitySpiritLoggerService()
        .infinitySpiritLogInfo("applocal (${jsonEncode(infinitySpiritMap)});");

    try {
      await infinitySpiritController.evaluateJavascript(
        source:
        "localStorage.setItem('app_data', JSON.stringify(${jsonEncode(infinitySpiritMap)}));",
      );
    } catch (e, st) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'infinitySpiritPutDeviceToLocalStorage error: $e\n$st');
    }
  }

  Future<void> infinitySpiritSendRawToPage(
      String? infinitySpiritToken, {
        String? infinitySpiritDeepLink,
      }) async {
    final InAppWebViewController? infinitySpiritController =
    await infinitySpiritWaitForController();
    if (infinitySpiritController == null) return;

    final Map<String, dynamic> infinitySpiritPayload =
    infinitySpiritBosun.infinitySpiritAppsFlyerPayload(
      infinitySpiritToken,
      infinitySpiritDeepLink: infinitySpiritDeepLink,
    );

    final String infinitySpiritJsonString = jsonEncode(infinitySpiritPayload);

    InfinitySpiritLoggerService()
        .infinitySpiritLogInfo('SendRawData: $infinitySpiritJsonString');

    final String infinitySpiritJsSafeJson = jsonEncode(infinitySpiritJsonString);
    final String infinitySpiritJsCode = 'sendRawData($infinitySpiritJsSafeJson);';

    try {
      await infinitySpiritController.evaluateJavascript(
        source: infinitySpiritJsCode,
      );
    } catch (e, st) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'infinitySpiritSendRawToPage evaluateJavascript error: $e\n$st');
    }
  }
}

// ============================================================================
// Статистика
// ============================================================================

Future<String> infinitySpiritResolveFinalUrl(
    String infinitySpiritStartUrl, {
      int infinitySpiritMaxHops = 10,
    }) async {
  final HttpClient infinitySpiritHttpClient = HttpClient();

  try {
    Uri infinitySpiritCurrentUri = Uri.parse(infinitySpiritStartUrl);

    for (int infinitySpiritIndex = 0;
    infinitySpiritIndex < infinitySpiritMaxHops;
    infinitySpiritIndex++) {
      final HttpClientRequest infinitySpiritRequest =
      await infinitySpiritHttpClient.getUrl(infinitySpiritCurrentUri);
      infinitySpiritRequest.followRedirects = false;
      final HttpClientResponse infinitySpiritResponse =
      await infinitySpiritRequest.close();

      if (infinitySpiritResponse.isRedirect) {
        final String? infinitySpiritLocationHeader =
        infinitySpiritResponse.headers.value(HttpHeaders.locationHeader);
        if (infinitySpiritLocationHeader == null ||
            infinitySpiritLocationHeader.isEmpty) {
          break;
        }

        final Uri infinitySpiritNextUri =
        Uri.parse(infinitySpiritLocationHeader);
        infinitySpiritCurrentUri = infinitySpiritNextUri.hasScheme
            ? infinitySpiritNextUri
            : infinitySpiritCurrentUri.resolveUri(infinitySpiritNextUri);
        continue;
      }

      return infinitySpiritCurrentUri.toString();
    }

    return infinitySpiritCurrentUri.toString();
  } catch (error) {
    print('goldenLuxuryResolveFinalUrl error: $error');
    return infinitySpiritStartUrl;
  } finally {
    infinitySpiritHttpClient.close(force: true);
  }
}

Future<void> infinitySpiritPostStat({
  required String infinitySpiritEvent,
  required int infinitySpiritTimeStart,
  required String infinitySpiritUrl,
  required int infinitySpiritTimeFinish,
  required String infinitySpiritAppSid,
  int? infinitySpiritFirstPageLoadTs,
}) async {
  try {
    final String infinitySpiritResolvedUrl =
    await infinitySpiritResolveFinalUrl(infinitySpiritUrl);

    final Map<String, dynamic> infinitySpiritPayload = <String, dynamic>{
      'event': infinitySpiritEvent,
      'timestart': infinitySpiritTimeStart,
      'timefinsh': infinitySpiritTimeFinish,
      'url': infinitySpiritResolvedUrl,
      'appleID': '6758657360',
      'open_count': '$infinitySpiritAppSid/$infinitySpiritTimeStart',
    };

    print('goldenLuxuryStat $infinitySpiritPayload');

    final http.Response infinitySpiritResponse = await http.post(
      Uri.parse('$infinitySpiritStatEndpoint/$infinitySpiritAppSid'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(infinitySpiritPayload),
    );

    print(
        'goldenLuxuryStat resp=${infinitySpiritResponse.statusCode} body=${infinitySpiritResponse.body}');
  } catch (error) {
    print('goldenLuxuryPostStat error: $error');
  }
}

// ============================================================================
// Банковские утилиты
// ============================================================================

bool infinitySpiritIsBankScheme(Uri infinitySpiritUri) {
  final String infinitySpiritScheme = infinitySpiritUri.scheme.toLowerCase();
  return kBankSchemes.contains(infinitySpiritScheme);
}

bool infinitySpiritIsBankDomain(Uri infinitySpiritUri) {
  final String infinitySpiritHost = infinitySpiritUri.host.toLowerCase();
  if (infinitySpiritHost.isEmpty) return false;

  for (final String infinitySpiritBank in kBankDomains) {
    final String infinitySpiritBankHost = infinitySpiritBank.toLowerCase();
    if (infinitySpiritHost == infinitySpiritBankHost ||
        infinitySpiritHost.endsWith('.$infinitySpiritBankHost')) {
      return true;
    }
  }
  return false;
}

Future<bool> infinitySpiritOpenBank(Uri infinitySpiritUri) async {
  try {
    if (infinitySpiritIsBankScheme(infinitySpiritUri)) {
      final bool infinitySpiritOk = await launchUrl(
        infinitySpiritUri,
        mode: LaunchMode.externalApplication,
      );
      return infinitySpiritOk;
    }

    if ((infinitySpiritUri.scheme == 'http' ||
        infinitySpiritUri.scheme == 'https') &&
        infinitySpiritIsBankDomain(infinitySpiritUri)) {
      final bool infinitySpiritOk = await launchUrl(
        infinitySpiritUri,
        mode: LaunchMode.externalApplication,
      );
      return infinitySpiritOk;
    }
  } catch (e) {
    print('infinitySpiritOpenBank error: $e; url=$infinitySpiritUri');
  }
  return false;
}

// ============================================================================
// ЛОАДЕР (солнышко вокруг второй картинки)
// ============================================================================




// ============================================================================
// Главный WebView — Harbor
// ============================================================================

class InfinitySpiritHarbor extends StatefulWidget {
  final String? infinitySpiritSignal;

  const InfinitySpiritHarbor({super.key, required this.infinitySpiritSignal});

  @override
  State<InfinitySpiritHarbor> createState() => _InfinitySpiritHarborState();
}

class _InfinitySpiritHarborState extends State<InfinitySpiritHarbor>
    with WidgetsBindingObserver {
  InAppWebViewController? infinitySpiritWebViewController;
  final String infinitySpiritHomeUrl = 'https://sus.spiritmagic.us/';

  int infinitySpiritWebViewKeyCounter = 0;
  DateTime? infinitySpiritSleepAt;
  bool infinitySpiritVeilVisible = false;
  double infinitySpiritWarmProgress = 0.0;
  late Timer infinitySpiritWarmTimer;
  final int infinitySpiritWarmSeconds = 6;
  bool infinitySpiritCoverVisible = true;

  bool infinitySpiritLoadedOnceSent = false;
  int? infinitySpiritFirstPageTimestamp;

  InfinitySpiritCourierService? infinitySpiritCourier;
  InfinitySpiritBosunViewModel? infinitySpiritBosunInstance;

  String infinitySpiritCurrentUrl = '';
  int infinitySpiritStartLoadTimestamp = 0;

  final InfinitySpiritDeviceProfile infinitySpiritDeviceProfileInstance =
  InfinitySpiritDeviceProfile();
  final InfinitySpiritAnalyticsSpyService infinitySpiritAnalyticsSpyInstance =
  InfinitySpiritAnalyticsSpyService();

  final Set<String> infinitySpiritSpecialSchemes = <String>{
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

  final Set<String> infinitySpiritExternalHosts = <String>{
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'm.me',
    'signal.me',
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

  String? infinitySpiritDeepLinkFromPush;

  String? infinitySpiritBaseUserAgent;
  String infinitySpiritCurrentUserAgent = "";
  String? infinitySpiritCurrentUrlValue;

  String? infinitySpiritServerUserAgent;

  bool infinitySpiritSafeAreaEnabled = false;
  Color infinitySpiritSafeAreaBackgroundColor = const Color(0xFF000000);

  bool infinitySpiritStartupSendRawDone = false;

  String? infinitySpiritPendingLoadedJs;

  bool infinitySpiritLoadedJsExecutedOnce = false;

  bool infinitySpiritIsInGoogleAuth = false;

  List<String> infinitySpiritButtonWhitelist = <String>[];
  bool infinitySpiritShowBackButton = false;

  static const MethodChannel infinitySpiritAppsFlyerDeepLinkChannel =
  MethodChannel('appsflyer_deeplink_channel');

  bool infinitySpiritLoaderVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    infinitySpiritFirstPageTimestamp = DateTime.now().millisecondsSinceEpoch;
    infinitySpiritCurrentUrlValue = infinitySpiritHomeUrl;

    // Лоадер скрываем через 8 секунд
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() {
        infinitySpiritLoaderVisible = false;
      });
    });

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          infinitySpiritCoverVisible = false;
        });
      }
    });

    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() {
        infinitySpiritVeilVisible = true;
      });
    });

    infinitySpiritBindPushChannelFromAppDelegate();
    infinitySpiritBindAppsFlyerDeepLinkChannel();
    infinitySpiritBootHarbor();
  }

  // ======================= AppsFlyer deep link bridge =======================

  void infinitySpiritBindAppsFlyerDeepLinkChannel() {
    infinitySpiritAppsFlyerDeepLinkChannel
        .setMethodCallHandler((MethodCall infinitySpiritCall) async {
      if (infinitySpiritCall.method == 'onDeepLink') {
        try {
          final dynamic infinitySpiritArgs = infinitySpiritCall.arguments;

          Map<String, dynamic> infinitySpiritPayload;

          print(" Data Deepl link ${infinitySpiritArgs.toString()}");
          if (infinitySpiritArgs is Map) {
            infinitySpiritPayload =
            Map<String, dynamic>.from(infinitySpiritArgs as Map);
          } else if (infinitySpiritArgs is String) {
            infinitySpiritPayload =
            jsonDecode(infinitySpiritArgs) as Map<String, dynamic>;
          } else {
            infinitySpiritPayload = <String, dynamic>{
              'raw': infinitySpiritArgs.toString()
            };
          }

          InfinitySpiritLoggerService().infinitySpiritLogInfo(
            'AppsFlyer onDeepLink from iOS: $infinitySpiritPayload',
          );

          final dynamic infinitySpiritRaw = infinitySpiritPayload['raw'];
          if (infinitySpiritRaw is Map) {
            final Map<String, dynamic> infinitySpiritNormalized =
            Map<String, dynamic>.from(infinitySpiritRaw as Map);

            print("One Link Data $infinitySpiritNormalized");
            infinitySpiritAnalyticsSpyInstance
                .infinitySpiritSetOneLinkData(infinitySpiritNormalized);
          } else {
            infinitySpiritAnalyticsSpyInstance
                .infinitySpiritSetOneLinkData(infinitySpiritPayload);
          }
        } catch (e, st) {
          InfinitySpiritLoggerService()
              .infinitySpiritLogError('Error in onDeepLink handler: $e\n$st');
        }
      }
    });
  }

  // ======================= Push Data bridge из AppDelegate ==================

  void infinitySpiritBindPushChannelFromAppDelegate() {
    const MethodChannel infinitySpiritPushChannel =
    MethodChannel('com.example.fcm/push');

    infinitySpiritPushChannel
        .setMethodCallHandler((MethodCall infinitySpiritCall) async {
      if (infinitySpiritCall.method == 'setPushData') {
        try {
          Map<String, dynamic> infinitySpiritPushData;
          if (infinitySpiritCall.arguments is Map) {
            infinitySpiritPushData =
            Map<String, dynamic>.from(infinitySpiritCall.arguments);
            print("Get Push Data $infinitySpiritPushData");
          } else if (infinitySpiritCall.arguments is String) {
            infinitySpiritPushData = jsonDecode(
                infinitySpiritCall.arguments as String)
            as Map<String, dynamic>;
          } else {
            infinitySpiritPushData = <String, dynamic>{
              'raw': infinitySpiritCall.arguments.toString()
            };
          }

          InfinitySpiritLoggerService().infinitySpiritLogInfo(
              'Got push data from AppDelegate: $infinitySpiritPushData');

          infinitySpiritDeviceProfileInstance.infinitySpiritLastPushData =
              infinitySpiritPushData;

          final dynamic infinitySpiritUriRaw =
              infinitySpiritPushData['uri'] ??
                  infinitySpiritPushData['deep_link'];
          if (infinitySpiritUriRaw != null &&
              infinitySpiritUriRaw.toString().isNotEmpty) {
            final String infinitySpiritUriValue =
            infinitySpiritUriRaw.toString();
            infinitySpiritDeepLinkFromPush = infinitySpiritUriValue;
            await infinitySpiritSaveCachedDeep(infinitySpiritUriValue);
          }
        } catch (e, st) {
          InfinitySpiritLoggerService()
              .infinitySpiritLogError('setPushData handler error: $e\n$st');
        }
      }
    });
  }

  // ---------------- User-Agent ----------------

  Future<void> infinitySpiritUpdateUserAgentFromServerPayload(
      Map<dynamic, dynamic> infinitySpiritRoot) async {
    String? infinitySpiritFullUa;
    String? infinitySpiritUaTail;

    final dynamic infinitySpiritContent = infinitySpiritRoot['content'];
    if (infinitySpiritContent is Map) {
      if (infinitySpiritContent['fullua'] != null &&
          infinitySpiritContent['fullua'].toString().trim().isNotEmpty) {
        infinitySpiritFullUa =
            infinitySpiritContent['fullua'].toString().trim();
      }
      if (infinitySpiritContent['uatail'] != null &&
          infinitySpiritContent['uatail'].toString().trim().isNotEmpty) {
        infinitySpiritUaTail =
            infinitySpiritContent['uatail'].toString().trim();
      }
    }

    if (infinitySpiritFullUa == null &&
        infinitySpiritRoot['fullua'] != null &&
        infinitySpiritRoot['fullua'].toString().trim().isNotEmpty) {
      infinitySpiritFullUa = infinitySpiritRoot['fullua'].toString().trim();
    }
    if (infinitySpiritUaTail == null &&
        infinitySpiritRoot['uatail'] != null &&
        infinitySpiritRoot['uatail'].toString().trim().isNotEmpty) {
      infinitySpiritUaTail = infinitySpiritRoot['uatail'].toString().trim();
    }

    if (infinitySpiritUaTail == null) {
      final dynamic infinitySpiritAdData = infinitySpiritRoot['adata'];
      if (infinitySpiritAdData is Map &&
          infinitySpiritAdData['uatail'] != null &&
          infinitySpiritAdData['uatail'].toString().trim().isNotEmpty) {
        infinitySpiritUaTail =
            infinitySpiritAdData['uatail'].toString().trim();
      }
    }

    await infinitySpiritApplyUserAgent(
      infinitySpiritFullUa: infinitySpiritFullUa,
      infinitySpiritUaTail: infinitySpiritUaTail,
    );
  }

  Future<void> infinitySpiritApplyUserAgent({
    String? infinitySpiritFullUa,
    String? infinitySpiritUaTail,
  }) async {
    if (infinitySpiritWebViewController == null) return;

    if (infinitySpiritBaseUserAgent == null ||
        infinitySpiritBaseUserAgent!.trim().isEmpty) {
      try {
        final dynamic infinitySpiritUa =
        await infinitySpiritWebViewController!.evaluateJavascript(
          source: "navigator.userAgent",
        );
        if (infinitySpiritUa is String &&
            infinitySpiritUa.trim().isNotEmpty) {
          infinitySpiritBaseUserAgent = infinitySpiritUa.trim();
          infinitySpiritCurrentUserAgent = infinitySpiritBaseUserAgent!;
          infinitySpiritDeviceProfileInstance.infinitySpiritBaseUserAgent =
              infinitySpiritBaseUserAgent;
          InfinitySpiritLoggerService().infinitySpiritLogInfo(
              'Base User-Agent detected: $infinitySpiritBaseUserAgent');
        }
      } catch (e) {
        InfinitySpiritLoggerService()
            .infinitySpiritLogWarn('Failed to get base userAgent from JS: $e');
      }
    }

    if (infinitySpiritBaseUserAgent == null ||
        infinitySpiritBaseUserAgent!.trim().isEmpty) {
      InfinitySpiritLoggerService().infinitySpiritLogWarn(
          'Base User-Agent is still null/empty, skip UA update');
      return;
    }

    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'Server UA payload: fullua="$infinitySpiritFullUa", uatail="$infinitySpiritUaTail", base="$infinitySpiritBaseUserAgent"');

    String infinitySpiritNewUa;
    if (infinitySpiritFullUa != null &&
        infinitySpiritFullUa.trim().isNotEmpty) {
      infinitySpiritNewUa = infinitySpiritFullUa.trim();
    } else if (infinitySpiritUaTail != null &&
        infinitySpiritUaTail.trim().isNotEmpty) {
      infinitySpiritNewUa =
      "${infinitySpiritBaseUserAgent!}/${infinitySpiritUaTail.trim()}";
    } else {
      infinitySpiritNewUa = "${infinitySpiritBaseUserAgent!}";
    }

    infinitySpiritServerUserAgent = infinitySpiritNewUa;
    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'Server UA calculated and stored: $infinitySpiritServerUserAgent');
  }

  Future<void> infinitySpiritApplyNormalUserAgentIfNeeded() async {
    if (infinitySpiritWebViewController == null) return;

    if (infinitySpiritIsInGoogleAuth) {
      InfinitySpiritLoggerService().infinitySpiritLogInfo(
          'Skip normal UA apply because we are in Google auth flow');
      return;
    }

    final String infinitySpiritTargetUa =
        infinitySpiritServerUserAgent ??
            infinitySpiritBaseUserAgent ??
            'random';

    if (infinitySpiritTargetUa == infinitySpiritCurrentUserAgent) {
      InfinitySpiritLoggerService().infinitySpiritLogInfo(
          'Normal UA unchanged, keeping: $infinitySpiritCurrentUserAgent');
      return;
    }

    InfinitySpiritLoggerService()
        .infinitySpiritLogInfo('Applying NORMAL WebView User-Agent: $infinitySpiritTargetUa');

    try {
      await infinitySpiritWebViewController!.setSettings(
        settings: InAppWebViewSettings(userAgent: infinitySpiritTargetUa),
      );
      infinitySpiritCurrentUserAgent = infinitySpiritTargetUa;
      print('[UA] NORMAL WEBVIEW USER AGENT: $infinitySpiritCurrentUserAgent');
    } catch (e) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'Error while setting normal User-Agent "$infinitySpiritTargetUa": $e');
    }
  }

  Future<void> infinitySpiritPrintJsUserAgent() async {
    if (infinitySpiritWebViewController == null) return;

    try {
      final dynamic infinitySpiritUa =
      await infinitySpiritWebViewController!.evaluateJavascript(
        source: "navigator.userAgent",
      );

      if (infinitySpiritUa is String) {
        print('[JS UA] navigator.userAgent = $infinitySpiritUa');
      } else {
        print('[JS UA] navigator.userAgent (non-string) = $infinitySpiritUa');
      }
    } catch (e, st) {
      print('Error reading navigator.userAgent: $e\n$st');
    }
  }

  Future<void> infinitySpiritDebugPrintCurrentUserAgent() async {
    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        '[STATE UA] infinitySpiritCurrentUserAgent = $infinitySpiritCurrentUserAgent');
    await infinitySpiritPrintJsUserAgent();
  }

  bool infinitySpiritIsGoogleUrl(Uri infinitySpiritUri) {
    final String infinitySpiritFull =
    infinitySpiritUri.toString().toLowerCase();
    return infinitySpiritFull.contains('google');
  }

  Future<void> infinitySpiritAddRandomToUserAgentForGoogle() async {
    if (infinitySpiritWebViewController == null) return;

    const String infinitySpiritTargetUa = 'random';

    if (infinitySpiritCurrentUserAgent == infinitySpiritTargetUa &&
        infinitySpiritIsInGoogleAuth) {
      InfinitySpiritLoggerService().infinitySpiritLogInfo(
          'Already in Google flow with random UA, skip reapply');
      return;
    }

    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'Switching User-Agent to RANDOM for Google URL: $infinitySpiritTargetUa');

    try {
      await infinitySpiritWebViewController!.setSettings(
        settings: InAppWebViewSettings(userAgent: infinitySpiritTargetUa),
      );
      infinitySpiritCurrentUserAgent = infinitySpiritTargetUa;
      infinitySpiritIsInGoogleAuth = true;
      print('[UA] GOOGLE RANDOM USER AGENT: $infinitySpiritCurrentUserAgent');
    } catch (e) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'Error while setting RANDOM User-Agent for Google URL: $e');
    }
  }

  Future<void> infinitySpiritRestoreUserAgentAfterGoogleIfNeeded() async {
    if (!infinitySpiritIsInGoogleAuth) {
      return;
    }
    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'Restoring normal User-Agent after leaving Google URL');
    infinitySpiritIsInGoogleAuth = false;
    await infinitySpiritApplyNormalUserAgentIfNeeded();
  }

  Future<void> infinitySpiritLoadLoadedFlag() async {
    final SharedPreferences infinitySpiritPrefs =
    await SharedPreferences.getInstance();
    infinitySpiritLoadedOnceSent =
        infinitySpiritPrefs.getBool(infinitySpiritLoadedOnceKey) ?? false;
  }

  Future<void> infinitySpiritSaveLoadedFlag() async {
    final SharedPreferences infinitySpiritPrefs =
    await SharedPreferences.getInstance();
    await infinitySpiritPrefs.setBool(infinitySpiritLoadedOnceKey, true);
    infinitySpiritLoadedOnceSent = true;
  }

  Future<void> infinitySpiritLoadCachedDeep() async {
    try {
      final SharedPreferences infinitySpiritPrefs =
      await SharedPreferences.getInstance();
      final String? infinitySpiritCached =
      infinitySpiritPrefs.getString(infinitySpiritCachedDeepKey);
      if ((infinitySpiritCached ?? '').isNotEmpty) {
        infinitySpiritDeepLinkFromPush = infinitySpiritCached;
      }
    } catch (_) {}
  }

  Future<void> infinitySpiritSaveCachedDeep(String infinitySpiritUri) async {
    try {
      final SharedPreferences infinitySpiritPrefs =
      await SharedPreferences.getInstance();
      await infinitySpiritPrefs.setString(
          infinitySpiritCachedDeepKey, infinitySpiritUri);
    } catch (_) {}
  }

  Future<void> infinitySpiritSendLoadedOnce({
    required String infinitySpiritUrl,
    required int infinitySpiritTimestart,
  }) async {
    if (infinitySpiritLoadedOnceSent) return;

    final int infinitySpiritNow = DateTime.now().millisecondsSinceEpoch;

    await infinitySpiritPostStat(
      infinitySpiritEvent: 'Loaded',
      infinitySpiritTimeStart: infinitySpiritTimestart,
      infinitySpiritTimeFinish: infinitySpiritNow,
      infinitySpiritUrl: infinitySpiritUrl,
      infinitySpiritAppSid:
      infinitySpiritAnalyticsSpyInstance.infinitySpiritAppsFlyerUid,
      infinitySpiritFirstPageLoadTs: infinitySpiritFirstPageTimestamp,
    );

    await infinitySpiritSaveLoadedFlag();
  }

  void infinitySpiritBootHarbor() {
    infinitySpiritStartWarmProgress();
    infinitySpiritWireFcmHandlers();
    infinitySpiritAnalyticsSpyInstance.infinitySpiritStartTracking(
      infinitySpiritOnUpdate: () => setState(() {}),
    );
    infinitySpiritBindNotificationTap();
    infinitySpiritPrepareDeviceProfile();
  }

  // ====================== FCM ========================

  void infinitySpiritWireFcmHandlers() {
    FirebaseMessaging.onMessage
        .listen((RemoteMessage infinitySpiritMessage) async {
      final dynamic infinitySpiritLink = infinitySpiritMessage.data['uri'];
      if (infinitySpiritLink != null) {
        final String infinitySpiritUri = infinitySpiritLink.toString();
        infinitySpiritDeepLinkFromPush = infinitySpiritUri;
        await infinitySpiritSaveCachedDeep(infinitySpiritUri);
      } else {
        infinitySpiritResetHomeAfterDelay();
      }
    });

    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage infinitySpiritMessage) async {
      final dynamic infinitySpiritLink = infinitySpiritMessage.data['uri'];
      if (infinitySpiritLink != null) {
        final String infinitySpiritUri = infinitySpiritLink.toString();
        infinitySpiritDeepLinkFromPush = infinitySpiritUri;
        await infinitySpiritSaveCachedDeep(infinitySpiritUri);

        infinitySpiritNavigateToUri(infinitySpiritUri);

        await infinitySpiritPushDeviceInfo();
        await infinitySpiritPushAppsFlyerData();
      } else {
        infinitySpiritResetHomeAfterDelay();
      }
    });
  }

  // ====================== Tap по пушу с native ============================

  void infinitySpiritBindNotificationTap() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((MethodCall infinitySpiritCall) async {
      if (infinitySpiritCall.method == 'onNotificationTap') {
        final Map<String, dynamic> infinitySpiritPayload =
        Map<String, dynamic>.from(infinitySpiritCall.arguments);
        final String? infinitySpiritUriRaw =
        infinitySpiritPayload['uri']?.toString();

        if (infinitySpiritUriRaw != null &&
            infinitySpiritUriRaw.isNotEmpty &&
            !infinitySpiritUriRaw.contains('Нет URI')) {
          final String infinitySpiritUriValue = infinitySpiritUriRaw;
          infinitySpiritDeepLinkFromPush = infinitySpiritUriValue;
          await infinitySpiritSaveCachedDeep(infinitySpiritUriValue);

          if (!context.mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext context) =>
                  InfinitySpiritTableView(infinitySpiritUriValue),
            ),
                (Route<dynamic> infinitySpiritRoute) => false,
          );

          await infinitySpiritPushDeviceInfo();
          await infinitySpiritPushAppsFlyerData();
        }
      }
    });
  }

  Future<void> infinitySpiritPrepareDeviceProfile() async {
    try {
      await infinitySpiritDeviceProfileInstance.infinitySpiritInitialize();

      final FirebaseMessaging infinitySpiritMessaging =
          FirebaseMessaging.instance;
      final NotificationSettings infinitySpiritSettings =
      await infinitySpiritMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      infinitySpiritDeviceProfileInstance.infinitySpiritPushEnabled =
          infinitySpiritSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
              infinitySpiritSettings.authorizationStatus ==
                  AuthorizationStatus.provisional;

      await infinitySpiritLoadLoadedFlag();
      await infinitySpiritLoadCachedDeep();

      infinitySpiritBosunInstance = InfinitySpiritBosunViewModel(
        infinitySpiritDeviceProfileInstance: infinitySpiritDeviceProfileInstance,
        infinitySpiritAnalyticsSpyInstance: infinitySpiritAnalyticsSpyInstance,
      );

      infinitySpiritCourier = InfinitySpiritCourierService(
        infinitySpiritBosun: infinitySpiritBosunInstance!,
        infinitySpiritGetWebViewController: () => infinitySpiritWebViewController,
      );
    } catch (error) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'infinitySpiritPrepareDeviceProfile fail: $error');
    }
  }

  void infinitySpiritNavigateToUri(String infinitySpiritLink) async {
    try {
      await infinitySpiritWebViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(infinitySpiritLink)),
      );
    } catch (error) {
      InfinitySpiritLoggerService()
          .infinitySpiritLogError('navigate error: $error');
    }
  }

  void infinitySpiritResetHomeAfterDelay() {
    Future<void>.delayed(const Duration(seconds: 3), () {
      try {
        infinitySpiritWebViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(infinitySpiritHomeUrl)),
        );
      } catch (_) {}
    });
  }

  String? infinitySpiritResolveTokenForShip() {
    if (widget.infinitySpiritSignal != null &&
        widget.infinitySpiritSignal!.isNotEmpty) {
      return widget.infinitySpiritSignal;
    }
    return null;
  }

  Future<void> infinitySpiritSendAllDataToPageTwice() async {
    await infinitySpiritPushDeviceInfo();

    Future<void>.delayed(const Duration(seconds: 6), () async {
      await infinitySpiritPushDeviceInfo();
      await infinitySpiritPushAppsFlyerData();
    });
  }

  Future<void> infinitySpiritPushDeviceInfo() async {
    final String? infinitySpiritTokenValue = infinitySpiritResolveTokenForShip();

    try {
      await infinitySpiritCourier?.infinitySpiritPutDeviceToLocalStorage(
          infinitySpiritTokenValue);
    } catch (error) {
      InfinitySpiritLoggerService()
          .infinitySpiritLogError('infinitySpiritPushDeviceInfo error: $error');
    }
  }

  Future<void> infinitySpiritPushAppsFlyerData() async {
    final String? infinitySpiritTokenValue = infinitySpiritResolveTokenForShip();

    try {
      await infinitySpiritCourier?.infinitySpiritSendRawToPage(
        infinitySpiritTokenValue,
        infinitySpiritDeepLink: infinitySpiritDeepLinkFromPush,
      );
    } catch (error) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'infinitySpiritPushAppsFlyerData error: $error');
    }
  }

  void infinitySpiritStartWarmProgress() {
    int infinitySpiritTick = 0;
    infinitySpiritWarmProgress = 0.0;

    infinitySpiritWarmTimer =
        Timer.periodic(const Duration(milliseconds: 100),
                (Timer infinitySpiritTimer) {
              if (!mounted) return;

              setState(() {
                infinitySpiritTick++;
                infinitySpiritWarmProgress =
                    infinitySpiritTick / (infinitySpiritWarmSeconds * 10);

                if (infinitySpiritWarmProgress >= 1.0) {
                  infinitySpiritWarmProgress = 1.0;
                  infinitySpiritWarmTimer.cancel();
                }
              });
            });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState infinitySpiritState) {
    if (infinitySpiritState == AppLifecycleState.paused) {
      infinitySpiritSleepAt = DateTime.now();
    }

    if (infinitySpiritState == AppLifecycleState.resumed) {
      if (Platform.isIOS && infinitySpiritSleepAt != null) {
        final DateTime infinitySpiritNow = DateTime.now();
        final Duration infinitySpiritDrift =
        infinitySpiritNow.difference(infinitySpiritSleepAt!);

        if (infinitySpiritDrift > const Duration(minutes: 25)) {
          infinitySpiritReboardHarbor();
        }
      }
      infinitySpiritSleepAt = null;
    }
  }

  void infinitySpiritReboardHarbor() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback(
            (Duration infinitySpiritDuration) {
          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<Widget>(
              builder: (BuildContext infinitySpiritContext) =>
                  InfinitySpiritHarbor(
                      infinitySpiritSignal: widget.infinitySpiritSignal),
            ),
                (Route<dynamic> infinitySpiritRoute) => false,
          );
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    infinitySpiritWarmTimer.cancel();
    super.dispose();
  }

  // ===================== Email / mailto =====================

  bool infinitySpiritIsBareEmail(Uri infinitySpiritUri) {
    final String infinitySpiritScheme = infinitySpiritUri.scheme;
    if (infinitySpiritScheme.isNotEmpty) return false;
    final String infinitySpiritRaw = infinitySpiritUri.toString();
    return infinitySpiritRaw.contains('@') &&
        !infinitySpiritRaw.contains(' ');
  }

  Uri infinitySpiritToMailto(Uri infinitySpiritUri) {
    final String infinitySpiritFull = infinitySpiritUri.toString();
    final List<String> infinitySpiritParts = infinitySpiritFull.split('?');
    final String infinitySpiritEmail = infinitySpiritParts.first;
    final Map<String, String> infinitySpiritQueryParams =
    infinitySpiritParts.length > 1
        ? Uri.splitQueryString(infinitySpiritParts[1])
        : <String, String>{};

    return Uri(
      scheme: 'mailto',
      path: infinitySpiritEmail,
      queryParameters:
      infinitySpiritQueryParams.isEmpty ? null : infinitySpiritQueryParams,
    );
  }

  Future<bool> infinitySpiritOpenMailExternal(
      Uri infinitySpiritMailto) async {
    try {
      final String infinitySpiritScheme =
      infinitySpiritMailto.scheme.toLowerCase();
      final String infinitySpiritPath =
      infinitySpiritMailto.path.toLowerCase();

      InfinitySpiritLoggerService().infinitySpiritLogInfo(
          'infinitySpiritOpenMailExternal: scheme=$infinitySpiritScheme path=$infinitySpiritPath uri=$infinitySpiritMailto');

      if (infinitySpiritScheme != 'mailto') {
        final bool infinitySpiritOk = await launchUrl(
          infinitySpiritMailto,
          mode: LaunchMode.externalApplication,
        );
        InfinitySpiritLoggerService().infinitySpiritLogInfo(
            'infinitySpiritOpenMailExternal: non-mailto result=$infinitySpiritOk');
        return infinitySpiritOk;
      }

      final bool infinitySpiritCan =
      await canLaunchUrl(infinitySpiritMailto);
      InfinitySpiritLoggerService().infinitySpiritLogInfo(
          'infinitySpiritOpenMailExternal: canLaunchUrl(mailto) = $infinitySpiritCan');

      if (infinitySpiritCan) {
        final bool infinitySpiritOk = await launchUrl(
          infinitySpiritMailto,
          mode: LaunchMode.externalApplication,
        );
        InfinitySpiritLoggerService().infinitySpiritLogInfo(
            'infinitySpiritOpenMailExternal: externalApplication result=$infinitySpiritOk');
        if (infinitySpiritOk) return true;
      }

      InfinitySpiritLoggerService().infinitySpiritLogWarn(
          'infinitySpiritOpenMailExternal: no native handler for mailto, fallback to Gmail Web');
      final Uri infinitySpiritGmailUri =
      infinitySpiritGmailizeMailto(infinitySpiritMailto);
      final bool infinitySpiritWebOk =
      await infinitySpiritOpenWeb(infinitySpiritGmailUri);
      InfinitySpiritLoggerService().infinitySpiritLogInfo(
          'infinitySpiritOpenMailExternal: Gmail Web fallback result=$infinitySpiritWebOk');
      return infinitySpiritWebOk;
    } catch (e, st) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'infinitySpiritOpenMailExternal error: $e\n$st; url=$infinitySpiritMailto');
      return false;
    }
  }

  Future<bool> infinitySpiritOpenMailWeb(Uri infinitySpiritMailto) async {
    final Uri infinitySpiritGmailUri =
    infinitySpiritGmailizeMailto(infinitySpiritMailto);
    return infinitySpiritOpenWeb(infinitySpiritGmailUri);
  }

  Uri infinitySpiritGmailizeMailto(Uri infinitySpiritMailUri) {
    final Map<String, String> infinitySpiritQueryParams =
        infinitySpiritMailUri.queryParameters;

    final Map<String, String> infinitySpiritParams = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (infinitySpiritMailUri.path.isNotEmpty)
        'to': infinitySpiritMailUri.path,
      if ((infinitySpiritQueryParams['subject'] ?? '').isNotEmpty)
        'su': infinitySpiritQueryParams['subject']!,
      if ((infinitySpiritQueryParams['body'] ?? '').isNotEmpty)
        'body': infinitySpiritQueryParams['body']!,
      if ((infinitySpiritQueryParams['cc'] ?? '').isNotEmpty)
        'cc': infinitySpiritQueryParams['cc']!,
      if ((infinitySpiritQueryParams['bcc'] ?? '').isNotEmpty)
        'bcc': infinitySpiritQueryParams['bcc']!,
    };

    return Uri.https('mail.google.com', '/mail/', infinitySpiritParams);
  }

  bool infinitySpiritIsPlatformLink(Uri infinitySpiritUri) {
    final String infinitySpiritScheme = infinitySpiritUri.scheme.toLowerCase();
    if (infinitySpiritSpecialSchemes.contains(infinitySpiritScheme)) {
      return true;
    }

    if (infinitySpiritScheme == 'http' ||
        infinitySpiritScheme == 'https') {
      final String infinitySpiritHost =
      infinitySpiritUri.host.toLowerCase();

      if (infinitySpiritExternalHosts.contains(infinitySpiritHost)) {
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

  String infinitySpiritDigitsOnly(String infinitySpiritSource) =>
      infinitySpiritSource.replaceAll(RegExp(r'[^0-9+]'), '');

  Uri infinitySpiritHttpizePlatformUri(Uri infinitySpiritUri) {
    final String infinitySpiritScheme = infinitySpiritUri.scheme.toLowerCase();

    if (infinitySpiritScheme == 'tg' ||
        infinitySpiritScheme == 'telegram') {
      final Map<String, String> infinitySpiritQp =
          infinitySpiritUri.queryParameters;
      final String? infinitySpiritDomain = infinitySpiritQp['domain'];

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

    if ((infinitySpiritScheme == 'http' ||
        infinitySpiritScheme == 'https') &&
        infinitySpiritUri.host.toLowerCase().endsWith('t.me')) {
      return infinitySpiritUri;
    }

    if (infinitySpiritScheme == 'viber') {
      return infinitySpiritUri;
    }

    if (infinitySpiritScheme == 'whatsapp') {
      final Map<String, String> infinitySpiritQp =
          infinitySpiritUri.queryParameters;
      final String? infinitySpiritPhone = infinitySpiritQp['phone'];
      final String? infinitySpiritText = infinitySpiritQp['text'];

      if (infinitySpiritPhone != null &&
          infinitySpiritPhone.isNotEmpty) {
        return Uri.https(
          'wa.me',
          '/${infinitySpiritDigitsOnly(infinitySpiritPhone)}',
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

    if ((infinitySpiritScheme == 'http' ||
        infinitySpiritScheme == 'https') &&
        (infinitySpiritUri.host
            .toLowerCase()
            .endsWith('wa.me') ||
            infinitySpiritUri.host
                .toLowerCase()
                .endsWith('whatsapp.com'))) {
      return infinitySpiritUri;
    }

    if (infinitySpiritScheme == 'skype') {
      return infinitySpiritUri;
    }

    if (infinitySpiritScheme == 'fb-messenger') {
      final String infinitySpiritPath =
      infinitySpiritUri.pathSegments.isNotEmpty
          ? infinitySpiritUri.pathSegments.join('/')
          : '';
      final Map<String, String> infinitySpiritQp =
          infinitySpiritUri.queryParameters;

      final String infinitySpiritId =
          infinitySpiritQp['id'] ??
              infinitySpiritQp['user'] ??
              infinitySpiritPath;

      if (infinitySpiritId.isNotEmpty) {
        return Uri.https(
          'm.me',
          '/$infinitySpiritId',
          infinitySpiritUri.queryParameters.isEmpty
              ? null
              : infinitySpiritUri.queryParameters,
        );
      }

      return Uri.https(
        'm.me',
        '/',
        infinitySpiritUri.queryParameters.isEmpty
            ? null
            : infinitySpiritUri.queryParameters,
      );
    }

    if (infinitySpiritScheme == 'sgnl') {
      final Map<String, String> infinitySpiritQp =
          infinitySpiritUri.queryParameters;
      final String? infinitySpiritPhone = infinitySpiritQp['phone'];
      final String? infinitySpiritUsername =
      infinitySpiritQp['username'];

      if (infinitySpiritPhone != null &&
          infinitySpiritPhone.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#p/${infinitySpiritDigitsOnly(infinitySpiritPhone)}',
        );
      }

      if (infinitySpiritUsername != null &&
          infinitySpiritUsername.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/#u/$infinitySpiritUsername',
        );
      }

      final String infinitySpiritPath =
      infinitySpiritUri.pathSegments.join('/');
      if (infinitySpiritPath.isNotEmpty) {
        return Uri.https(
          'signal.me',
          '/$infinitySpiritPath',
          infinitySpiritUri.queryParameters.isEmpty
              ? null
              : infinitySpiritUri.queryParameters,
        );
      }

      return infinitySpiritUri;
    }

    if (infinitySpiritScheme == 'tel') {
      return Uri.parse(
          'tel:${infinitySpiritDigitsOnly(infinitySpiritUri.path)}');
    }

    if (infinitySpiritScheme == 'mailto') {
      return infinitySpiritUri;
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

  Future<bool> infinitySpiritOpenWeb(Uri infinitySpiritUri) async {
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
    } catch (error) {
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

  Future<bool> infinitySpiritOpenExternal(Uri infinitySpiritUri) async {
    try {
      return await launchUrl(
        infinitySpiritUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      return false;
    }
  }

  void infinitySpiritHandleServerSavedata(
      String infinitySpiritSavedata) {
    print('onServerResponse savedata: $infinitySpiritSavedata');
  }

  Color infinitySpiritParseHexColor(String infinitySpiritHex) {
    String infinitySpiritValue = infinitySpiritHex.trim();
    if (infinitySpiritValue.startsWith('#')) {
      infinitySpiritValue =
          infinitySpiritValue.substring(1);
    }
    if (infinitySpiritValue.length == 6) {
      infinitySpiritValue = 'FF$infinitySpiritValue';
    }
    final int infinitySpiritIntColor =
        int.tryParse(infinitySpiritValue, radix: 16) ?? 0xFF000000;
    return Color(infinitySpiritIntColor);
  }

  Future<void> infinitySpiritUpdateAppDataInLocalStorageFromProfile() async {
    if (infinitySpiritWebViewController == null) return;

    final String? infinitySpiritTokenValue =
    infinitySpiritResolveTokenForShip();
    final Map<String, dynamic> infinitySpiritMap =
    infinitySpiritDeviceProfileInstance.infinitySpiritToMap(
        infinitySpiritFcmToken: infinitySpiritTokenValue);

    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'updateAppDataFromProfile: ${jsonEncode(infinitySpiritMap)}');

    try {
      await infinitySpiritWebViewController!.evaluateJavascript(
        source:
        "localStorage.setItem('app_data', JSON.stringify(${jsonEncode(infinitySpiritMap)}));",
      );
    } catch (e, st) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'infinitySpiritUpdateAppDataInLocalStorageFromProfile error: $e\n$st');
    }
  }

  void infinitySpiritUpdateExtraDataFromServerPayload(
      Map<dynamic, dynamic> infinitySpiritRoot) {
    try {
      final dynamic infinitySpiritAdDataRaw =
      infinitySpiritRoot['adata'];
      if (infinitySpiritAdDataRaw is Map) {
        final Map infinitySpiritAdData = infinitySpiritAdDataRaw;

        final dynamic infinitySpiritButtonswlRaw =
        infinitySpiritAdData['buttonswl'];
        if (infinitySpiritButtonswlRaw is List) {
          final List<String> infinitySpiritList =
          infinitySpiritButtonswlRaw
              .where((dynamic infinitySpiritE) =>
          infinitySpiritE != null)
              .map((dynamic infinitySpiritE) =>
              infinitySpiritE.toString().trim())
              .where((String infinitySpiritE) =>
          infinitySpiritE.isNotEmpty)
              .toList();
          setState(() {
            infinitySpiritButtonWhitelist = infinitySpiritList;
          });
          InfinitySpiritLoggerService().infinitySpiritLogInfo(
              'buttonswl updated: $infinitySpiritButtonWhitelist');
          infinitySpiritUpdateBackButtonVisibility();
        }

        final dynamic infinitySpiritSavelsRaw =
        infinitySpiritAdData['savels'];
        if (infinitySpiritSavelsRaw is Map) {
          infinitySpiritDeviceProfileInstance.infinitySpiritSavels =
          Map<String, dynamic>.from(infinitySpiritSavelsRaw);
          InfinitySpiritLoggerService().infinitySpiritLogInfo(
              'savels stored in profile: ${infinitySpiritDeviceProfileInstance.infinitySpiritSavels}');
          infinitySpiritUpdateAppDataInLocalStorageFromProfile();
        }
      }
    } catch (e, st) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'Error in infinitySpiritUpdateExtraDataFromServerPayload: $e\n$st');
    }
  }

  void infinitySpiritUpdateSafeAreaFromServerPayload(
      Map<dynamic, dynamic> infinitySpiritRoot) {
    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'SAFEAREA RAW PAYLOAD: ${jsonEncode(infinitySpiritRoot)}');

    bool? infinitySpiritSafearea;
    String? infinitySpiritBgLightHex;
    String? infinitySpiritBgDarkHex;

    final dynamic infinitySpiritContent =
    infinitySpiritRoot['content'];
    if (infinitySpiritContent is Map) {
      if (infinitySpiritContent['safearea'] != null) {
        final dynamic infinitySpiritRaw =
        infinitySpiritContent['safearea'];
        if (infinitySpiritRaw is bool) {
          infinitySpiritSafearea = infinitySpiritRaw;
        } else if (infinitySpiritRaw is String) {
          final String infinitySpiritV =
          infinitySpiritRaw.toLowerCase().trim();
          if (infinitySpiritV == 'true' ||
              infinitySpiritV == '1' ||
              infinitySpiritV == 'yes') {
            infinitySpiritSafearea = true;
          }
          if (infinitySpiritV == 'false' ||
              infinitySpiritV == '0' ||
              infinitySpiritV == 'no') {
            infinitySpiritSafearea = false;
          }
        } else if (infinitySpiritRaw is num) {
          infinitySpiritSafearea = infinitySpiritRaw != 0;
        }
      }

      if (infinitySpiritContent['safearea_color'] != null &&
          infinitySpiritContent['safearea_color']
              .toString()
              .trim()
              .isNotEmpty) {
        infinitySpiritBgLightHex = infinitySpiritContent['safearea_color']
            .toString()
            .trim();
        infinitySpiritBgDarkHex = infinitySpiritBgLightHex;
      }
    }

    final dynamic infinitySpiritAdData =
    infinitySpiritRoot['adata'];
    if (infinitySpiritAdData is Map) {
      if (infinitySpiritSafearea == null &&
          infinitySpiritAdData['safearea'] != null) {
        final dynamic infinitySpiritRaw =
        infinitySpiritAdData['safearea'];
        if (infinitySpiritRaw is bool) {
          infinitySpiritSafearea = infinitySpiritRaw;
        } else if (infinitySpiritRaw is String) {
          final String infinitySpiritV =
          infinitySpiritRaw.toLowerCase().trim();
          if (infinitySpiritV == 'true' ||
              infinitySpiritV == '1' ||
              infinitySpiritV == 'yes') {
            infinitySpiritSafearea = true;
          }
          if (infinitySpiritV == 'false' ||
              infinitySpiritV == '0' ||
              infinitySpiritV == 'no') {
            infinitySpiritSafearea = false;
          }
        } else if (infinitySpiritRaw is num) {
          infinitySpiritSafearea = infinitySpiritRaw != 0;
        }
      }

      if (infinitySpiritAdData['bgsareaw'] != null &&
          infinitySpiritAdData['bgsareaw']
              .toString()
              .trim()
              .isNotEmpty) {
        infinitySpiritBgLightHex = infinitySpiritAdData['bgsareaw']
            .toString()
            .trim();
      }
      if (infinitySpiritAdData['bgsareab'] != null &&
          infinitySpiritAdData['bgsareab']
              .toString()
              .trim()
              .isNotEmpty) {
        infinitySpiritBgDarkHex = infinitySpiritAdData['bgsareab']
            .toString()
            .trim();
      }
    }

    if (infinitySpiritSafearea == null &&
        infinitySpiritRoot['safearea'] != null) {
      final dynamic infinitySpiritRaw =
      infinitySpiritRoot['safearea'];
      if (infinitySpiritRaw is bool) {
        infinitySpiritSafearea = infinitySpiritRaw;
      } else if (infinitySpiritRaw is String) {
        final String infinitySpiritV =
        infinitySpiritRaw.toLowerCase().trim();
        if (infinitySpiritV == 'true' ||
            infinitySpiritV == '1' ||
            infinitySpiritV == 'yes') {
          infinitySpiritSafearea = true;
        }
        if (infinitySpiritV == 'false' ||
            infinitySpiritV == '0' ||
            infinitySpiritV == 'no') {
          infinitySpiritSafearea = false;
        }
      } else if (infinitySpiritRaw is num) {
        infinitySpiritSafearea = infinitySpiritRaw != 0;
      }
    }

    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'SAFEAREA PARSED: enabled=$infinitySpiritSafearea, light=$infinitySpiritBgLightHex, dark=$infinitySpiritBgDarkHex');

    if (infinitySpiritSafearea == null) {
      return;
    }

    final Brightness infinitySpiritPlatformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    String? infinitySpiritChosenHex;
    if (infinitySpiritPlatformBrightness == Brightness.light) {
      infinitySpiritChosenHex =
          infinitySpiritBgLightHex ?? infinitySpiritBgDarkHex;
    } else {
      infinitySpiritChosenHex =
          infinitySpiritBgDarkHex ?? infinitySpiritBgLightHex;
    }

    final bool infinitySpiritEnabled = infinitySpiritSafearea;
    Color infinitySpiritBackground = infinitySpiritEnabled
        ? const Color(0xFF1A1A22)
        : const Color(0xFF000000);

    if (infinitySpiritEnabled &&
        infinitySpiritChosenHex != null &&
        infinitySpiritChosenHex.isNotEmpty) {
      infinitySpiritBackground =
          infinitySpiritParseHexColor(infinitySpiritChosenHex);
    }

    setState(() {
      infinitySpiritSafeAreaEnabled = infinitySpiritEnabled;
      infinitySpiritSafeAreaBackgroundColor =
          infinitySpiritBackground;
      infinitySpiritDeviceProfileInstance
          .infinitySpiritSafeAreaEnabled =
          infinitySpiritEnabled;
      infinitySpiritDeviceProfileInstance
          .infinitySpiritSafeAreaColor =
      infinitySpiritEnabled
          ? (infinitySpiritChosenHex ?? '#1A1A22')
          : '';
    });

    InfinitySpiritLoggerService().infinitySpiritLogInfo(
        'SAFEAREA STATE UPDATED: enabled=$infinitySpiritSafeAreaEnabled, color=$infinitySpiritSafeAreaBackgroundColor (brightness=$infinitySpiritPlatformBrightness)');
  }

  bool infinitySpiritMatchesButtonWhitelist(String infinitySpiritUrl) {
    if (infinitySpiritUrl.isEmpty) return false;
    Uri? infinitySpiritUri;
    try {
      infinitySpiritUri = Uri.parse(infinitySpiritUrl);
    } catch (_) {
      return false;
    }

    final String infinitySpiritHost =
    infinitySpiritUri.host.toLowerCase();
    final String infinitySpiritFull = infinitySpiritUri.toString();

    for (final String infinitySpiritItem
    in infinitySpiritButtonWhitelist) {
      final String infinitySpiritTrimmed =
      infinitySpiritItem.trim();
      if (infinitySpiritTrimmed.isEmpty) continue;

      if (infinitySpiritTrimmed.startsWith('http://') ||
          infinitySpiritTrimmed.startsWith('https://')) {
        if (infinitySpiritFull.startsWith(infinitySpiritTrimmed)) {
          return true;
        }
      } else {
        final String infinitySpiritDomain =
        infinitySpiritTrimmed.toLowerCase();
        if (infinitySpiritHost == infinitySpiritDomain ||
            infinitySpiritHost.endsWith('.$infinitySpiritDomain')) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> infinitySpiritUpdateBackButtonVisibility() async {
    final String infinitySpiritCurrent =
        infinitySpiritCurrentUrlValue ?? infinitySpiritCurrentUrl;
    final bool infinitySpiritShouldShow =
    infinitySpiritMatchesButtonWhitelist(infinitySpiritCurrent);
    if (infinitySpiritShouldShow != infinitySpiritShowBackButton) {
      setState(() {
        infinitySpiritShowBackButton = infinitySpiritShouldShow;
      });
    }
  }

  Future<void> infinitySpiritHandleBackButtonPressed() async {
    if (infinitySpiritWebViewController == null) return;
    try {
      if (await infinitySpiritWebViewController!.canGoBack()) {
        await infinitySpiritWebViewController!.goBack();
      } else {
        await infinitySpiritWebViewController!.loadUrl(
          urlRequest:
          URLRequest(url: WebUri(infinitySpiritHomeUrl)),
        );
      }
    } catch (e, st) {
      InfinitySpiritLoggerService().infinitySpiritLogError(
          'Error on back button pressed: $e\n$st');
    }
  }



  @override
  Widget build(BuildContext context) {
    infinitySpiritBindNotificationTap();

    final Color infinitySpiritBgColor = infinitySpiritSafeAreaEnabled
        ? infinitySpiritSafeAreaBackgroundColor
        : Colors.black;

    final Widget infinitySpiritWebViewStack = Stack(
      children: <Widget>[
        if (infinitySpiritCoverVisible)
          const SizedBox.shrink()
        else
          Container(
            color: infinitySpiritBgColor,
            child: Stack(
              children: <Widget>[
                InAppWebView(
                  key: ValueKey<int>(infinitySpiritWebViewKeyCounter),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    isInspectable: true,
                    disableDefaultErrorPage: true,
                    mediaPlaybackRequiresUserGesture: false,
                    transparentBackground: true,

                    allowsInlineMediaPlayback: true,
                    allowsPictureInPictureMediaPlayback: true,
                    useOnDownloadStart: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    useShouldOverrideUrlLoading: true,
                    supportMultipleWindows: true,

                  ),
                  initialUrlRequest: URLRequest(
                    url: WebUri(infinitySpiritHomeUrl),
                  ),
                  onWebViewCreated:
                      (InAppWebViewController infinitySpiritController) async {
                    infinitySpiritWebViewController =
                        infinitySpiritController;
                    infinitySpiritCurrentUrlValue =
                        infinitySpiritHomeUrl;

                    infinitySpiritBosunInstance ??=
                        InfinitySpiritBosunViewModel(
                          infinitySpiritDeviceProfileInstance:
                          infinitySpiritDeviceProfileInstance,
                          infinitySpiritAnalyticsSpyInstance:
                          infinitySpiritAnalyticsSpyInstance,
                        );

                    infinitySpiritCourier ??=
                        InfinitySpiritCourierService(
                          infinitySpiritBosun: infinitySpiritBosunInstance!,
                          infinitySpiritGetWebViewController: () =>
                          infinitySpiritWebViewController,
                        );

                    try {
                      final dynamic infinitySpiritUa =
                      await infinitySpiritController.evaluateJavascript(
                        source: "navigator.userAgent",
                      );
                      if (infinitySpiritUa is String &&
                          infinitySpiritUa.trim().isNotEmpty) {
                        infinitySpiritBaseUserAgent =
                            infinitySpiritUa.trim();
                        infinitySpiritCurrentUserAgent =
                        infinitySpiritBaseUserAgent!;
                        infinitySpiritDeviceProfileInstance
                            .infinitySpiritBaseUserAgent =
                            infinitySpiritBaseUserAgent;
                        InfinitySpiritLoggerService()
                            .infinitySpiritLogInfo(
                            'Initial WebView User-Agent: $infinitySpiritBaseUserAgent');
                        print(
                            '[UA] INITIAL WEBVIEW USER AGENT: $infinitySpiritBaseUserAgent');
                      }
                    } catch (e) {
                      InfinitySpiritLoggerService().infinitySpiritLogWarn(
                          'Failed to read navigator.userAgent on create: $e');
                    }

                    await infinitySpiritApplyNormalUserAgentIfNeeded();

                    infinitySpiritController.addJavaScriptHandler(
                      handlerName: 'onServerResponse',
                      callback:
                          (List<dynamic> infinitySpiritArgs) async {
                        if (infinitySpiritArgs.isEmpty) return null;

                        print("Get Data server $infinitySpiritArgs");

                        try {
                          dynamic infinitySpiritFirst =
                          infinitySpiritArgs[0];

                          if (infinitySpiritFirst is List &&
                              infinitySpiritFirst.isNotEmpty) {
                            infinitySpiritFirst =
                                infinitySpiritFirst.first;
                          }

                          if (infinitySpiritFirst is Map) {
                            final Map<dynamic, dynamic>
                            infinitySpiritRoot =
                                infinitySpiritFirst;

                            if (infinitySpiritRoot['savedata'] !=
                                null) {
                              infinitySpiritHandleServerSavedata(
                                  infinitySpiritRoot['savedata']
                                      .toString());
                            }

                            infinitySpiritUpdateExtraDataFromServerPayload(
                                infinitySpiritRoot);
                            infinitySpiritUpdateSafeAreaFromServerPayload(
                                infinitySpiritRoot);
                            await infinitySpiritUpdateUserAgentFromServerPayload(
                                infinitySpiritRoot);

                            await infinitySpiritApplyNormalUserAgentIfNeeded();

                            try {
                              if (!infinitySpiritLoadedJsExecutedOnce) {
                                final dynamic infinitySpiritAdDataRaw =
                                infinitySpiritRoot['adata'];
                                if (infinitySpiritAdDataRaw is Map) {
                                  final Map infinitySpiritAdData =
                                      infinitySpiritAdDataRaw;
                                  final dynamic infinitySpiritLoadedJsRaw =
                                  infinitySpiritAdData['loadedjs'];
                                  if (infinitySpiritLoadedJsRaw != null) {
                                    final String infinitySpiritLoadedJs =
                                    infinitySpiritLoadedJsRaw
                                        .toString()
                                        .trim();
                                    if (infinitySpiritLoadedJs
                                        .isNotEmpty) {
                                      infinitySpiritPendingLoadedJs =
                                          infinitySpiritLoadedJs;
                                      InfinitySpiritLoggerService()
                                          .infinitySpiritLogInfo(
                                        'loadedjs received, will execute ONCE after 6 seconds',
                                      );

                                      Future<void>.delayed(
                                        const Duration(seconds: 6),
                                            () async {
                                          if (!mounted) return;
                                          if (infinitySpiritLoadedJsExecutedOnce) {
                                            InfinitySpiritLoggerService()
                                                .infinitySpiritLogInfo(
                                                'Skipping loadedjs: already executed once');
                                            return;
                                          }
                                          if (infinitySpiritWebViewController ==
                                              null) {
                                            InfinitySpiritLoggerService()
                                                .infinitySpiritLogWarn(
                                                'Skipping loadedjs execution: controller is null');
                                            return;
                                          }
                                          final String?
                                          infinitySpiritJsToRun =
                                              infinitySpiritPendingLoadedJs;
                                          if (infinitySpiritJsToRun ==
                                              null ||
                                              infinitySpiritJsToRun
                                                  .isEmpty) {
                                            return;
                                          }
                                          InfinitySpiritLoggerService()
                                              .infinitySpiritLogInfo(
                                              'Executing loadedjs from server payload (ONCE, delayed 6s)');
                                          try {
                                            await infinitySpiritWebViewController
                                                ?.evaluateJavascript(
                                              source:
                                              infinitySpiritJsToRun,
                                            );
                                            infinitySpiritLoadedJsExecutedOnce =
                                            true;
                                          } catch (e, st) {
                                            InfinitySpiritLoggerService()
                                                .infinitySpiritLogError(
                                                'Error executing delayed loadedjs: $e\n$st');
                                          }
                                        },
                                      );
                                    }
                                  }
                                }
                              } else {
                                InfinitySpiritLoggerService()
                                    .infinitySpiritLogInfo(
                                    'loadedjs ignored: already executed once earlier');
                              }
                            } catch (e, st) {
                              InfinitySpiritLoggerService()
                                  .infinitySpiritLogError(
                                  'Error scheduling loadedjs: $e\n$st');
                            }
                          }
                        } catch (e, st) {
                          print('onServerResponse error: $e\n$st');
                        }

                        return null;
                      },
                    );
                  },
                  onPermissionRequest:
                      (InAppWebViewController infinitySpiritController,
                      PermissionRequest infinitySpiritRequest) async {
                    return PermissionResponse(
                      resources: infinitySpiritRequest.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onLoadStart:
                      (InAppWebViewController infinitySpiritController,
                      Uri? infinitySpiritUri) async {
                    setState(() {
                      infinitySpiritStartLoadTimestamp =
                          DateTime.now().millisecondsSinceEpoch;
                    });

                    final Uri? infinitySpiritViewUri =
                        infinitySpiritUri;
                    if (infinitySpiritViewUri != null) {
                      infinitySpiritCurrentUrlValue =
                          infinitySpiritViewUri.toString();

                      if (infinitySpiritIsGoogleUrl(
                          infinitySpiritViewUri)) {
                        await infinitySpiritAddRandomToUserAgentForGoogle();
                      } else {
                        await infinitySpiritRestoreUserAgentAfterGoogleIfNeeded();
                        await infinitySpiritApplyNormalUserAgentIfNeeded();
                      }

                      await infinitySpiritUpdateBackButtonVisibility();

                      if (infinitySpiritIsBareEmail(
                          infinitySpiritViewUri)) {
                        try {
                          await infinitySpiritController.stopLoading();
                        } catch (_) {}
                        final Uri infinitySpiritMailto =
                        infinitySpiritToMailto(
                            infinitySpiritViewUri);
                        await infinitySpiritOpenMailExternal(
                            infinitySpiritMailto);
                        return;
                      }

                      final String infinitySpiritScheme =
                      infinitySpiritViewUri.scheme
                          .toLowerCase();

                      if (infinitySpiritScheme == 'mailto') {
                        try {
                          await infinitySpiritController.stopLoading();
                        } catch (_) {}
                        await infinitySpiritOpenMailExternal(
                            infinitySpiritViewUri);
                        return;
                      }

                      if (infinitySpiritIsBankScheme(
                          infinitySpiritViewUri)) {
                        try {
                          await infinitySpiritController.stopLoading();
                        } catch (_) {}
                        await infinitySpiritOpenBank(
                            infinitySpiritViewUri);
                        return;
                      }

                      if (infinitySpiritScheme != 'http' &&
                          infinitySpiritScheme != 'https') {
                        try {
                          await infinitySpiritController.stopLoading();
                        } catch (_) {}
                      }
                    }
                  },
                  onLoadError:
                      (InAppWebViewController infinitySpiritController,
                      Uri? infinitySpiritUri,
                      int infinitySpiritCode,
                      String infinitySpiritMessage) async {
                    final int infinitySpiritNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String infinitySpiritEvent =
                        'InAppWebViewError(code=$infinitySpiritCode, message=$infinitySpiritMessage)';

                    await infinitySpiritPostStat(
                      infinitySpiritEvent: infinitySpiritEvent,
                      infinitySpiritTimeStart: infinitySpiritNow,
                      infinitySpiritTimeFinish: infinitySpiritNow,
                      infinitySpiritUrl:
                      infinitySpiritUri?.toString() ?? '',
                      infinitySpiritAppSid:
                      infinitySpiritAnalyticsSpyInstance
                          .infinitySpiritAppsFlyerUid,
                      infinitySpiritFirstPageLoadTs:
                      infinitySpiritFirstPageTimestamp,
                    );
                  },
                  onReceivedError:
                      (InAppWebViewController infinitySpiritController,
                      WebResourceRequest infinitySpiritRequest,
                      WebResourceError infinitySpiritError) async {
                    final int infinitySpiritNow =
                        DateTime.now().millisecondsSinceEpoch;
                    final String infinitySpiritDescription =
                    (infinitySpiritError.description ?? '').toString();
                    final String infinitySpiritEvent =
                        'WebResourceError(code=$infinitySpiritError, message=$infinitySpiritDescription)';

                    await infinitySpiritPostStat(
                      infinitySpiritEvent: infinitySpiritEvent,
                      infinitySpiritTimeStart: infinitySpiritNow,
                      infinitySpiritTimeFinish: infinitySpiritNow,
                      infinitySpiritUrl:
                      infinitySpiritRequest.url?.toString() ?? '',
                      infinitySpiritAppSid:
                      infinitySpiritAnalyticsSpyInstance
                          .infinitySpiritAppsFlyerUid,
                      infinitySpiritFirstPageLoadTs:
                      infinitySpiritFirstPageTimestamp,
                    );
                  },
                  onLoadStop:
                      (InAppWebViewController infinitySpiritController,
                      Uri? infinitySpiritUri) async {

                    setState(() {
                      infinitySpiritCurrentUrl =
                          infinitySpiritUri.toString();
                      infinitySpiritCurrentUrlValue =
                          infinitySpiritCurrentUrl;
                    });

                    if (infinitySpiritUri != null &&
                        !infinitySpiritIsGoogleUrl(
                            infinitySpiritUri)) {
                      await infinitySpiritRestoreUserAgentAfterGoogleIfNeeded();
                      await infinitySpiritApplyNormalUserAgentIfNeeded();
                    }

                    await infinitySpiritDebugPrintCurrentUserAgent();

                    await infinitySpiritSendAllDataToPageTwice();
                    await infinitySpiritUpdateBackButtonVisibility();

                    Future<void>.delayed(
                      const Duration(seconds: 20),
                          () {
                        infinitySpiritSendLoadedOnce(
                          infinitySpiritUrl:
                          infinitySpiritCurrentUrl.toString(),
                          infinitySpiritTimestart:
                          infinitySpiritStartLoadTimestamp,
                        );
                      },
                    );
                  },
                  shouldOverrideUrlLoading:
                      (InAppWebViewController infinitySpiritController,
                      NavigationAction infinitySpiritAction) async {
                    final Uri? infinitySpiritUri =
                        infinitySpiritAction.request.url;
                    if (infinitySpiritUri == null) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    infinitySpiritCurrentUrlValue =
                        infinitySpiritUri.toString();
                    await infinitySpiritUpdateBackButtonVisibility();

                    if (infinitySpiritIsGoogleUrl(infinitySpiritUri)) {
                      await infinitySpiritAddRandomToUserAgentForGoogle();
                    } else {
                      await infinitySpiritRestoreUserAgentAfterGoogleIfNeeded();
                      await infinitySpiritApplyNormalUserAgentIfNeeded();
                    }

                    if (infinitySpiritIsBareEmail(
                        infinitySpiritUri)) {
                      final Uri infinitySpiritMailto =
                      infinitySpiritToMailto(
                          infinitySpiritUri);
                      await infinitySpiritOpenMailExternal(
                          infinitySpiritMailto);
                      return NavigationActionPolicy.CANCEL;
                    }

                    final String infinitySpiritScheme =
                    infinitySpiritUri.scheme.toLowerCase();

                    if (infinitySpiritScheme == 'mailto') {
                      await infinitySpiritOpenMailExternal(
                          infinitySpiritUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (infinitySpiritIsBankScheme(
                        infinitySpiritUri)) {
                      await infinitySpiritOpenBank(
                          infinitySpiritUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if ((infinitySpiritScheme == 'http' ||
                        infinitySpiritScheme == 'https') &&
                        infinitySpiritIsBankDomain(
                            infinitySpiritUri)) {
                      await infinitySpiritOpenBank(
                          infinitySpiritUri);

                      if (infinitySpiritIsAdobeRedirect(
                          infinitySpiritUri)) {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute<Widget>(
                              builder: (_) =>
                                  InfinitySpiritAdobeRedirectScreen(
                                      infinitySpiritUri:
                                      infinitySpiritUri),
                            ),
                          );
                        }
                        return NavigationActionPolicy.CANCEL;
                      }
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
                    infinitySpiritUri.host.toLowerCase();
                    final bool infinitySpiritIsSocial =
                        infinitySpiritHost.endsWith('facebook.com') ||
                            infinitySpiritHost.endsWith('instagram.com') ||
                            infinitySpiritHost.endsWith('twitter.com') ||
                            infinitySpiritHost.endsWith('x.com');

                    if (infinitySpiritIsSocial) {
                      await infinitySpiritOpenExternal(
                          infinitySpiritUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (infinitySpiritIsPlatformLink(
                        infinitySpiritUri)) {
                      final Uri infinitySpiritWebUri =
                      infinitySpiritHttpizePlatformUri(
                          infinitySpiritUri);
                      await infinitySpiritOpenExternal(
                          infinitySpiritWebUri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (infinitySpiritScheme != 'http' &&
                        infinitySpiritScheme != 'https') {
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onCreateWindow:
                      (InAppWebViewController infinitySpiritController,
                      CreateWindowAction infinitySpiritRequest) async {
                    final Uri? infinitySpiritUri =
                        infinitySpiritRequest.request.url;
                    if (infinitySpiritUri == null) {
                      return false;
                    }

                    infinitySpiritCurrentUrlValue =
                        infinitySpiritUri.toString();
                    await infinitySpiritUpdateBackButtonVisibility();

                    if (infinitySpiritIsGoogleUrl(infinitySpiritUri)) {
                      await infinitySpiritAddRandomToUserAgentForGoogle();
                    } else {
                      await infinitySpiritRestoreUserAgentAfterGoogleIfNeeded();
                      await infinitySpiritApplyNormalUserAgentIfNeeded();
                    }

                    if (infinitySpiritIsBankScheme(
                        infinitySpiritUri) ||
                        ((infinitySpiritUri.scheme == 'http' ||
                            infinitySpiritUri.scheme == 'https') &&
                            infinitySpiritIsBankDomain(
                                infinitySpiritUri))) {
                      await infinitySpiritOpenBank(
                          infinitySpiritUri);
                      return false;
                    }

                    if (infinitySpiritIsBareEmail(
                        infinitySpiritUri)) {
                      final Uri infinitySpiritMailto =
                      infinitySpiritToMailto(
                          infinitySpiritUri);
                      await infinitySpiritOpenMailExternal(
                          infinitySpiritMailto);
                      return false;
                    }

                    final String infinitySpiritScheme =
                    infinitySpiritUri.scheme.toLowerCase();

                    if (infinitySpiritScheme == 'mailto') {
                      await infinitySpiritOpenMailExternal(
                          infinitySpiritUri);
                      return false;
                    }

                    if (infinitySpiritScheme == 'tel') {
                      await launchUrl(
                        infinitySpiritUri,
                        mode: LaunchMode.externalApplication,
                      );
                      return false;
                    }

                    final String infinitySpiritHost =
                    infinitySpiritUri.host.toLowerCase();
                    final bool infinitySpiritIsSocial =
                        infinitySpiritHost.endsWith('facebook.com') ||
                            infinitySpiritHost.endsWith('instagram.com') ||
                            infinitySpiritHost.endsWith('twitter.com') ||
                            infinitySpiritHost.endsWith('x.com');

                    if (infinitySpiritIsSocial) {
                      await infinitySpiritOpenExternal(
                          infinitySpiritUri);
                      return false;
                    }

                    if (infinitySpiritIsPlatformLink(
                        infinitySpiritUri)) {
                      final Uri infinitySpiritWebUri =
                      infinitySpiritHttpizePlatformUri(
                          infinitySpiritUri);
                      await infinitySpiritOpenExternal(
                          infinitySpiritWebUri);
                      return false;
                    }

                    if (infinitySpiritScheme == 'http' ||
                        infinitySpiritScheme == 'https') {
                      infinitySpiritController.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(
                              infinitySpiritUri.toString()),
                        ),
                      );
                    }

                    return false;
                  },
                  onDownloadStartRequest:
                      (InAppWebViewController infinitySpiritController,
                      DownloadStartRequest infinitySpiritReq) async {
                    await infinitySpiritOpenExternal(
                        infinitySpiritReq.url);
                  },
                ),

                // ЛОАДЕР поверх WebView по центру, скрывается через 8 секунд
                // ФУllscreen-лоадер
                if (infinitySpiritLoaderVisible)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: InfinitySpiritCenterLoaderScreen2(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    final Widget infinitySpiritTopBackBar =
    (infinitySpiritSafeAreaEnabled && infinitySpiritShowBackButton)
        ? Container(
      color: infinitySpiritSafeAreaBackgroundColor,
      padding:
      const EdgeInsets.only(left: 4, right: 4),
      height: 48,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Colors.white),
            onPressed:
            infinitySpiritHandleBackButtonPressed,
          ),
        ],
      ),
    )
        : const SizedBox.shrink();

    final Widget infinitySpiritFullScreen = Column(
      children: <Widget>[
        infinitySpiritTopBackBar,
        Expanded(child: infinitySpiritWebViewStack),
      ],
    );

    final Widget infinitySpiritBody = infinitySpiritSafeAreaEnabled
        ? SafeArea(

      child: infinitySpiritFullScreen,
    )
        : infinitySpiritFullScreen;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: infinitySpiritBgColor,
        body: SizedBox.expand(
          child: ColoredBox(
            color: infinitySpiritBgColor,
            child: infinitySpiritBody,
          ),
        ),
      ),
    );
  }

  bool infinitySpiritIsAdobeRedirect(Uri infinitySpiritUri) {
    final String infinitySpiritHost =
    infinitySpiritUri.host.toLowerCase();
    return infinitySpiritHost == 'c00.adobe.com';
  }
}

// ---------------------- Экран для c00.adobe.com ----------------------

class InfinitySpiritAdobeRedirectScreen extends StatelessWidget {
  final Uri infinitySpiritUri;

  const InfinitySpiritAdobeRedirectScreen(
      {super.key, required this.infinitySpiritUri});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF111111),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                "Go to the App Store and download the app.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// main()
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(
      infinitySpiritFcmBackgroundHandler);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(
        true);
  }

  tz_data.initializeTimeZones();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: InfinitySpiritHall(),
    ),
  );
}