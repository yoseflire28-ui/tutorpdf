import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'files_screen.dart';
import 'ai_assistant_screen.dart';
import 'tools_screen.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    FilesScreen(),
    AiAssistantScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) async {
    if (index == 2) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // User is a guest! Redirect them to the AuthScreen login page
        final loggedIn = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              onAuthSuccess: () {
                Navigator.of(context).pop(true);
              },
            ),
          ),
        );
        if (loggedIn == true || FirebaseAuth.instance.currentUser != null) {
          setState(() {
            _selectedIndex = 2;
          });
        }
        return;
      }
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DC), // Cream App Canvas
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF3D3D3F), // Dark Charcoal container
        selectedItemColor: const Color(0xFFE65A4B), // Coral Red active
        unselectedItemColor: const Color(0xFFF9F6F0), // Off-White inactive
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_copy_rounded),
            label: 'Files',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_rounded),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_rounded),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
