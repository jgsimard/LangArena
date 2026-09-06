namespace Benchmarks

open System
open System.Text
open System.Collections.Generic

module CharCodes =
    let CHAR_EOF = '\000'
    let CHAR_PLUS = '+'
    let CHAR_MINUS = '-'
    let CHAR_STAR = '*'
    let CHAR_SLASH = '/'
    let CHAR_PERCENT = '%'
    let CHAR_LPAREN = '('
    let CHAR_RPAREN = ')'
    let CHAR_EQUALS = '='
    let CHAR_ZERO = '0'
    let CHAR_NINE = '9'
    let CHAR_A_LOWER = 'a'
    let CHAR_Z_LOWER = 'z'
    let CHAR_A_UPPER = 'A'
    let CHAR_Z_UPPER = 'Z'
    let CHAR_SPACE = ' '
    let CHAR_TAB = '\t'
    let CHAR_NEWLINE = '\n'
    let CHAR_CR = '\r'

[<AbstractClass>]
type Node() = class end

type Number(value: int64) =
    inherit Node()
    member _.Value = value

type Variable(name: string) =
    inherit Node()
    member _.Name = name

type BinaryOp(op: char, left: Node, right: Node) =
    inherit Node()
    member _.Op = op
    member _.Left = left
    member _.Right = right

type Assignment(varName: string, expr: Node) =
    inherit Node()
    member _.Var = varName
    member _.Expr = expr

[<AllowNullLiteral>]
type Parser(input: string) =
    let mutable pos = 0
    let mutable currentChar = if input.Length > 0 then input.[0] else CharCodes.CHAR_EOF
    let expressions = List<Node>()

    let isDigit (char: char) =
        char >= CharCodes.CHAR_ZERO && char <= CharCodes.CHAR_NINE

    let isLetter (char: char) =
        (char >= CharCodes.CHAR_A_LOWER && char <= CharCodes.CHAR_Z_LOWER)
        || (char >= CharCodes.CHAR_A_UPPER && char <= CharCodes.CHAR_Z_UPPER)

    let isWhitespace (char: char) =
        char = CharCodes.CHAR_SPACE
        || char = CharCodes.CHAR_TAB
        || char = CharCodes.CHAR_NEWLINE
        || char = CharCodes.CHAR_CR

    let advance () =
        pos <- pos + 1

        if pos >= input.Length then
            currentChar <- CharCodes.CHAR_EOF
        else
            currentChar <- input.[pos]

    let skipWhitespace () =
        while isWhitespace currentChar do
            advance ()

    let rec parseNumber () =
        let mutable value = 0L

        while isDigit currentChar do
            value <- value * 10L + int64 (currentChar - CharCodes.CHAR_ZERO)
            advance ()

        Number(value) :> Node

    let rec parseVariable () =
        let start = pos

        while isLetter currentChar || isDigit currentChar do
            advance ()

        let varName = input.Substring(start, pos - start)

        skipWhitespace ()

        if currentChar = CharCodes.CHAR_EQUALS then
            advance ()
            let expr = parseExpression ()
            Assignment(varName, expr) :> Node
        else
            Variable(varName) :> Node

    and parseExpression () =
        let mutable node = parseTerm ()
        let mutable continueLoop = true

        while continueLoop do
            skipWhitespace ()

            if currentChar = CharCodes.CHAR_PLUS || currentChar = CharCodes.CHAR_MINUS then
                let op = currentChar
                advance ()
                let right = parseTerm ()
                node <- BinaryOp(op, node, right) :> Node
            else
                continueLoop <- false

        node

    and parseTerm () =
        let mutable node = parseFactor ()
        let mutable continueLoop = true

        while continueLoop do
            skipWhitespace ()

            if
                currentChar = CharCodes.CHAR_STAR
                || currentChar = CharCodes.CHAR_SLASH
                || currentChar = CharCodes.CHAR_PERCENT
            then
                let op = currentChar
                advance ()
                let right = parseFactor ()
                node <- BinaryOp(op, node, right) :> Node
            else
                continueLoop <- false

        node

    and parseFactor () =
        skipWhitespace ()

        if isDigit currentChar then
            parseNumber ()
        elif isLetter currentChar then
            parseVariable ()
        elif currentChar = CharCodes.CHAR_LPAREN then
            advance ()
            let node = parseExpression ()
            skipWhitespace ()

            if currentChar = CharCodes.CHAR_RPAREN then
                advance ()

            node
        else
            advance ()
            Number(0L) :> Node

    member _.Parse() =
        while currentChar <> CharCodes.CHAR_EOF do
            skipWhitespace ()

            if currentChar = CharCodes.CHAR_EOF then
                ()
            else
                let expr = parseExpression ()
                expressions.Add(expr)

                skipWhitespace ()

                while currentChar = CharCodes.CHAR_NEWLINE do
                    advance ()
                    skipWhitespace ()

        List.ofSeq expressions

type Interpreter() =
    let variables = Dictionary<string, int64>()

    let safeAbs (x: int64) =
        if x >= 0L then x
        elif x = Int64.MinValue then Int64.MaxValue
        else -x

    let simpleDiv (a: int64) (b: int64) =
        if b = 0L then
            0L
        elif (a >= 0L && b > 0L) || (a < 0L && b < 0L) then
            a / b
        else
            let absA = safeAbs a
            let absB = safeAbs b
            -(absA / absB)

    let simpleMod (a: int64) (b: int64) =
        if b = 0L then 0L else a - simpleDiv a b * b

    let rec evaluate (node: Node) =
        match node with
        | :? Number as num -> num.Value
        | :? Variable as var ->
            match variables.TryGetValue(var.Name) with
            | true, value -> value
            | false, _ -> 0L
        | :? BinaryOp as bin ->
            let left = evaluate bin.Left
            let right = evaluate bin.Right

            match bin.Op with
            | '+' -> left + right
            | '-' -> left - right
            | '*' -> left * right
            | '/' -> simpleDiv left right
            | '%' -> simpleMod left right
            | _ -> 0L
        | :? Assignment as assign ->
            let value = evaluate assign.Expr
            variables.[assign.Var] <- value
            value
        | _ -> 0L

    member _.Run(expressions: Node list) =
        let mutable result = 0L

        for expr in expressions do
            result <- evaluate expr

        result

module ProgramGenerator =
    let generateRandomProgram (n: int64) =
        let sb = StringBuilder()
        sb.AppendLine("v0 = 1") |> ignore

        for i = 0 to 9 do
            let v = i + 1
            sb.AppendLine($"v{v} = v{v - 1} + {v}") |> ignore

        let mutable i = 0L

        while i < n do
            let v = int (i + 10L)
            sb.Append($"v{v} = v{v - 1} + ") |> ignore

            match Helper.NextInt(10) with
            | 0 ->
                sb.AppendFormat(
                    "(v{0} / 3) * 4 - {1} / (3 + (18 - v{2})) % v{3} + 2 * ((9 - v{4}) * (v{5} + 7))",
                    v - 1,
                    i,
                    v - 2,
                    v - 3,
                    v - 6,
                    v - 5
                )
                |> ignore
            | 1 ->
                sb.AppendFormat("v{0} + (v{1} + v{2}) * v{3} - (v{4} / v{5})", v - 1, v - 2, v - 3, v - 4, v - 5, v - 6)
                |> ignore
            | 2 -> sb.AppendFormat("(3789 - (((v{0})))) + 1", v - 7) |> ignore
            | 3 -> sb.AppendFormat("4/2 * (1-3) + v{0}/v{1}", v - 9, v - 5) |> ignore
            | 4 -> sb.AppendFormat("1+2+3+4+5+6+v{0}", v - 1) |> ignore
            | 5 -> sb.AppendFormat("(99999 / v{0})", v - 3) |> ignore
            | 6 -> sb.AppendFormat("0 + 0 - v{0}", v - 8) |> ignore
            | 7 -> sb.AppendFormat("((((((((((v{0})))))))))) * 2", v - 6) |> ignore
            | 8 -> sb.AppendFormat("{0} * (v{1}%6)%7", i, v - 1) |> ignore
            | 9 -> sb.AppendFormat("(1)/(0-v{0}) + (v{1})", v - 5, v - 7) |> ignore
            | _ -> ()

            sb.AppendLine() |> ignore
            i <- i + 1L

        sb.ToString()

type CalculatorAst() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable text = ""
    let mutable result = 0u
    let mutable expressions: Node list = []

    member this.SetOperations(operations: int64) =
        n <- operations
        text <- ProgramGenerator.generateRandomProgram n

    member this.Parse() =
        let parser = Parser(text)
        expressions <- parser.Parse()

        result <- result + uint32 expressions.Length

        match expressions with
        | [] -> ()
        | _ ->
            let last = expressions |> List.last

            match last with
            | :? Assignment as assign -> result <- result + Helper.Checksum(assign.Var)
            | _ -> ()

    member this.Expressions = expressions

    override this.Checksum = result
    override this.Name = "Calculator::Ast"

    override this.Prepare() =
        n <- this.ConfigVal("operations")
        this.SetOperations(n)
        result <- 0u

    override this.Run(_: int64) = this.Parse()

type CalculatorInterpreter() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable result = 0u
    let mutable ast: Node list = []

    override this.Checksum = result
    override this.Name = "Calculator::Interpreter"

    override this.Prepare() =
        n <- this.ConfigVal("operations")

        let calculator = CalculatorAst()
        calculator.SetOperations(n)
        calculator.Parse()

        ast <- calculator.Expressions

        result <- 0u

    override this.Run(_: int64) =
        let interpreter = Interpreter()
        let calcResult = interpreter.Run(ast)
        result <- result + uint32 calcResult
