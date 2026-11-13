import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../data/profile_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _continue();
  }

  Future<void> _continue() async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    try {
      final profile = await ref.read(profileRepositoryProvider).load();
      if (!mounted) return;
      context.go(profile == null ? '/onboarding' : '/beranda');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data lokal tidak dapat dibuka. Coba buka aplikasi lagi.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 247,
                height: 247,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.iceBlue,
                  borderRadius: BorderRadius.circular(52),
                ),
                child: SvgPicture.asset(
                  'assets/brand/presensiku_emblem.svg',
                  semanticsLabel: 'Logo KelasKu',
                ),
              ),
              const SizedBox(height: 36),
              Text('KelasKu', style: Theme.of(context).textTheme.displaySmall),
              Text(
                'by god1mas',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Kelola kelas, presensi, dan penilaian dalam satu tempat.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              Text(
                'Tanpa internet · Tanpa login',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Dibuat untuk rutinitas guru yang lebih praktis.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .save(name: _nameController.text, schoolName: _schoolController.text);
      ref.invalidate(teacherProfileProvider);
      if (!mounted) return;
      context.go('/beranda');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil belum tersimpan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpace.xl),
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/brand/presensiku_emblem.svg',
                              width: 72,
                              height: 72,
                            ),
                            const SizedBox(width: AppSpace.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.yellow,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: const Text(
                                'LANGKAH PERTAMA',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Text(
                          'Kenalan dulu, yuk!',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: 32),
                        ),
                        Text(
                          'Biar lebih personal, isi nama kamu dulu.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpace.xl),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpace.lg),
                          decoration: BoxDecoration(
                            color: AppColors.lavender,
                            borderRadius: BorderRadius.circular(
                              AppRadius.featured,
                            ),
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/figma/onboarding_book.svg',
                                width: 52,
                                height: 52,
                              ),
                              const SizedBox(width: AppSpace.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Semuanya bisa offline.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontSize: 17),
                                    ),
                                    const SizedBox(height: AppSpace.sm),
                                    Text(
                                      'Data siswa tetap di HP.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.navy),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        const Text('Nama guru'),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Budi Santoso',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Nama guru wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: AppSpace.lg),
                        const Text('Nama sekolah (opsional)'),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _schoolController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'SMP Negeri 1 Contoh',
                          ),
                          onFieldSubmitted: (_) => _save(),
                        ),
                        const SizedBox(height: AppSpace.lg),
                      ],
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mulai pakai KelasKu  ↗'),
              ),
              const SizedBox(height: AppSpace.base),
              Text(
                'Tidak perlu akun atau password.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpace.lg),
            ],
          ),
        ),
      ),
    );
  }
}
