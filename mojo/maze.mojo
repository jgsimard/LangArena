from helper import Helper
from benchmark import Benchmark, Config

comptime MAZE_WALL = 0
comptime MAZE_SPACE = 1
comptime MAZE_START = 2
comptime MAZE_FINISH = 3
comptime MAZE_BORDER = 4


struct _MazeCell(Copyable):
    var kind: Int
    var x: Int
    var y: Int
    var neighbors: List[Tuple[Int, Int]]
    var neighbor_count: Int

    def __init__(out self, x: Int, y: Int):
        self.kind = MAZE_WALL
        self.x = x
        self.y = y
        self.neighbors = List[Tuple[Int, Int]](capacity=4)
        self.neighbor_count = 0

    def is_walkable(self) -> Bool:
        return (
            self.kind == MAZE_SPACE
            or self.kind == MAZE_START
            or self.kind == MAZE_FINISH
        )

    def is_wall(self) -> Bool:
        return self.kind == MAZE_WALL

    def is_space(self) -> Bool:
        return self.kind == MAZE_SPACE

    def reset(mut self):
        if self.kind == MAZE_SPACE:
            self.kind = MAZE_WALL


struct _PriorityQueue(Movable):
    var heap: List[Tuple[Int, Int]]
    var best: List[Int]

    def __init__(out self, size: Int):
        self.heap = List[Tuple[Int, Int]]()
        self.best = List[Int](length=size, fill=2147483647)

    def empty(self) -> Bool:
        return len(self.heap) == 0

    def push(mut self, vertex: Int, priority: Int):
        if priority >= self.best[vertex]:
            return
        self.best[vertex] = priority
        self.heap.append((vertex, priority))
        var i = len(self.heap) - 1
        while i > 0:
            var parent = (i - 1) // 2
            if self.heap[parent][1] <= priority:
                break
            var tmp = self.heap[i]
            self.heap[i] = self.heap[parent]
            self.heap[parent] = tmp
            i = parent

    def pop(mut self) -> Tuple[Int, Int]:
        var min_val = self.heap[0]
        var last = self.heap[len(self.heap) - 1]
        _ = self.heap.pop()
        if len(self.heap) > 0:
            self.heap[0] = last
            var i = 0
            while True:
                var left = 2 * i + 1
                var right = 2 * i + 2
                var smallest = i
                if (
                    left < len(self.heap)
                    and self.heap[left][1] < self.heap[smallest][1]
                ):
                    smallest = left
                if (
                    right < len(self.heap)
                    and self.heap[right][1] < self.heap[smallest][1]
                ):
                    smallest = right
                if smallest == i:
                    break
                var tmp = self.heap[i]
                self.heap[i] = self.heap[smallest]
                self.heap[smallest] = tmp
                i = smallest
        return min_val


struct MazeGenerator(Benchmark, Movable):
    var w: Int
    var h: Int
    var cells: List[List[_MazeCell]]
    var start_x: Int
    var start_y: Int
    var finish_x: Int
    var finish_y: Int
    var result: UInt32

    def __init__(out self, config: Config) raises:
        self.w = config.get_i64("Maze::Generator", "w")
        self.h = config.get_i64("Maze::Generator", "h")

        if self.w < 5:
            self.w = 5
        if self.h < 5:
            self.h = 5

        self.start_x = 1
        self.start_y = 1
        self.finish_x = self.w - 2
        self.finish_y = self.h - 2
        self.cells = List[List[_MazeCell]]()
        self.result = 0

    def class_name(self) -> String:
        return "Maze::Generator"

    def prepare(mut self, mut helper: Helper) raises:
        self.cells = List[List[_MazeCell]]()
        for y in range(self.h):
            var row = List[_MazeCell](capacity=self.w)
            for x in range(self.w):
                row.append(_MazeCell(x, y))
            self.cells.append(row^)

        self.cells[self.start_y][self.start_x].kind = MAZE_START
        self.cells[self.finish_y][self.finish_x].kind = MAZE_FINISH

        self._link_neighbors(helper)
        self.result = 0

    def _link_neighbors(mut self, mut helper: Helper):
        for y in range(self.h):
            for x in range(self.w):
                if x == 0 or y == 0 or x == self.w - 1 or y == self.h - 1:
                    self.cells[y][x].kind = MAZE_BORDER

        for y in range(1, self.h - 1):
            for x in range(1, self.w - 1):
                ref cell = self.cells[y][x]

                cell.neighbors = List[Tuple[Int, Int]](capacity=4)
                cell.neighbor_count = 0

                cell.neighbors.append((y - 1, x))
                cell.neighbors.append((y + 1, x))
                cell.neighbors.append((y, x + 1))
                cell.neighbors.append((y, x - 1))
                cell.neighbor_count = 4

                for _ in range(4):
                    var i = helper.next_int(4)
                    var j = helper.next_int(4)
                    if i != j:
                        var tmp = cell.neighbors[i]
                        cell.neighbors[i] = cell.neighbors[j]
                        cell.neighbors[j] = tmp

        self.cells[self.start_y][self.start_x].kind = MAZE_START
        self.cells[self.finish_y][self.finish_x].kind = MAZE_FINISH

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self._reset()
        self._generate()
        var mid_y = self.h >> 1
        var mid_x = self.w >> 1
        self.result += UInt32(self.cells[mid_y][mid_x].kind)

    def checksum(self) -> UInt32:
        var hash: UInt32 = 2166136261
        var prime: UInt32 = 16777619
        for y in range(self.h):
            for x in range(self.w):
                if self.cells[y][x].kind == MAZE_SPACE:
                    var j_sq = UInt32(x * y)
                    hash = (hash ^ j_sq) * prime
        return self.result + hash

    def _reset(mut self):
        for y in range(self.h):
            for x in range(self.w):
                self.cells[y][x].reset()
        self.cells[self.start_y][self.start_x].kind = MAZE_START
        self.cells[self.finish_y][self.finish_x].kind = MAZE_FINISH

    def _generate(mut self):
        var start_neighbors = self.cells[self.start_y][
            self.start_x
        ].neighbors.copy()

        for i in range(4):
            var neighbor = start_neighbors[i]
            var ny = neighbor[0]
            var nx = neighbor[1]
            if self.cells[ny][nx].kind == MAZE_WALL:
                self._dig(ny, nx)

        var finish_neighbors = self.cells[self.finish_y][
            self.finish_x
        ].neighbors.copy()

        for i in range(4):
            var neighbor = finish_neighbors[i]
            var ny = neighbor[0]
            var nx = neighbor[1]
            if self.cells[ny][nx].kind == MAZE_WALL:
                self._ensure_open_finish(ny, nx)

    def _dig(mut self, start_y: Int, start_x: Int):
        var stack = List[Tuple[Int, Int]](capacity=self.w * self.h)
        stack.append((start_y, start_x))

        while len(stack) > 0:
            var pos = stack.pop()
            var y = pos[0]
            var x = pos[1]

            var walkable_count = 0

            for i in range(4):
                var neighbor = self.cells[y][x].neighbors[i]
                var ny = neighbor[0]
                var nx = neighbor[1]
                if self.cells[ny][nx].is_walkable():
                    walkable_count += 1

            if walkable_count == 1:
                self.cells[y][x].kind = MAZE_SPACE

                for i in range(4):
                    var neighbor = self.cells[y][x].neighbors[i]
                    var ny = neighbor[0]
                    var nx = neighbor[1]
                    if self.cells[ny][nx].kind == MAZE_WALL:
                        stack.append((ny, nx))

    def _ensure_open_finish(mut self, y: Int, x: Int):
        self.cells[y][x].kind = MAZE_SPACE

        var walkable_count = 0

        for i in range(4):
            var neighbor = self.cells[y][x].neighbors[i]
            var ny = neighbor[0]
            var nx = neighbor[1]
            if self.cells[ny][nx].is_walkable():
                walkable_count += 1

        if walkable_count > 1:
            return

        for i in range(4):
            var neighbor = self.cells[y][x].neighbors[i]
            var ny = neighbor[0]
            var nx = neighbor[1]
            if self.cells[ny][nx].kind == MAZE_WALL:
                self._ensure_open_finish(ny, nx)


struct MazeBFS(Benchmark, Movable):
    var generator: MazeGenerator
    var result: UInt32
    var path: List[Tuple[Int, Int]]

    def __init__(out self, config: Config) raises:
        self.generator = MazeGenerator(config)
        self.result = 0
        self.path = List[Tuple[Int, Int]]()

    def class_name(self) -> String:
        return "Maze::BFS"

    def prepare(mut self, mut helper: Helper) raises:
        self.generator.prepare(helper)
        self.generator._generate()

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.path = Self._bfs(
            self.generator,
            self.generator.start_x,
            self.generator.start_y,
            self.generator.finish_x,
            self.generator.finish_y,
        )
        self.result += UInt32(len(self.path))

    def checksum(self) -> UInt32:
        return self.result + Self._mid_cell_checksum(self.path)

    @staticmethod
    def _mid_cell_checksum(path: List[Tuple[Int, Int]]) -> UInt32:
        if len(path) == 0:
            return 0
        var mid = len(path) // 2
        var cell = path[mid]
        return UInt32(cell[0] * cell[1])

    @staticmethod
    def _bfs(
        maze: MazeGenerator,
        sx: Int,
        sy: Int,
        tx: Int,
        ty: Int,
    ) -> List[Tuple[Int, Int]]:
        if sx == tx and sy == ty:
            var r = List[Tuple[Int, Int]]()
            r.append((sx, sy))
            return r^

        var visited = List[List[Bool]]()
        for _ in range(maze.h):
            var row = List[Bool](length=maze.w, fill=False)
            visited.append(row^)

        var queue = List[Int]()
        var path_nodes = List[Tuple[Int, Int, Int]]()

        visited[sy][sx] = True
        path_nodes.append((sx, sy, -1))
        queue.append(0)

        var q_idx = 0
        while q_idx < len(queue):
            var path_id = queue[q_idx]
            q_idx += 1
            var cur = path_nodes[path_id]
            var cx = cur[0]
            var cy = cur[1]

            ref cell = maze.cells[cy][cx]

            for i in range(cell.neighbor_count):
                var neighbor_coords = cell.neighbors[i]
                var ny = neighbor_coords[0]
                var nx = neighbor_coords[1]

                if nx == tx and ny == ty:
                    var result = List[Tuple[Int, Int]]()
                    result.append((tx, ty))
                    var current = path_id
                    while current >= 0:
                        var p = path_nodes[current]
                        result.append((p[0], p[1]))
                        current = p[2]
                    var reversed_result = List[Tuple[Int, Int]]()
                    for i in range(len(result) - 1, -1, -1):
                        reversed_result.append(result[i])
                    return reversed_result^

                if maze.cells[ny][nx].is_walkable() and not visited[ny][nx]:
                    visited[ny][nx] = True
                    path_nodes.append((nx, ny, path_id))
                    queue.append(len(path_nodes) - 1)

        return List[Tuple[Int, Int]]()


struct MazeAStar(Benchmark, Movable):
    var generator: MazeGenerator
    var result: UInt32
    var path: List[Tuple[Int, Int]]

    def __init__(out self, config: Config) raises:
        self.generator = MazeGenerator(config)
        self.result = 0
        self.path = List[Tuple[Int, Int]]()

    def class_name(self) -> String:
        return "Maze::AStar"

    def prepare(mut self, mut helper: Helper) raises:
        self.generator.prepare(helper)
        self.generator._generate()

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.path = Self._astar(
            self.generator,
            self.generator.start_x,
            self.generator.start_y,
            self.generator.finish_x,
            self.generator.finish_y,
        )
        self.result += UInt32(len(self.path))

    def checksum(self) -> UInt32:
        return self.result + Self._mid_cell_checksum(self.path)

    @staticmethod
    def _mid_cell_checksum(path: List[Tuple[Int, Int]]) -> UInt32:
        if len(path) == 0:
            return 0
        var mid = len(path) // 2
        var cell = path[mid]
        return UInt32(cell[0] * cell[1])

    @staticmethod
    def _heuristic(ax: Int, ay: Int, bx: Int, by: Int) -> Int:
        var dx = ax - bx
        var dy = ay - by
        if dx < 0:
            dx = -dx
        if dy < 0:
            dy = -dy
        return dx + dy

    @staticmethod
    def _astar(
        maze: MazeGenerator,
        sx: Int,
        sy: Int,
        tx: Int,
        ty: Int,
    ) -> List[Tuple[Int, Int]]:
        if sx == tx and sy == ty:
            var r = List[Tuple[Int, Int]]()
            r.append((sx, sy))
            return r^

        var size = maze.w * maze.h
        var start_idx = sy * maze.w + sx
        var target_idx = ty * maze.w + tx

        var came_from = List[Int](length=size, fill=-1)
        var g_score = List[Int](length=size, fill=2147483647)
        var best_f = List[Int](length=size, fill=2147483647)

        var open_set = _PriorityQueue(size)

        g_score[start_idx] = 0
        var f_start = MazeAStar._heuristic(sx, sy, tx, ty)
        open_set.push(start_idx, f_start)
        best_f[start_idx] = f_start

        while not open_set.empty():
            var cur = open_set.pop()
            var current_idx = cur[0]
            var f_val = cur[1]

            if f_val != best_f[current_idx]:
                continue

            if current_idx == target_idx:
                var result = List[Tuple[Int, Int]]()
                var cur_idx = current_idx
                while cur_idx != -1:
                    var cy = cur_idx // maze.w
                    var cx = cur_idx % maze.w
                    result.append((cx, cy))
                    cur_idx = came_from[cur_idx]

                var reversed_result = List[Tuple[Int, Int]]()
                for i in range(len(result) - 1, -1, -1):
                    reversed_result.append(result[i])
                return reversed_result^

            var cy = current_idx // maze.w
            var cx = current_idx % maze.w
            var current_g = g_score[current_idx]

            ref cell = maze.cells[cy][cx]

            for i in range(cell.neighbor_count):
                var neighbor_coords = cell.neighbors[i]
                var ny = neighbor_coords[0]
                var nx = neighbor_coords[1]

                if not maze.cells[ny][nx].is_walkable():
                    continue

                var neighbor_idx = ny * maze.w + nx
                var tentative_g = current_g + 1

                if tentative_g < g_score[neighbor_idx]:
                    came_from[neighbor_idx] = current_idx
                    g_score[neighbor_idx] = tentative_g
                    var f_new = tentative_g + MazeAStar._heuristic(
                        nx, ny, tx, ty
                    )
                    if f_new < best_f[neighbor_idx]:
                        best_f[neighbor_idx] = f_new
                        open_set.push(neighbor_idx, f_new)

        return List[Tuple[Int, Int]]()
