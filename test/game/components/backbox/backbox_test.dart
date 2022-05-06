// ignore_for_file: cascade_invocations, prefer_const_constructors

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flame/input.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinball/game/components/backbox/bloc/backbox_bloc.dart';
import 'package:pinball/game/components/backbox/displays/displays.dart';
import 'package:pinball/game/game.dart';
import 'package:pinball/l10n/l10n.dart';
import 'package:pinball_components/pinball_components.dart';
import 'package:pinball_flame/pinball_flame.dart';
import 'package:pinball_theme/pinball_theme.dart' as theme;

class _TestGame extends Forge2DGame with HasKeyboardHandlerComponents {
  final character = theme.DashTheme();

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    await images.loadAll([
      character.leaderboardIcon.keyName,
      Assets.images.backbox.marquee.keyName,
      Assets.images.backbox.displayDivider.keyName,
    ]);
  }

  Future<void> pump(Backbox component) {
    return ensureAdd(
      FlameBlocProvider<GameBloc, GameState>.value(
        value: GameBloc(),
        children: [
          FlameProvider.value(
            _MockAppLocalizations(),
            children: [component],
          ),
        ],
      ),
    );
  }
}

class _MockRawKeyUpEvent extends Mock implements RawKeyUpEvent {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return super.toString();
  }
}

RawKeyUpEvent _mockKeyUp(LogicalKeyboardKey key) {
  final event = _MockRawKeyUpEvent();
  when(() => event.logicalKey).thenReturn(key);
  return event;
}

class _MockBackboxBloc extends Mock implements BackboxBloc {}

class _MockLeaderboardRepository extends Mock implements LeaderboardRepository {
}

class _MockAppLocalizations extends Mock implements AppLocalizations {
  @override
  String get score => '';

  @override
  String get name => '';

  @override
  String get enterInitials => '';

  @override
  String get arrows => '';

  @override
  String get andPress => '';

  @override
  String get enterReturn => '';

  @override
  String get toSubmit => '';

  @override
  String get loading => '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final flameTester = FlameTester(_TestGame.new);

  late BackboxBloc bloc;

  setUp(() {
    bloc = _MockBackboxBloc();
    whenListen(
      bloc,
      Stream.value(LoadingState()),
      initialState: LoadingState(),
    );
  });

  group('Backbox', () {
    flameTester.test(
      'loads correctly',
      (game) async {
        final backbox = Backbox.test(bloc: bloc);
        await game.pump(backbox);
        expect(game.descendants(), contains(backbox));
      },
    );

    flameTester.testGameWidget(
      'renders correctly',
      setUp: (game, tester) async {
        await game.onLoad();
        game.camera
          ..followVector2(Vector2(0, -130))
          ..zoom = 6;
        await game.pump(
          Backbox.test(bloc: bloc),
        );
        await tester.pump();
      },
      verify: (game, tester) async {
        await expectLater(
          find.byGame<_TestGame>(),
          matchesGoldenFile('../golden/backbox.png'),
        );
      },
    );

    flameTester.test(
      'requestInitials adds InitialsInputDisplay',
      (game) async {
        final backbox = Backbox.test(
          bloc: BackboxBloc(
            leaderboardRepository: _MockLeaderboardRepository(),
          ),
        );
        await game.pump(backbox);
        backbox.requestInitials(
          score: 0,
          character: game.character,
        );
        await game.ready();

        expect(
          backbox.descendants().whereType<InitialsInputDisplay>().length,
          equals(1),
        );
      },
    );

    flameTester.test(
      'adds PlayerInitialsSubmitted when initials are submitted',
      (game) async {
        final bloc = _MockBackboxBloc();
        final state = InitialsFormState(
          score: 10,
          character: game.character,
        );
        whenListen(
          bloc,
          Stream.value(state),
          initialState: state,
        );
        final backbox = Backbox.test(bloc: bloc);
        await game.pump(backbox);

        game.onKeyEvent(_mockKeyUp(LogicalKeyboardKey.enter), {});
        verify(
          () => bloc.add(
            PlayerInitialsSubmitted(
              score: 10,
              initials: 'AAA',
              character: game.character,
            ),
          ),
        ).called(1);
      },
    );

    flameTester.test(
      'adds InitialsSubmissionSuccessDisplay on InitialsSuccessState',
      (game) async {
        whenListen(
          bloc,
          Stream.value(InitialsSuccessState()),
          initialState: InitialsSuccessState(),
        );
        final backbox = Backbox.test(bloc: bloc);
        await game.pump(backbox);

        expect(
          game
              .descendants()
              .whereType<InitialsSubmissionSuccessDisplay>()
              .length,
          equals(1),
        );
      },
    );

    flameTester.test(
      'adds InitialsSubmissionFailureDisplay on InitialsFailureState',
      (game) async {
        whenListen(
          bloc,
          Stream.value(InitialsFailureState()),
          initialState: InitialsFailureState(),
        );
        final backbox = Backbox.test(bloc: bloc);
        await game.pump(backbox);

        expect(
          game
              .descendants()
              .whereType<InitialsSubmissionFailureDisplay>()
              .length,
          equals(1),
        );
      },
    );

    flameTester.test(
      'closes the subscription when it is removed',
      (game) async {
        final streamController = StreamController<BackboxState>();
        whenListen(
          bloc,
          streamController.stream,
          initialState: LoadingState(),
        );

        final backbox = Backbox.test(bloc: bloc);
        await game.pump(backbox);

        backbox.removeFromParent();
        await game.ready();

        streamController.add(InitialsFailureState());
        await game.ready();

        expect(
          backbox
              .descendants()
              .whereType<InitialsSubmissionFailureDisplay>()
              .isEmpty,
          isTrue,
        );
      },
    );
  });
}