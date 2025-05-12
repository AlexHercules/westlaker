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
import \'package:dio/dio.dart\';
import \'package:html/dom.dart\';

class WestlakeAAORepository extends BaseRepositoryWithDio {
  static const String _LOGIN_URL =
      "https://uis.westlake.edu.cn/authserver/login?service=http%3A%2F%2Faao.westlake.edu.cn%2Fyour%2Fnotice%2Fpath%2Fpage.psp"; // TODO: Westlake University - 请确认此URL (uis & aao/jwc domains), 特别是 service URL (原为 jwc.fudan.edu.cn/eb/b7/c9397a388023/page.psp)

  WestlakeAAORepository._();

  // TODO: Westlake University - \'type\' parameter (e.g., "9397") is Fudan-specific. Needs complete review for Westlake AAO categories.
  static String _listUrl(String type, int page) {
    return "https://aao.westlake.edu.cn/$type/list${page <= 1 ? "" : page.toString()}.htm"; // TODO: Westlake University - 请确认此URL结构 (aao/jwc domain) 和通知分类 \'type\' 参数
  }

  static const String _BASE_URL = "https://aao.westlake.edu.cn"; // TODO: Westlake University - 请确认教务处基础URL (原为 jwc.fudan.edu.cn)
  // TODO: Westlake University - This announcement type ID ("9397") is Fudan-specific. Needs replacement with Westlake's equivalent.
  static const String TYPE_NOTICE_ANNOUNCEMENT = "westlake_notice_type"; // Placeholder for Westlake's notice type
  static final _instance = WestlakeAAORepository._();

  factory WestlakeAAORepository.getInstance() => _instance;

  Future<List<Notice>?> getNotices(String type, int page, PersonInfo? info) =>
      UISLoginTool.tryAsyncWithAuth(
          dio, _LOGIN_URL, cookieJar!, info, () => _getNotices(type, page));

  Future<List<Notice>?> _getNotices(String type, int page) async { // TODO: Westlake University - This entire method including HTML parsing needs complete review/rewrite for Westlake AAO website structure.
    List<Notice> notices = [];
    Response<String> response = await dio.get(_listUrl(type, page)); 
    // TODO: Westlake University - Verify if "Under Maintenance" check is relevant or how to check for errors for Westlake AAO.
    if (response.data?.contains("Under Maintenance") ?? false) {
      throw NotConnectedToLANError(); // TODO: Westlake University - Evaluate if this specific error is appropriate.
    }
    BeautifulSoup soup = BeautifulSoup(response.data.toString());
    // TODO: Westlake University - The CSS selector ".wp_article_list_table" is Fudan-specific (from their CMS likely). This will need to be changed for Westlake.
    Iterable<Element> noticeNodes = soup
        .findAll(".wp_article_list_table > tbody > tr > td > table > tbody") 
        .map((e) => e.element!);
    for (Element noticeNode in noticeNodes) {
      // TODO: Westlake University - The following querySelectors are Fudan-specific and need complete review.
      List<Element> noticeInfo =
          noticeNode.querySelector("tr")!.querySelectorAll("td");
      notices.add(Notice(
          noticeInfo[0].text.trim(),
          _BASE_URL + noticeInfo[0].querySelector("a")!.attributes["href"]!, // URL construction depends on Westlake's site structure
          noticeInfo[1].text.trim()));
    }
    return notices;
  }

  Future<bool> checkConnection(PersonInfo? info) => // TODO: Westlake University - Purpose of this check might need review based on Westlake's system reliability.
      getNotices(TYPE_NOTICE_ANNOUNCEMENT, 1, info)
          .then((value) => true, onError: (e) => false);

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名 (was fudan.edu.cn, but AAO might be aao.westlake.edu.cn)
}

// TODO: Westlake University - Evaluate if this error type is still relevant or if a more generic/specific error is needed for Westlake.
class NotConnectedToLANError implements Exception {}

class Notice {
  String title;
  String url;
  String time;

  Notice(this.title, this.url, this.time);
} 