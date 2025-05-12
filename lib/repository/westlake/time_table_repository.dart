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

import \'dart:convert\';

import \'package:dan_xi/common/constant.dart\';
import \'package:dan_xi/model/person.dart\';
import \'package:dan_xi/model/time_table.dart\'; // TODO: Westlake University - TimeTable.fromHtml and related parsing logic will need complete rewrite.
import \'package:dan_xi/provider/settings_provider.dart\'; // TODO: Westlake University - Review SettingsProvider for Fudan-specific settings (e.g., semester, start date)
// TODO: Westlake University - Ensure this import points to the correct Westlake version after migration
import \'package:dan_xi/repository/westlake/uis_login_tool.dart\';
import \'package:dan_xi/util/io/cache.dart\';
import \'package:dan_xi/util/io/dio_utils.dart\';
import \'package:dio/dio.dart\';
import \'package:html/dom.dart\' as dom;

class TimeTableRepository extends BaseRepositoryWithDio {
  // TODO: Westlake University - All URLs below are Fudan-specific (uis & jwfw domains and all paths like /eams/, login.action, etc.). Need complete replacement.
  static const String LOGIN_URL =
      \'https://uis.westlake.edu.cn/authserver/login?service=http%3A%2F%2Fjw.westlake.edu.cn%2Feams%2Flogin.action\'; // Placeholder: jw.westlake.edu.cn for academic affairs
  static const String EXAM_TABLE_LOGIN_URL =
      \'https://uis.westlake.edu.cn/authserver/login?service=http%3A%2F%2Fjw.westlake.edu.cn%2Feams%2FstdExamTable%21examTable.action\';
  static const String ID_URL =
      \'https://jw.westlake.edu.cn/eams/courseTableForStd.action\';
  static const String TIME_TABLE_URL =
      \'https://jw.westlake.edu.cn/eams/courseTableForStd!courseTable.action\';
  static const String EXAM_TABLE_URL =
      \'https://jw.westlake.edu.cn/eams/stdExamTable!examTable.action\';
  static const String HOST = "https://jw.westlake.edu.cn/eams/";
  static const String KEY_TIMETABLE_CACHE = "timetable";

  TimeTableRepository._();

  static final _instance = TimeTableRepository._();

  factory TimeTableRepository.getInstance() => _instance;

  // TODO: Westlake University - This regex is Fudan-specific for extracting IDs from HTML. Needs rewrite.
  String? _getIds(String html) {
    RegExp idMatcher = RegExp(r\'(?<=ids\",\").+(?=\"\\);)\');
    return idMatcher.firstMatch(html)!.group(0);
  }

  Future<TimeTable?> loadTimeTableRemotely(PersonInfo? info,
          {DateTime? startTime}) =>
      UISLoginTool.tryAsyncWithAuth(dio, LOGIN_URL, cookieJar!, info,
          () => _loadTimeTableRemotely(startTime: startTime));

  // TODO: Westlake University - This logic for getting default semester ID (from cookie \"semester.id\") is Fudan-specific. Needs rewrite.
  Future<String?> getDefaultSemesterId(PersonInfo? info) {
    return UISLoginTool.tryAsyncWithAuth(dio, LOGIN_URL, cookieJar!, info,
        () async {
      await dio.get(ID_URL);
      return (await cookieJar!.loadForRequest(Uri.parse(HOST)))
          .firstWhere((element) => element.name == "semester.id") // This cookie name is Fudan-specific
          .value;
    });
  }

  // TODO: Westlake University - This entire method is heavily Fudan-specific and needs a complete rewrite.
  Future<TimeTable?> _loadTimeTableRemotely({DateTime? startTime}) async {
    // TODO: Westlake University - Logic for getting appropriate semesterId (from settings or cookie) is Fudan-specific.
    Future<String?> getAppropriateSemesterId() async {
      String? setValue = SettingsProvider.getInstance().timetableSemester;
      if (setValue == null || setValue.isEmpty) {
        return (await cookieJar!.loadForRequest(Uri.parse(HOST)))
            .firstWhere((element) => element.name == "semester.id") // Fudan-specific cookie
            .value;
      } else {
        return setValue;
      }
    }

    Response<String> idPage = await dio.get(ID_URL); // Relies on Fudan's ID_URL
    String? termId = _getIds(idPage.data!); // Relies on Fudan's _getIds logic
    // TODO: Westlake University - POST request body parameters (ignoreHead, setting.kind, startWeek, ids, semester.id) are Fudan-specific.
    Response<String> tablePage = await dio.post(TIME_TABLE_URL, // Relies on Fudan's TIME_TABLE_URL
        data: {
          "ignoreHead": "1",
          "setting.kind": "std",
          "startWeek": "1",
          "ids": termId,
          "semester.id": await getAppropriateSemesterId()
        },
        options: DioUtils.NON_REDIRECT_OPTION_WITH_FORM_TYPE);
    // TODO: Westlake University - TimeTable.fromHtml is Fudan-specific. The entire HTML parsing logic needs to be rewritten for Westlake's system.
    TimeTable timetable = TimeTable.fromHtml(
        startTime ??
            DateTime.tryParse(
                SettingsProvider.getInstance().thisSemesterStartDate ?? "") ?? // Fudan-specific setting
            Constant.DEFAULT_SEMESTER_START_DATE, // Review default start date
        tablePage.data!);
    // TODO: Westlake University - This logic for adjusting availableWeeks might be Fudan-specific (related to their calendar/week numbering).
    for (var course in timetable.courses!) {
      for (var weekday in course.times!) {
        if (weekday.weekDay == 6) { // Assuming Saturday adjustment
          for (int i = 0; i < course.availableWeeks!.length; i++) {
            course.availableWeeks![i] = course.availableWeeks![i] - 1;
          }
          break;
        }
      }
    }
    return timetable;
  }

  Future<TimeTable?> loadTimeTable(PersonInfo? info,
      {DateTime? startTime, bool forceLoadFromRemote = false}) async {
    startTime ??= TimeTable.defaultStartTime;
    if (forceLoadFromRemote) {
      TimeTable? result = await Cache.getRemotely<TimeTable>(
          KEY_TIMETABLE_CACHE,
          () async =>
              (await loadTimeTableRemotely(info, startTime: startTime))!,
          (cachedValue) => TimeTable.fromJson(jsonDecode(cachedValue!)),
          (object) => jsonEncode(object.toJson()));
      SettingsProvider.getInstance().timetableLastUpdated = DateTime.now(); // Fudan-specific setting
      return result;
    } else {
      return Cache.get<TimeTable>(
          KEY_TIMETABLE_CACHE,
          () async =>
              (await loadTimeTableRemotely(info, startTime: startTime))!,
          (cachedValue) => TimeTable.fromJson(jsonDecode(cachedValue!)),
          (object) => jsonEncode(object.toJson()));
    }
  }

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名 (was fudan.edu.cn, academic affairs might be jw.westlake.edu.cn or aao.westlake.edu.cn)
}

// TODO: Westlake University - This Test class and its fromHtml are Fudan-specific (likely for exam info). Needs complete review/rewrite.
class Test {
  final String id;
  final String name;
  final String type;
  final String date;
  final String time;
  final String location;
  final String testCategory;
  final String note;

  Test(this.id, this.name, this.type, this.date, this.time, this.location,
      this.testCategory, this.note);

  factory Test.fromHtml(dom.Element html) {
    List<dom.Element> elements = html.getElementsByTagName("td");
    return Test(
        elements[0].text.trim(),
        elements[2].text.trim(),
        elements[3].text.trim(),
        elements[4].text.trim(),
        elements[5].text.trim(),
        elements[6].text.trim(),
        elements[7].text.trim(),
        elements[8].text.trim());
  }
} 