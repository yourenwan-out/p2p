import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/features/game_board/providers/game_provider.dart';
import 'package:p2p_codenames/features/game_board/models/game_state.dart';
import 'package:p2p_codenames/features/game_board/models/word_card.dart';
import 'package:p2p_codenames/features/game_board/models/player.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  final TextEditingController _clueWordController = TextEditingController();
  int _clueNumber = 1;

  @override
  void dispose() {
    _clueWordController.dispose();
    super.dispose();
  }

  void _sendClue() {
    final word = _clueWordController.text.trim();
    if (word.isEmpty || word.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال كلمة واحدة فقط بدون مسافات')),
      );
      return;
    }
    ref.read(connectionProvider.notifier).sendClue(word, _clueNumber);
    _clueWordController.clear();
    setState(() {
      _clueNumber = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final connectionState = ref.watch(connectionProvider);
    final connectionNotifier = ref.read(connectionProvider.notifier);

    Player? localPlayer;
    if (connectionState.localPlayerId != null) {
      try {
        localPlayer = connectionState.players.firstWhere((p) => p.id == connectionState.localPlayerId);
      } catch (e) {
        // Not found
      }
    }

    final int redLeft = 9 - gameState.cards.where((c) => c.color == CardColor.red && c.isRevealed).length;
    final int blueLeft = 8 - gameState.cards.where((c) => c.color == CardColor.blue && c.isRevealed).length;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        ref.read(connectionProvider.notifier).disconnect();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            localPlayer != null 
                ? 'الأسماء السرية - ${localPlayer.team == Team.red ? "الفريق الأحمر" : "الفريق الأزرق"}'
                : 'الأسماء السرية',
            style: TextStyle(fontSize: 18.sp),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              ref.read(connectionProvider.notifier).disconnect();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: SafeArea(
        child: Column(
          children: [
            // Score Board
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
              color: Colors.grey.shade200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الأحمر: $redLeft', style: TextStyle(color: Colors.red, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                  Text(
                    'دور: ${gameState.currentTurn == Team.red ? "الأحمر" : "الأزرق"}',
                    style: TextStyle(
                      fontSize: 20.sp, 
                      fontWeight: FontWeight.bold,
                      color: gameState.currentTurn == Team.red ? Colors.red : Colors.blue,
                    ),
                  ),
                  Text('الأزرق: $blueLeft', style: TextStyle(color: Colors.blue, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            // Clue and Controls Section
            if (localPlayer != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: _buildControls(localPlayer, gameState, connectionNotifier),
              ),

            // Game Board Grid
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: 25,
                  itemBuilder: (context, index) {
                    final card = gameState.cards[index];
                    final canClick = _canClickCard(card, localPlayer, gameState);
                    
                    return GestureDetector(
                      onTap: canClick ? () => connectionNotifier.sendCardFlip(index) : null,
                      child: Card(
                        color: _getCardColor(card, localPlayer),
                        elevation: card.isRevealed ? 1 : 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          side: BorderSide(
                            color: canClick ? Colors.lightGreen : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(2.w),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                card.word,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: card.isRevealed 
                                      ? Colors.white 
                                      : (localPlayer?.role == Role.spymaster ? _getTextColorForSpymaster(card.color) : Colors.black87),
                                  decoration: card.isRevealed ? TextDecoration.lineThrough : null,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Game Over Banner
            if (gameState.isGameOver)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.h),
                color: Colors.green.shade700,
                child: Column(
                  children: [
                    Text(
                      'انتهت اللعبة! الفائز: ${gameState.winner == Team.red ? "الفريق الأحمر" : "الفريق الأزرق"}',
                      style: TextStyle(fontSize: 22.sp, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (connectionState.isHost)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Add Rematch Logic
                            ref.read(gameProvider.notifier).resetGame();
                            connectionState.socketHost?.broadcastGameState(ref.read(gameProvider));
                          },
                          child: const Text('إعادة اللعب'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ));
  }

  Widget _buildControls(Player localPlayer, GameState gameState, ConnectionNotifier notifier) {
    if (gameState.isGameOver) {
      return const SizedBox.shrink();
    }

    if (localPlayer.role == Role.spymaster) {
      if (localPlayer.team != gameState.currentTurn) {
        return Text('بانتظار دور فريقك...', style: TextStyle(fontSize: 16.sp, color: Colors.grey));
      }
      if (gameState.currentClueWord != null) {
        return Text('لقد أعطيت تلميحاً! بانتظار العملاء...', style: TextStyle(fontSize: 16.sp, color: Colors.blueAccent));
      }
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _clueWordController,
              decoration: const InputDecoration(
                labelText: 'التلميح (كلمة واحدة)',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          DropdownButton<int>(
            value: _clueNumber,
            items: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 99].map((e) => DropdownMenuItem(
              value: e,
              child: Text(e == 99 ? 'غير محدود' : e.toString()),
            )).toList(),
            onChanged: (v) => setState(() => _clueNumber = v!),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: _sendClue,
            child: const Text('إرسال'),
          ),
        ],
      );
    } else {
      // Operative UI
      if (gameState.currentClueWord == null) {
        return Text('الرئيس يفكر بالتلميح...', style: TextStyle(fontSize: 16.sp, fontStyle: FontStyle.italic));
      }
      
      int maxGuesses = gameState.currentClueNumber == 99 ? 99 : (gameState.currentClueNumber! + 1);
      bool canPass = localPlayer.team == gameState.currentTurn && 
                     gameState.remainingGuesses < maxGuesses;

      return Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.yellow.shade100,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'التلميح: ${gameState.currentClueWord} (${gameState.currentClueNumber == 99 ? "∞" : gameState.currentClueNumber})', 
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              'متبقي: ${gameState.remainingGuesses == 99 ? "∞" : gameState.remainingGuesses}', 
              style: TextStyle(fontSize: 14.sp, color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            if (canPass) ...[
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: () => notifier.sendPassTurn(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('إنهاء الدور'),
              ),
            ]
          ],
        ),
      );
    }
  }

  bool _canClickCard(WordCard card, Player? localPlayer, GameState gameState) {
    if (card.isRevealed) return false;
    if (gameState.isGameOver) return false;
    if (localPlayer == null) return false;
    if (localPlayer.role != Role.operative) return false;
    if (gameState.currentTurn != localPlayer.team) return false;
    if (gameState.currentClueWord == null) return false;
    if (gameState.remainingGuesses <= 0) return false;
    return true;
  }

  Color _getCardColor(WordCard card, Player? localPlayer) {
    if (card.isRevealed) {
      return _getTrueColor(card.color);
    }
    if (localPlayer?.role == Role.spymaster) {
      return _getTrueColor(card.color).withValues(alpha: 0.2); // Translucent color for Spymaster
    }
    return Colors.amber.shade100; // Neutral cardboard color for unrevealed
  }

  Color _getTrueColor(CardColor color) {
    switch (color) {
      case CardColor.red: return Colors.red.shade400;
      case CardColor.blue: return Colors.blue.shade400;
      case CardColor.neutral: return Colors.brown.shade300;
      case CardColor.assassin: return Colors.black87;
    }
  }

  Color _getTextColorForSpymaster(CardColor color) {
    switch (color) {
      case CardColor.red: return Colors.red.shade900;
      case CardColor.blue: return Colors.blue.shade900;
      case CardColor.neutral: return Colors.brown.shade900;
      case CardColor.assassin: return Colors.black;
    }
  }
}