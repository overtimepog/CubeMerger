# Cubes Control

A Flutter puzzle game where players strategically slide and merge numbered cubes to clear levels. The goal is to consolidate cubes into a single cube or reach a target number while earning stars for efficiency.

## Features

- **Procedurally Generated Levels**: Each level is dynamically generated and guaranteed to be solvable
- **Star-Based Scoring**: Earn up to 3 stars based on how efficiently you solve each level
- **Smooth Animations**: Beautiful scaling animations when cubes merge
- **Obstacles**: Navigate around strategically placed obstacles
- **Progressive Difficulty**: Each new level increases the target number, making the game progressively challenging
- **In-Code Assets**: All visuals are built using Flutter widgets (no external assets required)

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (latest stable version)
- An IDE (VS Code, Android Studio, or IntelliJ)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/CubeMerger.git
   ```

2. Navigate to the project directory:
   ```bash
   cd CubeMerger
   ```

3. Get dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## How to Play

1. **Basic Movement**:
   - Swipe in any direction (up, down, left, right) to move all cubes
   - Cubes will slide until they hit a wall, obstacle, or another cube

2. **Merging**:
   - When two cubes with the same number collide, they merge into one cube
   - The new cube's value is the sum of the two merged cubes
   - Each cube can only merge once per move

3. **Winning**:
   - Reach the target number shown at the top of the screen
   - Try to use as few moves as possible to earn more stars
   - After completing a level, the target number doubles for the next challenge

4. **Obstacles**:
   - Black squares with 'X' marks are obstacles
   - Cubes cannot pass through obstacles
   - Use obstacles strategically to help align your cubes

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by classic number merging puzzle games
- Built with Flutter for cross-platform compatibility
