import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/colors.dart';
import 'core/constants/theme.dart';
import 'core/providers/app_providers.dart';
import 'core/services/supabase_service.dart';
import 'core/utils/phone_helper.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/update_phone_number_screen.dart';
import 'features/home_shell.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Enable edge-to-edge mode with transparent system navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Initialize SupabaseService.
  await SupabaseService.instance.initialize(
    url: 'https://dsminsgahrnwzskmwsvn.supabase.co',
    anonKey: 'sb_publishable_Jf1BIZCrl_l2zP0xcD0OGQ_wxYu06Z2',
  );

  runApp(
    const ProviderScope(
      child: RoomRentalApp(),
    ),
  );
}

class RoomRentalApp extends ConsumerWidget {
  const RoomRentalApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authProvider, (previous, next) {
      if (!next.isLoading) {
        FlutterNativeSplash.remove();
      }
    });

    final authState = ref.watch(authProvider);
    if (!authState.isLoading) {
      FlutterNativeSplash.remove();
    }
    final textScaleFactor = ref.watch(textScaleFactorProvider);

    return MaterialApp(
      title: 'Bhai App',
      theme: getAppTheme(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      debugShowCheckedModeBanner: false,
      home: authState.when(
        data: (owner) {
          if (owner != null) {
            if (PhoneHelper.isPlaceholderPhoneNumber(owner.mobileNo)) {
              return const UpdatePhoneNumberScreen();
            }
            return const HomeShell();
          }
          return const AuthScreen();
        },
        loading: () => Container(
          decoration: AppColors.backgroundGradient,
          child: const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryPill),
            ),
          ),
        ),
        error: (err, stack) => const AuthScreen(),
      ),
    );
  }
}
