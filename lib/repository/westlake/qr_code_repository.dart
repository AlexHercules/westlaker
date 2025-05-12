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
import \'package:dan_xi/repository/base_repository.dart\';
// TODO: Westlake University - Ensure this import points to the correct Westlake version after migration
import \'package:dan_xi/repository/westlake/uis_login_tool.dart\';

// TODO: Westlake University - Evaluate if this specific exception is needed or how terms agreement is handled for Westlake's QR code system.
class TermsNotAgreed implements Exception {}

class QRCodeRepository extends BaseRepositoryWithDio {
  // TODO: Westlake University - This LOGIN_URL is extremely Fudan-specific (uis, workflow1, ecard domains, cas-login, app_id, fudan/zfm/qrcode paths). Needs complete replacement with Westlake's equivalent QR code authentication flow.
  static const String LOGIN_URL =
      "https://uis.westlake.edu.cn/authserver/login?service=https%3A%2F%2Fworkflow.westlake.edu.cn%2Fsite%2Flogin%2Fcas-login%3Fredirect_url%3Dhttps%253A%252F%252Fworkflow.westlake.edu.cn%252Fopen%252Fconnection%252Findex%253Fapp_id%253Dwestlake_app_id%2526state%253D%2526redirect_url%253Dhttps%253A%252F%252Fecard.westlake.edu.cn%252Fepay%252Fwxpage%252Fwestlake%252Fzfm%252Fqrcode%253Furl%253D0"; // Placeholder domains and paths
  // TODO: Westlake University - This QR_URL is Fudan-specific (ecard domain, fudan/zfm/qrcode path). Needs complete replacement.
  static const String QR_URL =
      "https://ecard.westlake.edu.cn/epay/wxpage/westlake/zfm/qrcode"; // Placeholder domain and path

  QRCodeRepository._();

  static final _instance = QRCodeRepository._();

  factory QRCodeRepository.getInstance() => _instance;

  Future<String?> getQRCode(PersonInfo? info) => UISLoginTool.tryAsyncWithAuth(
      dio, LOGIN_URL, cookieJar!, info, () => _getQRCode());

  // TODO: Westlake University - This entire method is Fudan-specific (HTML parsing for #myText and #btn-agree-ok). Needs complete rewrite for Westlake's QR code system.
  Future<String?> _getQRCode() async {
    final res = await dio.get(QR_URL);
    BeautifulSoup soup = BeautifulSoup(res.data.toString());
    try {
      // The element ID "#myText" and attribute 'value' for QR code data are Fudan-specific.
      return soup.find("#myText")!.attributes[\'value\']; 
    } catch (_) {
      // The element ID "#btn-agree-ok" for checking terms agreement is Fudan-specific.
      if (soup.find("#btn-agree-ok") != null) {
        throw TermsNotAgreed();
      } else {
        rethrow;
      }
    }
  }

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名 (was fudan.edu.cn, but QR might involve ecard.westlake.edu.cn or workflow.westlake.edu.cn)
} 