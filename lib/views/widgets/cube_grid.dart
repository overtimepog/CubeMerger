import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/game_viewmodel.dart';
import '../../models/cube.dart';

class CubeGrid extends StatelessWidget {
  const CubeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GameViewModel>();
    final grid = viewModel.grid;

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            viewModel.moveCubes("right");
          } else {
            viewModel.moveCubes("left");
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            viewModel.moveCubes("down");
          } else {
            viewModel.moveCubes("up");
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: grid.size * grid.size,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: grid.size,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              int row = index ~/ grid.size;
              int col = index % grid.size;
              final cube = grid.cells[row][col];

              return CubeCell(cube: cube);
            },
          ),
        ),
      ),
    );
  }
}

class CubeCell extends StatelessWidget {
  final Cube cube;

  const CubeCell({
    super.key,
    required this.cube,
  });

  @override
  Widget build(BuildContext context) {
    Widget cellContent = Container(
      decoration: BoxDecoration(
        color: cube.getColor(),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: cube.isMoving ? 4 : 2,
            offset: const Offset(0, 2),
            spreadRadius: cube.isMoving ? 1 : 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          cube.isObstacle ? "X" : (cube.value?.toString() ?? ""),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: cube.isObstacle || cube.value == null
                ? Colors.white
                : Colors.white.withAlpha(230),
          ),
        ),
      ),
    );

    if (!cube.isMoving) return cellContent;

    return AnimatedBuilder(
      animation: context.read<GameViewModel>().animationController,
      builder: (context, child) {
        final controller = context.read<GameViewModel>().animationController;

        final moveAnimation = CurvedAnimation(
          parent: controller,
          curve: cube.isMerging ? Curves.easeInOutBack : Curves.easeOutCubic,
        );

        final scaleAnimation = Tween<double>(
          begin: cube.isMerging ? 1.0 : 0.8,
          end: cube.isMerging ? 1.2 : 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutBack,
        ));

        final rotateAnimation = Tween<double>(
          begin: 0.0,
          end: cube.isMerging ? 0.1 : 0.05,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ));

        return Transform(
          transform: Matrix4.identity()
            ..translate(
              cube.startPosition.dx +
                  (cube.endPosition.dx - cube.startPosition.dx) *
                      moveAnimation.value,
              cube.startPosition.dy +
                  (cube.endPosition.dy - cube.startPosition.dy) *
                      moveAnimation.value,
            )
            ..rotateZ(rotateAnimation.value)
            ..scale(scaleAnimation.value),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: cellContent,
    );
  }
}
