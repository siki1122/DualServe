import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_home.dart';
import 'screens/provider/provider_main_layout.dart';
import 'screens/admin/admin_home.dart';
import 'utils/app_theme.dart';
import 'screens/customer/customer_main_layout.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'services/notification_service.dart';
import 'services/notification_service_local.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'widgets/error_boundary.dart';

import 'screens/auth/pending_approval_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Offline Persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: const ErrorBoundary(child: MyApp()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return MaterialApp(
          title: 'Household & Towing Services',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: userProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
          routes: {'/login': (context) => const LoginScreen()},
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;


          // Trigger data load in provider and init notifications
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(
              context,
              listen: false,
            ).loadCurrentUserData();
            NotificationService().initialize(); // INIT FCM
            LocalNotificationService().initialize(); // INIT LOCAL FALLBACK
          });
          return const RoleBasedHome();
        }
        
        // Clear user data when logged out
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<UserProvider>(context, listen: false).clear();
        });
        return const LoginScreen();
      },
    );
  }
}

class RoleBasedHome extends StatelessWidget {
  const RoleBasedHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Check if profile is incomplete (missing name or role)
        final profile = userProvider.userProfile;
        if (profile == null ||
            profile['name'] == null ||
            profile['name'].toString().isEmpty ||
            profile['role'] == null) {
          return const ProfileSetupScreen();
        }

        final role = userProvider.role;
        if (role == 'provider') {
          return const ProviderMainLayout();
        } else if (role == 'pending_provider') {
          return const PendingApprovalScreen();
        } else if (role == 'admin') {
          return const AdminHome();
        }
        return const CustomerMainLayout();
      },
    );
  }
}
