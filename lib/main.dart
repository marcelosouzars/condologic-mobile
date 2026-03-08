import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CondoLogicApp());
}

class CondoLogicApp extends StatelessWidget {
  const CondoLogicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CondoLogic Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: LoginScreen(), 
    );
}
}