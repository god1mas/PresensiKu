import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

class TeacherProfile {
  const TeacherProfile({required this.name, this.schoolName});

  final String name;
  final String? schoolName;

  factory TeacherProfile.fromMap(Map<String, Object?> map) {
    return TeacherProfile(
      name: map['name'] as String,
      schoolName: map['school_name'] as String?,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(appDatabaseProvider).database);
});

final teacherProfileProvider = FutureProvider<TeacherProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).load();
});

class ProfileRepository {
  const ProfileRepository(this.database);

  final Database database;

  Future<TeacherProfile?> load() async {
    final rows = await database.query(
      'teacher_profile',
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : TeacherProfile.fromMap(rows.single);
  }

  Future<void> save({required String name, String? schoolName}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nama guru wajib diisi.');
    }
    final trimmedSchool = schoolName?.trim();
    final now = DateTime.now().toIso8601String();
    final existing = await load();
    final values = <String, Object?>{
      'name': trimmedName,
      'school_name': trimmedSchool == null || trimmedSchool.isEmpty
          ? null
          : trimmedSchool,
      'updated_at': now,
    };
    if (existing == null) {
      await database.insert('teacher_profile', {
        'id': 1,
        ...values,
        'created_at': now,
      });
    } else {
      await database.update('teacher_profile', values, where: 'id = 1');
    }
  }
}
