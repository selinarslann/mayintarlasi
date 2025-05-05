import 'package:flutter/material.dart';

class NewGameScreen extends StatelessWidget {
  const NewGameScreen({super.key});

  void _selectDuration(BuildContext context, int seconds) {
    Navigator.pushNamed(
      context,
      '/match-waiting',
      arguments: {'durationInSeconds': seconds},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Oyun Süresi Seç")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Hızlı Oyun",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _selectDuration(context, 120),
              child: const Text("2 Dakika"),
            ),
            ElevatedButton(
              onPressed: () => _selectDuration(context, 300),
              child: const Text("5 Dakika"),
            ),
            const SizedBox(height: 24),
            const Text(
              "Genişletilmiş Oyun",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _selectDuration(context, 43200),
              child: const Text("12 Saat"),
            ),
            ElevatedButton(
              onPressed: () => _selectDuration(context, 86400),
              child: const Text("24 Saat"),
            ),
          ],
        ),
      ),
    );
  }
}
