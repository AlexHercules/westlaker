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

import \'package:dan_xi/common/constant.dart\'; // TODO: Westlake University - Review Campus related constants and CampusEx.fromChineseName logic
import \'package:dan_xi/model/person.dart\';
import \'package:dan_xi/repository/base_repository.dart\';
// TODO: Westlake University - Ensure this import points to the correct Westlake version after migration
import \'package:dan_xi/repository/westlake/uis_login_tool.dart\';
import \'package:dan_xi/util/public_extension_methods.dart\';
import \'package:dan_xi/util/vague_time.dart\';
import \'package:dio/dio.dart\';
import \'package:intl/intl.dart\';

class WestlakeBusRepository extends BaseRepositoryWithDio {
  static const String _LOGIN_URL =
      "https://uis.westlake.edu.cn/authserver/login?service=https%3A%2F%2Fappservice.westlake.edu.cn%2Fa_westlakelapp%2Fapi%2Fsso%2Findex%3Fredirect%3Dhttps%253A%252F%252Fappservice.westlake.edu.cn%252Fwestlakebus%252Fwap%252Fdefault%252Flists%26from%3Dwap"; // TODO: Westlake University - 请确认此URL (uis & appservice domains), 特别是service URL中的路径 (原为 zlapp.fudan.edu.cn, a_fudanzlapp, fudanbus)
  static const String _INFO_URL =
      "https://appservice.westlake.edu.cn/westlakebus/wap/default/lists"; // TODO: Westlake University - 请确认此URL (appservice domain and westlakebus path)

  WestlakeBusRepository._();

  static final _instance = WestlakeBusRepository._();

  factory WestlakeBusRepository.getInstance() => _instance;

  Future<List<BusScheduleItem>?> loadBusList(PersonInfo? info,
          {bool holiday = false}) =>
      UISLoginTool.tryAsyncWithAuth(dio, _LOGIN_URL, cookieJar!, info,
          () => _loadBusList(holiday: holiday));

  Future<List<BusScheduleItem>?> _loadBusList({bool holiday = false}) async { // TODO: Westlake University - This method needs complete review for Westlake Bus API (POST params & JSON structure).
    List<BusScheduleItem> items = [];
    Response<String> r = await dio.post(_INFO_URL,
        data: FormData.fromMap(
            {"holiday": holiday.toRequestParamStringRepresentation()})); // Verify POST parameter \"holiday\"
    Map<String, dynamic> json = jsonDecode(r.data!);
    // The following JSON parsing is Fudan-specific, e.g., json[\'d\'][\'data\'] and route[\'lists\']
    // TODO: Westlake University - Adjust JSON parsing based on Westlake Bus API response structure.
    json[\'d\'][\'data\'].forEach((route) {
      if (route[\'lists\'] is List) {
        items.addAll((route[\'lists\'] as List)
            .map((e) => BusScheduleItem.fromRawJson(e))); // fromRawJson is Fudan-specific
      }
    });
    return items.filter((element) => element.realStartTime != null);
  }

  @override
  String get linkHost => "westlake.edu.cn"; // TODO: Westlake University - 请确认此域名 (was fudan.edu.cn, bus info might be on a subdomain like appservice.westlake.edu.cn)
}

class BusScheduleItem implements Comparable<BusScheduleItem> {
  final String? id;
  Campus start; // TODO: Westlake University - Review Campus enum and mapping
  Campus end; // TODO: Westlake University - Review Campus enum and mapping
  VagueTime? startTime;
  VagueTime? endTime;
  BusDirection direction; // TODO: Westlake University - Review BusDirection enum if necessary
  final bool holidayRun;

  VagueTime? get realStartTime => startTime ?? endTime;

  BusScheduleItem(this.id, this.start, this.end, this.startTime, this.endTime,
      this.direction, this.holidayRun);

  // TODO: Westlake University - This fromRawJson is entirely Fudan-specific due to field names and CampusEx.fromChineseName. Needs complete rewrite for Westlake Bus API.
  factory BusScheduleItem.fromRawJson(Map<String, dynamic> json) =>
      BusScheduleItem(
          json[\'id\'], // Field name \'id\' might differ
          CampusEx.fromChineseName(json[\'start\']), // Field name \'start\' and CampusEx logic are Fudan-specific
          CampusEx.fromChineseName(json[\'end\']),   // Field name \'end\' and CampusEx logic are Fudan-specific
          _parseTime(json[\'stime\']), // Field name \'stime\' might differ
          _parseTime(json[\'etime\']), // Field name \'etime\' might differ
          BusDirection.values[int.parse(json[\'arrow\'])], // Field name \'arrow\' and its value meaning might differ
          int.parse(json[\'holiday\']) != 0); // Field name \'holiday\' might differ

  // Some times are using "." as separator, so we need to parse it manually
  // TODO: Westlake University - Verify time format from Westlake Bus API.
  static VagueTime? _parseTime(String time) {
    if (time.isEmpty) {
      return null;
    }
    return VagueTime.onlyHHmm(time.replaceAll(".", ":"));
  }

  BusScheduleItem.reversed(BusScheduleItem original)
      : id = original.id,
        start = original.end,
        end = original.start,
        startTime = original.endTime,
        endTime = original.startTime,
        direction = original.direction.reverse(),
        holidayRun = original.holidayRun;

  BusScheduleItem copyWith({BusDirection? direction}) {
    return BusScheduleItem(id, start, end, startTime, endTime,
        direction ?? this.direction, holidayRun);
  }

  @override
  int compareTo(BusScheduleItem other) =>
      realStartTime!.compareTo(other.realStartTime!);

  @override
  String toString() {
    return \'BusScheduleItem{id: $id, start: $start, end: $end, startTime: $startTime, endTime: $endTime, direction: $direction, holidayRun: $holidayRun}\';
  }
}

// TODO: Westlake University - Review if this enum and its logic is applicable.
enum BusDirection {
  NONE,
  DUAL,

  /// From end to start
  BACKWARD,

  /// From start to end
  FORWARD
}

// TODO: Westlake University - Review if this extension is applicable.
extension BusDirectionExtension on BusDirection {
  static const FORWARD_ARROW = " → ";
  static const BACKWARD_ARROW = " ← ";
  static const DUAL_ARROW = " ↔ ";

  String? toText() {
    switch (this) {
      case BusDirection.FORWARD:
        return FORWARD_ARROW;
      case BusDirection.BACKWARD:
        return BACKWARD_ARROW;
      case BusDirection.DUAL:
        return DUAL_ARROW;
      default:
        return null;
    }
  }

  BusDirection reverse() {
    switch (this) {
      case BusDirection.FORWARD:
        return BusDirection.BACKWARD;
      case BusDirection.BACKWARD:
        return BusDirection.FORWARD;
      default:
        return this;
    }
  }
}

extension VagueTimeExtension on VagueTime {
  String toDisplayFormat() {
    final format = NumberFormat("00");
    return "${format.format(hour)}:${format.format(minute)}";
  }
} 