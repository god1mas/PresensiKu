import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_theme.dart';
import '../core/education/academic_scope.dart';
import '../core/design/tokens.dart';
import '../features/academics/presentation/class_screens.dart';
import '../features/academics/presentation/roster_screens.dart';
import '../features/attendance/presentation/attendance_screens.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/history/presentation/history_screens.dart';
import '../features/grading/presentation/grading_screens.dart';
import '../features/onboarding/presentation/onboarding_screens.dart';
import '../features/reports/data/report_repository.dart';
import '../features/reports/presentation/report_screens.dart';
import '../features/settings/presentation/backup_screen.dart';
import '../features/settings/presentation/period_settings_screen.dart';
import '../features/settings/presentation/help_screens.dart';
import 'phase2_tabs.dart';
import 'feature_selection_screens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => ProviderScope(
          overrides: [
            selectedAcademicPeriodProvider.overrideWithValue(
              int.tryParse(state.uri.queryParameters['periode'] ?? ''),
            ),
          ],
          child: AcademicScope(uri: state.uri, child: child),
        ),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/absensi',
            builder: (context, state) => AttendanceSetupScreen(
              initialClassId: int.tryParse(
                state.uri.queryParameters['kelas'] ?? '',
              ),
              initialSubjectId: int.tryParse(
                state.uri.queryParameters['mapel'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/absensi/sukses/:id',
            builder: (context, state) => AttendanceSuccessScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/absensi/:id',
            builder: (context, state) => AttendanceRecordScreen(
              id: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/laporan',
            builder: (context, state) => const ReportScreen(),
          ),
          GoRoute(
            path: '/laporan/pilih',
            builder: (context, state) =>
                const FeatureSelectionScreen(reports: true),
          ),
          GoRoute(
            path: '/laporan/presensi',
            builder: (context, state) => const ReportScreen(),
          ),
          GoRoute(
            path: '/laporan/penilaian',
            builder: (context, state) =>
                const GradingDestinationScreen(history: false),
          ),
          GoRoute(
            path: '/laporan/ekspor',
            builder: (context, state) => ReportExportScreen(
              initialFilter:
                  state.extra as ReportFilter? ?? const ReportFilter(),
            ),
          ),
          GoRoute(
            path: '/cadangan',
            builder: (context, state) => const BackupScreen(restoreMode: false),
          ),
          GoRoute(
            path: '/pulihkan',
            builder: (context, state) => const BackupScreen(restoreMode: true),
          ),
          GoRoute(
            path: '/periode',
            builder: (context, state) => const PeriodSettingsScreen(),
          ),
          GoRoute(
            path: '/panduan',
            builder: (context, state) => const UserGuideScreen(),
          ),
          GoRoute(
            path: '/tentang',
            builder: (context, state) => const AboutKelasKuScreen(),
          ),
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/beranda',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/kelas',
                builder: (context, state) => ClassListScreen(
                  selectionMode: state.uri.queryParameters['pilih'] == '1',
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ClassDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'siswa',
                        builder: (context, state) => StudentManagementScreen(
                          classId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      GoRoute(
                        path: 'mapel/:subjectId',
                        builder: (context, state) => SubjectDetailScreen(
                          classId: int.parse(state.pathParameters['id']!),
                          subjectId: int.parse(
                            state.pathParameters['subjectId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'penilaian',
                            builder: (context, state) =>
                                AssessmentOverviewScreen(
                                  classId: int.parse(
                                    state.pathParameters['id']!,
                                  ),
                                  subjectId: int.parse(
                                    state.pathParameters['subjectId']!,
                                  ),
                                ),
                            routes: [
                              GoRoute(
                                path: 'tambah',
                                builder: (context, state) =>
                                    AssessmentFormScreen(
                                      classId: int.parse(
                                        state.pathParameters['id']!,
                                      ),
                                      subjectId: int.parse(
                                        state.pathParameters['subjectId']!,
                                      ),
                                    ),
                              ),
                              GoRoute(
                                path: ':assessmentId',
                                builder: (context, state) =>
                                    AssessmentDetailScreen(
                                      classId: int.parse(
                                        state.pathParameters['id']!,
                                      ),
                                      subjectId: int.parse(
                                        state.pathParameters['subjectId']!,
                                      ),
                                      assessmentId: int.parse(
                                        state.pathParameters['assessmentId']!,
                                      ),
                                    ),
                                routes: [
                                  GoRoute(
                                    path: 'nilai',
                                    builder: (context, state) =>
                                        GradeEntryScreen(
                                          classId: int.parse(
                                            state.pathParameters['id']!,
                                          ),
                                          subjectId: int.parse(
                                            state.pathParameters['subjectId']!,
                                          ),
                                          assessmentId: int.parse(
                                            state
                                                .pathParameters['assessmentId']!,
                                          ),
                                        ),
                                  ),
                                  GoRoute(
                                    path: 'edit',
                                    builder: (context, state) =>
                                        AssessmentFormScreen(
                                          classId: int.parse(
                                            state.pathParameters['id']!,
                                          ),
                                          subjectId: int.parse(
                                            state.pathParameters['subjectId']!,
                                          ),
                                          assessmentId: int.parse(
                                            state
                                                .pathParameters['assessmentId']!,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GoRoute(
                            path: 'kategori',
                            builder: (context, state) =>
                                CategoryManagementScreen(
                                  classId: int.parse(
                                    state.pathParameters['id']!,
                                  ),
                                  subjectId: int.parse(
                                    state.pathParameters['subjectId']!,
                                  ),
                                ),
                            routes: [
                              GoRoute(
                                path: 'tambah',
                                builder: (context, state) =>
                                    const CategoryAddScreen(),
                              ),
                            ],
                          ),
                          GoRoute(
                            path: 'bobot',
                            builder: (context, state) => WeightSettingsScreen(
                              classId: int.parse(state.pathParameters['id']!),
                              subjectId: int.parse(
                                state.pathParameters['subjectId']!,
                              ),
                            ),
                          ),
                          GoRoute(
                            path: 'rekap',
                            builder: (context, state) => GradeRecapScreen(
                              classId: int.parse(state.pathParameters['id']!),
                              subjectId: int.parse(
                                state.pathParameters['subjectId']!,
                              ),
                            ),
                            routes: [
                              GoRoute(
                                path: ':studentId',
                                builder: (context, state) => StudentGradeScreen(
                                  classId: int.parse(
                                    state.pathParameters['id']!,
                                  ),
                                  subjectId: int.parse(
                                    state.pathParameters['subjectId']!,
                                  ),
                                  studentId: int.parse(
                                    state.pathParameters['studentId']!,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          GoRoute(
                            path: 'ekspor',
                            builder: (context, state) => GradeExportScreen(
                              classId: int.parse(state.pathParameters['id']!),
                              subjectId: int.parse(
                                state.pathParameters['subjectId']!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/riwayat',
                builder: (context, state) =>
                    const FeatureSelectionScreen(reports: false),
                routes: [
                  GoRoute(
                    path: 'presensi',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                  GoRoute(
                    path: 'penilaian',
                    builder: (context, state) =>
                        const GradingDestinationScreen(history: true),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => HistoryDetailScreen(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/pengaturan',
                builder: (context, state) => const SettingsTab(),
              ),
              GoRoute(
                path: '/mata-pelajaran',
                builder: (context, state) => const SubjectScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class PresensiKuApp extends ConsumerWidget {
  const PresensiKuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'KelasKu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const paths = ['/beranda', '/kelas', '/riwayat', '/pengaturan'];
    const labels = ['Beranda', 'Kelas', 'Riwayat', 'Pengaturan'];
    const icons = [
      Icons.home_outlined,
      Icons.menu_book_outlined,
      Icons.access_time_outlined,
      Icons.settings_outlined,
    ];
    final currentPath = GoRouterState.of(context).uri.path;
    var selected = paths.indexWhere((path) => currentPath.startsWith(path));
    if (selected < 0) selected = 0;
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 75,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: List.generate(paths.length, (index) {
              final active = selected == index;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: () => context.go(paths[index]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: active ? AppColors.iceBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[index],
                          size: 22,
                          color: active ? AppColors.blue : AppColors.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[index],
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10,
                            color: active ? AppColors.blue : AppColors.muted,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
