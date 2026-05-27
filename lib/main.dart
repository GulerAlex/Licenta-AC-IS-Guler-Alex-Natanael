import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/data/app_preferences_store.dart';
import 'package:unihub/data/unihub_repository.dart';
import 'package:unihub/models/user_profile.dart';
import 'package:unihub/screens/functionality/academic_setup_screen.dart';
import 'package:unihub/screens/functionality/grades_screen.dart';
import 'package:unihub/screens/functionality/login_screen.dart';
import 'package:unihub/screens/functionality/profile_screen.dart';
import 'package:unihub/screens/functionality/schedule_screen.dart';
import 'package:unihub/screens/functionality/signup_screen.dart';
import 'package:unihub/screens/functionality/subjects_screen.dart';
import 'package:unihub/screens/functionality/today_screen.dart';
import 'package:unihub/screens/ui/noise_overlay.dart';
import 'package:unihub/services/notification_service.dart';
import 'package:unihub/supabase/supabase_config.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

void _authLog(String message) {
  if (kDebugMode) {
    debugPrint('[AUTH] $message');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _authLog('App boot started.');
  runApp(const AppBootstrap());
}

Future<void> _initializeSupabase() async {
  _authLog(
    'Supabase initialize starting. url=${SupabaseConfig.url} keyLength=${SupabaseConfig.anonKey.length}',
  );
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ).timeout(const Duration(seconds: 20));
    await NotificationService.instance.initialize();
    _authLog('Supabase initialize succeeded.');
  } catch (e, stackTrace) {
    _authLog('Supabase initialize failed: $e');
    _authLog('Supabase initialize stack: $stackTrace');
    rethrow;
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  static final Future<void> _initFuture = _initializeSupabase();

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      _authLog('Supabase config missing. URL or key is empty.');
      return const _SupabaseConfigErrorApp();
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SupabaseLoadingApp();
        }

        if (snapshot.hasError) {
          return const _SupabaseInitErrorApp();
        }

        _authLog('Running MyApp.');
        return const MyApp();
      },
    );
  }
}

class _SupabaseLoadingApp extends StatelessWidget {
  const _SupabaseLoadingApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class _SupabaseInitErrorApp extends StatelessWidget {
  const _SupabaseInitErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nu am putut porni conexiunea cu serverul. Verifica internetul si redeschide aplicatia.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SupabaseConfigErrorApp extends StatelessWidget {
  const _SupabaseConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuratia Supabase lipseste. Furnizeaza SUPABASE_URL si SUPABASE_ANON_KEY prin --dart-define.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppPreferencesStore _preferences = AppPreferencesStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_preferences.load());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _preferences,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: 'UniHub',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ro'),
          supportedLocales: const <Locale>[Locale('ro')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: _preferences.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const AuthGateway(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF35B86F),
        primary: const Color(0xFF35B86F),
        secondary: const Color(0xFF88A892),
        surface: isDark ? const Color(0xFF1D211D) : const Color(0xFFF6FAF6),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF111411)
          : const Color(0xFFF1F6F1),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class AuthGateway extends StatefulWidget {
  const AuthGateway({super.key});

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isInitialized = false;
  bool _isResolvingOnboarding = false;
  bool _needsOnboarding = false;
  bool _didSkipOnboarding = false;
  Session? _session;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authLog('AuthGateway initState.');
    _initializeAuth();
  }

  @override
  void dispose() {
    _authLog('AuthGateway dispose.');
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    _authLog('Auth initialization started.');
    await _logNetworkProbe('initializeAuth');
    _session = _supabase.auth.currentSession;
    _authLog(
      'Current session at startup: ${_session != null ? 'present' : 'null'}',
    );

    _authSubscription = _supabase.auth.onAuthStateChange.listen((
      AuthState data,
    ) {
      _authLog(
        'Auth state changed: event=${data.event.name} '
        'hasSession=${data.session != null} '
        'userId=${data.session?.user.id}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _session = data.session;
        if (data.session == null) {
          _needsOnboarding = false;
          _didSkipOnboarding = false;
        }
      });

      if (data.session != null) {
        unawaited(_refreshOnboardingState());
      }
    });

    if (_session != null) {
      await _refreshOnboardingState();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isInitialized = true;
    });
    _authLog('Auth initialization completed. _isInitialized=true');
  }

  Future<void> _refreshOnboardingState() async {
    if (_supabase.auth.currentUser == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _needsOnboarding = false;
        _didSkipOnboarding = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isResolvingOnboarding = true;
    });

    try {
      final UniHubRepository repository = UniHubRepository.instance;
      final results = await Future.wait<Object?>([
        repository.fetchCurrentGroupCode(),
        repository.fetchProfile(),
      ]);
      final String? groupCode = results[0] as String?;
      final UserProfile profile = results[1] as UserProfile;
      if (!mounted) {
        return;
      }
      setState(() {
        _needsOnboarding =
            !_didSkipOnboarding &&
            (groupCode == null ||
                profile.faculty.trim().isEmpty ||
                profile.studyYear == null);
      });
    } catch (e, stackTrace) {
      _authLog('Onboarding state fetch failed: $e');
      _authLog('Onboarding state fetch stack: $stackTrace');
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingOnboarding = false;
        });
      }
    }
  }

  Future<bool> _saveAcademicOnboarding({
    required String faculty,
    required int studyYear,
    required String groupCode,
  }) async {
    _authLog(
      'Academic onboarding started. userId=${_supabase.auth.currentUser?.id}',
    );
    try {
      await UniHubRepository.instance.setAcademicProfileDetails(
        faculty: faculty,
        studyYear: studyYear,
        groupCode: groupCode,
      );
      if (mounted) {
        setState(() {
          _needsOnboarding = false;
          _didSkipOnboarding = false;
        });
      }
      await _refreshOnboardingState();
      _authLog('Academic onboarding completed successfully.');
      return true;
    } catch (e, stackTrace) {
      _authLog('Academic onboarding failed: $e');
      _authLog('Academic onboarding stack: $stackTrace');
      return false;
    }
  }

  void _skipAcademicOnboarding() {
    _authLog('Academic onboarding skipped for current session.');
    setState(() {
      _needsOnboarding = false;
      _didSkipOnboarding = true;
    });
  }

  Future<void> _logNetworkProbe(String source) async {
    if (!kDebugMode) {
      return;
    }

    final String host = Uri.parse(SupabaseConfig.url).host;
    _authLog('Network probe[$source] started for host=$host');

    try {
      final Uri healthUri = Uri.parse('${SupabaseConfig.url}/auth/v1/health');
      final http.Response response = await http
          .get(
            healthUri,
            headers: <String, String>{'apikey': SupabaseConfig.anonKey},
          )
          .timeout(const Duration(seconds: 8));
      _authLog(
        'Network probe[$source] HTTP success: status=${response.statusCode} bodyLen=${response.body.length}',
      );
    } catch (e) {
      _authLog('Network probe[$source] HTTP failed: $e');
    }
  }

  Future<bool> _authenticate(String email, String password) async {
    _authLog('Login attempt started for email=${email.trim().toLowerCase()}');
    await _logNetworkProbe('login');
    try {
      final AuthResponse response = await _supabase.auth
          .signInWithPassword(
            email: email.trim().toLowerCase(),
            password: password,
          )
          .timeout(const Duration(seconds: 20));

      final bool isAuthenticated =
          response.session != null || _supabase.auth.currentSession != null;

      _authLog(
        'Login response received. hasResponseSession=${response.session != null} '
        'hasCurrentSession=${_supabase.auth.currentSession != null} '
        'isAuthenticated=$isAuthenticated userId=${response.user?.id}',
      );

      return isAuthenticated;
    } on TimeoutException catch (e) {
      _authLog('Login timeout: $e');
      return false;
    } on AuthException catch (e, stackTrace) {
      _authLog(
        'Login auth exception: message=${e.message} status=${e.statusCode}',
      );
      _authLog('Login auth exception stack: $stackTrace');
      return false;
    } catch (e, stackTrace) {
      _authLog('Login unexpected exception: $e');
      _authLog('Login unexpected stack: $stackTrace');
      return false;
    }
  }

  Future<bool> _register(
    String email,
    String password,
    String nume,
    String prenume,
  ) async {
    _authLog('Sign up attempt started for email=${email.trim().toLowerCase()}');
    final String cleanedNume = nume.trim();
    final String cleanedPrenume = prenume.trim();
    final String fullName = '$cleanedNume $cleanedPrenume'.trim();

    try {
      final AuthResponse response = await _supabase.auth
          .signUp(
            email: email.trim().toLowerCase(),
            password: password,
            data: <String, dynamic>{
              'name': fullName,
              'last_name': cleanedNume,
              'first_name': cleanedPrenume,
            },
          )
          .timeout(const Duration(seconds: 20));

      _authLog(
        'Sign up response received. hasUser=${response.user != null} '
        'hasSession=${response.session != null} userId=${response.user?.id}',
      );

      if (response.user == null) {
        _authLog('Sign up failed because response.user is null.');
        return false;
      }

      return true;
    } on TimeoutException catch (e) {
      _authLog('Sign up timeout: $e');
      return false;
    } on AuthException catch (e, stackTrace) {
      _authLog(
        'Sign up auth exception: message=${e.message} status=${e.statusCode}',
      );
      _authLog('Sign up auth exception stack: $stackTrace');
      return false;
    } catch (e, stackTrace) {
      _authLog('Sign up unexpected exception: $e');
      _authLog('Sign up unexpected stack: $stackTrace');
      return false;
    }
  }

  Future<void> _logout() async {
    _authLog('Logout started for userId=${_supabase.auth.currentUser?.id}');
    await _supabase.auth.signOut();
    _authLog('Logout completed.');
  }

  Future<String?> _openSignUp() {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => SignUpScreen(onSignUp: _register),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_session != null) {
      if (_isResolvingOnboarding) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (_needsOnboarding) {
        return AcademicSetupScreen(
          onSaveAcademicOnboarding: _saveAcademicOnboarding,
          onSkip: _skipAcademicOnboarding,
        );
      }

      return UniHubHomePage(onLogout: _logout);
    }

    return LoginScreen(onLogin: _authenticate, onOpenSignUp: _openSignUp);
  }
}

class UniHubHomePage extends StatefulWidget {
  const UniHubHomePage({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<UniHubHomePage> createState() => _UniHubHomePageState();
}

class _UniHubHomePageState extends State<UniHubHomePage> {
  final AppPreferencesStore _preferences = AppPreferencesStore.instance;
  final UniHubRepository _repository = UniHubRepository.instance;
  late PersistentTabController _controller;
  late int _academicDataVersion;

  @override
  void initState() {
    super.initState();
    _academicDataVersion = _repository.academicDataVersion.value;
    _controller = PersistentTabController(initialIndex: 0);
    _controller.addListener(() {
      setState(() {});
    });
    _repository.academicDataVersion.addListener(_handleAcademicDataChanged);
    _preferences.addListener(_handlePreferencesChanged);
  }

  @override
  void dispose() {
    _repository.academicDataVersion.removeListener(_handleAcademicDataChanged);
    _preferences.removeListener(_handlePreferencesChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleAcademicDataChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _academicDataVersion = _repository.academicDataVersion.value;
    });
  }

  void _handlePreferencesChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  List<Widget> get _screens => <Widget>[
    TodayScreen(
      onOpenSchedule: () => _controller.jumpToTab(1),
      onOpenSubjects: () => _controller.jumpToTab(2),
    ),
    const ScheduleScreen(),
    const SubjectsScreen(),
    GradesScreen(
      academicDataVersion: _academicDataVersion,
      isActive: _controller.index == 3,
    ),
    ProfileScreen(
      onLogout: widget.onLogout,
      themePreference: _preferences.themePreference,
      avatarColor: _preferences.avatarColor,
      onThemePreferenceChanged: _preferences.setThemePreference,
      onAvatarColorChanged: _preferences.setAvatarColor,
    ),
  ];

  List<PersistentBottomNavBarItem> _navBarsItems() {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.dashboard_rounded),
        title: ("Astazi"),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        activeColorSecondary: Colors.black,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.calendar_month_rounded),
        title: ("Orar"),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        activeColorSecondary: Colors.black,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.menu_book_rounded),
        title: ("Materii"),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        activeColorSecondary: Colors.black,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.grade_rounded),
        title: ("Note"),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        activeColorSecondary: Colors.black,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person_outline_rounded),
        title: ("Profil"),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        activeColorSecondary: Colors.black,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const GrainBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: PersistentTabView(
            context,
            controller: _controller,
            screens: _screens,
            items: _navBarsItems(),
            handleAndroidBackButtonPress: true, // Default is true.
            resizeToAvoidBottomInset:
                true, // This needs to be true if you want to move up the screen when keyboard appears. Default is true.
            stateManagement: true, // Default is true.
            hideNavigationBarWhenKeyboardAppears: true,
            padding: const EdgeInsets.only(top: 8),
            backgroundColor: Colors.transparent,
            decoration: const NavBarDecoration(
              colorBehindNavBar: Colors.transparent,
            ),
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 26),
            isVisible: true,
            animationSettings: const NavBarAnimationSettings(
              navBarItemAnimation: ItemAnimationSettings(
                duration: Duration(milliseconds: 200),
                curve: Curves.ease,
              ),
              screenTransitionAnimation: ScreenTransitionAnimationSettings(
                animateTabTransition: false,
              ),
            ),
            confineToSafeArea: true,
            navBarHeight: kBottomNavigationBarHeight + 6,
            navBarStyle: NavBarStyle
                .style7, // Choose the nav bar style with this property
          ),
        ),
      ],
    );
  }
}
