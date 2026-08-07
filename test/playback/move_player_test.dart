import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/cube/cube_state.dart';
import 'package:rubicsolver/playback/move_player.dart';
import 'package:rubicsolver/solver/cube_solver.dart';
import 'package:rubicsolver/solver/solution_move.dart';

void main() {
  test('seek and previous rebuild exact cube state', () {
    final initial = CubeSolver.applyAlgorithm(CubeState.solved(), 'R U');
    final player = MovePlayer(
      initial: initial,
      moves: [SolutionMove("U'"), SolutionMove("R'")],
    );

    player.seek(2);
    expect(player.currentState, CubeState.solved());
    expect(player.currentIndex, 2);
    expect(player.isComplete, isTrue);

    player.previous();
    expect(player.currentIndex, 1);
    expect(player.currentState, CubeSolver.applyAlgorithm(initial, "U'"));
  });

  test('next and seek clamp to the available solution steps', () {
    final player = MovePlayer(
      initial: CubeState.solved(),
      moves: [SolutionMove('R')],
    );
    var notifications = 0;
    player.addListener(() => notifications++);

    player.previous();
    expect(player.currentIndex, 0);
    player.next();
    player.next();
    expect(player.currentIndex, 1);
    player.seek(-10);
    expect(player.currentIndex, 0);
    player.seek(10);
    expect(player.currentIndex, 1);
    expect(notifications, greaterThanOrEqualTo(3));
  });

  test('speed accepts the supported playback intervals', () {
    final player = MovePlayer(
      initial: CubeState.solved(),
      moves: [SolutionMove('R')],
    );

    player.speed = const Duration(milliseconds: 500);
    expect(player.speed, const Duration(milliseconds: 500));
    player.speed = const Duration(milliseconds: 1400);
    expect(player.speed, const Duration(milliseconds: 1400));
    expect(
      () => player.speed = const Duration(milliseconds: 100),
      throwsArgumentError,
    );
  });

  testWidgets('play advances on schedule and pauses at the end', (
    tester,
  ) async {
    final player = MovePlayer(
      initial: CubeState.solved(),
      moves: [SolutionMove('R'), SolutionMove("R'")],
      speed: const Duration(milliseconds: 500),
    );
    addTearDown(player.dispose);

    player.play();
    expect(player.isPlaying, isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    expect(player.currentIndex, 1);
    expect(player.isPlaying, isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    expect(player.currentIndex, 2);
    expect(player.isComplete, isTrue);
    expect(player.isPlaying, isFalse);
  });

  testWidgets('dispose cancels the playback timer', (tester) async {
    final player = MovePlayer(
      initial: CubeState.solved(),
      moves: [SolutionMove('R'), SolutionMove("R'")],
      speed: const Duration(milliseconds: 500),
    );
    var notifications = 0;
    player.addListener(() => notifications++);

    player.play();
    final beforeDispose = notifications;
    player.dispose();
    await tester.pump(const Duration(seconds: 2));

    expect(player.isPlaying, isFalse);
    expect(notifications, beforeDispose);
  });
}
