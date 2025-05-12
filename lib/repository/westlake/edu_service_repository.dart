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
import \'dart:io\'; // TODO: Westlake University - Review if dart:io specific Cookie logic is still the best approach or if dio_cookie_manager can handle all cases.

import \'package:beautiful_soup_dart/beautiful_soup.dart\';
import \'package:dan_xi/model/person.dart\';
import \'package:dan_xi/repository/base_repository.dart\';
// TODO: Westlake University - Ensure this import points to the correct Westlake version after migration
import \'package:dan_xi/repository/westlake/uis_login_tool.dart\';
import \'package:dan_xi/util/public_extension_methods.dart\';
import \'package:dio/dio.dart\';
import \'package:html/dom.dart\' as dom;

class EduServiceRepository extends BaseRepositoryWithDio {
  // TODO: Westlake University - All URLs below are Fudan-specific (uis & jwfw domains and all paths like /eams/, !search.action, etc.). Need complete replacement with Westlake's academic system URLs.
  static const String EXAM_TABLE_LOGIN_URL =
      \'https://uis.westlake.edu.cn/authserver/login?service=http%3A%2F%2Fjw.westlake.edu.cn%2Feams%2FstdExamTable%21examTable.action\'; // Placeholder: jw.westlake.edu.cn for academic affairs
  static const String EXAM_TABLE_URL =
      \'https://jw.westlake.edu.cn/eams/stdExamTable!examTable.action\';

  static String kExamScoreUrl(semesterId) =>
      \'https://jw.westlake.edu.cn/eams/teach/grade/course/person!search.action?semesterId=$semesterId\';

  static const String GPA_URL =
      "https://jw.westlake.edu.cn/eams/myActualGpa!search.action";

  static const String SEMESTER_DATA_URL =
      "https://jw.westlake.edu.cn/eams/dataQuery.action";

  static const String HOST = "https://jw.westlake.edu.cn/eams/";
  static const String KEY_TIMETABLE_CACHE = "timetable"; // This seems to be a duplicate key from TimeTableRepository, might need review.
  static const String ID_URL =
      \'https://jw.westlake.edu.cn/eams/courseTableForStd.action\';
  // TODO: Westlake University - Review headers, especially Origin, for Westlake's academic system.
  static const Map<String, String> _JWFW_HEADER = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:84.0) Gecko/20100101 Firefox/84.0",
    "Accept": "text/xml",
    "Accept-Language": "zh-CN,en-US;q=0.7,en;q=0.3",
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "Origin": "https://jw.westlake.edu.cn", // Placeholder
    "Connection": "keep-alive",
  };

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名 (was fudan.edu.cn, academic services might be jw.westlake.edu.cn or aao.westlake.edu.cn)

  EduServiceRepository._();

  static final _instance = EduServiceRepository._();

  factory EduServiceRepository.getInstance() => _instance;

  Future<List<Exam>?> loadExamListRemotely(PersonInfo? info,
          {String? semesterId}) =>
      UISLoginTool.tryAsyncWithAuth(dio, EXAM_TABLE_LOGIN_URL, cookieJar!, info,
          () => _loadExamList(semesterId: semesterId));

  // TODO: Westlake University - This logic for getting semester ID from cookie ("semester.id") is Fudan-specific. Needs rewrite.
  Future<String?> get semesterIdFromCookie async =>
      (await cookieJar!.loadForRequest(Uri.parse(HOST)))
          .firstWhere((element) => element.name == "semester.id", // Fudan-specific cookie name
              orElse: () => Cookie("semester.id", ""))
          .value;

  // TODO: Westlake University - This entire method (cookie manipulation, HTML parsing via Exam.fromHtml) is Fudan-specific. Needs complete rewrite.
  Future<List<Exam>?> _loadExamList({String? semesterId}) async {
    String? oldSemesterId = await semesterIdFromCookie; // Fudan-specific
    // Set the semester id - this cookie manipulation is Fudan-specific.
    if (semesterId != null) {
      cookieJar?.saveFromResponse(
          Uri.parse(HOST), [Cookie("semester.id", semesterId)]);
    }
    final Response<String> r = await dio.get(EXAM_TABLE_URL,
        options: Options(headers: Map.of(_JWFW_HEADER)));

    // Restore old semester id - Fudan-specific cookie manipulation.
    if (oldSemesterId != null) {
      cookieJar?.saveFromResponse(
          Uri.parse(HOST), [Cookie("semester.id", oldSemesterId)]);
    }
    final BeautifulSoup soup = BeautifulSoup(r.data!);
    // The HTML parsing (tbody, tr, Exam.fromHtml) is Fudan-specific.
    final dom.Element tableBody = soup.find("tbody")!.element!;
    return tableBody
        .getElementsByTagName("tr")
        .map((e) => Exam.fromHtml(e)) // Exam.fromHtml is Fudan-specific
        .toList();
  }

  Future<List<ExamScore>?> loadExamScoreRemotely(PersonInfo? info,
          {String? semesterId}) =>
      UISLoginTool.tryAsyncWithAuth(dio, EXAM_TABLE_LOGIN_URL, cookieJar!, info,
          () => _loadExamScore(semesterId));

  // TODO: Westlake University - This entire method (URL construction, HTML parsing via ExamScore.fromEduServiceHtml) is Fudan-specific. Needs complete rewrite.
  Future<List<ExamScore>?> _loadExamScore([String? semesterId]) async {
    final Response<String> r = await dio.get(
        kExamScoreUrl(semesterId ?? await semesterIdFromCookie), // semesterIdFromCookie is Fudan-specific
        options: Options(headers: Map.of(_JWFW_HEADER)));
    final BeautifulSoup soup = BeautifulSoup(r.data!);
    // The HTML parsing (tbody, tr, ExamScore.fromEduServiceHtml) is Fudan-specific.
    final dom.Element tableBody = soup.find("tbody")!.element!;
    return tableBody
        .getElementsByTagName("tr")
        .map((e) => ExamScore.fromEduServiceHtml(e)) // ExamScore.fromEduServiceHtml is Fudan-specific
        .toList();
  }

  Future<List<GPAListItem>?> loadGPARemotely(PersonInfo? info) =>
      UISLoginTool.tryAsyncWithAuth(
          dio, EXAM_TABLE_LOGIN_URL, cookieJar!, info, () => _loadGPA());

  // TODO: Westlake University - This entire method (HTML parsing via GPAListItem.fromHtml) is Fudan-specific. Needs complete rewrite.
  Future<List<GPAListItem>?> _loadGPA() async {
    final Response<String> r =
        await dio.get(GPA_URL, options: Options(headers: Map.of(_JWFW_HEADER)));
    final BeautifulSoup soup = BeautifulSoup(r.data!);
    // The HTML parsing (tbody, tr, GPAListItem.fromHtml) is Fudan-specific.
    final dom.Element tableBody = soup.find("tbody")!.element!;
    return tableBody
        .getElementsByTagName("tr")
        .map((e) => GPAListItem.fromHtml(e)) // GPAListItem.fromHtml is Fudan-specific
        .toList();
  }

  /// Load the semesters id & name, etc.
  ///
  /// Returns an unpacked list of [SemesterInfo].
  Future<List<SemesterInfo>?> loadSemesters(PersonInfo? info) =>
      UISLoginTool.tryAsyncWithAuth(
          dio, EXAM_TABLE_LOGIN_URL, cookieJar!, info, () => _loadSemesters(),
          retryTimes: 2);

  // TODO: Westlake University - This entire method (POST params, _normalizeJson, SemesterInfo.fromJson) is Fudan-specific. Needs complete rewrite.
  Future<List<SemesterInfo>?> _loadSemesters() async {
    await dio.get(EXAM_TABLE_URL, // Initial GET might be part of Fudan's flow
        options: Options(headers: Map.of(_JWFW_HEADER)));
    // POST request parameter "dataType=semesterCalendar&empty=false" is Fudan-specific.
    final Response<String> semesterResponse = await dio.post(SEMESTER_DATA_URL,
        data: "dataType=semesterCalendar&empty=false",
        options: Options(contentType: \'application/x-www-form-urlencoded\'));
    final BeautifulSoup soup = BeautifulSoup(semesterResponse.data!);

    // _normalizeJson and the subsequent JSON parsing (json[\'semesters\']) are Fudan-specific.
    final jsonText = _normalizeJson(soup.getText().trim()); 
    final json = jsonDecode(jsonText);
    final Map<String, dynamic> semesters = json[\'semesters\']; // Field name \'semesters\' might differ
    List<SemesterInfo> sems = [];
    for (var element in semesters.values) {
      if (element is List && element.isNotEmpty) {
        var annualSemesters = element.map((e) => SemesterInfo.fromJson(e)); // SemesterInfo.fromJson is Fudan-specific
        sems.addAll(annualSemesters);
      }
    }
    if (sems.isEmpty) throw "Retrieval failed"; // Error condition might need review
    return sems;
  }

  /// JSON-Like Text: {aaaa:"asdasd"}
  /// Real JSON Text: {"aaaa":"asdasd"}
  ///
  /// Add a pair of quote on the both sides of every key.
  /// This requires that no quote is included in the key or value. Or the result will be
  /// abnormal.
  // TODO: Westlake University - This _normalizeJson method is a workaround for Fudan's non-standard JSON. Unlikely to be needed for Westlake; a proper JSON API is expected.
  String _normalizeJson(String jsonLikeText) {
    String result = "";
    bool inQuote = false;
    bool inKey = false;
    for (String char
        in jsonLikeText.runes.map((rune) => String.fromCharCode(rune))) {
      if (char == \'"\') {
        inQuote = !inQuote;
      } else if (char.isAlpha() || char.isNumber()) {
        if (!inQuote && !inKey) {
          result += \'"\';
          inKey = true;
        }
      } else {
        if (inKey) {
          result += \'"\';
          inKey = false;
        }
      }
      result += char;
    }
    return result;
  }
}

// TODO: Westlake University - Review SemesterInfo fields (id, schoolYear, name) based on Westlake's API.
class SemesterInfo {
  final String? semesterId;
  final String? schoolYear;
  final String? name;

  SemesterInfo(this.semesterId, this.schoolYear, this.name);

  /// Example:
  /// "name":"1" means this is the first semester of the year.
  ///
  ///   {
  // 			"id": "163",
  // 			"schoolYear": "1994-1995",
  // 			"name": "1"
  // 		}
  factory SemesterInfo.fromJson(Map<String, dynamic> json) { // Field names \'id\', \'schoolYear\', \'name\' are Fudan-specific.
    return SemesterInfo(json[\'id\'], json[\'schoolYear\'], json[\'name\']);
  }
}

// TODO: Westlake University - Review Exam class and its fromHtml. HTML parsing is Fudan-specific.
class Exam {
  final String id;
  final String name;
  final String type;
  final String date;
  final String time;
  final String location;
  final String testCategory;
  final String note;

  Exam(this.id, this.name, this.type, this.date, this.time, this.location,
      this.testCategory, this.note);

  factory Exam.fromHtml(dom.Element html) { // Parsing from HTML table (td elements) is Fudan-specific.
    List<dom.Element> elements = html.getElementsByTagName("td");
    return Exam(
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

// TODO: Westlake University - Review ExamScore class and its fromEduServiceHtml/fromDataCenterHtml. HTML parsing is Fudan-specific.
class ExamScore {
  final String id;
  final String name;
  final String type;
  final String credit;
  final String level;
  final String? score;

  ExamScore(this.id, this.name, this.type, this.credit, this.level, this.score);

  factory ExamScore.fromEduServiceHtml(dom.Element html) { // Parsing from HTML table (td elements) is Fudan-specific.
    List<dom.Element> elements = html.getElementsByTagName("td");
    return ExamScore(
        elements[2].text.trim(),
        elements[3].text.trim(),
        elements[4].text.trim(),
        elements[5].text.trim(),
        elements[6].text.trim(),
        elements[7].text.trim());
  }

  /// NOTE: Result's [type] is year + semester(e.g. "2020-2021 2"),
  /// and [id] doesn't contain the last 2 digits.
  // This factory method seems to be for a different data source (DataCenter) and might have different parsing logic.
  factory ExamScore.fromDataCenterHtml(dom.Element html) { // Parsing from HTML table (td elements) is Fudan-specific.
    List<dom.Element> elements = html.getElementsByTagName("td");
    return ExamScore(
        elements[0].text.trim(),
        elements[3].text.trim(),
        \'${elements[1].text.trim()} ${elements[2].text.trim()}\',
        elements[4].text.trim(),
        elements[5].text.trim(),
        null);
  }
}

// TODO: Westlake University - Review GPAListItem class and its fromHtml. HTML parsing is Fudan-specific.
class GPAListItem {
  final String name;
  final String id;
  final String year;
  final String major;
  final String college;
  final String gpa;
  final String credits;
  final String rank;

  GPAListItem(this.name, this.id, this.gpa, this.credits, this.rank, this.year,
      this.major, this.college);

  factory GPAListItem.fromHtml(dom.Element html) { // Parsing from HTML table (td elements) is Fudan-specific.
    List<dom.Element> elements = html.getElementsByTagName("td");
    return GPAListItem(
        elements[1].text,
        elements[0].text,
        elements[5].text,
        elements[6].text,
        elements[7].text,
        elements[2].text,
        elements[3].text,
        elements[4].text);
  }
} 