import Foundation

private let CHAR_EOF: UInt8 = 0
private let CHAR_PLUS = UInt8(ascii: "+")
private let CHAR_MINUS = UInt8(ascii: "-")
private let CHAR_STAR = UInt8(ascii: "*")
private let CHAR_SLASH = UInt8(ascii: "/")
private let CHAR_PERCENT = UInt8(ascii: "%")
private let CHAR_LPAREN = UInt8(ascii: "(")
private let CHAR_RPAREN = UInt8(ascii: ")")
private let CHAR_EQUALS = UInt8(ascii: "=")
private let CHAR_ZERO = UInt8(ascii: "0")
private let CHAR_NINE = UInt8(ascii: "9")
private let CHAR_A_LOWER = UInt8(ascii: "a")
private let CHAR_Z_LOWER = UInt8(ascii: "z")
private let CHAR_A_UPPER = UInt8(ascii: "A")
private let CHAR_Z_UPPER = UInt8(ascii: "Z")
private let CHAR_SPACE = UInt8(ascii: " ")
private let CHAR_TAB = UInt8(ascii: "\t")
private let CHAR_NEWLINE = UInt8(ascii: "\n")
private let CHAR_CR = UInt8(ascii: "\r")

final class CalculatorAst: BenchmarkProtocol {
  indirect enum Node {
    case number(Int64)
    case variable(String)
    case binaryOp(Character, Node, Node)
    case assignment(String, Node)
  }

  private var resultVal: UInt32 = 0
  private var text: String = ""
  public var expressions: [Node] = []
  public var n: Int64 = 0

  init() {
    n = configValue("operations") ?? 0
  }

  private func generateRandomProgram(_ n: Int64 = 1000) -> String {
    var result = "v0 = 1\n"
    for i in 0..<10 {
      let v = i + 1
      result += "v\(v) = v\(v - 1) + \(v)\n"
    }
    for i in 0..<Int(n) {
      let v = i + 10
      result += "v\(v) = v\(v - 1) + "
      let rand = Helper.nextInt(max: 10)
      switch rand {
      case 0:
        result +=
          "(v\(v - 1) / 3) * 4 - \(i) / (3 + (18 - v\(v - 2))) % v\(v - 3) + 2 * ((9 - v\(v - 6)) * (v\(v - 5) + 7))"
      case 1:
        result += "v\(v - 1) + (v\(v - 2) + v\(v - 3)) * v\(v - 4) - (v\(v - 5) / v\(v - 6))"
      case 2:
        result += "(3789 - (((v\(v - 7))))) + 1"
      case 3:
        result += "4/2 * (1-3) + v\(v - 9)/v\(v - 5)"
      case 4:
        result += "1+2+3+4+5+6+v\(v - 1)"
      case 5:
        result += "(99999 / v\(v - 3))"
      case 6:
        result += "0 + 0 - v\(v - 8)"
      case 7:
        result += "((((((((((v\(v - 6)))))))))) * 2"
      case 8:
        result += "\(i) * (v\(v - 1)%6)%7"
      case 9:
        result += "(1)/(0-v\(v - 5)) + (v\(v - 7))"
      default:
        result += "0"
      }
      result += "\n"
    }
    return result
  }

  private class Parser {
    private let input: String
    private let bytes: [UInt8]
    private var pos: Int
    private let len: Int
    private var currentByte: UInt8
    var expressions: [Node] = []

    init(_ input: String) {
      self.input = input
      self.bytes = Array(input.utf8)
      self.pos = 0
      self.len = self.bytes.count
      self.currentByte = self.len > 0 ? self.bytes[0] : CHAR_EOF
    }

    func parse() -> [Node] {
      while currentByte != CHAR_EOF {
        skipWhitespace()
        if currentByte == CHAR_EOF { break }
        expressions.append(parseExpression())

        skipWhitespace()
        while currentByte == CHAR_NEWLINE {
          advance()
          skipWhitespace()
        }
      }
      return expressions
    }

    private func parseExpression() -> Node {
      var node = parseTerm()
      while true {
        skipWhitespace()

        if currentByte == CHAR_PLUS || currentByte == CHAR_MINUS {
          let op = Character(UnicodeScalar(currentByte))
          advance()
          let right = parseTerm()
          node = .binaryOp(op, node, right)
        } else {
          break
        }
      }
      return node
    }

    private func parseTerm() -> Node {
      var node = parseFactor()
      while true {
        skipWhitespace()

        if currentByte == CHAR_STAR || currentByte == CHAR_SLASH || currentByte == CHAR_PERCENT {
          let op = Character(UnicodeScalar(currentByte))
          advance()
          let right = parseFactor()
          node = .binaryOp(op, node, right)
        } else {
          break
        }
      }
      return node
    }

    private func parseFactor() -> Node {
      skipWhitespace()

      if isDigit(currentByte) {
        return parseNumber()
      } else if isLetter(currentByte) {
        return parseVariable()
      } else if currentByte == CHAR_LPAREN {
        advance()
        let node = parseExpression()
        skipWhitespace()
        if currentByte == CHAR_RPAREN {
          advance()
        }
        return node
      } else {
        advance()
        return .number(0)
      }
    }

    private func parseNumber() -> Node {
      var value: Int64 = 0
      while isDigit(currentByte) {
        value = value * 10 + Int64(currentByte - CHAR_ZERO)
        advance()
      }
      return .number(value)
    }

    private func parseVariable() -> Node {
      let start = pos
      while isLetter(currentByte) || isDigit(currentByte) {
        advance()
      }

      let varName = String(bytes: bytes[start..<pos], encoding: .ascii) ?? ""

      skipWhitespace()
      if currentByte == CHAR_EQUALS {
        advance()
        let expr = parseExpression()
        return .assignment(varName, expr)
      }
      return .variable(varName)
    }

    private func advance() {
      pos += 1
      if pos >= len {
        currentByte = CHAR_EOF
      } else {
        currentByte = bytes[pos]
      }
    }

    private func skipWhitespace() {
      while isWhitespace(currentByte) {
        advance()
      }
    }

    private func isDigit(_ byte: UInt8) -> Bool {
      return byte >= CHAR_ZERO && byte <= CHAR_NINE
    }

    private func isLetter(_ byte: UInt8) -> Bool {
      return (byte >= CHAR_A_LOWER && byte <= CHAR_Z_LOWER)
        || (byte >= CHAR_A_UPPER && byte <= CHAR_Z_UPPER)
    }

    private func isWhitespace(_ byte: UInt8) -> Bool {
      return byte == CHAR_SPACE || byte == CHAR_TAB || byte == CHAR_NEWLINE || byte == CHAR_CR
    }
  }

  func prepare() {
    text = generateRandomProgram(n)
  }

  func run(iterationId: Int) {
    let parser = Parser(text)
    expressions = parser.parse()
    resultVal &+= UInt32(expressions.count)

    if !expressions.isEmpty,
      case .assignment(let varName, _) = expressions.last!
    {
      resultVal &+= Helper.checksum(varName)
    }
  }

  var checksum: UInt32 {
    return resultVal
  }
  func name() -> String {
    return "Calculator::Ast"
  }
}
