import ../benchmark
import ../helper
import calculator_common

const
  CHAR_EOF = byte(0)
  CHAR_PLUS = byte('+')
  CHAR_MINUS = byte('-')
  CHAR_STAR = byte('*')
  CHAR_SLASH = byte('/')
  CHAR_PERCENT = byte('%')
  CHAR_LPAREN = byte('(')
  CHAR_RPAREN = byte(')')
  CHAR_EQUALS = byte('=')
  CHAR_ZERO = byte('0')
  CHAR_NINE = byte('9')
  CHAR_A_LOWER = byte('a')
  CHAR_Z_LOWER = byte('z')
  CHAR_A_UPPER = byte('A')
  CHAR_Z_UPPER = byte('Z')
  CHAR_SPACE = byte(' ')
  CHAR_TAB = byte('\t')
  CHAR_NEWLINE = byte('\n')
  CHAR_CR = byte('\r')

type
  Parser = object
    input: string
    pos: int
    len: int
    currentByte: byte
    expressions: seq[Node]

  CalculatorAst* = ref object of Benchmark
    n*: int64
    resultVal*: uint32
    expressions*: seq[Node]
    text*: string

proc newParser*(input: string): Parser =
  result = Parser(
    input: input,
    pos: 0,
    len: input.len,
    expressions: @[]
  )
  if result.len > 0:
    result.currentByte = byte(input[0])
  else:
    result.currentByte = CHAR_EOF

proc advance(p: var Parser) =
  inc p.pos
  if p.pos >= p.len:
    p.currentByte = CHAR_EOF
  else:
    p.currentByte = byte(p.input[p.pos])

proc isWhitespace(byte: byte): bool =
  byte == CHAR_SPACE or byte == CHAR_TAB or byte == CHAR_NEWLINE or byte == CHAR_CR

proc skipWhitespace(p: var Parser) =
  while isWhitespace(p.currentByte):
    p.advance()

proc parseNumber(p: var Parser): Node

proc parseVariable(p: var Parser): Node

proc parseFactor(p: var Parser): Node

proc parseTerm(p: var Parser): Node

proc parseExpression(p: var Parser): Node

proc isDigit(byte: byte): bool =
  byte >= CHAR_ZERO and byte <= CHAR_NINE

proc isLetter(byte: byte): bool =
  (byte >= CHAR_A_LOWER and byte <= CHAR_Z_LOWER) or
    (byte >= CHAR_A_UPPER and byte <= CHAR_Z_UPPER)

proc parseNumber(p: var Parser): Node =
  var v: int64 = 0
  while isDigit(p.currentByte):
    v = v * 10 + (int(p.currentByte) - int(CHAR_ZERO))
    p.advance()
  newNodeNumber(v)

proc parseVariable(p: var Parser): Node =
  let startPos = p.pos

  while isLetter(p.currentByte) or isDigit(p.currentByte):
    p.advance()

  let varName = p.input.substr(startPos, p.pos - 1)

  p.skipWhitespace()
  if p.currentByte == CHAR_EQUALS:
    p.advance()
    let expr = p.parseExpression()
    return newNodeAssignment(varName, expr)

  newNodeVariable(varName)

proc parseFactor(p: var Parser): Node =
  p.skipWhitespace()

  if isDigit(p.currentByte):
    return p.parseNumber()

  if isLetter(p.currentByte):
    return p.parseVariable()

  if p.currentByte == CHAR_LPAREN:
    p.advance()
    let node = p.parseExpression()
    p.skipWhitespace()
    if p.currentByte == CHAR_RPAREN:
      p.advance()
    return node

  p.advance()
  newNodeNumber(0)

proc parseTerm(p: var Parser): Node =
  var node = p.parseFactor()

  while true:
    p.skipWhitespace()

    if p.currentByte == CHAR_STAR or p.currentByte == CHAR_SLASH or
        p.currentByte == CHAR_PERCENT:
      let op = char(p.currentByte)
      p.advance()
      let right = p.parseFactor()
      node = newNodeBinaryOp(op, node, right)
    else:
      break

  node

proc parseExpression(p: var Parser): Node =
  var node = p.parseTerm()

  while true:
    p.skipWhitespace()

    if p.currentByte == CHAR_PLUS or p.currentByte == CHAR_MINUS:
      let op = char(p.currentByte)
      p.advance()
      let right = p.parseTerm()
      node = newNodeBinaryOp(op, node, right)
    else:
      break

  node

proc parse*(p: var Parser): seq[Node] =
  p.expressions = @[]

  while p.currentByte != CHAR_EOF:
    p.skipWhitespace()
    if p.currentByte == CHAR_EOF:
      break

    let expr = p.parseExpression()
    p.expressions.add(expr)

    p.skipWhitespace()
    while p.currentByte == CHAR_NEWLINE:
      p.advance()
      p.skipWhitespace()

  p.expressions

proc newCalculatorAst(): Benchmark =
  CalculatorAst()

method name(self: CalculatorAst): string = "Calculator::Ast"

method prepare(self: CalculatorAst) =
  self.n = config_i64("Calculator::Ast", "operations")
  self.text = generateRandomProgram(self.n)
  self.resultVal = 0
  self.expressions = @[]

method run(self: CalculatorAst, iteration_id: int) =
  var parser = newParser(self.text)
  self.expressions = parser.parse()
  self.resultVal = self.resultVal + uint32(self.expressions.len)

  if self.expressions.len > 0:
    let lastExpr = self.expressions[^1]
    if lastExpr.kind == nkAssignment:

      self.resultVal = self.resultVal + checksum(lastExpr.assignVar)

method checksum(self: CalculatorAst): uint32 =
  self.resultVal

registerBenchmark("Calculator::Ast", newCalculatorAst)
{.used.}
