import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Browser/device-local demo records. Each record has its own key so publishing
/// a role or saving an application cannot replace the rest of the collection.
class MockRecruitmentStore {
  MockRecruitmentStore(this._preferences);

  final SharedPreferences _preferences;
  static const _prefix = 'excelerate.mock.recruitment.v1.';

  Future<void> reload() => _preferences.reload();

  Map<String, Map<String, dynamic>> read(String collection) {
    final prefix = '$_prefix$collection.';
    return {
      for (final key
          in _preferences.getKeys().where((key) => key.startsWith(prefix)))
        key.substring(prefix.length): Map<String, dynamic>.from(
          jsonDecode(_preferences.getString(key)!) as Map,
        ),
    };
  }

  Future<void> save(String collection, Map<String, dynamic> record) async {
    final saved = await _preferences.setString(
      '$_prefix$collection.${record['id']}',
      jsonEncode(record),
    );
    if (!saved) throw StateError('Unable to save the demo record.');
  }
}
