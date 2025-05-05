import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _username;
  int _wonGames = 0;
  int _totalGames = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _username = data?['username'] ?? 'Kullanıcı';
          _wonGames = data?['wonGames'] ?? 0;
          _totalGames = data?['totalGames'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _username = "Bilinmeyen";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _username = "Hata";
        _isLoading = false;
      });
    }
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  double _calculateSuccessRate() {
    if (_totalGames == 0) return 0.0;
    return (_wonGames / _totalGames) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ana Sayfa"),
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            tooltip: "Çıkış Yap",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Hoş geldin, ${_username ?? ''}!",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Başarı Yüzdesi: ${_calculateSuccessRate().toStringAsFixed(1)}%",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),

            // --- Butonlar ---
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/new-game'),
              child: const Text("Yeni Oyun"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/active-games'),
              child: const Text("Aktif Oyunlar"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/finished-games'),
              child: const Text("Biten Oyunlar"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}
