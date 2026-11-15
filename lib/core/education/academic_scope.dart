import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';
import '../../features/onboarding/data/profile_repository.dart';
import 'education_level.dart';

final selectedAcademicPeriodProvider = Provider<int?>(
  (ref) => null,
  dependencies: [],
);

String periodPath(BuildContext context, String path, {int? periodId}) {
  final period =
      periodId?.toString() ??
      GoRouterState.of(context).uri.queryParameters['periode'];
  if (period == null) return path;
  final uri = Uri.parse(path);
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'periode': period})
      .toString();
}

class AcademicScope extends ConsumerStatefulWidget {
  const AcademicScope({super.key, required this.uri, required this.child});
  final Uri uri;
  final Widget child;
  @override
  ConsumerState<AcademicScope> createState() => _AcademicScopeState();
}

class _AcademicScopeState extends ConsumerState<AcademicScope> {
  late Future<EducationLevel?> level;
  @override
  void initState() {
    super.initState();
    level = load();
  }

  @override
  void didUpdateWidget(AcademicScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) level = load();
  }

  Future<EducationLevel?> load() async {
    final db = ref.read(appDatabaseProvider).database;
    final segments = widget.uri.pathSegments;
    int? classId = int.tryParse(widget.uri.queryParameters['kelas'] ?? '');
    if (segments.length > 1 && segments.first == 'kelas') {
      classId = int.tryParse(segments[1]);
    }
    if (segments.length > 1 && segments.first == 'absensi') {
      final id = int.tryParse(segments.last);
      if (id != null) {
        final rows = await db.query(
          'attendance_session',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isNotEmpty) classId = rows.single['class_id'] as int;
      }
    }
    if (classId == null) return null;
    final rows = await db.query(
      'school_class',
      where: 'id = ?',
      whereArgs: [classId],
    );
    return rows.isEmpty
        ? null
        : EducationLevel.parse(rows.single['education_level']) ??
              EducationLevel.smp;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(teacherProfileProvider).value;
    return FutureBuilder<EducationLevel?>(
      future: level,
      builder: (context, snapshot) => EducationScope(
        terms: EducationTerms(snapshot.data ?? profile?.educationLevel),
        child: widget.child,
      ),
    );
  }
}

class EducationScope extends InheritedWidget {
  const EducationScope({super.key, required this.terms, required super.child});
  final EducationTerms terms;
  @override
  bool updateShouldNotify(EducationScope oldWidget) =>
      terms.level != oldWidget.terms.level;
}

EducationTerms educationTerms(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<EducationScope>()?.terms ??
    const EducationTerms(null);

Future<T?> showAcademicDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final terms = educationTerms(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => EducationScope(
      terms: terms,
      child: Builder(builder: builder),
    ),
  );
}

/// Only interface copy uses this widget; user-entered names are never translated.
class AcademicText extends StatelessWidget {
  const AcademicText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) => Text(
    educationTerms(context).translate(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel,
  );
}
