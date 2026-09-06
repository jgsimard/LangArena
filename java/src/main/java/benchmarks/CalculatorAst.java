package benchmarks;

import java.util.*;

public class CalculatorAst extends Benchmark {

    interface Node {}

    static class Number implements Node {
        final long value;
        Number(long value) {
            this.value = value;
        }
    }

    static class Variable implements Node {
        final String name;
        Variable(String name) {
            this.name = name;
        }
    }

    static class BinaryOp implements Node {
        final char op;
        final Node left;
        final Node right;
        BinaryOp(char op, Node left, Node right) {
            this.op = op;
            this.left = left;
            this.right = right;
        }
    }

    static class Assignment implements Node {
        final String variable;
        final Node expr;
        Assignment(String variable, Node expr) {
            this.variable = variable;
            this.expr = expr;
        }
    }

    private long resultVal;
    private String text;
    public List<Node> expressions = new ArrayList<>();
    public long n;

    public CalculatorAst() {
        n = configVal("operations");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Calculator::Ast";
    }

    private String generateRandomProgram(long lines) {
        StringBuilder sb = new StringBuilder();
        sb.append("v0 = 1\n");

        for (int i = 0; i < 10; i++) {
            int v = i + 1;
            sb.append("v").append(v).append(" = v").append(v - 1)
            .append(" + ").append(v).append("\n");
        }

        for (long i = 0; i < lines; i++) {
            int v = (int)(i + 10);
            sb.append("v").append(v).append(" = v").append(v - 1).append(" + ");

            switch (Helper.nextInt(10)) {
            case 0:
                sb.append("(v").append(v - 1).append(" / 3) * 4 - ").append(i)
                .append(" / (3 + (18 - v").append(v - 2).append(")) % v")
                .append(v - 3).append(" + 2 * ((9 - v").append(v - 6)
                .append(") * (v").append(v - 5).append(" + 7))");
                break;
            case 1:
                sb.append("v").append(v - 1).append(" + (v").append(v - 2)
                .append(" + v").append(v - 3).append(") * v").append(v - 4)
                .append(" - (v").append(v - 5).append(" /  v").append(v - 6).append(")");
                break;
            case 2:
                sb.append("(3789 - (((v").append(v - 7).append(")))) + 1");
                break;
            case 3:
                sb.append("4/2 * (1-3) + v").append(v - 9).append("/v").append(v - 5);
                break;
            case 4:
                sb.append("1+2+3+4+5+6+v").append(v - 1);
                break;
            case 5:
                sb.append("(99999 / v").append(v - 3).append(")");
                break;
            case 6:
                sb.append("0 + 0 - v").append(v - 8);
                break;
            case 7:
                sb.append("((((((((((v").append(v - 6).append(")))))))))) * 2");
                break;
            case 8:
                sb.append(i).append(" * (v").append(v - 1).append("%6)%7");
                break;
            case 9:
                sb.append("(1)/(0-v").append(v - 5).append(") + (v").append(v - 7).append(")");
                break;
            }
            sb.append("\n");
        }

        return sb.toString();
    }

    @Override
    public void prepare() {
        text = generateRandomProgram(n);
    }

    static class Parser {

        private static final char CHAR_EOF = '\0';
        private static final char CHAR_PLUS = '+';
        private static final char CHAR_MINUS = '-';
        private static final char CHAR_STAR = '*';
        private static final char CHAR_SLASH = '/';
        private static final char CHAR_PERCENT = '%';
        private static final char CHAR_LPAREN = '(';
        private static final char CHAR_RPAREN = ')';
        private static final char CHAR_EQUALS = '=';
        private static final char CHAR_ZERO = '0';
        private static final char CHAR_NINE = '9';
        private static final char CHAR_A_LOWER = 'a';
        private static final char CHAR_Z_LOWER = 'z';
        private static final char CHAR_A_UPPER = 'A';
        private static final char CHAR_Z_UPPER = 'Z';
        private static final char CHAR_SPACE = ' ';
        private static final char CHAR_TAB = '\t';
        private static final char CHAR_NEWLINE = '\n';
        private static final char CHAR_CR = '\r';

        private final String input;
        private int pos;
        private char currentChar;
        final List<Node> expressions = new ArrayList<>();

        Parser(String input) {
            this.input = input;
            this.pos = 0;
            this.currentChar = input.length() > 0 ? input.charAt(0) : CHAR_EOF;
        }

        void parse() {
            while (currentChar != CHAR_EOF) {
                skipWhitespace();
                if (currentChar == CHAR_EOF) break;

                expressions.add(parseExpression());

                skipWhitespace();
                while (currentChar == CHAR_NEWLINE) {
                    advance();
                    skipWhitespace();
                }
            }
        }

        private Node parseExpression() {
            Node node = parseTerm();

            while (true) {
                skipWhitespace();

                if (currentChar == CHAR_PLUS || currentChar == CHAR_MINUS) {
                    char op = currentChar;
                    advance();
                    Node right = parseTerm();
                    node = new BinaryOp(op, node, right);
                } else {
                    break;
                }
            }

            return node;
        }

        private Node parseTerm() {
            Node node = parseFactor();

            while (true) {
                skipWhitespace();

                if (currentChar == CHAR_STAR || currentChar == CHAR_SLASH || currentChar == CHAR_PERCENT) {
                    char op = currentChar;
                    advance();
                    Node right = parseFactor();
                    node = new BinaryOp(op, node, right);
                } else {
                    break;
                }
            }

            return node;
        }

        private Node parseFactor() {
            skipWhitespace();

            if (isDigit(currentChar)) {
                return parseNumber();
            } else if (isLetter(currentChar)) {
                return parseVariable();
            } else if (currentChar == CHAR_LPAREN) {
                advance();
                Node node = parseExpression();
                skipWhitespace();
                if (currentChar == CHAR_RPAREN) {
                    advance();
                }
                return node;
            } else {
                advance();
                return new Number(0);
            }
        }

        private Node parseNumber() {
            long value = 0;
            while (isDigit(currentChar)) {
                value = value * 10 + (currentChar - CHAR_ZERO);
                advance();
            }
            return new Number(value);
        }

        private Node parseVariable() {
            int start = pos;
            while (isLetter(currentChar) || isDigit(currentChar)) {
                advance();
            }
            String varName = input.substring(start, pos);

            skipWhitespace();
            if (currentChar == CHAR_EQUALS) {
                advance();
                Node expr = parseExpression();
                return new Assignment(varName, expr);
            }

            return new Variable(varName);
        }

        private void advance() {
            pos++;
            if (pos >= input.length()) {
                currentChar = CHAR_EOF;
            } else {
                currentChar = input.charAt(pos);
            }
        }

        private void skipWhitespace() {
            while (isWhitespace(currentChar)) {
                advance();
            }
        }

        private boolean isDigit(char c) {
            return c >= CHAR_ZERO && c <= CHAR_NINE;
        }

        private boolean isLetter(char c) {
            return (c >= CHAR_A_LOWER && c <= CHAR_Z_LOWER) ||
                   (c >= CHAR_A_UPPER && c <= CHAR_Z_UPPER);
        }

        private boolean isWhitespace(char c) {
            return c == CHAR_SPACE || c == CHAR_TAB || c == CHAR_NEWLINE || c == CHAR_CR;
        }
    }

    @Override
    public void run(int iterationId) {
        Parser parser = new Parser(text);
        parser.parse();
        expressions = parser.expressions;
        resultVal += expressions.size();

        if (!expressions.isEmpty() && expressions.get(expressions.size() - 1) instanceof Assignment) {
            Assignment assign = (Assignment) expressions.get(expressions.size() - 1);
            resultVal += Helper.checksum(assign.variable);
        }
    }

    @Override
    public long checksum() {
        return resultVal;
    }

    public List<Node> getExpressions() {
        return expressions;
    }
}