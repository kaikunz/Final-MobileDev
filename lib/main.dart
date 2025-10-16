

import 'auth/login.dart';
import 'components/main.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pocketbase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPocketBase();

  final isLoggedIn = pb.authStore.isValid;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.kanitTextTheme(),
      ),
      home: isLoggedIn ? const MainApp() : const LoginPage(),
    );
  }
}