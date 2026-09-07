#include "benchmark.h"

typedef struct {
  int vertex;
  int distance;
} Pair;

typedef struct {
  int vertices;
  int jumps;
  int jump_len;
  int **adj;
  int *adj_count;
  int *adj_capacity;
} GraphPathGraph;

typedef struct {
  GraphPathGraph *graph;
  uint32_t result_val;
} GraphPathBaseData;

static GraphPathGraph *graph_path_graph_new(int vertices, int jumps,
                                            int jump_len) {
  GraphPathGraph *graph = malloc(sizeof(GraphPathGraph));
  graph->vertices = vertices;
  graph->jumps = jumps;
  graph->jump_len = jump_len;

  graph->adj = malloc(vertices * sizeof(int *));
  graph->adj_count = malloc(vertices * sizeof(int));
  graph->adj_capacity = malloc(vertices * sizeof(int));

  for (int i = 0; i < vertices; i++) {
    graph->adj_capacity[i] = 4;
    graph->adj[i] = malloc(graph->adj_capacity[i] * sizeof(int));
    graph->adj_count[i] = 0;
  }

  return graph;
}

static void graph_path_graph_free(GraphPathGraph *graph) {
  if (!graph)
    return;

  if (graph->adj) {
    for (int i = 0; i < graph->vertices; i++) {
      if (graph->adj[i])
        free(graph->adj[i]);
    }
    free(graph->adj);
  }
  if (graph->adj_count)
    free(graph->adj_count);
  if (graph->adj_capacity)
    free(graph->adj_capacity);
  free(graph);
}

static void graph_path_graph_add_edge(GraphPathGraph *graph, int u, int v) {
  if (graph->adj_count[u] >= graph->adj_capacity[u]) {
    graph->adj_capacity[u] *= 2;
    graph->adj[u] =
        realloc(graph->adj[u], graph->adj_capacity[u] * sizeof(int));
  }
  graph->adj[u][graph->adj_count[u]++] = v;

  if (graph->adj_count[v] >= graph->adj_capacity[v]) {
    graph->adj_capacity[v] *= 2;
    graph->adj[v] =
        realloc(graph->adj[v], graph->adj_capacity[v] * sizeof(int));
  }
  graph->adj[v][graph->adj_count[v]++] = u;
}

static void graph_path_graph_generate_random(GraphPathGraph *graph) {
  for (int i = 1; i < graph->vertices; i++) {
    graph_path_graph_add_edge(graph, i, i - 1);
  }

  for (int v = 0; v < graph->vertices; v++) {
    int num_jumps = Helper_next_int(graph->jumps);
    for (int j = 0; j < num_jumps; j++) {
      int offset = Helper_next_int(graph->jump_len) - graph->jump_len / 2;
      int u = v + offset;

      if (u >= 0 && u < graph->vertices && u != v) {
        graph_path_graph_add_edge(graph, v, u);
      }
    }
  }
}

static void graph_path_base_prepare(Benchmark *self, const char *bench_name,
                                    GraphPathBaseData *data) {
  (void)self;
  int vertices = (int)Helper_config_i64(bench_name, "vertices");
  int jumps = (int)Helper_config_i64(bench_name, "jumps");
  int jump_len = (int)Helper_config_i64(bench_name, "jump_len");

  data->graph = graph_path_graph_new(vertices, jumps, jump_len);
  graph_path_graph_generate_random(data->graph);
  data->result_val = 0;
}

static void graph_path_base_cleanup(GraphPathBaseData *data) {
  if (data->graph) {
    graph_path_graph_free(data->graph);
    data->graph = NULL;
  }
}

typedef struct {
  GraphPathBaseData base;
} GraphPathBFSData;

static int graph_path_bfs_search(GraphPathGraph *graph, int start, int target) {
  if (start == target)
    return 0;

  uint8_t *visited = calloc(graph->vertices, sizeof(uint8_t));
  Pair *queue = malloc(graph->vertices * sizeof(Pair));
  int front = 0, rear = 0;

  visited[start] = 1;
  queue[rear++] = (Pair){start, 0};

  while (front < rear) {
    Pair current = queue[front++];
    int v = current.vertex;
    int dist = current.distance;

    for (int i = 0; i < graph->adj_count[v]; i++) {
      int neighbor = graph->adj[v][i];
      if (neighbor == target) {
        free(visited);
        free(queue);
        return dist + 1;
      }

      if (!visited[neighbor]) {
        visited[neighbor] = 1;
        queue[rear++] = (Pair){neighbor, dist + 1};
      }
    }
  }

  free(visited);
  free(queue);
  return -1;
}

void GraphPathBFS_prepare(Benchmark *self) {
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  graph_path_base_prepare(self, "Graph::BFS", &data->base);
}

void GraphPathBFS_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  int length = graph_path_bfs_search(data->base.graph, 0,
                                     data->base.graph->vertices - 1);
  data->base.result_val += length;
}

uint32_t GraphPathBFS_checksum(Benchmark *self) {
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  return data->base.result_val;
}

void GraphPathBFS_cleanup(Benchmark *self) {
  GraphPathBFSData *data = (GraphPathBFSData *)self->data;
  graph_path_base_cleanup(&data->base);
}

Benchmark *GraphPathBFS_create(void) {
  Benchmark *bench = Benchmark_create("Graph::BFS");
  GraphPathBFSData *data = malloc(sizeof(GraphPathBFSData));
  memset(data, 0, sizeof(GraphPathBFSData));
  bench->data = data;
  bench->prepare = GraphPathBFS_prepare;
  bench->run = GraphPathBFS_run;
  bench->checksum = GraphPathBFS_checksum;
  bench->cleanup = GraphPathBFS_cleanup;
  return bench;
}

typedef struct {
  GraphPathBaseData base;
} GraphPathDFSData;

static int graph_path_dfs_search(GraphPathGraph *graph, int start, int target) {
  if (start == target)
    return 0;

  uint8_t *visited = calloc(graph->vertices, sizeof(uint8_t));
  Pair *stack = malloc(graph->vertices * sizeof(Pair));
  int stack_top = -1;
  int best_path = INT_MAX;

  stack[++stack_top] = (Pair){start, 0};

  while (stack_top >= 0) {
    Pair current = stack[stack_top--];
    int v = current.vertex;
    int dist = current.distance;

    if (visited[v] || dist >= best_path)
      continue;
    visited[v] = 1;

    for (int i = 0; i < graph->adj_count[v]; i++) {
      int neighbor = graph->adj[v][i];
      if (neighbor == target) {
        if (dist + 1 < best_path)
          best_path = dist + 1;
      } else if (!visited[neighbor]) {
        stack[++stack_top] = (Pair){neighbor, dist + 1};
      }
    }
  }

  free(visited);
  free(stack);
  return best_path == INT_MAX ? -1 : best_path;
}

void GraphPathDFS_prepare(Benchmark *self) {
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  graph_path_base_prepare(self, "Graph::DFS", &data->base);
}

void GraphPathDFS_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  int length = graph_path_dfs_search(data->base.graph, 0,
                                     data->base.graph->vertices - 1);
  data->base.result_val += length;
}

uint32_t GraphPathDFS_checksum(Benchmark *self) {
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  return data->base.result_val;
}

void GraphPathDFS_cleanup(Benchmark *self) {
  GraphPathDFSData *data = (GraphPathDFSData *)self->data;
  graph_path_base_cleanup(&data->base);
}

Benchmark *GraphPathDFS_create(void) {
  Benchmark *bench = Benchmark_create("Graph::DFS");
  GraphPathDFSData *data = malloc(sizeof(GraphPathDFSData));
  memset(data, 0, sizeof(GraphPathDFSData));
  bench->data = data;
  bench->prepare = GraphPathDFS_prepare;
  bench->run = GraphPathDFS_run;
  bench->checksum = GraphPathDFS_checksum;
  bench->cleanup = GraphPathDFS_cleanup;
  return bench;
}

typedef struct {
  GraphPathBaseData base;
} GraphPathAStarData;

typedef struct {
  int vertex;
  int priority;
} PriorityQueueItem;

typedef struct {
  PriorityQueueItem *items;
  int size;
  int capacity;
} PriorityQueue;

static void priority_queue_push(PriorityQueue *pq, int vertex, int priority) {
  if (pq->size >= pq->capacity) {
    pq->capacity = pq->capacity == 0 ? 16 : pq->capacity * 2;
    pq->items = realloc(pq->items, pq->capacity * sizeof(PriorityQueueItem));
  }

  int i = pq->size++;
  while (i > 0) {
    int parent = (i - 1) / 2;
    if (pq->items[parent].priority <= priority)
      break;
    pq->items[i] = pq->items[parent];
    i = parent;
  }
  pq->items[i] = (PriorityQueueItem){vertex, priority};
}

static PriorityQueueItem priority_queue_pop(PriorityQueue *pq) {
  PriorityQueueItem min = pq->items[0];
  pq->size--;
  if (pq->size > 0) {
    PriorityQueueItem last = pq->items[pq->size];
    int i = 0;
    while (true) {
      int left = 2 * i + 1;
      int right = 2 * i + 2;
      int smallest = i;

      if (left < pq->size &&
          pq->items[left].priority < pq->items[smallest].priority)
        smallest = left;
      if (right < pq->size &&
          pq->items[right].priority < pq->items[smallest].priority)
        smallest = right;

      if (smallest == i)
        break;

      pq->items[i] = pq->items[smallest];
      i = smallest;
    }
    pq->items[i] = last;
  }
  return min;
}

static int heuristic(int v, int target) { return target - v; }

static int graph_path_astar_search(GraphPathGraph *graph, int start,
                                   int target) {
  if (start == target)
    return 0;

  int *g_score = malloc(graph->vertices * sizeof(int));
  int *f_score = malloc(graph->vertices * sizeof(int));
  uint8_t *visited = calloc(graph->vertices, sizeof(uint8_t));

  for (int i = 0; i < graph->vertices; i++) {
    g_score[i] = INT_MAX;
    f_score[i] = INT_MAX;
  }
  g_score[start] = 0;
  f_score[start] = heuristic(start, target);

  PriorityQueue open_set = {0};
  priority_queue_push(&open_set, start, f_score[start]);

  uint8_t *in_open_set = calloc(graph->vertices, sizeof(uint8_t));
  in_open_set[start] = 1;

  while (open_set.size > 0) {
    PriorityQueueItem current_item = priority_queue_pop(&open_set);
    int current = current_item.vertex;
    in_open_set[current] = 0;

    if (current == target) {
      int result = g_score[current];
      free(g_score);
      free(f_score);
      free(visited);
      free(in_open_set);
      free(open_set.items);
      return result;
    }

    visited[current] = 1;

    for (int i = 0; i < graph->adj_count[current]; i++) {
      int neighbor = graph->adj[current][i];
      if (visited[neighbor])
        continue;

      int tentative_g = g_score[current] + 1;

      if (tentative_g < g_score[neighbor]) {
        g_score[neighbor] = tentative_g;
        int f = tentative_g + heuristic(neighbor, target);
        f_score[neighbor] = f;

        if (!in_open_set[neighbor]) {
          priority_queue_push(&open_set, neighbor, f);
          in_open_set[neighbor] = 1;
        }
      }
    }
  }

  free(g_score);
  free(f_score);
  free(visited);
  free(in_open_set);
  free(open_set.items);
  return -1;
}

void GraphPathAStar_prepare(Benchmark *self) {
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  graph_path_base_prepare(self, "Graph::AStar", &data->base);
}

void GraphPathAStar_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  int length = graph_path_astar_search(data->base.graph, 0,
                                       data->base.graph->vertices - 1);
  data->base.result_val += length;
}

uint32_t GraphPathAStar_checksum(Benchmark *self) {
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  return data->base.result_val;
}

void GraphPathAStar_cleanup(Benchmark *self) {
  GraphPathAStarData *data = (GraphPathAStarData *)self->data;
  graph_path_base_cleanup(&data->base);
}

Benchmark *GraphPathAStar_create(void) {
  Benchmark *bench = Benchmark_create("Graph::AStar");
  GraphPathAStarData *data = malloc(sizeof(GraphPathAStarData));
  memset(data, 0, sizeof(GraphPathAStarData));
  bench->data = data;
  bench->prepare = GraphPathAStar_prepare;
  bench->run = GraphPathAStar_run;
  bench->checksum = GraphPathAStar_checksum;
  bench->cleanup = GraphPathAStar_cleanup;
  return bench;
}
