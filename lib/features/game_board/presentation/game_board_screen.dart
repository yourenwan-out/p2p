import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:p2p_codenames/core/network/connection_provider.dart';
import 'package:p2p_codenames/features/game_board/providers/game_provider.dart';
import 'package:p2p_codenames/features/game_board/models/game_state.dart';
import 'package:p2p_codenames/features/game_board/models/word_card.dart';

/// Game board screen displaying the 5x5 grid
class GameBoardScreen extends ConsumerWidget {
  const GameBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final connectionState = ref.watch(connectionProvider);
    final gameNotifier = ref.read(gameProvider.notifier);
    final connectionNotifier = ref.read(connectionProvider.notifier);

    final myTeam = connectionState.isHost ? Team.red : Team.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Game Board - ${myTeam.name.toUpperCase()} Team',
          style: TextStyle(fontSize: 18.sp),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              'Current Turn: ${gameState.currentTurn.name.toUpperCase()}',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 25,
                itemBuilder: (context, index) {
                  final card = gameState.cards[index];
                  return GestureDetector(
                    onTap: () {
                      if (!card.isRevealed && gameState.currentTurn == myTeam && !gameState.isGameOver) {
                        // Send card flip
                        connectionNotifier.sendCardFlip(index);
                        // Locally reveal for immediate feedback
                        gameNotifier.revealCard(index);
                      }
                    },
                    child: Card(
                      color: card.isRevealed
                          ? _getCardColor(card.color)
                          : Colors.grey[300],
                      child: Center(
                        child: Text(
                          card.isRevealed ? '' : card.word,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: card.isRevealed ? Colors.white : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (gameState.isGameOver)
              Text(
                'Game Over! Winner: ${gameState.winner?.name.toUpperCase() ?? 'None'}',
                style: TextStyle(fontSize: 18.sp, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCardColor(CardColor color) {
    switch (color) {
      case CardColor.red:
        return Colors.red;
      case CardColor.blue:
        return Colors.blue;
      case CardColor.neutral:
        return Colors.grey;
      case CardColor.assassin:
        return Colors.black;
    }
  }
}