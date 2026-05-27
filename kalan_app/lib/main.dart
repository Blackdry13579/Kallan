import 'package:kalan_app/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalan_app/core/theme/app_theme.dart';
import 'package:kalan_app/core/utils/text_scale.dart';
import 'package:kalan_app/data/local/database_helper.dart';
import 'package:kalan_app/data/remote/supabase_service.dart';
import 'package:kalan_app/data/repositories/deck_repository_impl.dart';
import 'package:kalan_app/data/repositories/flashcard_repository_impl.dart';
import 'package:kalan_app/data/repositories/quiz_repository_impl.dart';
import 'package:kalan_app/data/repositories/user_repository_impl.dart';
import 'package:kalan_app/data/repositories/badge_repository_impl.dart';
import 'package:kalan_app/data/repositories/notification_repository_impl.dart';
import 'package:kalan_app/presentation/blocs/deck/deck_bloc.dart';
import 'package:kalan_app/presentation/blocs/deck/deck_event.dart';
import 'package:kalan_app/presentation/blocs/flashcard/flashcard_bloc.dart';
import 'package:kalan_app/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:kalan_app/presentation/blocs/sync/sync_bloc.dart';
import 'package:kalan_app/presentation/blocs/user/user_bloc.dart';
import 'package:kalan_app/presentation/blocs/badge/badge_bloc.dart';
import 'package:kalan_app/presentation/blocs/leaderboard/leaderboard_bloc.dart';
import 'package:kalan_app/presentation/blocs/notification/notification_bloc.dart';
import 'package:kalan_app/data/repositories/leaderboard_repository_impl.dart';
import 'package:kalan_app/services/sync_service.dart';
import 'package:kalan_app/presentation/widgets/celebration_listener.dart';
import 'package:kalan_app/presentation/widgets/notification_signal_banner.dart';
import 'package:kalan_app/services/connectivity_service.dart';
import 'package:kalan_app/services/deep_link_service.dart';
import 'package:app_links/app_links.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  String supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  String supabaseKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty) {
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  }
  if (supabaseKey.isEmpty) {
    supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  await SupabaseService.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  // Initialize Deep Linking
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    DeepLinkService.handleIncomingLink(uri);
  });

  appLinks.getInitialLink().then((uri) {
    if (uri != null) DeepLinkService.handleIncomingLink(uri);
  });

  final dbHelper = DatabaseHelper.instance;
  final connectivity = ConnectivityService();
  final deckRepo = DeckRepositoryImpl(dbHelper, connectivity);
  final flashcardRepo = FlashcardRepositoryImpl(dbHelper, connectivity);
  final quizRepo = QuizRepositoryImpl(dbHelper, connectivity);
  final userRepo = UserRepositoryImpl(dbHelper, connectivity);
  final badgeRepo = BadgeRepositoryImpl(dbHelper, connectivity);
  final leaderboardRepo = LeaderboardRepositoryImpl(dbHelper, connectivity);
  final notificationRepo = NotificationRepositoryImpl(dbHelper, connectivity);

  final prefs = await SharedPreferences.getInstance();
  final currentUserId = prefs.getString('current_user_uuid');

  if (currentUserId != null) {
    SyncService.instance.init();
    SyncService.instance.processQueue();
  }

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DeckRepositoryImpl>.value(value: deckRepo),
        RepositoryProvider<FlashcardRepositoryImpl>.value(value: flashcardRepo),
        RepositoryProvider<QuizRepositoryImpl>.value(value: quizRepo),
        RepositoryProvider<UserRepositoryImpl>.value(value: userRepo),
        RepositoryProvider<BadgeRepositoryImpl>.value(value: badgeRepo),
        RepositoryProvider<LeaderboardRepositoryImpl>.value(
            value: leaderboardRepo),
        RepositoryProvider<NotificationRepositoryImpl>.value(
            value: notificationRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<DeckBloc>(
            create: (_) => DeckBloc(deckRepo)..add(const LoadDecks()),
          ),
          BlocProvider<FlashcardBloc>(
            create: (_) => FlashcardBloc(flashcardRepo),
          ),
          BlocProvider<QuizBloc>(
            create: (_) => QuizBloc(quizRepo),
          ),
          BlocProvider<UserBloc>(
            create: (_) => UserBloc(userRepo),
          ),
          BlocProvider<BadgeBloc>(
            create: (_) => BadgeBloc(badgeRepo),
          ),
          BlocProvider<LeaderboardBloc>(
            create: (_) => LeaderboardBloc(leaderboardRepo),
          ),
          BlocProvider<SyncBloc>(create: (_) => SyncBloc()),
          BlocProvider<NotificationBloc>(
            create: (_) => NotificationBloc(notificationRepo),
          ),
        ],
        child: const KalanApp(),
      ),
    ),
  );
}

class KalanApp extends StatelessWidget {
  const KalanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KALAN',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
      builder: (context, child) {
        return NotificationSignalBanner(
          child: CelebrationListener(
            navigatorKey: appNavigatorKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(TextScale.normal.factor),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}
