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
import \'package:dan_xi/util/retrier.dart\';
import \'package:dio/dio.dart\';
import \'package:html/dom.dart\' as dom;

class WestlakePERepository extends BaseRepositoryWithDio {
  static const String _LOGIN_URL =
      "https://uis.westlake.edu.cn/authserver/login?service=http%3A%2F%2Ftac.westlake.edu.cn%2Fthirds%2Ftjb.act%3Fredir%3DsportScore"; // TODO: Westlake University - 请确认此URL和API端点 (uis & tac domains, service path, and query params)
  static const String _INFO_URL =
      "https://pe.westlake.edu.cn/sportScore/stScore.aspx"; // TODO: Westlake University - 请确认此URL和API端点 (assuming pe or fdtyjw equivalent for westlake)

  WestlakePERepository._();

  static final _instance = WestlakePERepository._();

  factory WestlakePERepository.getInstance() => _instance;

  Future<List<ExerciseObject>?> loadExerciseRecords(PersonInfo? info) =>
      Retrier.runAsyncWithRetry(() => _loadExerciseRecords(info));

  Future<List<ExerciseObject>?> _loadExerciseRecords(PersonInfo? info) async {
    // PE system request a token from UIS to log in.
    String token = "";
    // TODO: Westlake University - This login and token extraction logic is Fudan-specific. Needs review for Westlake's PE system.
    await UISLoginTool.loginUIS(dio, _LOGIN_URL, cookieJar!, info)
        .catchError((e) {
      if (e is DioException && e.type == DioExceptionType.badResponse) {
        String url = e.response!.requestOptions.path;
        token = Uri.tryParse(url)!.queryParameters[\'token\']!; // Token extraction might differ
      }
      return null;
    });
    final List<ExerciseObject> items = [];
    final Response<String> r = await dio.get("$_INFO_URL?token=$token"); // Use of token needs verification
    final BeautifulSoup soup = BeautifulSoup(r.data!);
    // TODO: Westlake University - All CSS selectors below are Fudan-specific and need complete review/rewrite for Westlake's PE system.
    final Iterable<dom.Element> tableLines = soup
        .findAll(
            "#pAll > table > tbody > tr:nth-child(6) > td > table > tbody > tr") // Highly specific selector
        .map((e) => e.element!);

    final Iterable<dom.Element> peScoreLines = soup
        .findAll(
            "#pAll > table > tbody > tr:nth-child(26) > td > table > tbody > tr > td") // Highly specific selector
        .map((e) => e.element!);

    if (tableLines.isEmpty) {
      // TODO: Westlake University - Error handling or condition might need adjustment.
      throw "Unable to get the data";
    }

    for (var line in tableLines) {
      items.addAll(ExerciseItem.fromHtml(line)); // fromHtml logic is Fudan-specific
    }
    int i = 0;
    List<String> peInfo = [];
    for (var line in peScoreLines) { // This loop and parsing logic is Fudan-specific
      i++;
      if (i == 1) continue;
      if (i == 6) {
        i = 0;
        continue;
      }
      peInfo.add(line.text);
      if (i == 5) {
        items.add(ExerciseRecord.fromHtml(
            peInfo[0], peInfo[1], peInfo[2], peInfo[3])); // fromHtml logic is Fudan-specific
        peInfo.clear();
      }
    }
    return items;
  }

  @override
  String get linkHost =>
      "pe.westlake.edu.cn"; // TODO: Westlake University - 请确认此域名 (e.g. pe.westlake.edu.cn or equivalent). Original comment: "uses a separate host here, since we are excepting an error response from server"
}

sealed class ExerciseObject {}

class ExerciseItem implements ExerciseObject {
  final String title;
  final int? times;

  ExerciseItem(this.title, this.times);

  // TODO: Westlake University - This fromHtml is Fudan-specific and needs a complete rewrite.
  static List<ExerciseItem> fromHtml(dom.Element html) {
    List<ExerciseItem> list = [];
    List<dom.Element> elements = html.getElementsByTagName("td");
    for (int i = 0; i < elements.length; i += 2) {
      list.add(ExerciseItem(elements[i].text.trim().replaceFirst("：", ""),
          int.tryParse(elements[i + 1].text.trim())));
    }
    return list;
  }
}

class ExerciseRecord implements ExerciseObject {
  final String title;
  final String result;
  final String singleScore;
  final String comment;

  ExerciseRecord(this.title, this.result, this.singleScore, this.comment);

  // TODO: Westlake University - This fromHtml is Fudan-specific and needs a complete rewrite.
  static ExerciseRecord fromHtml(
      String title, String result, String singleScore, String comment) {
    return ExerciseRecord(title, result, singleScore, comment);
  }
} 