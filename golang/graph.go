package main

type Pair struct {
	vertex   int
	distance int
}

type Graph struct {
	vertices int
	jumps    int
	jumpLen  int
	adj      [][]int
}

func NewGraph(vertices, jumps, jumpLen int) *Graph {
	adj := make([][]int, vertices)
	for i := range adj {
		adj[i] = make([]int, 0)
	}
	return &Graph{
		vertices: vertices,
		jumps:    jumps,
		jumpLen:  jumpLen,
		adj:      adj,
	}
}

func (g *Graph) AddEdge(u, v int) {
	g.adj[u] = append(g.adj[u], v)
	g.adj[v] = append(g.adj[v], u)
}

func (g *Graph) GenerateRandom() {

	for i := 1; i < g.vertices; i++ {
		g.AddEdge(i, i-1)
	}

	for v := 0; v < g.vertices; v++ {
		numJumps := NextInt(g.jumps)
		for j := 0; j < numJumps; j++ {
			offset := NextInt(g.jumpLen) - g.jumpLen/2
			u := v + offset

			if u >= 0 && u < g.vertices && u != v {
				g.AddEdge(v, u)
			}
		}
	}
}

type GraphPathBFS struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathBFS) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
}

func (g *GraphPathBFS) bfsShortestPath(start, target int) int {
	if start == target {
		return 0
	}

	visited := make([]byte, g.graph.vertices)
	queue := []Pair{{start, 0}}
	visited[start] = 1

	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		v := current.vertex
		dist := current.distance

		for _, neighbor := range g.graph.adj[v] {
			if neighbor == target {
				return dist + 1
			}

			if visited[neighbor] == 0 {
				visited[neighbor] = 1
				queue = append(queue, Pair{neighbor, dist + 1})
			}
		}
	}

	return -1
}

func (g *GraphPathBFS) Run(iteration_id int) {
	length := g.bfsShortestPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathBFS) Checksum() uint32 {
	return g.result
}

type GraphPathDFS struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathDFS) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
}

func (g *GraphPathDFS) dfsFindPath(start, target int) int {
	if start == target {
		return 0
	}

	visited := make([]byte, g.graph.vertices)
	stack := []Pair{{start, 0}}
	bestPath := int(^uint(0) >> 1)

	for len(stack) > 0 {
		current := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		v := current.vertex
		dist := current.distance

		if visited[v] == 1 || dist >= bestPath {
			continue
		}
		visited[v] = 1

		for _, neighbor := range g.graph.adj[v] {
			if neighbor == target {
				if dist+1 < bestPath {
					bestPath = dist + 1
				}
			} else if visited[neighbor] == 0 {
				stack = append(stack, Pair{neighbor, dist + 1})
			}
		}
	}

	if bestPath == int(^uint(0)>>1) {
		return -1
	}
	return bestPath
}

func (g *GraphPathDFS) Run(iteration_id int) {
	length := g.dfsFindPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathDFS) Checksum() uint32 {
	return g.result
}

type GraphPriorityQueueItem struct {
	vertex   int
	priority int
}

type GraphPriorityQueue struct {
	items []GraphPriorityQueueItem
}

func NewGraphPriorityQueue(capacity int) *GraphPriorityQueue {
	return &GraphPriorityQueue{
		items: make([]GraphPriorityQueueItem, 0, capacity),
	}
}

func (pq *GraphPriorityQueue) Push(vertex, priority int) {
	pq.items = append(pq.items, GraphPriorityQueueItem{vertex, priority})
	pq.siftUp(len(pq.items) - 1)
}

func (pq *GraphPriorityQueue) Pop() (int, int) {
	min := pq.items[0]
	pq.items[0] = pq.items[len(pq.items)-1]
	pq.items = pq.items[:len(pq.items)-1]
	pq.siftDown(0)
	return min.vertex, min.priority
}

func (pq *GraphPriorityQueue) Len() int {
	return len(pq.items)
}

func (pq *GraphPriorityQueue) siftUp(i int) {
	for i > 0 {
		parent := (i - 1) / 2
		if pq.items[parent].priority <= pq.items[i].priority {
			break
		}
		pq.items[parent], pq.items[i] = pq.items[i], pq.items[parent]
		i = parent
	}
}

func (pq *GraphPriorityQueue) siftDown(i int) {
	n := len(pq.items)
	for {
		left := 2*i + 1
		right := 2*i + 2
		smallest := i

		if left < n && pq.items[left].priority < pq.items[smallest].priority {
			smallest = left
		}
		if right < n && pq.items[right].priority < pq.items[smallest].priority {
			smallest = right
		}
		if smallest == i {
			break
		}
		pq.items[i], pq.items[smallest] = pq.items[smallest], pq.items[i]
		i = smallest
	}
}

type GraphPathAStar struct {
	BaseBenchmark
	graph  *Graph
	result uint32
}

func (g *GraphPathAStar) Prepare() {
	vertices := int(g.ConfigVal("vertices"))
	jumps := int(g.ConfigVal("jumps"))
	jumpLen := int(g.ConfigVal("jump_len"))

	g.graph = NewGraph(vertices, jumps, jumpLen)
	g.graph.GenerateRandom()
}

func (g *GraphPathAStar) heuristic(v, target int) int {
	return target - v
}

func (g *GraphPathAStar) aStarShortestPath(start, target int) int {
	if start == target {
		return 0
	}

	const INF = int(^uint(0) >> 1)
	gScore := make([]int, g.graph.vertices)
	fScore := make([]int, g.graph.vertices)
	closed := make([]byte, g.graph.vertices)

	for i := range gScore {
		gScore[i] = INF
		fScore[i] = INF
	}
	gScore[start] = 0
	fScore[start] = g.heuristic(start, target)

	openSet := NewGraphPriorityQueue(g.graph.vertices)
	inOpenSet := make([]byte, g.graph.vertices)

	openSet.Push(start, fScore[start])
	inOpenSet[start] = 1

	for openSet.Len() > 0 {
		current, _ := openSet.Pop()
		inOpenSet[current] = 0

		if current == target {
			return gScore[current]
		}

		closed[current] = 1

		for _, neighbor := range g.graph.adj[current] {
			if closed[neighbor] == 1 {
				continue
			}

			tentativeG := gScore[current] + 1

			if tentativeG < gScore[neighbor] {
				gScore[neighbor] = tentativeG
				fScore[neighbor] = tentativeG + g.heuristic(neighbor, target)

				if inOpenSet[neighbor] == 0 {
					openSet.Push(neighbor, fScore[neighbor])
					inOpenSet[neighbor] = 1
				}
			}
		}
	}

	return -1
}

func (g *GraphPathAStar) Run(iteration_id int) {
	length := g.aStarShortestPath(0, g.graph.vertices-1)
	g.result += uint32(length)
}

func (g *GraphPathAStar) Checksum() uint32 {
	return g.result
}
