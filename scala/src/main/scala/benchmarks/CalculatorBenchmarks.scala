package benchmarks

import scala.collection.mutable.{ArrayBuffer, Map}

class CalculatorAst extends Benchmark:
  sealed trait Node
  case class Number(value: Long) extends Node
  case class Variable(name: String) extends Node
  case class BinaryOp(op: Char, left: Node, right: Node) extends Node
  case class Assignment(variable: String, expr: Node) extends Node

  var n: Long = 0L
  private var resultVal: Long = 0L
  private var text: String = _
  var expressions: List[Node] = _

  n = configVal("operations")

  private def generateRandomProgram(lines: Long = 1000): String = {
    val sb = new StringBuilder()
    sb.append("v0 = 1\n")

    var i = 0
    while (i < 10) {
      val v = i + 1
      sb.append(s"v$v = v${v - 1} + $v\n")
      i += 1
    }

    i = 0
    while (i < lines) {
      val v = i + 10
      sb.append(s"v$v = v${v - 1} + ")
      Helper.nextInt(10) match {
        case 0 =>
          sb.append(
            s"(v${v - 1} / 3) * 4 - $i / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))"
          )
        case 1 => sb.append(s"v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} /  v${v - 6})")
        case 2 => sb.append(s"(3789 - (((v${v - 7})))) + 1")
        case 3 => sb.append(s"4/2 * (1-3) + v${v - 9}/v${v - 5}")
        case 4 => sb.append(s"1+2+3+4+5+6+v${v - 1}")
        case 5 => sb.append(s"(99999 / v${v - 3})")
        case 6 => sb.append(s"0 + 0 - v${v - 8}")
        case 7 => sb.append(s"((((((((((v${v - 6})))))))))) * 2")
        case 8 => sb.append(s"$i * (v${v - 1}%6)%7")
        case 9 => sb.append(s"(1)/(0-v${v - 5}) + (v${v - 7})")
      }
      sb.append("\n")
      i += 1
    }
    sb.toString()
  }

  override def prepare(): Unit = {
    text = generateRandomProgram(n)
  }

  private object CharCodes {
    val CHAR_EOF = '\u0000'
    val CHAR_PLUS = '+'
    val CHAR_MINUS = '-'
    val CHAR_STAR = '*'
    val CHAR_SLASH = '/'
    val CHAR_PERCENT = '%'
    val CHAR_LPAREN = '('
    val CHAR_RPAREN = ')'
    val CHAR_EQUALS = '='
    val CHAR_ZERO = '0'
    val CHAR_NINE = '9'
    val CHAR_A_LOWER = 'a'
    val CHAR_Z_LOWER = 'z'
    val CHAR_A_UPPER = 'A'
    val CHAR_Z_UPPER = 'Z'
    val CHAR_SPACE = ' '
    val CHAR_TAB = '\t'
    val CHAR_NEWLINE = '\n'
    val CHAR_CR = '\r'
  }

  private class Parser(val input: String) {
    import CharCodes._

    private var pos = 0
    private var currentChar = if (input.nonEmpty) input.charAt(0) else CHAR_EOF
    val expressions = ArrayBuffer.empty[Node]

    def parse(): List[Node] = {
      while (currentChar != CHAR_EOF) {
        skipWhitespace()
        if (currentChar == CHAR_EOF) return expressions.toList

        expressions.append(parseExpression())

        skipWhitespace()
        while (currentChar == CHAR_NEWLINE) {
          advance()
          skipWhitespace()
        }
      }
      expressions.toList
    }

    private def parseExpression(): Node = {
      var node = parseTerm()

      while (true) {
        skipWhitespace()

        if (currentChar == CHAR_PLUS || currentChar == CHAR_MINUS) {
          val op = currentChar
          advance()
          val right = parseTerm()
          node = BinaryOp(op, node, right)
        } else {
          return node
        }
      }
      node
    }

    private def parseTerm(): Node = {
      var node = parseFactor()

      while (true) {
        skipWhitespace()

        if (currentChar == CHAR_STAR || currentChar == CHAR_SLASH || currentChar == CHAR_PERCENT) {
          val op = currentChar
          advance()
          val right = parseFactor()
          node = BinaryOp(op, node, right)
        } else {
          return node
        }
      }
      node
    }

    private def parseFactor(): Node = {
      skipWhitespace()

      if (isDigit(currentChar)) {
        parseNumber()
      } else if (isLetter(currentChar)) {
        parseVariable()
      } else if (currentChar == CHAR_LPAREN) {
        advance()
        val node = parseExpression()
        skipWhitespace()
        if (currentChar == CHAR_RPAREN) advance()
        node
      } else {
        advance()
        Number(0)
      }
    }

    private def parseNumber(): Node = {
      var value = 0L
      while (isDigit(currentChar)) {
        value = value * 10 + (currentChar - CHAR_ZERO)
        advance()
      }
      Number(value)
    }

    private def parseVariable(): Node = {
      val start = pos
      while (isLetter(currentChar) || isDigit(currentChar)) {
        advance()
      }
      val varName = input.substring(start, pos)

      skipWhitespace()
      if (currentChar == CHAR_EQUALS) {
        advance()
        val expr = parseExpression()
        Assignment(varName, expr)
      } else {
        Variable(varName)
      }
    }

    private def advance(): Unit = {
      pos += 1
      if (pos >= input.length) {
        currentChar = CHAR_EOF
      } else {
        currentChar = input.charAt(pos)
      }
    }

    private def skipWhitespace(): Unit = {
      while (isWhitespace(currentChar)) {
        advance()
      }
    }

    private def isDigit(char: Char): Boolean = {
      char >= CHAR_ZERO && char <= CHAR_NINE
    }

    private def isLetter(char: Char): Boolean = {
      (char >= CHAR_A_LOWER && char <= CHAR_Z_LOWER) ||
      (char >= CHAR_A_UPPER && char <= CHAR_Z_UPPER)
    }

    private def isWhitespace(char: Char): Boolean = {
      char == CHAR_SPACE || char == CHAR_TAB || char == CHAR_NEWLINE || char == CHAR_CR
    }
  }

  override def run(iterationId: Int): Unit = {
    val parser = new Parser(text)
    expressions = parser.parse()
    resultVal += expressions.size.toLong
    if (expressions.nonEmpty && expressions.last.isInstanceOf[Assignment]) {
      val assign = expressions.last.asInstanceOf[Assignment]
      resultVal += Helper.checksum(assign.variable)
    }
  }

  override def checksum(): Long = resultVal & 0xffffffffL

  override def name(): String = "Calculator::Ast"

class CalculatorInterpreter extends Benchmark:
  private var n: Long = 0L
  private var resultVal: Long = 0L
  private var ast: List[CalculatorAst#Node] = _

  override def name(): String = "Calculator::Interpreter"

  override def prepare(): Unit = {
    n = configVal("operations")
    val calculator = new CalculatorAst()
    calculator.n = n
    calculator.prepare()
    calculator.run(0)
    ast = calculator.expressions
  }

  private class Interpreter {
    private val variables = scala.collection.mutable.Map.empty[String, Long]

    private def simpleDiv(a: Long, b: Long): Long = {
      if (b == 0L) return 0L
      if ((a >= 0 && b > 0) || (a < 0 && b < 0)) {
        a / b
      } else {
        -math.abs(a) / math.abs(b)
      }
    }

    private def simpleMod(a: Long, b: Long): Long = {
      if (b == 0L) return 0L
      a - simpleDiv(a, b) * b
    }

    private def evaluate(node: CalculatorAst#Node): Long = {
      node match {
        case num: CalculatorAst#Number =>
          num.value
        case varNode: CalculatorAst#Variable =>
          variables.getOrElse(varNode.name, 0L)
        case binOp: CalculatorAst#BinaryOp =>
          val left = evaluate(binOp.left)
          val right = evaluate(binOp.right)
          binOp.op match {
            case '+' => left + right
            case '-' => left - right
            case '*' => left * right
            case '/' => simpleDiv(left, right)
            case '%' => simpleMod(left, right)
            case _   => 0L
          }
        case assign: CalculatorAst#Assignment =>
          val value = evaluate(assign.expr)
          variables(assign.variable) = value
          value
      }
    }

    def run(expressions: List[CalculatorAst#Node]): Long = {
      var result = 0L
      for (expr <- expressions) {
        result = evaluate(expr)
      }
      result
    }
  }

  override def run(iterationId: Int): Unit = {
    val interpreter = new Interpreter()
    val result = interpreter.run(ast)
    resultVal += result
  }

  override def checksum(): Long = resultVal & 0xffffffffL
