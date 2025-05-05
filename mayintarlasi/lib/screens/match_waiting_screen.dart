import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchWaitingScreen extends StatefulWidget {
  final int durationInSeconds;

  const MatchWaitingScreen({super.key, required this.durationInSeconds});

  @override
  State<MatchWaitingScreen> createState() => _MatchWaitingScreenState();
}

class _MatchWaitingScreenState extends State<MatchWaitingScreen> {
  late final String currentUserId;
  late final CollectionReference matchmakingRef;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    matchmakingRef = FirebaseFirestore.instance.collection('matchmaking');

    _addSelfToQueue();
    _listenForMatch();
  }

  Future<void> _addSelfToQueue() async {
    final existing = await matchmakingRef
        .where('userId', isEqualTo: currentUserId)
        .where('duration', isEqualTo: widget.durationInSeconds)
        .where('matched', isEqualTo: false)
        .get();

    if (existing.docs.isEmpty) {
      await matchmakingRef.add({
        'userId': currentUserId,
        'duration': widget.durationInSeconds,
        'matched': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _listenForMatch() {
    matchmakingRef
        .where('duration', isEqualTo: widget.durationInSeconds)
        .where('matched', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      final docs = snapshot.docs;

      // Eğer 2 kullanıcı aynı süreyi seçmişse
      if (docs.length >= 2) {
        final myDocs = docs.where((doc) => doc['userId'] == currentUserId).toList();
        final others = docs.where((doc) => doc['userId'] != currentUserId).toList();

        if (myDocs.isEmpty || others.isEmpty) return;

        final myDoc = myDocs.first;
        final other = others.first;
        final otherUserId = other['userId'];

        final newGame = await FirebaseFirestore.instance.collection('games').add({
          'playerIds': [currentUserId, otherUserId],
          'duration': widget.durationInSeconds,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'turn': currentUserId,
        });


        await matchmakingRef.doc(myDoc.id).update({'matched': true});
        await matchmakingRef.doc(other.id).update({'matched': true});

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/game',
            arguments: {'gameId': newGame.id},
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text("Eşleşme bekleniyor..."),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // veriyi silmeden sadece ekrandan çık
              },
              child: const Text("Geri Dön"),
            ),
          ],
        ),
      ),
    );
  }
}
