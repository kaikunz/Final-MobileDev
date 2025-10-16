import 'package:flutter/material.dart';
import 'home.dart';
import 'profile.dart';
import 'settings.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    ProfilePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(primary: Colors.red),
      textTheme: theme.textTheme.apply(fontFamily: 'NotoSansThai'),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey.shade600,
        elevation: 12,
        type: BottomNavigationBarType.fixed,
        // bigger icons and labels for better touch targets / readability
        selectedIconTheme: const IconThemeData(size: 32, color: Colors.red),
        unselectedIconTheme: IconThemeData(size: 28, color: Colors.grey.shade600),
        selectedLabelStyle: (theme.textTheme.bodySmall)
                ?.copyWith(fontWeight: FontWeight.w700, color: Colors.red, fontSize: 14) ??
            const TextStyle(fontWeight: FontWeight.w700, color: Colors.red, fontSize: 14),
        unselectedLabelStyle: (theme.textTheme.bodySmall)
                ?.copyWith(color: Colors.grey, fontSize: 13) ??
            const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        body: _pages[_selectedIndex],
        // larger bar height and iconSize to make buttons feel bigger
        bottomNavigationBar: SizedBox(
          height: 78,
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            iconSize: 32,
            showUnselectedLabels: true,
            // colors and styles now come from localTheme.bottomNavigationBarTheme
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'หน้าแรก',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'โปรไฟล์',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'ตั้งค่า',
              ),
            ],
          ),
        ),
      ),
    );
  }
}