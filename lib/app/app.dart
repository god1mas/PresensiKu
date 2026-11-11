import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/app_theme.dart';
import '../core/design/tokens.dart';
import '../features/academics/presentation/class_screens.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/onboarding/presentation/onboarding_screens.dart';
import 'phase2_tabs.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
            builder: (context, state) => const ClassListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => ClassDetailScreen(
                  id: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/riwayat',
            builder: (context, state) => const HistoryTab(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => HistoryReadOnlyDetail(
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
            path: '/absensi',
            builder: (context, state) => const AttendanceGateScreen(),
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
      title: 'PresensiKu',
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
