#include "benchmark.h"

typedef struct {
  char *csv_data;
  uint32_t result_val;
  int64_t rows;
} CsvParseData;

typedef struct {
  double x, y, z;
} Point;

typedef struct {
  Point *items;
  int count;
  int capacity;
} PointList;

static char *generate_csv_for_parsing(int64_t rows) {
  size_t capacity = rows * 100 + 1;
  char *buffer = malloc(capacity);
  if (!buffer)
    return NULL;

  size_t pos = 0;
  for (int64_t i = 0; i < rows; i++) {
    char c = 'A' + (i % 26);
    double x = Helper_next_float(1.0);
    double z = Helper_next_float(1.0);
    double y = Helper_next_float(1.0);
    pos += snprintf(
        buffer + pos, capacity - pos,
        "\"point %c\\n, \"\"%lld\"\"\",%.10f,,%.10f,\"[%s\\n, %lld]\",%.10f\n",
        c, (long long)(i % 100), x, z, (i % 2 == 0) ? "true" : "false",
        (long long)(i % 100), y);
  }
  return buffer;
}

void CsvParse_prepare(Benchmark *self) {
  CsvParseData *data = (CsvParseData *)self->data;
  data->rows = Helper_config_i64(self->name, "rows");
  data->csv_data = generate_csv_for_parsing(data->rows);
  data->result_val = 0;
}

static void point_list_init(PointList *list) {
  list->items = NULL;
  list->count = 0;
  list->capacity = 0;
}

static int point_list_add(PointList *list, Point point) {
  if (list->count >= list->capacity) {
    int new_capacity = list->capacity == 0 ? 16 : list->capacity * 2;
    Point *new_items = realloc(list->items, new_capacity * sizeof(Point));
    if (!new_items)
      return -1;
    list->items = new_items;
    list->capacity = new_capacity;
  }
  list->items[list->count++] = point;
  return 0;
}

static void point_list_free(PointList *list) {
  free(list->items);
  list->items = NULL;
  list->count = 0;
  list->capacity = 0;
}

static int parse_field_value(const char *start, size_t len, double *value) {
  char buf[64];
  if (len >= sizeof(buf))
    return -1;
  memcpy(buf, start, len);
  buf[len] = '\0';
  *value = strtod(buf, NULL);
  return 0;
}

static int parse_points(const char *csv_data, PointList *points) {
  int field_idx = 0;
  const char *field_start = csv_data;
  int in_quotes = 0;
  double values[6] = {0};

  const char *s = csv_data;

  while (*s) {
    char ch = *s;

    if (ch == '"') {
      if (in_quotes && s[1] == '"') {
        s += 2;
        continue;
      }
      in_quotes = !in_quotes;
      s++;
    } else if (ch == ',' && !in_quotes) {
      if (field_idx == 1 || field_idx == 3 || field_idx == 5) {
        if (parse_field_value(field_start, s - field_start,
                              &values[field_idx]) != 0)
          return -1;
      }
      field_idx++;
      field_start = s + 1;
      s++;
    } else if (ch == '\n' && !in_quotes) {
      if (field_idx < 6) {
        if (field_idx == 1 || field_idx == 3 || field_idx == 5) {
          if (parse_field_value(field_start, s - field_start,
                                &values[field_idx]) != 0)
            return -1;
        }
        field_idx++;
      }

      if (field_idx >= 6) {
        Point point = {values[1], values[5], values[3]};
        if (point_list_add(points, point) != 0)
          return -1;
      }

      field_idx = 0;
      field_start = s + 1;
      s++;
    } else {
      s++;
    }
  }

  if (field_start < s && field_idx > 0) {
    if (field_idx < 6) {
      if (field_idx == 1 || field_idx == 3 || field_idx == 5) {
        if (parse_field_value(field_start, s - field_start,
                              &values[field_idx]) != 0)
          return -1;
      }
      field_idx++;
    }

    if (field_idx >= 6) {
      Point point = {values[1], values[5], values[3]};
      if (point_list_add(points, point) != 0)
        return -1;
    }
  }

  return points->count;
}

void CsvParse_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  CsvParseData *data = (CsvParseData *)self->data;
  if (!data->csv_data)
    return;

  PointList points;
  point_list_init(&points);

  int point_count = parse_points(data->csv_data, &points);

  if (point_count > 0) {
    double x_sum = 0, y_sum = 0, z_sum = 0;
    for (int i = 0; i < points.count; i++) {
      x_sum += points.items[i].x;
      y_sum += points.items[i].y;
      z_sum += points.items[i].z;
    }

    double len = points.count;
    data->result_val += Helper_checksum_f64(x_sum / len) +
                        Helper_checksum_f64(y_sum / len) +
                        Helper_checksum_f64(z_sum / len);
  }

  point_list_free(&points);
}

uint32_t CsvParse_checksum(Benchmark *self) {
  CsvParseData *data = (CsvParseData *)self->data;
  return data->result_val + Helper_checksum_string(data->csv_data);
}

void CsvParse_cleanup(Benchmark *self) {
  CsvParseData *data = (CsvParseData *)self->data;
  if (data->csv_data) {
    free(data->csv_data);
    data->csv_data = NULL;
  }
}

Benchmark *CsvParse_create(void) {
  Benchmark *bench = Benchmark_create("CSV::Parse");
  if (!bench)
    return NULL;

  CsvParseData *data = calloc(1, sizeof(CsvParseData));
  if (!data) {
    free(bench);
    return NULL;
  }

  bench->data = data;
  bench->prepare = CsvParse_prepare;
  bench->run = CsvParse_run;
  bench->checksum = CsvParse_checksum;
  bench->cleanup = CsvParse_cleanup;

  return bench;
}
