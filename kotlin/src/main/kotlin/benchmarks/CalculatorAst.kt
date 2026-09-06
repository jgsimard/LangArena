package benchmarks

import Benchmark

class CalculatorAst : Benchmark() {
    sealed interface Node

    data class Number(
        val value: Long,
    ) : Node

    data class Variable(
        val name: String,
    ) : Node

    data class BinaryOp(
        val op: Char,
        val left: Node,
        val right: Node,
    ) : Node

    data class Assignment(
        val variable: String,
        val expr: Node,
    ) : Node

    var n = configVal("operations")
    private var resultVal: UInt = 0u
    private lateinit var text: String
    lateinit var expressions: List<Node>

    private fun generateRandomProgram(lines: Long = 1000): String =
        buildString {
            append("v0 = 1\n")
            for (i in 0 until 10) {
                val v = i + 1
                append("v$v = v${v - 1} + $v\n")
            }
            for (i in 0 until lines) {
                val v = i + 10
                append("v$v = v${v - 1} + ")
                when (Helper.nextInt(10)) {
                    0 -> append("(v${v - 1} / 3) * 4 - $i / (3 + (18 - v${v - 2})) % v${v - 3} + 2 * ((9 - v${v - 6}) * (v${v - 5} + 7))")
                    1 -> append("v${v - 1} + (v${v - 2} + v${v - 3}) * v${v - 4} - (v${v - 5} /  v${v - 6})")
                    2 -> append("(3789 - (((v${v - 7})))) + 1")
                    3 -> append("4/2 * (1-3) + v${v - 9}/v${v - 5}")
                    4 -> append("1+2+3+4+5+6+v${v - 1}")
                    5 -> append("(99999 / v${v - 3})")
                    6 -> append("0 + 0 - v${v - 8}")
                    7 -> append("((((((((((v${v - 6})))))))))) * 2")
                    8 -> append("$i * (v${v - 1}%6)%7")
                    9 -> append("(1)/(0-v${v - 5}) + (v${v - 7})")
                }
                append("\n")
            }
        }

    override fun prepare() {
        text = generateRandomProgram(n)
    }

    private class Parser(
        private val input: String,
    ) {
        companion object {
            private const val CHAR_EOF = '\u0000'
            private const val CHAR_PLUS = '+'
            private const val CHAR_MINUS = '-'
            private const val CHAR_STAR = '*'
            private const val CHAR_SLASH = '/'
            private const val CHAR_PERCENT = '%'
            private const val CHAR_LPAREN = '('
            private const val CHAR_RPAREN = ')'
            private const val CHAR_EQUALS = '='
            private const val CHAR_ZERO = '0'
            private const val CHAR_NINE = '9'
            private const val CHAR_A_LOWER = 'a'
            private const val CHAR_Z_LOWER = 'z'
            private const val CHAR_A_UPPER = 'A'
            private const val CHAR_Z_UPPER = 'Z'
            private const val CHAR_SPACE = ' '
            private const val CHAR_TAB = '\t'
            private const val CHAR_NEWLINE = '\n'
            private const val CHAR_CR = '\r'
        }

        private var pos = 0
        private var currentChar = if (input.isNotEmpty()) input[0] else CHAR_EOF
        val expressions = mutableListOf<Node>()

        fun parse(): List<Node> {
            while (currentChar != CHAR_EOF) {
                skipWhitespace()
                if (currentChar == CHAR_EOF) break

                expressions.add(parseExpression())

                skipWhitespace()
                while (currentChar == CHAR_NEWLINE) {
                    advance()
                    skipWhitespace()
                }
            }
            return expressions
        }

        private fun parseExpression(): Node {
            var node = parseTerm()

            while (true) {
                skipWhitespace()

                if (currentChar == CHAR_PLUS || currentChar == CHAR_MINUS) {
                    val op = currentChar
                    advance()
                    val right = parseTerm()
                    node = BinaryOp(op, node, right)
                } else {
                    break
                }
            }

            return node
        }

        private fun parseTerm(): Node {
            var node = parseFactor()

            while (true) {
                skipWhitespace()

                if (currentChar == CHAR_STAR || currentChar == CHAR_SLASH || currentChar == CHAR_PERCENT) {
                    val op = currentChar
                    advance()
                    val right = parseFactor()
                    node = BinaryOp(op, node, right)
                } else {
                    break
                }
            }

            return node
        }

        private fun parseFactor(): Node {
            skipWhitespace()

            return when {
                isDigit(currentChar) -> {
                    parseNumber()
                }

                isLetter(currentChar) -> {
                    parseVariable()
                }

                currentChar == CHAR_LPAREN -> {
                    advance()
                    val node = parseExpression()
                    skipWhitespace()
                    if (currentChar == CHAR_RPAREN) {
                        advance()
                    }
                    node
                }

                else -> {
                    advance()
                    Number(0)
                }
            }
        }

        private fun parseNumber(): Node {
            var value = 0L
            while (isDigit(currentChar)) {
                value = value * 10 + (currentChar - CHAR_ZERO)
                advance()
            }
            return Number(value)
        }

        private fun parseVariable(): Node {
            val start = pos
            while (isLetter(currentChar) || isDigit(currentChar)) {
                advance()
            }
            val varName = input.substring(start, pos)

            skipWhitespace()
            if (currentChar == CHAR_EQUALS) {
                advance()
                val expr = parseExpression()
                return Assignment(varName, expr)
            }

            return Variable(varName)
        }

        private fun advance() {
            pos++
            if (pos >= input.length) {
                currentChar = CHAR_EOF
            } else {
                currentChar = input[pos]
            }
        }

        private fun skipWhitespace() {
            while (isWhitespace(currentChar)) {
                advance()
            }
        }

        private fun isDigit(char: Char): Boolean = char >= CHAR_ZERO && char <= CHAR_NINE

        private fun isLetter(char: Char): Boolean =
            (char >= CHAR_A_LOWER && char <= CHAR_Z_LOWER) ||
                (char >= CHAR_A_UPPER && char <= CHAR_Z_UPPER)

        private fun isWhitespace(char: Char): Boolean = char == CHAR_SPACE || char == CHAR_TAB || char == CHAR_NEWLINE || char == CHAR_CR
    }

    override fun run(iterationId: Int) {
        val parser = Parser(text)
        expressions = parser.parse()
        resultVal += expressions.size.toUInt()
        val last = expressions.lastOrNull()
        if (last is Assignment) {
            resultVal += Helper.checksum(last.variable)
        }
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Calculator::Ast"
}
