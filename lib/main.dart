import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'entities.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  img.Image? _originalImage;
  img.Image? _resizedImage;
  img.Image? _quantizedImage;
  bool _dragging = false;

  Board _originalBoard = Board.empty();
  late Board _currentBoard = _originalBoard.copy();

  bool _simulating = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) async {
        final dropItem = detail.files.single;

        final bytes = await dropItem.readAsBytes();

        final originalImage = img.decodeImage(bytes)!;
        final processingImage = img.decodeImage(bytes)!;

        img.copyResize(originalImage, width: 16 * 10);

        img.gaussianBlur(processingImage, radius: 8);

        img.adjustColor(
          processingImage,
          contrast: 1.5,
          saturation: 1.5,
        );

        final quantizedImage = img.quantize(
          processingImage,
          numberOfColors: 16,
        );

        setState(() {
          _originalImage = originalImage;
          _resizedImage = processingImage;
          _quantizedImage = quantizedImage;
        });

        // final pixels = <int>[];
        // for (int y = 0; y < resizeImg.height; y++) {
        //   for (int x = 0; x < resizeImg.width; x++) {
        //     // 画像のピクセルの色を取得
        //     final pixel = resizeImg.getPixel(x, y);

        //     pixels.add(
        //       ColorUtils.argbFromRgb(
        //         pixel.r.toInt(),
        //         pixel.g.toInt(),
        //         pixel.b.toInt(),
        //       ),
        //     );
        //   }
        // }
      },
      onDragEntered: (detail) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _dragging = false;
        });
      },
      child: Stack(
        children: [
          Scaffold(
            body: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      if (_originalImage != null)
                        Image.memory(
                          Uint8List.fromList(img.encodePng(_originalImage!)),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      if (_resizedImage != null)
                        Image.memory(
                          Uint8List.fromList(img.encodePng(_resizedImage!)),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      if (_quantizedImage != null)
                        Image.memory(
                          Uint8List.fromList(img.encodePng(_quantizedImage!)),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      Text(_originalImage?.hashCode.toString() ?? ''),
                      Text(_resizedImage?.hashCode.toString() ?? ''),
                      Text(_quantizedImage?.hashCode.toString() ?? ''),
                    ],
                  ),
                ),
                Expanded(
                  flex: 9,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Table(
                          border: TableBorder.all(),
                          defaultColumnWidth: const IntrinsicColumnWidth(),
                          children: [
                            for (int y = 0;
                                y < _currentBoard.tiles.boardMatrix.length;
                                y++)
                              TableRow(
                                children: [
                                  for (int x = 0;
                                      x <
                                          _currentBoard
                                              .tiles.boardMatrix[y].length;
                                      x++)
                                    TableCell(
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Material(
                                          color: _currentBoard.tiles
                                              .get(x, y)
                                              ?.color,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _currentBoard.excavate(x, y);
                                              });
                                            },
                                            child: Center(
                                              child: Text(
                                                "${_currentBoard.tiles.get(x, y)?.value}",
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _originalBoard = Board.generateRandomTiles();
                            _currentBoard = _originalBoard.copy();
                          });
                        },
                        child: const Text(
                          'Start',
                        ),
                      ),
                      ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _simulating = true;
                            });

                            final simulation = BoardSimulation(
                              originalBoard: _originalBoard.copy(),
                              simulationCount: 100,
                            );

                            simulation.execute().then((_) {
                              setState(() {
                                _simulating = false;
                                _currentBoard =
                                    simulation.bestResult.finalBoard;
                              });
                            });
                          },
                          child: const Text('Simulate')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_dragging)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
              ),
            ),
          if (_simulating)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
