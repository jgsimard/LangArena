module benchmarks.calculatorast;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.string;
import std.range;
import benchmark;
import helper;

private enum : char
{
    CHAR_EOF = '\0',
    CHAR_PLUS = '+',
    CHAR_MINUS = '-',
    CHAR_STAR = '*',
    CHAR_SLASH = '/',
    CHAR_PERCENT = '%',
    CHAR_LPAREN = '(',
    CHAR_RPAREN = ')',
    CHAR_EQUALS = '=',
    CHAR_ZERO = '0',
    CHAR_NINE = '9',
    CHAR_A_LOWER = 'a',
    CHAR_Z_LOWER = 'z',
    CHAR_A_UPPER = 'A',
    CHAR_Z_UPPER = 'Z',
    CHAR_SPACE = ' ',
    CHAR_TAB = '\t',
    CHAR_NEWLINE = '\n',
    CHAR_CR = '\r',
}

class CalculatorAst : Benchmark
{

    abstract class Node
    {

    }

    class Number : Node
    {
        long value;
        this(long v)
        {
            value = v;
        }
    }

    class Variable : Node
    {
        string name;
        this(string n)
        {
            name = n;
        }
    }

    class BinaryOp : Node
    {
        char op;
        Node left;
        Node right;

        this(char o, Node l, Node r)
        {
            op = o;
            left = l;
            right = r;
        }
    }

    class Assignment : Node
    {
        string var;
        Node expr;

        this(string v, Node e)
        {
            var = v;
            expr = e;
        }
    }

private:
    class Parser
    {
    private:
        string input;
        size_t pos;
        size_t len;
        char currentChar;
        Node[] expressions;

        bool isDigit(char c)
        {
            return c >= CHAR_ZERO && c <= CHAR_NINE;
        }

        bool isLetter(char c)
        {
            return (c >= CHAR_A_LOWER && c <= CHAR_Z_LOWER) || (c >= CHAR_A_UPPER
                    && c <= CHAR_Z_UPPER);
        }

        bool isWhitespace(char c)
        {
            return c == CHAR_SPACE || c == CHAR_TAB || c == CHAR_NEWLINE || c == CHAR_CR;
        }

        void advance()
        {
            pos++;
            if (pos >= len)
            {
                currentChar = CHAR_EOF;
            }
            else
            {
                currentChar = input[pos];
            }
        }

        void skipWhitespace()
        {
            while (isWhitespace(currentChar))
            {
                advance();
            }
        }

        Node parseNumber()
        {
            long v = 0;
            while (isDigit(currentChar))
            {
                v = v * 10 + (currentChar - CHAR_ZERO);
                advance();
            }
            return new Number(v);
        }

        Node parseVariable()
        {
            size_t start = pos;
            while (isLetter(currentChar) || isDigit(currentChar))
            {
                advance();
            }

            string varName = input[start .. pos];

            skipWhitespace();
            if (currentChar == CHAR_EQUALS)
            {
                advance();
                auto expr = parseExpression();
                return new Assignment(varName, expr);
            }

            return new Variable(varName);
        }

        Node parseFactor()
        {
            skipWhitespace();

            if (isDigit(currentChar))
            {
                return parseNumber();
            }

            if (isLetter(currentChar))
            {
                return parseVariable();
            }

            if (currentChar == CHAR_LPAREN)
            {
                advance();
                auto node = parseExpression();
                skipWhitespace();
                if (currentChar == CHAR_RPAREN)
                {
                    advance();
                }
                return node;
            }

            advance();
            return new Number(0);
        }

        Node parseTerm()
        {
            auto node = parseFactor();

            while (true)
            {
                skipWhitespace();

                if (currentChar == CHAR_STAR || currentChar == CHAR_SLASH
                        || currentChar == CHAR_PERCENT)
                {
                    char op = currentChar;
                    advance();
                    auto right = parseFactor();
                    node = new BinaryOp(op, node, right);
                }
                else
                {
                    break;
                }
            }

            return node;
        }

        Node parseExpression()
        {
            auto node = parseTerm();

            while (true)
            {
                skipWhitespace();

                if (currentChar == CHAR_PLUS || currentChar == CHAR_MINUS)
                {
                    char op = currentChar;
                    advance();
                    auto right = parseTerm();
                    node = new BinaryOp(op, node, right);
                }
                else
                {
                    break;
                }
            }

            return node;
        }

    public:
        this(string inputStr)
        {
            input = inputStr;
            pos = 0;
            len = input.length;
            currentChar = len > 0 ? input[0] : CHAR_EOF;
        }

        Node[] parse()
        {
            expressions = [];
            while (currentChar != CHAR_EOF)
            {
                skipWhitespace();
                if (currentChar == CHAR_EOF)
                    break;
                expressions ~= parseExpression();

                skipWhitespace();
                while (currentChar == CHAR_NEWLINE)
                {
                    advance();
                    skipWhitespace();
                }
            }
            return expressions;
        }
    }

    uint resultVal;
    string text;
    public Node[] expressions;

    string generateRandomProgram(long programSize)
    {
        import std.format : format;

        auto app = appender!string();
        app.put("v0 = 1\n");

        for (int i = 0; i < 10; i++)
        {
            int v = i + 1;
            app.put(format("v%d = v%d + %d\n", v, v - 1, v));
        }

        for (long i = 0; i < programSize; i++)
        {
            int v = cast(int)(i + 10);
            app.put(format("v%d = v%d + ", v, v - 1));

            switch (Helper.nextInt(10))
            {
            case 0:
                app.put(format("(v%d / 3) * 4 - %d / (3 + (18 - v%d)) %% v%d + 2 * ((9 - v%d) * (v%d + 7))",
                        v - 1, i, v - 2, v - 3, v - 6, v - 5));
                break;
            case 1:
                app.put(format("v%d + (v%d + v%d) * v%d - (v%d / v%d)", v - 1,
                        v - 2, v - 3, v - 4, v - 5, v - 6));
                break;
            case 2:
                app.put(format("(3789 - (((v%d)))) + 1", v - 7));
                break;
            case 3:
                app.put(format("4/2 * (1-3) + v%d/v%d", v - 9, v - 5));
                break;
            case 4:
                app.put(format("1+2+3+4+5+6+v%d", v - 1));
                break;
            case 5:
                app.put(format("(99999 / v%d)", v - 3));
                break;
            case 6:
                app.put(format("0 + 0 - v%d", v - 8));
                break;
            case 7:
                app.put(format("((((((((((v%d)))))))))) * 2", v - 6));
                break;
            case 8:
                app.put(format("%d * (v%d%%6)%%7", i, v - 1));
                break;
            case 9:
                app.put(format("(1)/(0-v%d) + (v%d)", v - 5, v - 7));
                break;
            default:
                break;
            }
            app.put("\n");
        }
        return app.data;
    }

protected:
    override string className() const
    {
        return "Calculator::Ast";
    }

public:
    this()
    {
        resultVal = 0;
        n = configVal("operations");
    }

    long n;

    override void prepare()
    {
        text = generateRandomProgram(n);
    }

    override void run(int iterationId)
    {
        auto parser = new Parser(text);
        expressions = parser.parse();
        resultVal += cast(uint) expressions.length;

        if (!expressions.empty)
        {

            if (auto assign = cast(Assignment) expressions[$ - 1])
            {
                resultVal += Helper.checksum(assign.var);
            }
        }
    }

    override uint checksum()
    {
        return resultVal;
    }
}
