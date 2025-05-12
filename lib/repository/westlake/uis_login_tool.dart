// ignore_for_file: deprecated_member_use

/*
 *     Copyright (C) 2021  DanXi-Dev
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import \'package:beautiful_soup_dart/beautiful_soup.dart\';
import \'package:dan_xi/model/person.dart\';
import \'package:dan_xi/provider/settings_provider.dart\';
// TODO: Westlake University - Review if ForumRepository import is still needed or if it was Fudan-specific.
import \'package:dan_xi/repository/forum/forum_repository.dart\'; 
import \'package:dan_xi/repository/cookie/independent_cookie_jar.dart\';
import \'package:dan_xi/util/io/dio_utils.dart\';
import \'package:dan_xi/util/io/queued_interceptor.dart\';
import \'package:dan_xi/util/io/user_agent_interceptor.dart\';
import \'package:dan_xi/util/public_extension_methods.dart\';
import \'package:dan_xi/util/retrier.dart\';
import \'package:dio/dio.dart\';
import \'package:dio5_log/dio_log.dart\';
import \'package:dio_cookie_manager/dio_cookie_manager.dart\';
import \'package:flutter/painting.dart\'; // TODO: Westlake University - Review if painting import is necessary here.
import \'package:mutex/mutex.dart\';

class UISLoginTool {
  // TODO: Westlake University - Replace these error patterns with those from Westlake University's UIS.
  static const String CAPTCHA_CODE_NEEDED = "请输入验证码"; // Example: Westlake might use "Verification code required"
  static const String CREDENTIALS_INVALID = "密码有误";    // Example: Westlake might use "Incorrect username or password"
  static const String WEAK_PASSWORD = "弱密码提示";       // Example: Westlake might have different weak password handling or no such specific message.
  static const String UNDER_MAINTENANCE = "网络维护中 | Under Maintenance"; // Example: Westlake might use "System undergoing maintenance"

  /// RWLocks to prevent multiple login requests happening at the same time.
  static final Map<IndependentCookieJar, ReadWriteMutex> _lockMap = {};

  /// Track the epoch of the last login to prevent multiple sequential login requests.
  /// The epoch should be updated after each change of the cookie jar.
  static final Map<IndependentCookieJar, Accumulator> _epochMap = {};

  /// The main function to request a service behind the UIS login system.
  static Future<E> tryAsyncWithAuth<E>(Dio dio, String serviceUrl, // serviceUrl will now be a Westlake service URL
      IndependentCookieJar jar, PersonInfo? info, Future<E> Function() function,
      {int retryTimes = 1, bool Function(dynamic error)? isFatalError}) {
    ReadWriteMutex lock = _lockMap.putIfAbsent(jar, () => ReadWriteMutex());
    Accumulator epoch = _epochMap.putIfAbsent(jar, () => Accumulator());
    int? currentEpoch;
    final serviceUri = Uri.tryParse(serviceUrl)!;
    return Retrier.tryAsyncWithFix(
      () {
        return lock.protectRead(() async {
          currentEpoch = epoch.value;
          // TODO: Westlake University - Cookie check logic might need adjustment based on Westlake UIS cookie behavior.
          if ((await jar.loadForRequest(serviceUri)).isEmpty) {
            throw NotLoginError("Cannot find cookies for $serviceUrl");
          }
          return await function();
        });
      },
      (_) async {
        await lock.protectWrite(() async {
          if (currentEpoch != epoch.value) {
            return null;
          }
          // TODO: Westlake University - Ensure _loginUIS is adapted for Westlake's UIS before this call.
          await _loginUIS(dio, serviceUrl, jar, info);
          epoch.increment(1);
        });
      },
      retryTimes: retryTimes,
      isFatalError: isFatalError,
    );
  }

  /// Log in Westlake UIS system and return the response.
  static Future<Response<dynamic>?> loginUIS(Dio dio, String serviceUrl, // serviceUrl will now be a Westlake service URL
      IndependentCookieJar jar, PersonInfo? info) async {
    ReadWriteMutex lock = _lockMap.putIfAbsent(jar, () => ReadWriteMutex());
    Accumulator epoch = _epochMap.putIfAbsent(jar, () => Accumulator());
    return await lock.protectWrite(() async {
      // TODO: Westlake University - Ensure _loginUIS is adapted for Westlake's UIS before this call.
      final result = await _loginUIS(dio, serviceUrl, jar, info);
      epoch.increment(1);
      return result;
    });
  }

  // TODO: Westlake University - This entire _loginUIS method is Fudan-specific and needs a complete rewrite for Westlake's UIS.
  static Future<Response<dynamic>?> _loginUIS(Dio dio, String serviceUrl, // serviceUrl will now be a Westlake service URL
      IndependentCookieJar jar, PersonInfo? info) async {
    Dio workDio = DioUtils.newDioWithProxy();
    workDio.options = BaseOptions(
        receiveDataWhenStatusError: true,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5));
    IndependentCookieJar workJar = IndependentCookieJar.createFrom(jar);
    workDio.interceptors.add(LimitedQueuedInterceptor.getInstance());
    workDio.interceptors.add(UserAgentInterceptor(
        userAgent: SettingsProvider.getInstance().customUserAgent));
    workDio.interceptors.add(CookieManager(workJar));
    workDio.interceptors.add(DioLogInterceptor());

    // TODO: Westlake University - The 'CASTGC' cookie workaround is Fudan-specific. Remove or adapt for Westlake's UIS.
    // fixme: workaround by deleting `CASTGC` cookie before requesting the UIS page
    // See https://github.com/DanXi-Dev/DanXi/issues/491 for details.
    workJar.deleteCookiesByName("CASTGC"); 
    Map<String?, String?> data = {};
    // TODO: Westlake University - Scraping <input> fields from the login page is Fudan-specific. Westlake's UIS might have a different login mechanism (e.g., JSON API, different form fields).
    Response<String> res = await workDio.get(serviceUrl);
    BeautifulSoup(res.data!).findAll("input").forEach((element) {
      if (element.attributes[\'type\'] != "button") {
        data[element.attributes[\'name\']] = element.attributes[\'value\'];
      }
    });
    // TODO: Westlake University - Verify username/password field names for Westlake's UIS.
    data[\'username\'] = info!.id;
    data["password"] = info.password;
    res = await workDio.post(serviceUrl,
        data: data.encodeMap(),
        options: DioUtils.NON_REDIRECT_OPTION_WITH_FORM_TYPE);
    final Response<dynamic> response =
        await DioUtils.processRedirect(workDio, res);
    
    // TODO: Westlake University - All error string matching below is Fudan-specific. Replace with Westlake's UIS error handling.
    if (response.data.toString().contains(CREDENTIALS_INVALID)) {
      CredentialsInvalidException().fire();
      throw CredentialsInvalidException();
    } else if (response.data.toString().contains(CAPTCHA_CODE_NEEDED)) {
      CaptchaNeededException().fire();
      throw CaptchaNeededException();
    } else if (response.data.toString().contains(UNDER_MAINTENANCE)) {
      throw NetworkMaintenanceException();
    } else if (response.data.toString().contains(WEAK_PASSWORD)) {
      throw GeneralLoginFailedException();
    }

    jar.cloneFrom(workJar);
    return response;
  }
}

// TODO: Westlake University - Review if these specific exceptions are still applicable or need renaming/modification for Westlake's UIS error types.
class CaptchaNeededException implements Exception {}

class CredentialsInvalidException implements Exception {}

class NetworkMaintenanceException implements Exception {}

class GeneralLoginFailedException implements Exception {}

// TODO: Westlake University - Review if NotLoginError is still needed or if standard errors cover this.
class NotLoginError implements Exception {
  final String message;
  NotLoginError(this.message);
  @override
  String toString() => "NotLoginError: $message";
}

// TODO: Westlake University - Review if Accumulator helper class is still the best approach for managing login epochs.
class Accumulator {
  int value = 0;
  void increment(int by) => value += by;
} 