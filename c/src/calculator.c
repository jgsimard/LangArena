#include "benchmark.h"

#define CHAR_EOF '\0'
#define CHAR_PLUS '+'
#define CHAR_MINUS '-'
#define CHAR_STAR '*'
#define CHAR_SLASH '/'
#define CHAR_PERCENT '%'
#define CHAR_LPAREN '('
#define CHAR_RPAREN ')'
#define CHAR_EQUALS '='
#define CHAR_ZERO '0'
#define CHAR_NINE '9'
#define CHAR_A_LOWER 'a'
#define CHAR_Z_LOWER 'z'
#define CHAR_A_UPPER 'A'
#define CHAR_Z_UPPER 'Z'
#define CHAR_SPACE ' '
#define CHAR_TAB '\t'
#define CHAR_NEWLINE '\n'
#define CHAR_CR '\r'

typedef enum {
  AST_NUMBER,
  AST_VARIABLE,
  AST_BINARY_OP,
  AST_ASSIGNMENT
} AST_NodeType;

typedef struct AST_Node AST_Node;
typedef struct AST_BinaryOp AST_BinaryOp;
typedef struct AST_Assignment AST_Assignment;

struct AST_BinaryOp {
  char op;
  AST_Node *left;
  AST_Node *right;
};

struct AST_Assignment {
  char *var_name;
  AST_Node *expr;
};

struct AST_Node {
  AST_NodeType type;
  union {
    int64_t number_value;
    char *variable_name;
    AST_BinaryOp *binary_op;
    AST_Assignment *assignment;
  } data;
};

typedef struct {
  AST_Node **expressions;
  int64_t expressions_count;
  int64_t expressions_capacity;
  uint32_t result_val;
  char *text;
  int64_t operations;
} CalculatorAstData;

static AST_Node *ast_node_new_number(int64_t value) {
  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_NUMBER;
  node->data.number_value = value;
  return node;
}

static AST_Node *ast_node_new_variable(const char *name) {
  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_VARIABLE;
  node->data.variable_name = strdup(name);
  return node;
}

static AST_Node *ast_node_new_binary_op(char op, AST_Node *left,
                                        AST_Node *right) {
  AST_BinaryOp *binary_op = malloc(sizeof(AST_BinaryOp));
  binary_op->op = op;
  binary_op->left = left;
  binary_op->right = right;

  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_BINARY_OP;
  node->data.binary_op = binary_op;
  return node;
}

static AST_Node *ast_node_new_assignment(const char *var_name, AST_Node *expr) {
  AST_Assignment *assignment = malloc(sizeof(AST_Assignment));
  assignment->var_name = strdup(var_name);
  assignment->expr = expr;

  AST_Node *node = malloc(sizeof(AST_Node));
  node->type = AST_ASSIGNMENT;
  node->data.assignment = assignment;
  return node;
}

static void ast_node_free(AST_Node *node) {
  if (!node)
    return;

  switch (node->type) {
  case AST_VARIABLE:
    free(node->data.variable_name);
    break;
  case AST_BINARY_OP:
    if (node->data.binary_op) {
      ast_node_free(node->data.binary_op->left);
      ast_node_free(node->data.binary_op->right);
      free(node->data.binary_op);
    }
    break;
  case AST_ASSIGNMENT:
    if (node->data.assignment) {
      free(node->data.assignment->var_name);
      ast_node_free(node->data.assignment->expr);
      free(node->data.assignment);
    }
    break;
  default:
    break;
  }
  free(node);
}

typedef struct {
  const char *input;
  size_t pos;
  size_t len;
  char current_char;
} CalculatorAstParser;

static AST_Node *
calculator_ast_parser_parse_expression(CalculatorAstParser *parser);
static AST_Node *calculator_ast_parser_parse_term(CalculatorAstParser *parser);
static AST_Node *
calculator_ast_parser_parse_factor(CalculatorAstParser *parser);

static bool is_digit(char c) { return c >= CHAR_ZERO && c <= CHAR_NINE; }

static bool is_letter(char c) {
  return (c >= CHAR_A_LOWER && c <= CHAR_Z_LOWER) ||
         (c >= CHAR_A_UPPER && c <= CHAR_Z_UPPER);
}

static bool is_whitespace(char c) {
  return c == CHAR_SPACE || c == CHAR_TAB || c == CHAR_NEWLINE || c == CHAR_CR;
}

static void calculator_ast_parser_init(CalculatorAstParser *parser,
                                       const char *input) {
  parser->input = input;
  parser->pos = 0;
  parser->len = strlen(input);
  parser->current_char = parser->len > 0 ? input[0] : CHAR_EOF;
}

static void calculator_ast_parser_advance(CalculatorAstParser *parser) {
  parser->pos++;
  if (parser->pos >= parser->len) {
    parser->current_char = CHAR_EOF;
  } else {
    parser->current_char = parser->input[parser->pos];
  }
}

static void calculator_ast_parser_skip_whitespace(CalculatorAstParser *parser) {
  while (is_whitespace(parser->current_char)) {
    calculator_ast_parser_advance(parser);
  }
}

static AST_Node *
calculator_ast_parser_parse_number(CalculatorAstParser *parser) {
  int64_t value = 0;
  while (is_digit(parser->current_char)) {
    value = value * 10 + (parser->current_char - CHAR_ZERO);
    calculator_ast_parser_advance(parser);
  }
  return ast_node_new_number(value);
}

static AST_Node *
calculator_ast_parser_parse_variable(CalculatorAstParser *parser) {
  size_t start = parser->pos;
  while (is_letter(parser->current_char) || is_digit(parser->current_char)) {
    calculator_ast_parser_advance(parser);
  }

  size_t len = parser->pos - start;
  char *var_name = malloc(len + 1);
  strncpy(var_name, parser->input + start, len);
  var_name[len] = '\0';

  calculator_ast_parser_skip_whitespace(parser);

  if (parser->current_char == CHAR_EQUALS) {
    calculator_ast_parser_advance(parser);
    AST_Node *expr = calculator_ast_parser_parse_expression(parser);
    AST_Node *node = ast_node_new_assignment(var_name, expr);
    free(var_name);
    return node;
  }

  AST_Node *node = ast_node_new_variable(var_name);
  free(var_name);
  return node;
}

static AST_Node *
calculator_ast_parser_parse_factor(CalculatorAstParser *parser) {
  calculator_ast_parser_skip_whitespace(parser);

  if (is_digit(parser->current_char)) {
    return calculator_ast_parser_parse_number(parser);
  }

  if (is_letter(parser->current_char)) {
    return calculator_ast_parser_parse_variable(parser);
  }

  if (parser->current_char == CHAR_LPAREN) {
    calculator_ast_parser_advance(parser);
    AST_Node *node = calculator_ast_parser_parse_expression(parser);
    calculator_ast_parser_skip_whitespace(parser);
    if (parser->current_char == CHAR_RPAREN) {
      calculator_ast_parser_advance(parser);
    }
    return node;
  }

  calculator_ast_parser_advance(parser);
  return ast_node_new_number(0);
}

static AST_Node *calculator_ast_parser_parse_term(CalculatorAstParser *parser) {
  AST_Node *node = calculator_ast_parser_parse_factor(parser);

  while (true) {
    calculator_ast_parser_skip_whitespace(parser);

    if (parser->current_char == CHAR_STAR ||
        parser->current_char == CHAR_SLASH ||
        parser->current_char == CHAR_PERCENT) {
      char op = parser->current_char;
      calculator_ast_parser_advance(parser);
      AST_Node *right = calculator_ast_parser_parse_factor(parser);
      node = ast_node_new_binary_op(op, node, right);
    } else {
      break;
    }
  }

  return node;
}

static AST_Node *
calculator_ast_parser_parse_expression(CalculatorAstParser *parser) {
  AST_Node *node = calculator_ast_parser_parse_term(parser);

  while (true) {
    calculator_ast_parser_skip_whitespace(parser);

    if (parser->current_char == CHAR_PLUS ||
        parser->current_char == CHAR_MINUS) {
      char op = parser->current_char;
      calculator_ast_parser_advance(parser);
      AST_Node *right = calculator_ast_parser_parse_term(parser);
      node = ast_node_new_binary_op(op, node, right);
    } else {
      break;
    }
  }

  return node;
}

static void calculator_ast_parser_parse_all(CalculatorAstParser *parser,
                                            CalculatorAstData *data) {
  data->expressions_count = 0;

  while (parser->current_char != CHAR_EOF) {
    calculator_ast_parser_skip_whitespace(parser);
    if (parser->current_char == CHAR_EOF)
      break;

    if (data->expressions_count >= data->expressions_capacity) {
      data->expressions_capacity =
          data->expressions_capacity ? data->expressions_capacity * 2 : 16;
      data->expressions = realloc(
          data->expressions, data->expressions_capacity * sizeof(AST_Node *));
    }

    data->expressions[data->expressions_count++] =
        calculator_ast_parser_parse_expression(parser);

    calculator_ast_parser_skip_whitespace(parser);
    while (parser->current_char == CHAR_NEWLINE) {
      calculator_ast_parser_advance(parser);
      calculator_ast_parser_skip_whitespace(parser);
    }
  }
}

static char *calculator_ast_generate_random_program(int64_t operations) {
  size_t capacity = operations * 100;
  char *result = malloc(capacity);
  size_t len = 0;

  len += snprintf(result + len, capacity - len, "v0 = 1\n");
  for (int i = 0; i < 10; i++) {
    len += snprintf(result + len, capacity - len, "v%d = v%d + %d\n", i + 1, i,
                    i + 1);
  }

  for (int64_t i = 0; i < operations; i++) {
    int v = (int)(i + 10);

    len += snprintf(result + len, capacity - len, "v%d = v%d + ", v, v - 1);

    switch (Helper_next_int(10)) {
    case 0:
      len += snprintf(result + len, capacity - len,
                      "(v%d / 3) * 4 - %ld / (3 + (18 - v%d)) %% v%d + 2 * ((9 "
                      "- v%d) * (v%d + 7))",
                      v - 1, (long)i, v - 2, v - 3, v - 6, v - 5);
      break;
    case 1:
      len += snprintf(result + len, capacity - len,
                      "v%d + (v%d + v%d) * v%d - (v%d / v%d)", v - 1, v - 2,
                      v - 3, v - 4, v - 5, v - 6);
      break;
    case 2:
      len += snprintf(result + len, capacity - len, "(3789 - (((v%d)))) + 1",
                      v - 7);
      break;
    case 3:
      len += snprintf(result + len, capacity - len, "4/2 * (1-3) + v%d/v%d",
                      v - 9, v - 5);
      break;
    case 4:
      len += snprintf(result + len, capacity - len, "1+2+3+4+5+6+v%d", v - 1);
      break;
    case 5:
      len += snprintf(result + len, capacity - len, "(99999 / v%d)", v - 3);
      break;
    case 6:
      len += snprintf(result + len, capacity - len, "0 + 0 - v%d", v - 8);
      break;
    case 7:
      len += snprintf(result + len, capacity - len,
                      "((((((((((v%d)))))))))) * 2", v - 6);
      break;
    case 8:
      len += snprintf(result + len, capacity - len, "%ld * (v%d%%6)%%7",
                      (long)i, v - 1);
      break;
    case 9:
      len += snprintf(result + len, capacity - len, "(1)/(0-v%d) + (v%d)",
                      v - 5, v - 7);
      break;
    }
    len += snprintf(result + len, capacity - len, "\n");
  }

  result[len] = '\0';
  return result;
}

void CalculatorAst_prepare(Benchmark *self) {
  CalculatorAstData *data = (CalculatorAstData *)self->data;

  data->operations = Helper_config_i64(self->name, "operations");
  if (data->operations <= 0) {
    data->operations = 1000;
  }

  data->text = calculator_ast_generate_random_program(data->operations);
  data->expressions = NULL;
  data->expressions_count = 0;
  data->expressions_capacity = 0;
  data->result_val = 0;
}

void CalculatorAst_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  CalculatorAstData *data = (CalculatorAstData *)self->data;

  if (data->expressions) {
    for (int64_t i = 0; i < data->expressions_count; i++) {
      ast_node_free(data->expressions[i]);
    }
    free(data->expressions);
    data->expressions = NULL;
    data->expressions_count = 0;
    data->expressions_capacity = 0;
  }

  CalculatorAstParser parser;
  calculator_ast_parser_init(&parser, data->text);

  if (data->expressions) {
    for (int64_t i = 0; i < data->expressions_count; i++) {
      ast_node_free(data->expressions[i]);
    }
    free(data->expressions);
    data->expressions = NULL;
    data->expressions_count = 0;
    data->expressions_capacity = 0;
  }

  calculator_ast_parser_parse_all(&parser, data);

  uint32_t iteration_result = (uint32_t)data->expressions_count;

  if (data->expressions_count > 0 &&
      data->expressions[data->expressions_count - 1]->type == AST_ASSIGNMENT) {
    AST_Node *last = data->expressions[data->expressions_count - 1];
    iteration_result += Helper_checksum_string(last->data.assignment->var_name);
  }

  data->result_val += iteration_result;
}

uint32_t CalculatorAst_checksum(Benchmark *self) {
  CalculatorAstData *data = (CalculatorAstData *)self->data;
  return data->result_val;
}

void CalculatorAst_cleanup(Benchmark *self) {
  CalculatorAstData *data = (CalculatorAstData *)self->data;

  if (data->text) {
    free(data->text);
    data->text = NULL;
  }

  if (data->expressions) {
    for (int64_t i = 0; i < data->expressions_count; i++) {
      ast_node_free(data->expressions[i]);
    }
    free(data->expressions);
    data->expressions = NULL;
  }
}

Benchmark *CalculatorAst_create(void) {
  Benchmark *bench = Benchmark_create("Calculator::Ast");

  CalculatorAstData *data = malloc(sizeof(CalculatorAstData));
  memset(data, 0, sizeof(CalculatorAstData));

  bench->data = data;

  bench->prepare = CalculatorAst_prepare;
  bench->run = CalculatorAst_run;
  bench->checksum = CalculatorAst_checksum;
  bench->cleanup = CalculatorAst_cleanup;

  return bench;
}

typedef struct {
  char *name;
  int64_t value;
  UT_hash_handle hh;
} VariableEntry;

typedef struct {
  VariableEntry *variables_hash;
} CalculatorInterpreterContext;

static CalculatorInterpreterContext *calculator_interpreter_context_new(void) {
  CalculatorInterpreterContext *ctx =
      malloc(sizeof(CalculatorInterpreterContext));
  ctx->variables_hash = NULL;
  return ctx;
}

static void
calculator_interpreter_context_free(CalculatorInterpreterContext *ctx) {
  VariableEntry *entry, *tmp;

  HASH_ITER(hh, ctx->variables_hash, entry, tmp) {
    free(entry->name);
    HASH_DEL(ctx->variables_hash, entry);
    free(entry);
  }

  free(ctx);
}

static int64_t *
calculator_interpreter_context_get(CalculatorInterpreterContext *ctx,
                                   const char *name) {
  VariableEntry *entry = NULL;
  HASH_FIND_STR(ctx->variables_hash, name, entry);
  return entry ? &entry->value : NULL;
}

static void
calculator_interpreter_context_set(CalculatorInterpreterContext *ctx,
                                   const char *name, int64_t value) {
  VariableEntry *entry = NULL;
  HASH_FIND_STR(ctx->variables_hash, name, entry);

  if (entry) {
    entry->value = value;
  } else {
    entry = malloc(sizeof(VariableEntry));
    entry->name = strdup(name);
    entry->value = value;
    HASH_ADD_KEYPTR(hh, ctx->variables_hash, entry->name, strlen(entry->name),
                    entry);
  }
}

static int64_t calculator_interpreter_simple_div(int64_t a, int64_t b) {
  if (b == 0)
    return 0;
  if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
    return a / b;
  } else {
    int64_t abs_a = a >= 0 ? a : -a;
    int64_t abs_b = b >= 0 ? b : -b;
    return -(abs_a / abs_b);
  }
}

static int64_t calculator_interpreter_simple_mod(int64_t a, int64_t b) {
  if (b == 0)
    return 0;
  return a - calculator_interpreter_simple_div(a, b) * b;
}

static int64_t
calculator_interpreter_evaluate(AST_Node *node,
                                CalculatorInterpreterContext *ctx) {
  switch (node->type) {
  case AST_NUMBER:
    return node->data.number_value;

  case AST_VARIABLE: {
    int64_t *value =
        calculator_interpreter_context_get(ctx, node->data.variable_name);
    return value ? *value : 0;
  }

  case AST_BINARY_OP: {
    AST_BinaryOp *binop = node->data.binary_op;
    int64_t left = calculator_interpreter_evaluate(binop->left, ctx);
    int64_t right = calculator_interpreter_evaluate(binop->right, ctx);

    switch (binop->op) {
    case '+':
      return left + right;
    case '-':
      return left - right;
    case '*':
      return left * right;
    case '/':
      return calculator_interpreter_simple_div(left, right);
    case '%':
      return calculator_interpreter_simple_mod(left, right);
    default:
      return 0;
    }
  }

  case AST_ASSIGNMENT: {
    AST_Assignment *assign = node->data.assignment;
    int64_t value = calculator_interpreter_evaluate(assign->expr, ctx);
    calculator_interpreter_context_set(ctx, assign->var_name, value);
    return value;
  }
  }
  return 0;
}

typedef struct {
  CalculatorAstData ast_data;
  uint32_t result_val;
} CalculatorInterpreterData;

void CalculatorInterpreter_prepare(Benchmark *self) {
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;

  data->ast_data.operations = Helper_config_i64(self->name, "operations");
  if (data->ast_data.operations <= 0) {
    data->ast_data.operations = 1000;
  }

  data->ast_data.text =
      calculator_ast_generate_random_program(data->ast_data.operations);
  data->ast_data.expressions = NULL;
  data->ast_data.expressions_count = 0;
  data->ast_data.expressions_capacity = 0;

  CalculatorAstParser parser;
  calculator_ast_parser_init(&parser, data->ast_data.text);
  calculator_ast_parser_parse_all(&parser, &data->ast_data);

  data->result_val = 0;
}

void CalculatorInterpreter_run(Benchmark *self, int iteration_id) {
  (void)iteration_id;
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;

  CalculatorInterpreterContext *ctx = calculator_interpreter_context_new();
  int64_t iteration_result = 0;

  for (int64_t i = 0; i < data->ast_data.expressions_count; i++) {
    iteration_result =
        calculator_interpreter_evaluate(data->ast_data.expressions[i], ctx);
  }

  calculator_interpreter_context_free(ctx);

  data->result_val += iteration_result;
}

uint32_t CalculatorInterpreter_checksum(Benchmark *self) {
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;
  return data->result_val;
}

void CalculatorInterpreter_cleanup(Benchmark *self) {
  CalculatorInterpreterData *data = (CalculatorInterpreterData *)self->data;

  if (data->ast_data.text) {
    free(data->ast_data.text);
    data->ast_data.text = NULL;
  }

  if (data->ast_data.expressions) {
    for (int64_t i = 0; i < data->ast_data.expressions_count; i++) {
      ast_node_free(data->ast_data.expressions[i]);
    }
    free(data->ast_data.expressions);
    data->ast_data.expressions = NULL;
  }
}

Benchmark *CalculatorInterpreter_create(void) {
  Benchmark *bench = Benchmark_create("Calculator::Interpreter");

  CalculatorInterpreterData *data = malloc(sizeof(CalculatorInterpreterData));
  memset(data, 0, sizeof(CalculatorInterpreterData));

  bench->data = data;

  bench->prepare = CalculatorInterpreter_prepare;
  bench->run = CalculatorInterpreter_run;
  bench->checksum = CalculatorInterpreter_checksum;
  bench->cleanup = CalculatorInterpreter_cleanup;

  return bench;
}
