import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mayintarlasi/screens/active_games_screen.dart';
import 'package:mayintarlasi/screens/game_screen.dart';
import 'package:mayintarlasi/screens/match_waiting_screen.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelime Mayınları',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/new-game':
            return MaterialPageRoute(builder: (_) => const NewGameScreen());
          case '/match-waiting':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => MatchWaitingScreen(durationInSeconds: args['durationInSeconds']),
            );
          case '/active-games':
            return MaterialPageRoute(builder: (_) => const ActiveGamesScreen());
          case '/game':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => GameScreen(gameId: args['gameId']),
            );



          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('404 - Sayfa bulunamadı')),
              ),
            );
        }
      },
    );
  }
}
