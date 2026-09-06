#include "calculator.hpp"
#include <cctype>
#include <cstdlib>
#include <sstream>

CalculatorAst::Parser::Parser(const std::string &input_str)
    : input(input_str), pos(0), len(input_str.size()) {
  current_char = len > 0 ? input[0] : CHAR_EOF;
}

void CalculatorAst::Parser::advance() {
  pos++;
  if (pos >= len) {
    current_char = CHAR_EOF;
  } else {
    current_char = input[pos];
  }
}

void CalculatorAst::Parser::skip_whitespace() {
  while (is_whitespace(current_char))
    advance();
}

CalculatorAst::Node CalculatorAst::Parser::parse_number() {
  int64_t v = 0;
  while (is_digit(current_char)) {
    v = v * 10 + (current_char - CHAR_ZERO);
    advance();
  }
  return Node(Number{v});
}

CalculatorAst::Node CalculatorAst::Parser::parse_variable() {
  size_t start = pos;
  while (is_letter(current_char) || is_digit(current_char))
    advance();
  std::string var_name = input.substr(start, pos - start);

  skip_whitespace();
  if (current_char == CHAR_EQUALS) {
    advance();
    auto expr = parse_expression();
    return Node(std::make_unique<Assignment>(var_name, std::move(expr)));
  }
  return Node(Variable{var_name});
}

CalculatorAst::Node CalculatorAst::Parser::parse_factor() {
  skip_whitespace();

  if (is_digit(current_char))
    return parse_number();
  if (is_letter(current_char))
    return parse_variable();
  if (current_char == CHAR_LPAREN) {
    advance();
    auto node = parse_expression();
    skip_whitespace();
    if (current_char == CHAR_RPAREN)
      advance();
    return node;
  }
  advance();
  return Node(Number{0});
}

CalculatorAst::Node CalculatorAst::Parser::parse_term() {
  auto node = parse_factor();

  while (true) {
    skip_whitespace();

    if (current_char == CHAR_STAR || current_char == CHAR_SLASH ||
        current_char == CHAR_PERCENT) {
      char op = current_char;
      advance();
      auto right = parse_factor();
      node = Node(
          std::make_unique<BinaryOp>(op, std::move(node), std::move(right)));
    } else
      break;
  }
  return node;
}

CalculatorAst::Node CalculatorAst::Parser::parse_expression() {
  auto node = parse_term();

  while (true) {
    skip_whitespace();

    if (current_char == CHAR_PLUS || current_char == CHAR_MINUS) {
      char op = current_char;
      advance();
      auto right = parse_term();
      node = Node(
          std::make_unique<BinaryOp>(op, std::move(node), std::move(right)));
    } else
      break;
  }
  return node;
}

std::vector<CalculatorAst::Node> CalculatorAst::Parser::parse() {
  expressions.clear();

  while (current_char != CHAR_EOF) {
    skip_whitespace();
    if (current_char == CHAR_EOF)
      break;

    expressions.push_back(parse_expression());

    skip_whitespace();
    while (current_char == CHAR_NEWLINE) {
      advance();
      skip_whitespace();
    }
  }
  return std::move(expressions);
}

CalculatorAst::CalculatorAst() : result_val(0), n(config_val("operations")) {}

std::string CalculatorAst::name() const { return "Calculator::Ast"; }

std::string CalculatorAst::generate_random_program(int64_t n) {
  std::ostringstream os;
  os << "v0 = 1\n";
  for (int i = 0; i < 10; i++) {
    int v = i + 1;
    os << "v" << v << " = v" << (v - 1) << " + " << v << "\n";
  }
  for (int64_t i = 0; i < n; i++) {
    int v = static_cast<int>(i + 10);
    os << "v" << v << " = v" << (v - 1) << " + ";
    switch (Helper::next_int(10)) {
    case 0:
      os << "(v" << (v - 1) << " / 3) * 4 - " << i << " / (3 + (18 - v"
         << (v - 2) << ")) % v" << (v - 3) << " + 2 * ((9 - v" << (v - 6)
         << ") * (v" << (v - 5) << " + 7))";
      break;
    case 1:
      os << "v" << (v - 1) << " + (v" << (v - 2) << " + v" << (v - 3) << ") * v"
         << (v - 4) << " - (v" << (v - 5) << " / v" << (v - 6) << ")";
      break;
    case 2:
      os << "(3789 - (((v" << (v - 7) << ")))) + 1";
      break;
    case 3:
      os << "4/2 * (1-3) + v" << (v - 9) << "/v" << (v - 5);
      break;
    case 4:
      os << "1+2+3+4+5+6+v" << (v - 1);
      break;
    case 5:
      os << "(99999 / v" << (v - 3) << ")";
      break;
    case 6:
      os << "0 + 0 - v" << (v - 8);
      break;
    case 7:
      os << "((((((((((v" << (v - 6) << ")))))))))) * 2";
      break;
    case 8:
      os << i << " * (v" << (v - 1) << "%6)%7";
      break;
    case 9:
      os << "(1)/(0-v" << (v - 5) << ") + (v" << (v - 7) << ")";
      break;
    }
    os << "\n";
  }
  return os.str();
}

void CalculatorAst::prepare() { text = generate_random_program(n); }

void CalculatorAst::run(int iteration_id) {
  (void)iteration_id;
  Parser parser(text);
  expressions = parser.parse();
  result_val += expressions.size();
  if (!expressions.empty() &&
      std::holds_alternative<std::unique_ptr<Assignment>>(
          expressions.back().data)) {
    auto &assign =
        *std::get<std::unique_ptr<Assignment>>(expressions.back().data);
    result_val += Helper::checksum(assign.var);
  }
}

uint32_t CalculatorAst::checksum() { return result_val; }

int64_t CalculatorInterpreter::Interpreter::simple_div(int64_t a, int64_t b) {
  if (b == 0)
    return 0;
  if ((a >= 0 && b > 0) || (a < 0 && b < 0))
    return a / b;
  return -(std::abs(a) / std::abs(b));
}

int64_t CalculatorInterpreter::Interpreter::simple_mod(int64_t a, int64_t b) {
  if (b == 0)
    return 0;
  return a - simple_div(a, b) * b;
}

int64_t CalculatorInterpreter::Interpreter::Evaluator::operator()(
    const CalculatorAst::Number &n) const {
  return n.value;
}

int64_t CalculatorInterpreter::Interpreter::Evaluator::operator()(
    const CalculatorAst::Variable &v) const {
  auto it = variables.find(v.name);
  return (it != variables.end()) ? it->second : 0;
}

int64_t CalculatorInterpreter::Interpreter::Evaluator::operator()(
    const std::unique_ptr<CalculatorAst::BinaryOp> &binop) const {
  int64_t left = std::visit(*this, binop->left.data);
  int64_t right = std::visit(*this, binop->right.data);
  switch (binop->op) {
  case '+':
    return left + right;
  case '-':
    return left - right;
  case '*':
    return left * right;
  case '/':
    return simple_div(left, right);
  case '%':
    return simple_mod(left, right);
  default:
    return 0;
  }
}

int64_t CalculatorInterpreter::Interpreter::Evaluator::operator()(
    const std::unique_ptr<CalculatorAst::Assignment> &assign) const {
  int64_t value = std::visit(*this, assign->expr.data);
  variables[assign->var] = value;
  return value;
}

int64_t CalculatorInterpreter::Interpreter::run(
    const std::vector<CalculatorAst::Node> &expressions) {
  int64_t result = 0;
  Evaluator evaluator(variables);
  for (const auto &expr : expressions)
    result = std::visit(evaluator, expr.data);
  return result;
}

CalculatorInterpreter::CalculatorInterpreter() : result_val(0) {
  n = config_val("operations");
}

std::string CalculatorInterpreter::name() const {
  return "Calculator::Interpreter";
}

void CalculatorInterpreter::prepare() {
  CalculatorAst ca;
  ca.n = n;
  ca.prepare();
  ca.run(0);
  ast = ca.take_ast();
}

void CalculatorInterpreter::run(int iteration_id) {
  (void)iteration_id;
  Interpreter interpreter;
  int64_t result = interpreter.run(ast);
  result_val += result;
}

uint32_t CalculatorInterpreter::checksum() { return result_val; }