import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mizaan/core/theme/app_theme.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';

class HomePlaceholderScreen extends StatefulWidget {
  const HomePlaceholderScreen({super.key});

  @override
  State<HomePlaceholderScreen> createState() => _HomePlaceholderScreenState();
}

class _HomePlaceholderScreenState extends State<HomePlaceholderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ميزان — الرئيسية'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (_, state) {
          final user = state is Authenticated ? state.user : null;
          final cubit = context.read<AuthCubit>();
          final isBiometricOn = cubit.isBiometricEnabled;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 32,
                            backgroundColor: AppTheme.primaryColor,
                            child: Icon(
                              Icons.person,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user?.displayName ?? 'مستخدم ميزان',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text('تفعيل الدخول بالبصمة'),
                    subtitle: const Text('طلب البصمة عند فتح التطبيق'),
                    secondary: const Icon(Icons.fingerprint, color: AppTheme.primaryColor),
                    value: isBiometricOn,
                    onChanged: (val) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await cubit.setBiometricEnabled(val);
                      if (mounted) {
                        setState(() {});
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(val ? 'تم تفعيل البصمة' : 'تم تعطيل البصمة'),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      }
                    },
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => cubit.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('تسجيل الخروج'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
