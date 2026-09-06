use super::super::{helper, Benchmark};
use crate::config_i64;

const CHAR_EOF: u8 = 0;
const CHAR_PLUS: u8 = b'+';
const CHAR_MINUS: u8 = b'-';
const CHAR_STAR: u8 = b'*';
const CHAR_SLASH: u8 = b'/';
const CHAR_PERCENT: u8 = b'%';
const CHAR_LPAREN: u8 = b'(';
const CHAR_RPAREN: u8 = b')';
const CHAR_EQUALS: u8 = b'=';
const CHAR_ZERO: u8 = b'0';
const CHAR_NINE: u8 = b'9';
const CHAR_A_LOWER: u8 = b'a';
const CHAR_Z_LOWER: u8 = b'z';
const CHAR_A_UPPER: u8 = b'A';
const CHAR_Z_UPPER: u8 = b'Z';
const CHAR_SPACE: u8 = b' ';
const CHAR_TAB: u8 = b'\t';
const CHAR_NEWLINE: u8 = b'\n';
const CHAR_CR: u8 = b'\r';

#[derive(Clone)]
pub enum Node {
    Number(i64),
    Variable(String),
    BinaryOp(char, Box<Node>, Box<Node>),
    Assignment(String, Box<Node>),
}

pub struct CalculatorAst {
    pub(crate) n: i64,
    result_val: u32,
    text: String,
    expressions: Vec<Node>,
}

impl CalculatorAst {
    pub fn new() -> Self {
        let n = config_i64("Calculator::Ast", "operations");

        Self {
            n,
            result_val: 0,
            text: String::new(),
            expressions: Vec::new(),
        }
    }

    pub fn expressions(&self) -> &[Node] {
        &self.expressions
    }

    fn generate_random_program(&self, n: i64) -> String {
        let mut result = String::new();
        result.push_str("v0 = 1\n");

        for i in 0..10 {
            let v = i + 1;
            result.push_str(&format!("v{} = v{} + {}\n", v, v - 1, v));
        }

        for i in 0..n {
            let v = i + 10;
            result.push_str(&format!("v{} = v{} + ", v, v - 1));

            match helper::next_int(10) {
                0 => {
                    result.push_str(&format!(
                        "(v{} / 3) * 4 - {} / (3 + (18 - v{})) % v{} + 2 * ((9 - v{}) * (v{} + 7))",
                        v - 1,
                        i,
                        v - 2,
                        v - 3,
                        v - 6,
                        v - 5
                    ));
                }
                1 => {
                    result.push_str(&format!(
                        "v{} + (v{} + v{}) * v{} - (v{} / v{})",
                        v - 1,
                        v - 2,
                        v - 3,
                        v - 4,
                        v - 5,
                        v - 6
                    ));
                }
                2 => {
                    result.push_str(&format!("(3789 - (((v{})))) + 1", v - 7));
                }
                3 => {
                    result.push_str(&format!("4/2 * (1-3) + v{}/v{}", v - 9, v - 5));
                }
                4 => {
                    result.push_str(&format!("1+2+3+4+5+6+v{}", v - 1));
                }
                5 => {
                    result.push_str(&format!("(99999 / v{})", v - 3));
                }
                6 => {
                    result.push_str(&format!("0 + 0 - v{}", v - 8));
                }
                7 => {
                    result.push_str(&format!("((((((((((v{})))))))))) * 2", v - 6));
                }
                8 => {
                    result.push_str(&format!("{} * (v{}%6)%7", i, v - 1));
                }
                9 => {
                    result.push_str(&format!("(1)/(0-v{}) + (v{})", v - 5, v - 7));
                }
                _ => unreachable!(),
            }

            result.push('\n');
        }

        result
    }
}

impl Benchmark for CalculatorAst {
    fn name(&self) -> String {
        "Calculator::Ast".to_string()
    }

    fn prepare(&mut self) {
        self.text = self.generate_random_program(self.n);
    }

    fn run(&mut self, _iteration_id: i64) {
        self.expressions = Parser::new(&self.text).parse();
        self.result_val = self.result_val.wrapping_add(self.expressions.len() as u32);

        if let Some(Node::Assignment(var, _)) = self.expressions.last() {
            self.result_val = self.result_val.wrapping_add(helper::checksum_str(var));
        }
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

struct Parser<'a> {
    input: &'a str,
    pos: usize,
    len: usize,
    current_byte: u8,
    expressions: Vec<Node>,
}

impl<'a> Parser<'a> {
    fn new(input: &'a str) -> Self {
        let len = input.len();
        let current_byte = input.as_bytes().first().copied().unwrap_or(CHAR_EOF);

        Self {
            input,
            pos: 0,
            len,
            current_byte,
            expressions: Vec::new(),
        }
    }

    fn parse(mut self) -> Vec<Node> {
        while self.current_byte != CHAR_EOF {
            self.skip_whitespace();
            if self.current_byte == CHAR_EOF {
                break;
            }

            let expr = self.parse_expression();
            self.expressions.push(expr);

            self.skip_whitespace();
            while self.current_byte == CHAR_NEWLINE {
                self.advance();
                self.skip_whitespace();
            }
        }

        self.expressions
    }

    fn parse_expression(&mut self) -> Node {
        let node = self.parse_term();
        self.parse_expression_rest(node)
    }

    fn parse_expression_rest(&mut self, left_node: Node) -> Node {
        let mut current_node = left_node;

        loop {
            self.skip_whitespace();

            if self.current_byte == CHAR_PLUS || self.current_byte == CHAR_MINUS {
                let op = self.current_byte as char;
                self.advance();
                let right = self.parse_term();
                current_node = Node::BinaryOp(op, Box::new(current_node), Box::new(right));
            } else {
                break;
            }
        }

        current_node
    }

    fn parse_term(&mut self) -> Node {
        let node = self.parse_factor();
        self.parse_term_rest(node)
    }

    fn parse_term_rest(&mut self, left_node: Node) -> Node {
        let mut current_node = left_node;

        loop {
            self.skip_whitespace();

            if self.current_byte == CHAR_STAR
                || self.current_byte == CHAR_SLASH
                || self.current_byte == CHAR_PERCENT
            {
                let op = self.current_byte as char;
                self.advance();
                let right = self.parse_factor();
                current_node = Node::BinaryOp(op, Box::new(current_node), Box::new(right));
            } else {
                break;
            }
        }

        current_node
    }

    fn parse_factor(&mut self) -> Node {
        self.skip_whitespace();

        if self.is_digit(self.current_byte) {
            self.parse_number()
        } else if self.is_letter(self.current_byte) {
            self.parse_variable()
        } else if self.current_byte == CHAR_LPAREN {
            self.advance();
            let node = self.parse_expression();
            self.skip_whitespace();
            if self.current_byte == CHAR_RPAREN {
                self.advance();
            }
            node
        } else {
            self.advance();
            Node::Number(0)
        }
    }

    fn parse_number(&mut self) -> Node {
        let start = self.pos;
        while self.is_digit(self.current_byte) {
            self.advance();
        }

        let num_str = &self.input[start..self.pos];
        match num_str.parse::<i64>() {
            Ok(n) => Node::Number(n),
            Err(_) => Node::Number(0),
        }
    }

    fn parse_variable(&mut self) -> Node {
        let start = self.pos;
        while self.is_letter(self.current_byte) || self.is_digit(self.current_byte) {
            self.advance();
        }

        let var_name = self.input[start..self.pos].to_owned();

        self.skip_whitespace();
        if self.current_byte == CHAR_EQUALS {
            self.advance();
            let expr = self.parse_expression();
            return Node::Assignment(var_name, Box::new(expr));
        }

        Node::Variable(var_name)
    }

    fn advance(&mut self) {
        self.pos += 1;
        if self.pos >= self.len {
            self.current_byte = CHAR_EOF;
        } else {
            self.current_byte = self.input.as_bytes()[self.pos];
        }
    }

    fn skip_whitespace(&mut self) {
        while self.is_whitespace(self.current_byte) {
            self.advance();
        }
    }

    fn is_digit(&self, byte: u8) -> bool {
        byte >= CHAR_ZERO && byte <= CHAR_NINE
    }

    fn is_letter(&self, byte: u8) -> bool {
        (byte >= CHAR_A_LOWER && byte <= CHAR_Z_LOWER)
            || (byte >= CHAR_A_UPPER && byte <= CHAR_Z_UPPER)
    }

    fn is_whitespace(&self, byte: u8) -> bool {
        byte == CHAR_SPACE || byte == CHAR_TAB || byte == CHAR_NEWLINE || byte == CHAR_CR
    }
}
