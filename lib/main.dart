import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'signup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // uses google-services.json on Android
  runApp(const NoorAlTariqApp());
}

class NoorAlTariqApp extends StatelessWidget {
  const NoorAlTariqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noor Al-Tariq',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SignupPage(),
    );
  }
}
