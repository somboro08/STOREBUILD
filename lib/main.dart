import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() => runApp(const MartiStoreApp());

class MartiStoreApp extends StatelessWidget {
  const MartiStoreApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MartiStore',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const HomeScreen(),
      );
}
