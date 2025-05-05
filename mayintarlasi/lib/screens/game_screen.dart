import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/letter_model.dart';
import 'dart:math';

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});


  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int boardSize = 15;
  late List<Letter> letterPool;
  List<Letter> myLetters = [];
  List<List<String?>> board = List.generate(15, (_) => List.filled(15, null));
  List<List<String?>> hiddenMines = List.generate(15, (_) => List.filled(15, null));
  Letter? selectedLetter;
  Set<String> validWords = {};

  @override
  void initState() {
    super.initState();
    letterPool = generateLetterPool();
    drawInitialLetters();
    loadWordList();
    placeHiddenMines();

    // Firestore board'u dinle (rakip hamle yaptıysa anlık güncelle)
    FirebaseFirestore.instance
        .collection('games')
        .doc(widget.gameId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data != null) {
        setState(() {
          board = List<List<String?>>.from(
            data['board'].map<List<String?>>((row) => List<String?>.from(row)),
          );
        });
      }
    });
  }

  Future<void> saveMoveAndUpdateGame(String gameId, List<Map<String, dynamic>> tiles, int score) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Oyunun dokümanını al
    final gameDoc = await FirebaseFirestore.instance.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) return;

    // Karşı oyuncunun ID'sini bul
    final players = List<String>.from(data['playerIds']);
    final otherUserId = players.firstWhere((id) => id != currentUserId);

    // Firestore board'unu hazırla (15x15 string matrix)
    final updatedBoard = board.map((row) => row.map((cell) => cell).toList()).toList();

    // Hamleyi moves alt koleksiyonuna kaydet
    await FirebaseFirestore.instance
        .collection('games')
        .doc(gameId)
        .collection('moves')
        .add({
      'playerId': currentUserId,
      'tiles': tiles,
      'word': tiles.map((e) => e['char']).join(),
      'score': score,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Oyun dokümanını güncelle
    await FirebaseFirestore.instance.collection('games').doc(gameId).update({
      'board': updatedBoard,
      'turn': otherUserId,
      'scores.$currentUserId': FieldValue.increment(score),
    });
  }


  List<Letter> generateLetterPool() {
    final Map<String, Map<String, int>> letterMap = {
      'A': {'count': 12, 'point': 1},
      'B': {'count': 2, 'point': 3},
      'C': {'count': 2, 'point': 4},
      'Ç': {'count': 2, 'point': 4},
      'D': {'count': 2, 'point': 3},
      'E': {'count': 8, 'point': 1},
      'F': {'count': 1, 'point': 7},
      'G': {'count': 1, 'point': 5},
      'Ğ': {'count': 1, 'point': 8},
      'H': {'count': 1, 'point': 5},
      'I': {'count': 4, 'point': 2},
      'İ': {'count': 7, 'point': 1},
      'J': {'count': 1, 'point': 10},
      'K': {'count': 7, 'point': 1},
      'L': {'count': 7, 'point': 1},
      'M': {'count': 4, 'point': 2},
      'N': {'count': 5, 'point': 1},
      'O': {'count': 3, 'point': 2},
      'Ö': {'count': 1, 'point': 7},
      'P': {'count': 1, 'point': 5},
      'R': {'count': 6, 'point': 1},
      'S': {'count': 3, 'point': 2},
      'Ş': {'count': 2, 'point': 4},
      'T': {'count': 5, 'point': 1},
      'U': {'count': 3, 'point': 2},
      'Ü': {'count': 2, 'point': 3},
      'V': {'count': 1, 'point': 7},
      'Y': {'count': 2, 'point': 3},
      'Z': {'count': 2, 'point': 4},
      'JOKER': {'count': 2, 'point': 0},
    };

    final List<Letter> pool = [];
    letterMap.forEach((char, data) {
      for (int i = 0; i < data['count']!; i++) {
        pool.add(Letter(char, data['point']!));
      }
    });

    pool.shuffle();
    return pool;
  }

  List<Map<String, dynamic>> getPlacedWordTiles() {
    // Arka arkaya gelen yatay veya dikey harfleri kontrol eder
    List<Map<String, dynamic>> wordTiles = [];

    // Önce yatay kontrol (soldan sağa)
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (board[row][col] != null) {
          List<Map<String, dynamic>> temp = [];
          int c = col;
          while (c < boardSize && board[row][c] != null) {
            temp.add({"char": board[row][c], "row": row, "col": c});
            c++;
          }
          if (temp.length > 1) return temp;
        }
      }
    }

    // Sonra dikey kontrol (yukarıdan aşağıya)
    for (int col = 0; col < boardSize; col++) {
      for (int row = 0; row < boardSize; row++) {
        if (board[row][col] != null) {
          List<Map<String, dynamic>> temp = [];
          int r = row;
          while (r < boardSize && board[r][col] != null) {
            temp.add({"char": board[r][col], "row": r, "col": col});
            r++;
          }
          if (temp.length > 1) return temp;
        }
      }
    }

    return wordTiles;
  }

  Letter? getLetterFromChar(String char) {
    for (var letter in myLetters + letterPool) {
      if (letter.char == char) return letter;
    }
    return null;
  }

  int calculateWordScore(List<Map<String, dynamic>> tiles) {
    int total = 0;
    int wordMultiplier = 1;
    bool puanTransfer = false;
    bool harfKaybi = false;
    bool kelimeIptal = false;
    bool hamleEngel = false;

    for (var tile in tiles) {
      final char = tile['char'];
      final row = tile['row'];
      final col = tile['col'];
      final letter = getLetterFromChar(char);
      int point = letter?.point ?? 0;

      final cellType = _getSpecialCell(row, col);
      final mine = hiddenMines[row][col];
      if (mine == 'hamle_engel') {
        hamleEngel = true;
      }

      if (!hamleEngel) {
        if (cellType == 'H²') point *= 2;
        if (cellType == 'H³') point *= 3;
        if (cellType == 'K²') wordMultiplier *= 2;
        if (cellType == 'K³') wordMultiplier *= 3;
      }

      total += point;
    }

    int finalScore = total * wordMultiplier;

    for (var tile in tiles) {
      final row = tile['row'];
      final col = tile['col'];
      final mine = hiddenMines[row][col];

      if (mine == 'puan_bol') {
        finalScore = (finalScore * 0.3).round();
        break;
      } else if (mine == 'puan_transfer') {
        puanTransfer = true;
        break;
      } else if (mine == 'harf_kaybi') {
        harfKaybi = true;
        break;
      } else if (mine == 'kelime_iptal') {
        kelimeIptal = true;
        break;
      }
    }

    if (kelimeIptal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text("Mayın Aktif!"),
            content: Text("Kelimenin puanı tamamen iptal edildi."),
          ),
        );
      });
      return 0;
    }

    if (puanTransfer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text("Mayın Aktif!"),
            content: Text("Puan rakibe aktarıldı!"),
          ),
        );
      });
      return 0;
    }

    if (harfKaybi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text("Mayın Aktif!"),
            content: Text("Kalan harfler sıfırlandı, yeni harfler verildi."),
          ),
        );
        setState(() {
          letterPool.addAll(myLetters);
          myLetters.clear();
          drawInitialLetters();
        });
      });
    }

    if (hamleEngel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text("Mayın Aktif!"),
            content: Text("Harf ve kelime çarpanları devre dışı bırakıldı."),
          ),
        );
      });
    }

    return finalScore;
  }

  void placeHiddenMines() {
    final rand = Random();
    int placed = 0;
    while (placed < 5) {
      int row = rand.nextInt(boardSize);
      int col = rand.nextInt(boardSize);
      if (hiddenMines[row][col] == null && _getSpecialCell(row, col) == null) {
        hiddenMines[row][col] = 'puan_bol';
        placed++;
      }
    }

    int transferCount = 0;
    while (transferCount < 4) {
      int row = rand.nextInt(boardSize);
      int col = rand.nextInt(boardSize);
      if (hiddenMines[row][col] == null && _getSpecialCell(row, col) == null) {
        hiddenMines[row][col] = 'puan_transfer';
        transferCount++;
      }
    }

    int harfKaybiCount = 0;
    while (harfKaybiCount < 3) {
      int row = rand.nextInt(boardSize);
      int col = rand.nextInt(boardSize);
      if (hiddenMines[row][col] == null && _getSpecialCell(row, col) == null) {
        hiddenMines[row][col] = 'harf_kaybi';
        harfKaybiCount++;
      }
    }

    int iptalCount = 0;
    while (iptalCount < 2) {
      int row = rand.nextInt(boardSize);
      int col = rand.nextInt(boardSize);
      if (hiddenMines[row][col] == null && _getSpecialCell(row, col) == null) {
        hiddenMines[row][col] = 'kelime_iptal';
        iptalCount++;
      }
    }

    int engelCount = 0;
    while (engelCount < 2) {
      int row = rand.nextInt(boardSize);
      int col = rand.nextInt(boardSize);
      if (hiddenMines[row][col] == null && _getSpecialCell(row, col) == null) {
        hiddenMines[row][col] = 'hamle_engel';
        engelCount++;
      }
    }
  }

  Future<void> loadWordList() async {
    final raw = await rootBundle.loadString('assets/kelimeler.txt');
    final lines = raw
        .split('\n')
        .map((e) => e.trim().toLowerCase()) // <= bu satır kritik
        .toSet();

    debugPrint("Kelime sayısı: ${lines.length}");
    debugPrint("İçeriyor mu 'zebani': ${lines.contains('zebani')}");
    setState(() {
      validWords = lines;
    });
  }


  void drawInitialLetters() {
    setState(() {
      myLetters = letterPool.take(7).toList();
      letterPool.removeRange(0, 7);
    });
  }

  // calculateWordScore ve placeHiddenMines buraya eklendi (güncel sürümde zaten var)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kelime Mayınları")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Text("Sen: 0"),
                Text("🎲 ${letterPool.length} Harf kaldı"),
                const Text("Rakip: 0"),
              ],
            ),
          ),
          Expanded(child: buildGameBoard()),
          buildPlayerLetters(),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final tiles = getPlacedWordTiles();
          final word = tiles.map((e) => e['char'].toLowerCase()).join();
          final isValid = validWords.contains(word);
          final score = isValid ? calculateWordScore(tiles) : 0;

          // Alerti göster
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Kelime Kontrolü"),
              content: Text(
                isValid
                    ? "$word geçerli! Toplam puan: $score"
                    : "$word geçerli değil!",
                style: TextStyle(color: isValid ? Colors.green : Colors.red),
              ),
            ),
          );

          if (isValid && score > 0) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            final gameId = args['gameId'];
            await saveMoveAndUpdateGame(gameId, tiles, score);
          }
        },
        child: const Icon(Icons.check),
      ),
    );
  }

  Widget buildGameBoard() {
    return GridView.builder(
      itemCount: boardSize * boardSize,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: boardSize),
      itemBuilder: (context, index) {
        final row = index ~/ boardSize;
        final col = index % boardSize;
        final special = _getSpecialCell(row, col);
        final placedLetter = board[row][col];

        return GestureDetector(
          onTap: () {
            if (selectedLetter != null && placedLetter == null) {
              setState(() {
                board[row][col] = selectedLetter!.char;
                myLetters.remove(selectedLetter);
                selectedLetter = null;
              });
            }
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: _getCellColor(special),
            ),
            child: Text(
              (placedLetter ?? special ?? '').toLowerCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: placedLetter != null ? Colors.black : Colors.grey.shade700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildPlayerLetters() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: myLetters.map((letter) {
          final isSelected = selectedLetter == letter;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedLetter = isSelected ? null : letter;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: isSelected ? Colors.red : Colors.black, width: 2),
                color: Colors.yellow.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(letter.char, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(letter.point.toString(), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String? _getSpecialCell(int row, int col) {
    if (row == 7 && col == 7) return '⭐';
    if ((row == col || row + col == 14) && (row % 4 == 0)) return 'H²';
    if ((row == 0 || row == 14 || col == 0 || col == 14) && (row % 7 == 0 || col % 7 == 0)) return 'K³';
    return null;
  }

  Color _getCellColor(String? special) {
    switch (special) {
      case 'H²': return Colors.lightBlue.shade200;
      case 'H³': return Colors.pink.shade200;
      case 'K²': return Colors.green.shade200;
      case 'K³': return Colors.brown.shade300;
      case '⭐': return Colors.orange.shade300;
      default: return Colors.grey.shade200;
    }
  }
}

