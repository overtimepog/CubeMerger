import json
import random
from typing import List, Dict, Tuple
from collections import deque
from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor, as_completed
from halo import Halo
import time
from datetime import datetime, timedelta

############################################################
# 1. ADVANCED MASK GENERATION (MORE SHAPES)
############################################################

def generate_noise_mask(size: int, fill_prob: float = 0.45, smoothing_iterations: int = 3) -> List[List[bool]]:
    """
    Creates a random 'noisy' True/False mask and smooths it
    with a simple cellular-automaton step.
    """
    mask = [[(random.random() < fill_prob) for _ in range(size)] for _ in range(size)]
    
    def count_true_neighbors(g, x, y):
        count = 0
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and g[nx][ny]:
                    count += 1
        return count
    
    for _ in range(smoothing_iterations):
        new_mask = deepcopy(mask)
        for i in range(size):
            for j in range(size):
                neighbors = count_true_neighbors(mask, i, j)
                # If fewer than 4 neighbors are True, cell -> False
                new_mask[i][j] = (neighbors >= 4)
        mask = new_mask
    
    return mask

def generate_random_walk_mask(size: int, steps: int = None) -> List[List[bool]]:
    """
    Creates a mask (True/False) by randomly 'walking' from the center.
    True cells = visited cells.
    """
    if steps is None:
        steps = (size * size) // 2
    
    mask = [[False] * size for _ in range(size)]
    x, y = size // 2, size // 2
    mask[x][y] = True
    
    for _ in range(steps):
        dx, dy = random.choice([(1,0), (-1,0), (0,1), (0,-1)])
        x = max(0, min(size - 1, x + dx))
        y = max(0, min(size - 1, y + dy))
        mask[x][y] = True
    
    return mask

def generate_diamond_mask(size: int) -> List[List[bool]]:
    """
    Diamond shape: cells for which manhattan_distance(center) <= center
    If size=5, center=2, it forms a diamond from (2,2).
    """
    mask = [[False]*size for _ in range(size)]
    mid = size // 2
    for i in range(size):
        for j in range(size):
            if abs(i - mid) + abs(j - mid) <= mid:
                mask[i][j] = True
    return mask

def generate_circle_mask(size: int) -> List[List[bool]]:
    """
    Approximate circle mask.
    (i - mid)^2 + (j - mid)^2 <= radius^2
    """
    mask = [[False]*size for _ in range(size)]
    mid = (size - 1) / 2.0
    radius = size / 2.0 - 0.5  # slightly smaller
    for i in range(size):
        for j in range(size):
            dist_sq = (i - mid)**2 + (j - mid)**2
            if dist_sq <= radius**2:
                mask[i][j] = True
    return mask

def generate_cross_mask(size: int) -> List[List[bool]]:
    """
    A plus-shaped cross: A vertical and horizontal band around the center.
    """
    mask = [[False]*size for _ in range(size)]
    arm_thickness = size // 5 or 1  # minimal thickness=1
    mid = size // 2
    for i in range(size):
        for j in range(size):
            # If within arm_thickness of center row or center column
            if abs(i - mid) <= arm_thickness or abs(j - mid) <= arm_thickness:
                mask[i][j] = True
    return mask

def create_shape_mask(size: int) -> List[List[bool]]:
    """
    Master shape function. Chooses from multiple shapes: noise, walk, diamond,
    circle, cross.
    """
    shapes = ["noise", "walk", "diamond", "circle", "cross"]
    shape_type = random.choice(shapes)
    
    if shape_type == "noise":
        return generate_noise_mask(size, fill_prob=0.45, smoothing_iterations=3)
    elif shape_type == "walk":
        return generate_random_walk_mask(size)
    elif shape_type == "diamond":
        return generate_diamond_mask(size)
    elif shape_type == "circle":
        return generate_circle_mask(size)
    elif shape_type == "cross":
        return generate_cross_mask(size)
    else:
        # fallback: full square
        return [[True]*size for _ in range(size)]

############################################################
# 2. OBSTACLES & PAIR PLACEMENT
############################################################

def place_clustered_obstacles(
    grid: List[List[str]], 
    valid_cells: List[Tuple[int,int]], 
    num_clusters: int = 1, 
    cluster_size: int = 2
) -> None:
    """
    Places 'X' obstacles in a *small* number of clusters
    to avoid blocking the entire puzzle. BFS-based approach.
    """
    size = len(grid)
    queue_type = deque

    for _ in range(num_clusters):
        if not valid_cells:
            break
        seed = random.choice(valid_cells)
        queue = queue_type([seed])
        visited = {seed}
        placed = 0
        
        while queue and placed < cluster_size:
            x, y = queue.popleft()
            if grid[x][y] == "":
                grid[x][y] = "X"
                valid_cells.remove((x, y))
                placed += 1
            
            for dx, dy in [(-1,0), (1,0), (0,-1), (0,1)]:
                nx, ny = x + dx, y + dy
                if (0 <= nx < size and 0 <= ny < size and
                    (nx, ny) not in visited and (nx, ny) in valid_cells):
                    visited.add((nx, ny))
                    queue.append((nx, ny))

def can_connect(grid: List[List[str]], p1: Tuple[int,int], p2: Tuple[int,int]) -> bool:
    """
    Checks if p1 and p2 are in the same row or column,
    with no 'X' in between.
    """
    x1, y1 = p1
    x2, y2 = p2
    
    # same row
    if x1 == x2:
        start, end = sorted([y1, y2])
        for col in range(start+1, end):
            if grid[x1][col] == "X":
                return False
        return True
    
    # same column
    if y1 == y2:
        start, end = sorted([x1, x2])
        for row in range(start+1, end):
            if grid[row][y1] == "X":
                return False
        return True
    
    return False

############################################################
# 3. SOLVABILITY CHECK (BACKTRACKING)
############################################################

def find_pairs(grid: List[List[str]]) -> Dict[str, List[Tuple[int,int]]]:
    """
    Returns a mapping { '2': [(x1,y1), (x2,y2), ...], '4': [...], ... }
    skipping 'X' and '' cells.
    """
    pairs_map = {}
    size = len(grid)
    for i in range(size):
        for j in range(size):
            val = grid[i][j]
            if val not in ("", "X"):  # so it's a number
                pairs_map.setdefault(val, []).append((i, j))
    return pairs_map

def puzzle_solvable(grid: List[List[str]]) -> bool:
    """
    A backtracking solver that tries to remove pairs (same number)
    if they can connect in a straight line (row/col). 
    If all pairs can be removed, returns True; else False.
    """
    grid_copy = deepcopy(grid)
    pairs_map = find_pairs(grid_copy)
    
    # If no numbered cells remain, puzzle is solved
    if not pairs_map:
        return True
    
    # Try each pair among the coordinates for each number
    for val, coords in pairs_map.items():
        n = len(coords)
        # Might have multiple occurrences of the same number
        # We'll try each distinct pair.
        for i in range(n):
            for j in range(i+1, n):
                p1, p2 = coords[i], coords[j]
                if can_connect(grid_copy, p1, p2):
                    # Remove them
                    x1, y1 = p1
                    x2, y2 = p2
                    saved_val = val
                    grid_copy[x1][y1] = ""
                    grid_copy[x2][y2] = ""
                    
                    if puzzle_solvable(grid_copy):
                        return True
                    
                    # backtrack
                    grid_copy[x1][y1] = saved_val
                    grid_copy[x2][y2] = saved_val
    
    # If no solution found
    return False

############################################################
# 4. LEVEL GENERATION
############################################################

def get_grid_size(level: int) -> int:
    """
    Basic logic to choose grid size.
    - 1-25 => 5x5
    - 26-50 => 7x7
    - 51-100 => 8x8
    - 101+ => 10x10
    """
    if level > 100:
        return 10
    elif level > 50:
        return 8
    elif level > 25:
        return 7
    else:
        return 5

def get_possible_values(level: int) -> List[int]:
    """
    Which numbers can appear. 
    Higher level => more possible numbers.
    """
    values = [2, 4]
    if level > 5:   values.append(8)
    if level > 15:  values.append(16)
    if level > 25:  values.append(32)
    if level > 35:  values.append(64)
    return values

def generate_level(level_number: int, max_tries: int = 30) -> List[List[str]]:
    """
    - Create a shape (True/False mask) from multiple shape types.
    - Mark out-of-shape as 'X'.
    - Place a *small* cluster of BFS obstacles.
    - Place pairs with guaranteed direct line.
    - If puzzle_solvable => done. Otherwise, retry up to max_tries.
    Returns a 2D list of strings representing the puzzle.
    """
    size = get_grid_size(level_number)
    possible_values = get_possible_values(level_number)
    
    for attempt in range(1, max_tries + 1):
        # 1) Generate shape mask
        mask = create_shape_mask(size)
        
        # 2) Build initial grid
        grid = []
        for i in range(size):
            row = []
            for j in range(size):
                if mask[i][j]:
                    row.append("")  # playable
                else:
                    row.append("X") # out-of-shape => obstacle
            grid.append(row)
        
        # 3) Place BFS obstacles (tiny cluster)
        valid_cells = [(x, y) for x in range(size) for y in range(size)
                       if grid[x][y] == ""]
        if len(valid_cells) < 2:
            # Not enough to place pairs at all
            continue
        
        # Just 1 cluster, size 2 obstacles
        place_clustered_obstacles(grid, valid_cells, 
                                  num_clusters=1, 
                                  cluster_size=2)
        
        # Re-check empties
        available = [(x, y) for x in range(size) for y in range(size)
                     if grid[x][y] == ""]
        
        # 4) Place pairs
        max_pairs = len(available)//2
        desired_pairs = (level_number // 3) + 2
        num_pairs = min(desired_pairs, max_pairs)
        
        for _ in range(num_pairs):
            if len(available) < 2:
                break
            val = str(random.choice(possible_values))
            
            # pick first cell
            p1 = random.choice(available)
            available.remove(p1)
            grid[p1[0]][p1[1]] = val
            
            # possible second positions that can connect in row/col
            valid_seconds = []
            for p2 in available:
                if can_connect(grid, p1, p2):
                    valid_seconds.append(p2)
            
            if valid_seconds:
                p2 = random.choice(valid_seconds)
                available.remove(p2)
                grid[p2[0]][p2[1]] = val
            else:
                # revert if no valid second cell
                grid[p1[0]][p1[1]] = ""
                available.append(p1)
        
        # 5) Check solvability
        if puzzle_solvable(grid):
            return grid
    
    # If we exit the loop, no solvable puzzle found
    fallback = [["X"]*size for _ in range(size)]
    if size >= 2:
        fallback[0][0] = "2"
        fallback[0][1] = "2"
    return fallback

def generate_levels(num_levels: int = 100, max_workers: int = None) -> Dict[str, List[List[str]]]:
    """
    Builds a dict of { '1': [ [...] \n, [...] \n, ... ], '2': [...] \n, ... },
    each puzzle is a 2D list of strings (rows).
    Uses ThreadPoolExecutor for parallel processing with progress visualization.
    """
    all_levels = {}
    completed = 0
    start_time = time.time()
    
    def generate_level_task(lvl):
        puzzle_2d = generate_level(lvl, max_tries=30)
        return str(lvl), puzzle_2d
    
    spinner = Halo(text='Generating levels', spinner='dots')
    spinner.start()
    
    try:
        # If max_workers is None, ThreadPoolExecutor will choose based on CPU count
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            future_to_level = {
                executor.submit(generate_level_task, lvl): lvl 
                for lvl in range(1, num_levels + 1)
            }
            
            # Process completed tasks as they finish
            for future in as_completed(future_to_level):
                level_num, puzzle = future.result()
                all_levels[level_num] = puzzle
                completed += 1
                
                # Calculate ETA
                elapsed = time.time() - start_time
                rate = completed / elapsed
                remaining = num_levels - completed
                eta_seconds = remaining / rate if rate > 0 else 0
                eta = str(timedelta(seconds=int(eta_seconds)))
                
                # Update spinner text with progress and ETA
                progress = (completed / num_levels) * 100
                spinner.text = f'Generating levels: {completed}/{num_levels} ({progress:.1f}%) - ETA: {eta}'
    
    finally:
        spinner.stop_and_persist(symbol='✓', text=f'Generated {completed} levels in {time.time() - start_time:.1f}s')
    
    return all_levels

if __name__ == "__main__":
    # Generate 100 levels
    print("Starting level generation...")
    levels = generate_levels(100)
    
    print("\nSaving levels to JSON...")
    spinner = Halo(text='Writing to file', spinner='dots')
    spinner.start()
    
    try:
        # Custom JSON encoder to format arrays with newlines
        class PrettyJSONEncoder(json.JSONEncoder):
            def encode(self, obj):
                if isinstance(obj, dict):
                    items = []
                    for key, value in obj.items():
                        # Format each puzzle grid
                        formatted_grid = "[\n      " + ",\n      ".join(json.dumps(row) for row in value) + "\n    ]"
                        items.append(f'"{key}": {formatted_grid}')
                    return "{\n  " + ",\n  ".join(items) + "\n}"
                return super().encode(obj)
        
        # Dump to JSON with custom formatting
        with open("lib/levels.json", "w") as f:
            json.dump(levels, f, cls=PrettyJSONEncoder)
        
        spinner.stop_and_persist(symbol='✓', text='Saved puzzle levels to lib/levels.json')
    except Exception as e:
        spinner.fail(text=f'Failed to save levels: {str(e)}') 