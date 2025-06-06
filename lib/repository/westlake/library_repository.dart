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

import \'package:dan_xi/repository/base_repository.dart\';
import \'package:dio/dio.dart\';

class WestlakeLibraryRepository extends BaseRepositoryWithDio {
  static const String _INFO_URL =
      "https://mlibrary.westlake.edu.cn/api/common/h5/getspaceseat"; // TODO: Westlake University - 请确认此URL和API端点

  WestlakeLibraryRepository._();

  static final _instance = WestlakeLibraryRepository._();

  factory WestlakeLibraryRepository.getInstance() => _instance;

  Future<Map<String, String>> getLibraryRawData() async {
    Response<String> r = await dio.post(_INFO_URL);
    final jsonData = json.decode(r.data!);
    final campusToInNum = <String, String>{};
    for (final item in jsonData[\'data\']) { // TODO: Westlake University - Review data structure and field names (e.g., \'campusName\', \'inNum\') for Westlake API
      final campusName = item[\'campusName\'];
      final inNum = item[\'inNum\'];
      campusToInNum[campusName] = inNum;
    }
    return campusToInNum;
  }

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名
} 