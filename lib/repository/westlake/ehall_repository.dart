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

import \'package:dan_xi/model/person.dart\';
import \'package:dan_xi/repository/base_repository.dart\';
// TODO: Westlake University - Ensure this import points to the correct Westlake version after migration
import \'package:dan_xi/repository/westlake/uis_login_tool.dart\';
import \'package:dio/dio.dart\';

class WestlakeEhallRepository extends BaseRepositoryWithDio {
  static const String _INFO_URL =
      "https://ehall.westlake.edu.cn/jsonp/ywtb/info/getUserInfoAndSchoolInfo.json"; // TODO: Westlake University - 请确认此URL和API端点，特别是路径和参数
  static const String _LOGIN_URL =
      "https://uis.westlake.edu.cn/authserver/login?service=http%3A%2F%2Fehall.westlake.edu.cn%2Flogin%3Fservice%3Dhttp%3A%2F%2Fehall.westlake.edu.cn%2Fywtb-portal%2Fwestlake%2Findex.html"; // TODO: Westlake University - 请确认此URL和API端点，特别是service参数中的 Fudan specific path

  WestlakeEhallRepository._();

  static final _instance = WestlakeEhallRepository._();

  factory WestlakeEhallRepository.getInstance() => _instance;

  Future<StudentInfo> getStudentInfo(PersonInfo info) async =>
      UISLoginTool.tryAsyncWithAuth(
          dio, _LOGIN_URL, cookieJar!, info, _getStudentInfo);

  Future<StudentInfo> _getStudentInfo() async {
    Response<Map<String, dynamic>> rep = await dio.get(_INFO_URL);
    Map<String, dynamic> rawJson = rep.data!;
    // TODO: Westlake University - Review data structure and field names (e.g., \'userName\', \'userTypeName\', \'userDepartment\') for Westlake API
    if (rawJson[\'data\'][\'userName\'] == null) {
      throw GeneralLoginFailedException();
    }
    return StudentInfo(rawJson[\'data\'][\'userName\'],
        rawJson[\'data\'][\'userTypeName\'], rawJson[\'data\'][\'userDepartment\']);
  }

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名
}

class StudentInfo {
  final String? name;
  final String? userTypeName;
  final String? userDepartment;

  StudentInfo(this.name, this.userTypeName, this.userDepartment);
} 