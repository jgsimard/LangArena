package main

import (
	"fmt"
	"strconv"
	"strings"
)

const (
	CHAR_EOF     byte = 0
	CHAR_PLUS    byte = '+'
	CHAR_MINUS   byte = '-'
	CHAR_STAR    byte = '*'
	CHAR_SLASH   byte = '/'
	CHAR_PERCENT byte = '%'
	CHAR_LPAREN  byte = '('
	CHAR_RPAREN  byte = ')'
	CHAR_EQUALS  byte = '='
	CHAR_ZERO    byte = '0'
	CHAR_NINE    byte = '9'
	CHAR_A_LOWER byte = 'a'
	CHAR_Z_LOWER byte = 'z'
	CHAR_A_UPPER byte = 'A'
	CHAR_Z_UPPER byte = 'Z'
	CHAR_SPACE   byte = ' '
	CHAR_TAB     byte = '\t'
	CHAR_NEWLINE byte = '\n'
	CHAR_CR      byte = '\r'
)

type AstNode interface{}
type NumberNode struct{ value int64 }
type VariableNode struct{ name string }
type BinaryOpNode struct {
	op    byte
	left  AstNode
	right AstNode
}
type AssignmentNode struct {
	varName string
	expr    AstNode
}

type Parser struct {
	input   string
	pos     int
	len     int
	current byte
}

func NewParser(input string) *Parser {
	p := &Parser{
		input: input,
		len:   len(input),
	}
	if p.len > 0 {
		p.current = input[0]
	} else {
		p.current = CHAR_EOF
	}
	return p
}

func (p *Parser) parse() []AstNode {
	nodes := make([]AstNode, 0)
	for p.current != CHAR_EOF {
		p.skipWhitespace()
		if p.current == CHAR_EOF {
			break
		}
		node := p.parseExpression()
		if node != nil {
			nodes = append(nodes, node)
		}

		p.skipWhitespace()
		for p.current == CHAR_NEWLINE {
			p.advance()
			p.skipWhitespace()
		}
	}
	return nodes
}

func (p *Parser) parseExpression() AstNode {
	node := p.parseTerm()

	for {
		p.skipWhitespace()

		if p.current == CHAR_PLUS || p.current == CHAR_MINUS {
			op := p.current
			p.advance()
			right := p.parseTerm()
			node = BinaryOpNode{op: op, left: node, right: right}
		} else {
			break
		}
	}

	return node
}

func (p *Parser) parseTerm() AstNode {
	node := p.parseFactor()

	for {
		p.skipWhitespace()

		if p.current == CHAR_STAR || p.current == CHAR_SLASH || p.current == CHAR_PERCENT {
			op := p.current
			p.advance()
			right := p.parseFactor()
			node = BinaryOpNode{op: op, left: node, right: right}
		} else {
			break
		}
	}

	return node
}

func (p *Parser) parseFactor() AstNode {
	p.skipWhitespace()

	if p.isDigit(p.current) {
		return p.parseNumber()
	} else if p.isLetter(p.current) {
		return p.parseVariable()
	} else if p.current == CHAR_LPAREN {
		p.advance()
		node := p.parseExpression()
		p.skipWhitespace()
		if p.current == CHAR_RPAREN {
			p.advance()
		}
		return node
	} else {
		p.advance()
		return NumberNode{value: 0}
	}
}

func (p *Parser) parseNumber() AstNode {
	start := p.pos
	for p.isDigit(p.current) {
		p.advance()
	}
	val, _ := strconv.ParseInt(p.input[start:p.pos], 10, 64)
	return NumberNode{value: val}
}

func (p *Parser) parseVariable() AstNode {
	start := p.pos
	for p.isLetter(p.current) || p.isDigit(p.current) {
		p.advance()
	}
	varName := p.input[start:p.pos]

	p.skipWhitespace()
	if p.current == CHAR_EQUALS {
		p.advance()
		expr := p.parseExpression()
		return AssignmentNode{varName: varName, expr: expr}
	}

	return VariableNode{name: varName}
}

func (p *Parser) advance() {
	p.pos++
	if p.pos >= p.len {
		p.current = CHAR_EOF
	} else {
		p.current = p.input[p.pos]
	}
}

func (p *Parser) skipWhitespace() {
	for p.isWhitespace(p.current) {
		p.advance()
	}
}

func (p *Parser) isDigit(byte byte) bool {
	return byte >= CHAR_ZERO && byte <= CHAR_NINE
}

func (p *Parser) isLetter(byte byte) bool {
	return (byte >= CHAR_A_LOWER && byte <= CHAR_Z_LOWER) ||
		(byte >= CHAR_A_UPPER && byte <= CHAR_Z_UPPER)
}

func (p *Parser) isWhitespace(byte byte) bool {
	return byte == CHAR_SPACE || byte == CHAR_TAB || byte == CHAR_NEWLINE || byte == CHAR_CR
}

type CalculatorAst struct {
	BaseBenchmark
	n           int64
	result      uint32
	text        string
	expressions []AstNode
}

func (c *CalculatorAst) generateRandomProgram(n int) string {
	var builder strings.Builder
	builder.WriteString("v0 = 1\n")

	for i := 0; i < 10; i++ {
		v := i + 1
		builder.WriteString(fmt.Sprintf("v%d = v%d + %d\n", v, v-1, v))
	}

	for i := 0; i < n; i++ {
		v := i + 10
		builder.WriteString(fmt.Sprintf("v%d = v%d + ", v, v-1))

		switch NextInt(10) {
		case 0:
			builder.WriteString(fmt.Sprintf(
				"(v%d / 3) * 4 - %d / (3 + (18 - v%d)) %% v%d + 2 * ((9 - v%d) * (v%d + 7))",
				v-1, i, v-2, v-3, v-6, v-5))
		case 1:
			builder.WriteString(fmt.Sprintf(
				"v%d + (v%d + v%d) * v%d - (v%d / v%d)",
				v-1, v-2, v-3, v-4, v-5, v-6))
		case 2:
			builder.WriteString(fmt.Sprintf("(3789 - (((v%d)))) + 1", v-7))
		case 3:
			builder.WriteString(fmt.Sprintf("4/2 * (1-3) + v%d/v%d", v-9, v-5))
		case 4:
			builder.WriteString(fmt.Sprintf("1+2+3+4+5+6+v%d", v-1))
		case 5:
			builder.WriteString(fmt.Sprintf("(99999 / v%d)", v-3))
		case 6:
			builder.WriteString(fmt.Sprintf("0 + 0 - v%d", v-8))
		case 7:
			builder.WriteString(fmt.Sprintf("((((((((((v%d)))))))))) * 2", v-6))
		case 8:
			builder.WriteString(fmt.Sprintf("%d * (v%d%%6)%%7", i, v-1))
		case 9:
			builder.WriteString(fmt.Sprintf("(1)/(0-v%d) + (v%d)", v-5, v-7))
		}
		builder.WriteString("\n")
	}

	return builder.String()
}

func (c *CalculatorAst) Prepare() {
	c.n = c.ConfigVal("operations")
	c.text = c.generateRandomProgram(int(c.n))
}

func (c *CalculatorAst) Run(iteration_id int) {
	parser := NewParser(c.text)
	c.expressions = parser.parse()
	c.result += uint32(len(c.expressions))
	if len(c.expressions) > 0 {
		lastExpr := c.expressions[len(c.expressions)-1]
		if assign, ok := lastExpr.(AssignmentNode); ok {
			c.result += uint32(Checksum(assign.varName))
		}
	}
}

func (c *CalculatorAst) Checksum() uint32 {
	return c.result
}

func simpleDiv(a, b int64) int64 {
	if b == 0 {
		return 0
	}
	if (a >= 0 && b > 0) || (a < 0 && b < 0) {
		return a / b
	} else {
		return -(abs(a) / abs(b))
	}
}

func simpleMod(a, b int64) int64 {
	if b == 0 {
		return 0
	}
	return a - simpleDiv(a, b)*b
}

func abs(x int64) int64 {
	if x < 0 {
		return -x
	}
	return x
}

type Interpreter struct {
	variables map[string]int64
}

func NewInterpreter() *Interpreter {
	return &Interpreter{
		variables: make(map[string]int64),
	}
}

func (i *Interpreter) evaluate(node AstNode) int64 {
	switch n := node.(type) {
	case NumberNode:
		return n.value
	case VariableNode:
		if val, ok := i.variables[n.name]; ok {
			return val
		}
		return 0
	case BinaryOpNode:
		left := i.evaluate(n.left)
		right := i.evaluate(n.right)

		switch n.op {
		case '+':
			return left + right
		case '-':
			return left - right
		case '*':
			return left * right
		case '/':
			return simpleDiv(left, right)
		case '%':
			return simpleMod(left, right)
		default:
			return 0
		}
	case AssignmentNode:
		value := i.evaluate(n.expr)
		i.variables[n.varName] = value
		return value
	default:
		return 0
	}
}

func (i *Interpreter) run(expressions []AstNode) int64 {
	var result int64 = 0
	for _, expr := range expressions {
		result = i.evaluate(expr)
	}
	return result
}

type CalculatorInterpreter struct {
	BaseBenchmark
	ast    []AstNode
	result uint32
}

func (c *CalculatorInterpreter) Prepare() {
	astBench := &CalculatorAst{BaseBenchmark: BaseBenchmark{className: "Calculator::Interpreter"}}
	astBench.n = c.ConfigVal("operations")
	astBench.Prepare()
	astBench.Run(0)
	c.ast = astBench.expressions
}

func (c *CalculatorInterpreter) Run(iteration_id int) {
	interpreter := NewInterpreter()
	result := interpreter.run(c.ast)
	c.result += uint32(result)
}

func (c *CalculatorInterpreter) Checksum() uint32 {
	return c.result
}
