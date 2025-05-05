import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveGamesScreen extends StatelessWidget {
  const ActiveGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Aktif Oyunlar")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .where('playerIds', arrayContains: currentUserId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final games = snapshot.data?.docs ?? [];

          if (games.isEmpty) {
            return const Center(child: Text("Aktif oyun bulunamadı."));
          }

          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              final data = game.data() as Map<String, dynamic>;
              final players = data['playerIds'] as List<dynamic>;
              final scores = data['scores'] ?? {}; // {'uid1': 2, 'uid2': 1}
              final turn = data['turn'];

              final otherUserId = players.firstWhere((id) => id != currentUserId);
              final currentScore = scores[currentUserId] ?? 0;
              final otherScore = scores[otherUserId] ?? 0;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  String opponentName = "Yükleniyor...";
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    opponentName = userSnapshot.data!.get('username') ?? 'Rakip';
                  }

                  return ListTile(
                    title: Text("Rakip: $opponentName"),
                    subtitle: Text("Sen: $currentScore - Rakip: $otherScore\nSıra: ${turn == currentUserId ? 'Sende' : opponentName}"),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.pushNamed(context, '/game', arguments: {
                        'gameId': game.id,
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
