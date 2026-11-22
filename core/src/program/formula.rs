//! The expressions a `formula` progression is written in: numbers,
//! arithmetic, comparisons, `and`/`or`/`not`, and a handful of functions,
//! over the variables a lift's history gives ([VARIABLES]) and the
//! progression's own `let` names.
//!
//! Evaluation is f64 with only `+ − × ÷ %`, comparisons and rounding, which
//! IEEE 754 makes exact on every platform the core runs on: the phone and
//! the server get the same answer. There are no loops, no state, no clock
//! and no I/O; an expression is at most [MAX_SOURCE] characters and
//! [MAX_DEPTH] deep, and an evaluation takes at most [MAX_STEPS] steps.
//! Truth is a number: 0 is false, anything else true; a comparison gives 1
//! or 0.

use std::collections::BTreeMap;

pub const MAX_SOURCE: usize = 2000;
pub const MAX_DEPTH: usize = 64;
pub const MAX_STEPS: usize = 20_000;

/// Every variable a formula can read, with what it means.
pub const VARIABLES: &[(&str, &str)] = &[
    (
        "last.weight",
        "The last session's heaviest working weight (lb); 0 when never done",
    ),
    (
        "last.reps",
        "The reps the last session's heaviest working set was planned for",
    ),
    (
        "last.sets",
        "The working sets the last session was planned for",
    ),
    (
        "last.best_reps",
        "The most reps done in one working set at the last session's heaviest weight",
    ),
    ("last.hit", "1 when every working rep was hit last session"),
    (
        "last.missed",
        "1 when a rep was missed last session (not stopped early or rushed)",
    ),
    (
        "last.stopped_early",
        "1 when the last session left working sets undone, or a miss was rushed",
    ),
    (
        "has_last",
        "1 once the lift has a finished session to compare with",
    ),
    ("sessions", "The lift's finished sessions"),
    (
        "hits_in_row",
        "Sessions in a row, to the last, with every rep hit",
    ),
    (
        "fails_in_row",
        "Sessions in a row, to the last, with a rep missed",
    ),
    (
        "days_off",
        "Whole days since the lift was last done (0 when never)",
    ),
    (
        "max",
        "The walked estimated max (lb; reps for a bodyweight lift); 0 when unknown",
    ),
    ("start", "The lift's starting weight (lb), or 0"),
    (
        "step",
        "The equipment's weight step (lb) in the user's unit",
    ),
    ("kg", "1 when the user lifts in kilograms"),
    ("bodyweight", "1 for a bodyweight lift"),
    ("rep_low", "The bottom of the class's rep range"),
    ("rep_high", "The top of the class's rep range"),
];

/// Every function a formula can call: name, arity (None: two or more), and
/// what it does.
pub const FUNCTIONS: &[(&str, Option<usize>, &str)] = &[
    ("if", Some(3), "if(c, a, b): a when c is not 0, otherwise b"),
    ("min", None, "min(a, b, ...): the smallest"),
    ("max", None, "max(a, b, ...): the largest"),
    ("abs", Some(1), "abs(x)"),
    ("floor", Some(1), "floor(x): down to a whole number"),
    ("ceil", Some(1), "ceil(x): up to a whole number"),
    (
        "round",
        Some(1),
        "round(x): to the nearest whole number, halves away from 0",
    ),
    ("clamp", Some(3), "clamp(x, lo, hi)"),
    (
        "round_to",
        Some(2),
        "round_to(x, step): to the nearest multiple of step",
    ),
    (
        "snap",
        Some(1),
        "snap(w): w (lb) as the nearest weight the lift can load",
    ),
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Op {
    Add,
    Sub,
    Mul,
    Div,
    Rem,
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
    And,
    Or,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Expr {
    Num(f64),
    Var(String),
    Neg(Box<Expr>),
    Not(Box<Expr>),
    Bin(Op, Box<Expr>, Box<Expr>),
    Call(String, Vec<Expr>),
}

impl Expr {
    /// The names it reads, each once, in the order first read.
    pub fn names(&self) -> Vec<String> {
        let mut out = Vec::new();
        self.collect_names(&mut out);
        out
    }

    fn collect_names(&self, out: &mut Vec<String>) {
        match self {
            Expr::Num(_) => {}
            Expr::Var(name) => {
                if !out.contains(name) {
                    out.push(name.clone());
                }
            }
            Expr::Neg(e) | Expr::Not(e) => e.collect_names(out),
            Expr::Bin(_, a, b) => {
                a.collect_names(out);
                b.collect_names(out);
            }
            Expr::Call(_, args) => args.iter().for_each(|a| a.collect_names(out)),
        }
    }
}

// ── Parsing ──

#[derive(Clone, Debug, PartialEq)]
enum Token {
    Num(f64),
    Name(String),
    Op(&'static str),
    Open,
    Close,
    Comma,
}

fn tokens(src: &str) -> Result<Vec<Token>, String> {
    if src.len() > MAX_SOURCE {
        return Err(format!("longer than {MAX_SOURCE} characters"));
    }
    let chars: Vec<char> = src.chars().collect();
    let mut out = Vec::new();
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
        } else if c.is_ascii_digit()
            || (c == '.' && chars.get(i + 1).is_some_and(char::is_ascii_digit))
        {
            let start = i;
            while i < chars.len() && (chars[i].is_ascii_digit() || chars[i] == '.') {
                i += 1;
            }
            let text: String = chars[start..i].iter().collect();
            let n: f64 = text
                .parse()
                .map_err(|_| format!("{text:?} is not a number"))?;
            out.push(Token::Num(n));
        } else if c.is_ascii_alphabetic() || c == '_' {
            let start = i;
            while i < chars.len()
                && (chars[i].is_ascii_alphanumeric() || chars[i] == '_' || chars[i] == '.')
            {
                i += 1;
            }
            let name: String = chars[start..i].iter().collect();
            match name.as_str() {
                "and" => out.push(Token::Op("and")),
                "or" => out.push(Token::Op("or")),
                "not" => out.push(Token::Op("not")),
                "true" => out.push(Token::Num(1.0)),
                "false" => out.push(Token::Num(0.0)),
                _ => out.push(Token::Name(name)),
            }
        } else {
            let two: String = chars[i..(i + 2).min(chars.len())].iter().collect();
            let op = match two.as_str() {
                "==" => Some("=="),
                "!=" => Some("!="),
                "<=" => Some("<="),
                ">=" => Some(">="),
                "&&" => Some("and"),
                "||" => Some("or"),
                _ => None,
            };
            if let Some(op) = op {
                out.push(Token::Op(op));
                i += 2;
                continue;
            }
            out.push(match c {
                '+' => Token::Op("+"),
                '-' => Token::Op("-"),
                '*' => Token::Op("*"),
                '/' => Token::Op("/"),
                '%' => Token::Op("%"),
                '<' => Token::Op("<"),
                '>' => Token::Op(">"),
                '!' => Token::Op("not"),
                '(' => Token::Open,
                ')' => Token::Close,
                ',' => Token::Comma,
                _ => return Err(format!("unexpected {c:?}")),
            });
            i += 1;
        }
    }
    Ok(out)
}

struct Parser {
    tokens: Vec<Token>,
    at: usize,
    depth: usize,
}

fn binary(op: &str) -> Option<(Op, u8)> {
    Some(match op {
        "or" => (Op::Or, 1),
        "and" => (Op::And, 2),
        "==" => (Op::Eq, 3),
        "!=" => (Op::Ne, 3),
        "<" => (Op::Lt, 4),
        "<=" => (Op::Le, 4),
        ">" => (Op::Gt, 4),
        ">=" => (Op::Ge, 4),
        "+" => (Op::Add, 5),
        "-" => (Op::Sub, 5),
        "*" => (Op::Mul, 6),
        "/" => (Op::Div, 6),
        "%" => (Op::Rem, 6),
        _ => return None,
    })
}

impl Parser {
    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.at)
    }

    fn next(&mut self) -> Option<Token> {
        let t = self.tokens.get(self.at).cloned();
        self.at += 1;
        t
    }

    fn deeper(&mut self) -> Result<(), String> {
        self.depth += 1;
        if self.depth > MAX_DEPTH {
            return Err(format!("nested deeper than {MAX_DEPTH}"));
        }
        Ok(())
    }

    fn expr(&mut self, min: u8) -> Result<Expr, String> {
        self.deeper()?;
        let mut left = self.unary()?;
        while let Some(Token::Op(op)) = self.peek() {
            let Some((op, prec)) = binary(op) else {
                break;
            };
            if prec < min {
                break;
            }
            self.next();
            let right = self.expr(prec + 1)?;
            left = Expr::Bin(op, Box::new(left), Box::new(right));
        }
        self.depth -= 1;
        Ok(left)
    }

    fn unary(&mut self) -> Result<Expr, String> {
        match self.peek() {
            Some(Token::Op("-")) => {
                self.next();
                self.deeper()?;
                let e = self.unary()?;
                self.depth -= 1;
                Ok(Expr::Neg(Box::new(e)))
            }
            Some(Token::Op("not")) => {
                self.next();
                self.deeper()?;
                let e = self.unary()?;
                self.depth -= 1;
                Ok(Expr::Not(Box::new(e)))
            }
            _ => self.atom(),
        }
    }

    fn atom(&mut self) -> Result<Expr, String> {
        match self.next() {
            Some(Token::Num(n)) => Ok(Expr::Num(n)),
            Some(Token::Open) => {
                let e = self.expr(0)?;
                match self.next() {
                    Some(Token::Close) => Ok(e),
                    _ => Err("a ( is never closed".into()),
                }
            }
            Some(Token::Name(name)) => {
                if self.peek() != Some(&Token::Open) {
                    return Ok(Expr::Var(name));
                }
                self.next();
                let mut args = Vec::new();
                if self.peek() == Some(&Token::Close) {
                    self.next();
                } else {
                    loop {
                        args.push(self.expr(0)?);
                        match self.next() {
                            Some(Token::Comma) => continue,
                            Some(Token::Close) => break,
                            _ => return Err(format!("{name}( is never closed")),
                        }
                    }
                }
                let Some((_, arity, _)) = FUNCTIONS.iter().find(|(f, _, _)| *f == name) else {
                    return Err(format!("no function {name:?}"));
                };
                match arity {
                    Some(n) if args.len() != *n => {
                        return Err(format!("{name} takes {n}, given {}", args.len()))
                    }
                    None if args.len() < 2 => {
                        return Err(format!("{name} takes two or more, given {}", args.len()))
                    }
                    _ => {}
                }
                Ok(Expr::Call(name, args))
            }
            Some(Token::Op(op)) => Err(format!("unexpected {op:?}")),
            Some(Token::Close) => Err("unexpected )".into()),
            Some(Token::Comma) => Err("unexpected ,".into()),
            None => Err("ends too soon".into()),
        }
    }
}

/// Parse one expression.
pub fn parse(src: &str) -> Result<Expr, String> {
    let mut parser = Parser {
        tokens: tokens(src)?,
        at: 0,
        depth: 0,
    };
    if parser.tokens.is_empty() {
        return Err("empty".into());
    }
    let e = parser.expr(0)?;
    if let Some(t) = parser.peek() {
        return Err(format!("unexpected {t:?} after the expression"));
    }
    Ok(e)
}

// ── Evaluating ──

/// Where variables come from.
pub trait Scope {
    fn var(&self, name: &str) -> Option<f64>;
    /// `snap(w)`: w as the nearest weight the lift can load.
    fn snap(&self, weight_lb: f64) -> f64;
}

/// A formula's expressions and its `let` names, parsed, evaluated against a
/// scope. `let` names are evaluated when first read and kept.
pub struct Evaluator<'a> {
    lets: BTreeMap<String, Expr>,
    scope: &'a dyn Scope,
    values: std::cell::RefCell<BTreeMap<String, f64>>,
    busy: std::cell::RefCell<Vec<String>>,
    steps: std::cell::Cell<usize>,
}

impl<'a> Evaluator<'a> {
    /// Parse every `let`; the first that fails is the error, named.
    pub fn new(lets: &BTreeMap<String, String>, scope: &'a dyn Scope) -> Result<Self, String> {
        let mut parsed = BTreeMap::new();
        for (name, src) in lets {
            if !valid_name(name) {
                return Err(format!(
                    "let {name:?}: a name is letters, digits and underscores, starting with a letter"
                ));
            }
            if VARIABLES.iter().any(|(v, _)| v == name) {
                return Err(format!("let {name:?}: that is a variable already"));
            }
            parsed.insert(
                name.clone(),
                parse(src).map_err(|e| format!("let {name}: {e}"))?,
            );
        }
        Ok(Self {
            lets: parsed,
            scope,
            values: Default::default(),
            busy: Default::default(),
            steps: Default::default(),
        })
    }

    /// The value of `src`.
    pub fn eval_src(&self, src: &str) -> Result<f64, String> {
        let e = parse(src)?;
        self.eval(&e)
    }

    pub fn eval(&self, e: &Expr) -> Result<f64, String> {
        let steps = self.steps.get() + 1;
        self.steps.set(steps);
        if steps > MAX_STEPS {
            return Err(format!("more than {MAX_STEPS} steps"));
        }
        let v = match e {
            Expr::Num(n) => *n,
            Expr::Var(name) => self.var(name)?,
            Expr::Neg(e) => -self.eval(e)?,
            Expr::Not(e) => truth(self.eval(e)? == 0.0),
            Expr::Bin(Op::And, a, b) => truth(self.eval(a)? != 0.0 && self.eval(b)? != 0.0),
            Expr::Bin(Op::Or, a, b) => truth(self.eval(a)? != 0.0 || self.eval(b)? != 0.0),
            Expr::Bin(op, a, b) => {
                let (a, b) = (self.eval(a)?, self.eval(b)?);
                match op {
                    Op::Add => a + b,
                    Op::Sub => a - b,
                    Op::Mul => a * b,
                    Op::Div if b == 0.0 => return Err("divided by zero".into()),
                    Op::Div => a / b,
                    Op::Rem if b == 0.0 => return Err("% by zero".into()),
                    Op::Rem => a % b,
                    Op::Eq => truth(a == b),
                    Op::Ne => truth(a != b),
                    Op::Lt => truth(a < b),
                    Op::Le => truth(a <= b),
                    Op::Gt => truth(a > b),
                    Op::Ge => truth(a >= b),
                    Op::And | Op::Or => unreachable!("short-circuited above"),
                }
            }
            Expr::Call(name, args) => self.call(name, args)?,
        };
        if !v.is_finite() {
            return Err("not a finite number".into());
        }
        Ok(v)
    }

    fn call(&self, name: &str, args: &[Expr]) -> Result<f64, String> {
        if name == "if" {
            return if self.eval(&args[0])? != 0.0 {
                self.eval(&args[1])
            } else {
                self.eval(&args[2])
            };
        }
        let values = args
            .iter()
            .map(|a| self.eval(a))
            .collect::<Result<Vec<f64>, String>>()?;
        Ok(match name {
            "min" => values.iter().copied().fold(f64::INFINITY, f64::min),
            "max" => values.iter().copied().fold(f64::NEG_INFINITY, f64::max),
            "abs" => values[0].abs(),
            "floor" => values[0].floor(),
            "ceil" => values[0].ceil(),
            "round" => values[0].round(),
            "clamp" => {
                if values[1] > values[2] {
                    return Err("clamp's lo is over its hi".into());
                }
                values[0].clamp(values[1], values[2])
            }
            "round_to" => {
                if values[1] <= 0.0 {
                    return Err("round_to's step must be over 0".into());
                }
                (values[0] / values[1]).round() * values[1]
            }
            "snap" => self.scope.snap(values[0]),
            _ => return Err(format!("no function {name:?}")),
        })
    }

    fn var(&self, name: &str) -> Result<f64, String> {
        if let Some(v) = self.values.borrow().get(name) {
            return Ok(*v);
        }
        if let Some(e) = self.lets.get(name) {
            if self.busy.borrow().iter().any(|n| n == name) {
                return Err(format!("let {name} refers to itself"));
            }
            self.busy.borrow_mut().push(name.to_string());
            let v = self.eval(e);
            self.busy.borrow_mut().pop();
            let v = v.map_err(|e| format!("let {name}: {e}"))?;
            self.values.borrow_mut().insert(name.to_string(), v);
            return Ok(v);
        }
        self.scope
            .var(name)
            .ok_or_else(|| format!("no variable {name:?}"))
    }

    /// The names an expression reads that are neither variables nor lets.
    pub fn unknown_names(&self, e: &Expr) -> Vec<String> {
        e.names()
            .into_iter()
            .filter(|n| !self.lets.contains_key(n) && !VARIABLES.iter().any(|(v, _)| v == n))
            .collect()
    }

    pub fn lets(&self) -> &BTreeMap<String, Expr> {
        &self.lets
    }
}

fn truth(b: bool) -> f64 {
    if b {
        1.0
    } else {
        0.0
    }
}

fn valid_name(name: &str) -> bool {
    let mut chars = name.chars();
    chars.next().is_some_and(|c| c.is_ascii_alphabetic())
        && chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
        && name.len() <= 48
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Vars(Vec<(&'static str, f64)>);
    impl Scope for Vars {
        fn var(&self, name: &str) -> Option<f64> {
            self.0.iter().find(|(n, _)| *n == name).map(|(_, v)| *v)
        }
        fn snap(&self, w: f64) -> f64 {
            (w / 5.0).round() * 5.0
        }
    }

    fn eval(src: &str, lets: &[(&str, &str)]) -> Result<f64, String> {
        let scope = Vars(vec![
            ("last.weight", 100.0),
            ("last.reps", 8.0),
            ("last.hit", 1.0),
            ("step", 5.0),
        ]);
        let lets = lets
            .iter()
            .map(|(a, b)| (a.to_string(), b.to_string()))
            .collect();
        Evaluator::new(&lets, &scope)?.eval_src(src)
    }

    #[test]
    fn arithmetic_follows_precedence() {
        assert_eq!(eval("1 + 2 * 3", &[]), Ok(7.0));
        assert_eq!(eval("(1 + 2) * 3", &[]), Ok(9.0));
        assert_eq!(eval("10 - 4 - 3", &[]), Ok(3.0));
        assert_eq!(eval("-2 * -3", &[]), Ok(6.0));
        assert_eq!(eval("7 % 3", &[]), Ok(1.0));
        assert_eq!(eval("1 + 2 < 4 and 3 >= 3", &[]), Ok(1.0));
        assert_eq!(eval("not 1 or 0", &[]), Ok(0.0));
    }

    #[test]
    fn variables_functions_and_lets() {
        assert_eq!(
            eval(
                "if(last.hit and last.reps >= top, last.weight + step, last.weight)",
                &[("top", "8")]
            ),
            Ok(105.0)
        );
        assert_eq!(eval("min(3, 1, 2) + max(1, 4)", &[]), Ok(5.0));
        assert_eq!(eval("snap(last.weight * 1.03)", &[]), Ok(105.0));
        assert_eq!(eval("round_to(101.3, 2.5)", &[]), Ok(102.5));
        assert_eq!(eval("clamp(14, 5, 12)", &[]), Ok(12.0));
        assert_eq!(eval("b", &[("a", "2"), ("b", "a * 3")]), Ok(6.0));
    }

    #[test]
    fn mistakes_are_named() {
        assert!(eval("1 +", &[]).unwrap_err().contains("ends too soon"));
        assert!(eval("nope", &[]).unwrap_err().contains("no variable"));
        assert!(eval("pow(2, 3)", &[]).unwrap_err().contains("no function"));
        assert!(eval("if(1, 2)", &[]).unwrap_err().contains("takes 3"));
        assert!(eval("1 / 0", &[]).unwrap_err().contains("zero"));
        assert!(eval("a", &[("a", "a + 1")]).unwrap_err().contains("itself"));
        assert!(eval("(1", &[]).unwrap_err().contains("never closed"));
        let deep = format!("{}1{}", "(".repeat(100), ")".repeat(100));
        assert!(eval(&deep, &[]).unwrap_err().contains("deeper"));
    }
}
