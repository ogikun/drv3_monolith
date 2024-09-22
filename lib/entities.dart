import 'dart:math';

import 'package:collection/collection.dart';
import 'package:drv3_monolith/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// タイルの座標を表す型
typedef TileCoord = ({int x, int y});

/// ゲーム画面のボードを表すクラス
@immutable
class Board {
  Board._(
    this.tiles,
  ) : tileGroups = tiles.getTileGroups();

  final BoardMatrix tiles;
  final Set<TileGroup> tileGroups;

  /// 空のボードを生成する
  factory Board.empty() {
    return Board._(
      BoardMatrix(
        List.generate(
          yCount,
          (y) => List.generate(
            xCount,
            (x) => Tile(coord: (x: x, y: y), value: 0),
          ),
        ),
      ),
    );
  }

  factory Board.generateRandomTiles() {
    return Board._(BoardMatrix(
      List.generate(
        yCount,
        (y) => List.generate(
          xCount,
          (x) => Tile(
              coord: (x: x, y: y), value: Random().nextInt(maxTileValue) + 1),
        ),
      ),
    ));
  }

  void excavate(int x, int y) {
    final targetTile = tiles.get(x, y);

    final targetGroup =
        tileGroups.firstWhereOrNull((e) => e.tiles.contains(targetTile));

    for (final tile in targetGroup?.tiles ?? {}) {
      tiles.set(tile.coord.x, tile.coord.y, value: 0);
    }

    for (final affectedCoords in targetGroup?.affectedCoords ?? {}) {
      final affectedTile = tiles.get(affectedCoords.x, affectedCoords.y);
      if (affectedTile == null || affectedTile.value == 0) {
        continue;
      }

      final int nextValue;

      if (affectedTile.value == maxTileValue) {
        nextValue = 1;
      } else {
        nextValue = affectedTile.value + 1;
      }

      tiles.set(affectedCoords.x, affectedCoords.y, value: nextValue);
    }

    _refreshTileGroups();
  }

  Board copy() {
    return Board._(
      BoardMatrix(
        List.generate(
          yCount,
          (y) => List.generate(
            xCount,
            (x) => tiles.get(x, y) ?? Tile(coord: (x: x, y: y), value: 0),
          ),
        ),
      ),
    );
  }

  /// タイルグループ生成する
  void _refreshTileGroups() {
    tileGroups.clear();
    tileGroups.addAll(tiles.getTileGroups());
  }
}

@immutable
class BoardMatrix {
  const BoardMatrix(
    this.boardMatrix,
  );

  final List<List<Tile>> boardMatrix;

  int get remainingTileCount {
    return boardMatrix.expand((e) => e).where((e) => e.value != 0).length;
  }

  /// 指定した座標のタイルを取得する
  ///
  /// 座標が範囲外の場合はnullを返す
  Tile? get(int x, int y) {
    try {
      return boardMatrix[y][x];
    } on RangeError {
      return null;
    }
  }

  /// 指定した座標のタイルを書き換える
  void set(int x, int y, {required int value}) {
    boardMatrix[y][x] = Tile(coord: (x: x, y: y), value: value);
  }

  Set<TileGroup> getTileGroups() {
    final tileGroups = <TileGroup>{};
    final evaluatedCoords = <TileCoord>{};
    for (int y = 0; y < boardMatrix.length; y++) {
      for (int x = 0; x < boardMatrix[y].length; x++) {
        if (boardMatrix[y][x].value == 0) {
          continue;
        }
        if (evaluatedCoords.contains((x: x, y: y))) {
          continue;
        }

        final group = _getGroupOf(x, y);

        if (group != null) {
          evaluatedCoords.addAll(group.tiles.map((e) => e.coord));
          tileGroups.add(group);
        }
      }
    }
    return tileGroups;
  }

  /// 指定した座標のタイルを含むグループを取得する
  TileGroup? _getGroupOf(int x, int y) {
    final targetTile = get(x, y);

    if (targetTile == null) {
      return null;
    }

    if (targetTile.value < 1 || maxTileValue < targetTile.value) {
      return null;
    }

    var groupedTiles = <Tile>{targetTile};

    final evaluatedTiles = <Tile>{};
    var completed = false;
    while (!completed) {
      final newGroupedTiles = groupedTiles.expand((e) {
        if (evaluatedTiles.contains(e)) {
          return {e};
        }

        evaluatedTiles.add(e);

        final up = get(e.coord.x, e.coord.y - 1);
        final down = get(e.coord.x, e.coord.y + 1);
        final left = get(e.coord.x - 1, e.coord.y);
        final right = get(e.coord.x + 1, e.coord.y);

        return {
          e,
          if (up != null && up.value == targetTile.value) up,
          if (down != null && down.value == targetTile.value) down,
          if (left != null && left.value == targetTile.value) left,
          if (right != null && right.value == targetTile.value) right,
        };
      }).toSet();

      if (setEquals(groupedTiles, newGroupedTiles)) {
        completed = true;
      } else {
        groupedTiles = newGroupedTiles;
      }
    }

    if (groupedTiles.length < 2) {
      return null;
    }

    return TileGroup(tiles: groupedTiles);
  }
}

/// タイルを表すクラス
@immutable
class Tile {
  const Tile({
    required this.coord,
    required this.value,
  });

  final TileCoord coord;
  final int value;

  get color => switch (value) {
        1 => Colors.white,
        2 => Colors.pink,
        3 => Colors.yellow,
        4 => Colors.blue,
        _ => Colors.brown,
      };
}

@immutable
class TileGroup {
  const TileGroup._({
    required this.tiles,
    required this.affectedCoords,
  });

  factory TileGroup({required Set<Tile> tiles}) {
    final tileCoords = tiles
        .map(
          (e) => e.coord,
        )
        .toSet();

    final affectedCoords = tileCoords
        .expand(
          (e) => {
            if (e.y + 1 <= yCount) (x: e.x, y: e.y + 1),
            if (e.x - 1 >= 0) (x: e.x - 1, y: e.y),
            if (e.x + 1 <= xCount) (x: e.x + 1, y: e.y),
            if (e.y - 1 >= 0) (x: e.x, y: e.y - 1),
          },
        )
        .toSet();

    affectedCoords.removeAll(tileCoords);

    return TileGroup._(
      tiles: tiles,
      affectedCoords: affectedCoords,
    );
  }

  final Set<Tile> tiles;
  final Set<TileCoord> affectedCoords;
}

/// シミュレーション
@immutable
class BoardSimulation {
  BoardSimulation({
    required this.originalBoard,
    required this.simulationCount,
  }) : results = [];

  final Board originalBoard;
  final int simulationCount;
  final List<BoardSimulationResult> results;

  Future<void> execute() async {
    Future<BoardSimulationResult> simulate(Board originalBoard) async {
      return compute<Board, BoardSimulationResult>((board) async {
        return Future(() {
          final simulatingBoard = board.copy();
          final logs = <TileCoord>[];
          while (simulatingBoard.tileGroups.isNotEmpty) {
            final targetIndex =
                Random().nextInt(simulatingBoard.tileGroups.length);
            final target = simulatingBoard.tileGroups.toList()[targetIndex];

            simulatingBoard.excavate(
              target.tiles.first.coord.x,
              target.tiles.first.coord.y,
            );

            logs.add((
              x: target.tiles.first.coord.x,
              y: target.tiles.first.coord.y,
            ));
          }

          return BoardSimulationResult(
            finalBoard: simulatingBoard,
            logs: logs,
            remainingTileCount: simulatingBoard.tiles.remainingTileCount,
          );
        });
      }, originalBoard);
    }

    results.clear();

    final newResults = await compute((board) async {
      return await Future.wait([
        for (int i = 0; i < simulationCount; i++) simulate(board),
      ]);
    }, originalBoard);

    results.addAll(newResults);
  }

  BoardSimulationResult get bestResult {
    return results.reduce((a, b) {
      return a.remainingTileCount < b.remainingTileCount ? a : b;
    });
  }
}

/// シミュレーション結果
@immutable
class BoardSimulationResult {
  const BoardSimulationResult({
    required this.finalBoard,
    required this.logs,
    required this.remainingTileCount,
  });

  final Board finalBoard;
  final List<TileCoord> logs;
  final int remainingTileCount;
}
