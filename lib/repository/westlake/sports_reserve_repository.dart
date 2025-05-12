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
import \'package:dan_xi/common/constant.dart\'; // TODO: Westlake University - Review constants, especially Campus related
import \'package:dan_xi/model/person.dart\';
import \'package:dan_xi/repository/base_repository.dart\';
// TODO: Westlake University - Ensure this import points to the correct Westlake version after migration
import \'package:dan_xi/repository/westlake/uis_login_tool.dart\';
import \'package:dan_xi/util/public_extension_methods.dart\';
import \'package:dio/dio.dart\';
import \'package:html/dom.dart\' as dom;
import \'package:intl/intl.dart\';
import \'package:provider/provider.dart\'; // TODO: Westlake University - Review if Provider is used and how

class SportsReserveRepository extends BaseRepositoryWithDio {
  static const String LOGIN_URL =
      "https://uis.westlake.edu.cn/authserver/login?service=https%3A%2F%2Felife.westlake.edu.cn%2Flogin2.action"; // TODO: Westlake University - 请确认此URL和API端点 (uis & elife domains, and service path)
  static const String STADIUM_LIST_URL =
      "https://elife.westlake.edu.cn/public/front/search.htm??id=2c9c486e4f821a19014f82381feb0001"; // TODO: Westlake University - 请确认此URL和API端点, ID参数可能特定于复旦
  static const String STADIUM_LIST_NUMBER_URL =
      "https://elife.westlake.edu.cn/public/front/search.htm?1=1&id=2c9c486e4f821a19014f82381feb0001&orderBack=null&fieldID=&dicID=&dicSql=&pageBean.pageNo=1&pageBean.pageSize=10"; // TODO: Westlake University - 请确认此URL和API端点, ID及其他参数可能特定于复旦

  static sStadiumDetailUrl(String? contentId, DateTime queryDate) =>
      "https://elife.westlake.edu.cn/public/front/getResource2.htm?contentId=$contentId&ordersId=&"
      "currentDate=${DateFormat(\'yyyy-MM-dd\').format(queryDate)}"; // TODO: Westlake University - 请确认此URL和API端点, contentId参数格式及路径

  SportsReserveRepository._();

  static final _instance = SportsReserveRepository._();

  factory SportsReserveRepository.getInstance() => _instance;

  Future<List<StadiumData>?> getStadiumFullList(PersonInfo info,
          {DateTime? queryDate, SportsType? type, Campus? campus}) =>
      UISLoginTool.tryAsyncWithAuth(
          dio,
          LOGIN_URL,
          cookieJar!,
          info,
          () => _getStadiumFullList(
              queryDate: queryDate, type: type, campus: campus));

  Future<int> _getStadiumPageNumber() async { // TODO: Westlake University - This logic is highly dependent on Fudan's HTML structure. Needs complete review/rewrite.
    Response<String> rep = await dio.get(STADIUM_LIST_NUMBER_URL);
    String pageNumber = rep.data!.between(\'页次:1/\', \'页\')!; // This parsing is Fudan-specific
    return int.parse(pageNumber);
  }

  Future<List<StadiumData>?> _getStadiumFullList(
      {DateTime? queryDate, SportsType? type, Campus? campus}) async { // TODO: Westlake University - This logic is highly dependent on Fudan's HTML structure. Needs complete review/rewrite.
    var result = <StadiumData>[];
    int pages = await _getStadiumPageNumber();
    for (int i = 1; i <= pages; i++) {
      result.addAll((await _getStadiumList(
          queryDate: queryDate, type: type, campus: campus, page: i))!);
    }
    return result;
  }

  Future<List<StadiumData>?> _getStadiumList(
      {DateTime? queryDate,
      SportsType? type,
      Campus? campus, // TODO: Westlake University - Review Campus enum and its usage
      int page = 1}) async { // TODO: Westlake University - This logic is highly dependent on Fudan's HTML structure and POST body. Needs complete review/rewrite.
    String body = "id=2c9c486e4f821a19014f82381feb0001&" // This ID is likely Fudan-specific
        "resourceDate=${queryDate == null ? \'\' : DateFormat(\'yyyy-MM-dd\').format(queryDate)}&"
        "beginTime=&"
        "endTime=&"
        "fieldID=2c9c486e4f821a19014f824467b70006&" // This fieldID is likely Fudan-specific
        "dicID=&"
        "fieldID=2c9c486e4f821a19014f824535480007&" // This fieldID is likely Fudan-specific
        "dicID=${type?.id ?? \'\'}&" // SportsType.id is Fudan-specific
        "pageBean.pageNo=$page";
    Response<String> res = await dio.post(STADIUM_LIST_URL,
        data: body,
        options: Options(contentType: \'application/x-www-form-urlencoded\'));
    BeautifulSoup soup = BeautifulSoup(res.data!);
    Iterable<dom.Element> elements =
        soup.findAll(\'.order_list > table\').map((e) => e.element!); // CSS selector is Fudan-specific

    return elements.map((e) => StadiumData.fromHtml(e)).toList();
  }

  Future<StadiumScheduleData?> getScheduleData(
          PersonInfo info, StadiumData stadium, DateTime date) =>
      UISLoginTool.tryAsyncWithAuth(dio, LOGIN_URL, cookieJar!, info,
          () => _getScheduleData(stadium, date));

  Future<StadiumScheduleData?> _getScheduleData(
      StadiumData stadium, DateTime date) async { // TODO: Westlake University - This logic is highly dependent on Fudan's HTML structure. Needs complete review/rewrite.
    Response<String> res =
        await dio.get(sStadiumDetailUrl(stadium.contentId, date)); // contentId format and validity needs check for Westlake
    BeautifulSoup soup = BeautifulSoup(res.data!);
    List<Bs4Element> listOfSchedule = soup
        .findAll("table", class_: "site_table") // CSS selector is Fudan-specific
        .first
        .findAll("", selector: "tbody>tr"); // CSS selector is Fudan-specific
    return StadiumScheduleData.fromHtmlPart(
        stadium, date, listOfSchedule.map((e) => e.element!).toList());
  }

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名
}

class StadiumData {
  final String? name;
  final Campus? area; // TODO: Westlake University - Review Campus enum and its mapping
  final SportsType? type; // TODO: Westlake University - Review SportsType enum and its mapping
  final String? info;
  final String? contentId; // TODO: Westlake University - Review contentId source and format

  StadiumData(this.name, this.area, this.type, this.info, this.contentId);

  @override
  String toString() {
    return \'StadiumData{name: $name, area: $area, type: $type, info: $info, contentId: $contentId}\';
  }

  // TODO: Westlake University - This fromHtml is entirely Fudan-specific and needs a complete rewrite for Westlake's sports reservation system.
  factory StadiumData.fromHtml(dom.Element element) {
    var tableItems = element
        .querySelector(\'td[valign=top]:not([align])\')!
        .querySelectorAll(\'tr\');
    String? name, info, contentId;
    Campus? campus;
    SportsType? type;
    for (var element in tableItems) {
      var key = element.querySelector(\'th\')?.text.trim();
      var valueElement = element.querySelector(\'td\');
      switch (key) { // These case strings are Fudan-specific
        case \'服务项目：\':
          name = valueElement!.querySelector(\'a\')!.text.trim();
          contentId = valueElement
              .querySelector(\'a\')!
              .attributes[\'href\']!
              .between(\'contentId=\', \'&\');
          break;
        case \'开放说明：\':
          info = valueElement!.text.trim();
          break;
        case \'校区：\': // TODO: Westlake University - Adapt Campus parsing logic
          campus = CampusEx.fromChineseName(valueElement!.text.trim());
          break;
        case \'运动项目：\': // TODO: Westlake University - Adapt SportsType parsing logic
          type = SportsType.fromLiterateName(valueElement!.text.trim());
      }
    }
    return StadiumData(name, campus, type, info, contentId);
  }
}

class StadiumScheduleData {
  final StadiumData stadium;
  final DateTime date;

  /// Schedule and reservation details.
  final List<StadiumScheduleItem> schedule;

  StadiumScheduleData(this.stadium, this.schedule, this.date);

  @override
  String toString() {
    return \'StadiumScheduleData{stadium: $stadium, date: $date, schedule: $schedule}\';
  }

  // TODO: Westlake University - This fromHtmlPart is entirely Fudan-specific and needs a complete rewrite for Westlake's sports reservation system.
  factory StadiumScheduleData.fromHtmlPart(
          StadiumData stadium, DateTime date, List<dom.Element> elements) =>
      StadiumScheduleData(
          stadium,
          elements.map((e) {
            var timeElement = e.getElementsByClassName(\'site_td1\').first; // CSS class is Fudan-specific
            var timeMatches =
                RegExp(r\'\\d{2}:\\d{2}\').allMatches(timeElement.text);
            var reverseElement = e.getElementsByClassName(\'site_td4\').first; // CSS class is Fudan-specific
            var reverseNums = reverseElement.text.trim().split("/");
            return StadiumScheduleItem(
                timeMatches.first.group(0)!,
                timeMatches.last.group(0)!,
                int.parse(reverseNums[0]),
                int.parse(reverseNums[1]));
          }).toList(),
          date);
}

class StadiumScheduleItem {
  final String startTime, endTime;
  final int reserved, total;

  @override
  String toString() {
    return \'StadiumScheduleItem{startTime: $startTime, endTime: $endTime, reserved: $reserved, total: $total}\';
  }

  StadiumScheduleItem(this.startTime, this.endTime, this.reserved, this.total);
}

// ignore_for_file: non_constant_identifier_names
// TODO: Westlake University - Review all SportsType IDs and names. These are Fudan-specific.
class SportsType {
  final String id;
  final Create<String?> name;
  static final SportsType BADMINTON =
      SportsType._(\'2c9c486e4f821a19014f824823c5000c\', (context) => null);
  static final SportsType TENNIS =
      SportsType._(\'2c9c486e4f821a19014f824823c5000d\', (context) => null);
  static final SportsType SOCCER =
      SportsType._(\'2c9c486e4f821a19014f824823c5000e\', (context) => null);
  static final SportsType BASKETBALL =
      SportsType._(\'2c9c486e4f821a19014f824823c5000f\', (context) => null);
  static final SportsType VOLLEYBALL =
      SportsType._(\'2c9c486e4f821a19014f824823c50010\', (context) => null);
  static final SportsType BALLROOM =
      SportsType._(\'2c9c486e4f821a19014f824823c50011\', (context) => null);
  static final SportsType GYM =
      SportsType._(\'8aecc6ce66851ffa0166d77ef48a60e6\', (context) => null);
  static final SportsType BATHROOM = // This seems unusual for a sports type, might be Fudan specific data artifact
      SportsType._(\'8aecc6ce7176eb1801719b4ab80c4d73\', (context) => null);
  static final SportsType PLAYGROUND =
      SportsType._(\'8aecc6ce7176eb18017207d74e1a4ef5\', (context) => null);

  static SportsType? fromLiterateName(String name) { // TODO: Westlake University - Update these Chinese names and corresponding enum values
    switch (name) {
      case \'羽毛球\':
        return SportsType.BADMINTON;
      case \'网球\':
        return SportsType.TENNIS;
      case \'足球\':
        return SportsType.SOCCER;
      case \'篮球\':
        return SportsType.BASKETBALL;
      case \'排球\':
        return SportsType.VOLLEYBALL;
      case \'舞蹈房\':
        return SportsType.BALLROOM;
      case \'体能房\':
        return SportsType.GYM;
      case \'浴室\': // This seems unusual for a sports type
        return SportsType.BATHROOM;
      case \'田径场\':
        return SportsType.PLAYGROUND;
    }
    return null;
  }

  SportsType._(this.id, this.name);
} 