const ast = @import("./ast.zig");
const std = @import("std");

const Lexer = struct {
    input: []const u8,
    tokens: std.ArrayList(*ast.TokenStruct),
    currentToken: ?*ast.TokenStruct,
    currentIndex: usize,

    pub fn init(input: []const u8, tokens: std.ArrayList(*ast.TokenStruct), allocator: std.mem.Allocator) !*Lexer {
        var lexer = try allocator.create(Lexer);
        lexer.input = input;
        lexer.tokens = tokens;
        lexer.currentIndex = 0;
        lexer.currentToken = tokens.items[0];
        return lexer;
    }

    pub fn nextToken(lexer: *Lexer) ?*ast.TokenStruct {
        lexer.currentIndex += 1;
        if (lexer.currentIndex < lexer.tokens.items.len) {
            lexer.currentToken = lexer.tokens.items[lexer.currentIndex];
            return lexer.tokens.items[lexer.currentIndex];
        }
        return null;
    }

    pub fn peekToken(lexer: *Lexer) ?*ast.TokenStruct {
        if (lexer.currentIndex + 1 < lexer.tokens.items.len) {
            return lexer.tokens.items[lexer.currentIndex + 1];
        }
        return null;
    }
};

fn lex(input: []const u8, allocator: std.mem.Allocator) !*Lexer {
    var index: usize = 0;
    var arrayList = std.ArrayList(*ast.TokenStruct).init(allocator);
    while (index < input.len) {
        var token = try allocator.create(ast.TokenStruct);
        token.* = switch (input[index]) {
            '+' => ast.TokenStruct{ .Operator = ast.OperatorType.Plus },
            '-' => ast.TokenStruct{ .Operator = ast.OperatorType.Minus },
            '*' => ast.TokenStruct{ .Operator = ast.OperatorType.Multiply },
            '/' => ast.TokenStruct{ .Operator = ast.OperatorType.Divide },
            '(' => ast.TokenStruct{ .LParen = {} },
            ')' => ast.TokenStruct{ .RParen = {} },
            else => blk: {
                if (input[index] > '0' and input[index] < '9') {
                    var parsed = try std.fmt.parseInt(i32, input[index .. index + 1], 10);
                    var tokenStruct = ast.TokenStruct{ .Integer = parsed };
                    break :blk tokenStruct;
                } else {
                    break :blk ast.TokenStruct{ .Invalid = {} };
                }
            },
        };
        if (@as(ast.TokenStruct, token.*) == ast.TokenStruct.Invalid) {
            return Lexer.init(input, arrayList, allocator);
        }
        try arrayList.append(token);
        index += 1;
    }
    return Lexer.init(input, arrayList, allocator);
}

fn getPrecedence(token: *ast.TokenStruct) u32 {
    var tokenDerefed = token.*;
    switch (tokenDerefed) {
        .Operator => |opToken| {
            if (opToken == ast.OperatorType.Plus or opToken == ast.OperatorType.Minus) {
                return 1;
            } else if (opToken == ast.OperatorType.Multiply or opToken == ast.OperatorType.Divide) {
                return 2;
            }
        },
        .Integer => {
            return 0;
        },
        .Invalid => {
            return 0;
        },
        .LParen => {
            return 0;
        },
        .RParen => {
            return 0;
        },
    }
    return 0;
}

fn parsePrefix(lexer: *Lexer, allocator: std.mem.Allocator) !*ast.TreeNode {
    var tokenOpt = lexer.currentToken;
    var prefixParsed = try allocator.create(ast.TreeNode);
    if (tokenOpt) |token| {
        if (@as(ast.TokenType, token.*) == ast.TokenType.Integer) {
            prefixParsed.* = ast.TreeNode{ .Integer = token.Integer };
        } else if (@as(ast.TokenType, token.*) == ast.TokenType.LParen) {
            _ = Lexer.nextToken(lexer);
            var parsedBracketExpression = try parse(lexer, allocator, 0);
            prefixParsed = parsedBracketExpression;
        } else if (@as(ast.TokenType, token.*) == ast.TokenType.Operator) {
            std.debug.assert(token.Operator == ast.OperatorType.Minus);
            var nextToken = lexer.nextToken();
            std.debug.assert(@as(ast.TokenType, nextToken.?.*) == ast.TokenType.Integer);
            prefixParsed.* = ast.TreeNode{ .Integer = -1 * nextToken.?.Integer };
        } else {
            unreachable;
        }
        return prefixParsed;
    } else {
        return ParserError.ParseError;
    }
}

const ParserError = error{ ParseError, OutOfMemory };

fn parseInfix(lexer: *Lexer, lhs: *ast.TreeNode, allocator: std.mem.Allocator) !*ast.TreeNode {
    if (lexer.currentToken) |currentToken| {
        if (@as(ast.TokenType, currentToken.*) == ast.TokenType.RParen) {
            return lhs;
        }
        _ = Lexer.nextToken(lexer);
        const op = currentToken.Operator;
        const derefedToken = currentToken.*;
        var rhsOpt = switch (derefedToken) {
            .Operator => try parse(lexer, allocator, getPrecedence(currentToken)),
            .Integer => null,
            .Invalid => null,
            .LParen => null,
            .RParen => null,
        };
        if (rhsOpt) |rhs| {
            var parsed = try allocator.create(ast.TreeNode);
            parsed.BinOp = ast.BinOpStruct{
                .lhs = lhs,
                .rhs = rhs,
                .op = op,
            };
            return parsed;
        } else {
            return lhs;
        }
    } else {
        std.debug.assert(false);
    }
    return lhs;
}

fn parse(lexer: *Lexer, allocator: std.mem.Allocator, currentPrecedence: u32) (ParserError)!*ast.TreeNode {
    var parsed = try parsePrefix(lexer, allocator);
    const peekedTokenOpt = lexer.peekToken();
    if (peekedTokenOpt) |peekToken| {
        var precedence = getPrecedence(peekToken);
        while ((precedence > currentPrecedence)) {
            const nextTokenOpt = Lexer.nextToken(lexer);
            if (nextTokenOpt) |_| {
                parsed = try parseInfix(lexer, parsed, allocator);
            } else {
                return parsed; // null => lexer tokens are done
            }
        }
    } else {
        return parsed; // null => there are no more tokens to parse, hence no rhs
    }
    return parsed;
}

pub fn eval(root: *ast.TreeNode) i32 {
    var rootDerefed = root.*;
    switch (rootDerefed) {
        .Integer => |integer| {
            return integer;
        },
        .BinOp => |binOp| {
            var lhs = eval(binOp.lhs);
            var rhs = eval(binOp.rhs);
            var result = switch (binOp.op) {
                .Plus => lhs + rhs,
                .Minus => lhs - rhs,
                .Multiply => lhs * rhs,
                .Divide => @divTrunc(lhs, rhs),
            };
            return result;
        },
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input: [1024]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    _ = try stdin.readUntilDelimiter(&input, '\n');
    var lexer = try lex(&input, allocator);
    var parsed = try parse(lexer, allocator, 0);
    var evaled = eval(parsed);
    std.debug.print("Eval result: {}", .{evaled});
}

test "test lexer" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input = "1+2*3";
    var lexer = try lex(input, allocator);
    const tokens = lexer.tokens;
    std.debug.assert(tokens.items[0].Integer == 1);
    std.debug.assert(tokens.items[1].Operator == ast.OperatorType.Plus);
    std.debug.assert(tokens.items[2].Integer == 2);
    std.debug.assert(tokens.items[3].Operator == ast.OperatorType.Multiply);
    std.debug.assert(tokens.items[4].Integer == 3);
}

test "test parser" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input = "1+2*3";
    var lexer = try lex(input, allocator);
    var parsed = try parse(lexer, allocator, 0);
    std.debug.assert(parsed.BinOp.op == ast.OperatorType.Plus);
    std.debug.assert(parsed.BinOp.lhs.Integer == 1);
    std.debug.assert(parsed.BinOp.rhs.BinOp.op == ast.OperatorType.Multiply);
    std.debug.assert(parsed.BinOp.rhs.BinOp.lhs.Integer == 2);
    std.debug.assert(parsed.BinOp.rhs.BinOp.rhs.Integer == 3);
}

test "test eval" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input = "1+2*3";
    var lexer = try lex(input, allocator);
    var parsed = try parse(lexer, allocator, 0);
    var evaled = eval(parsed);
    std.debug.assert(evaled == 7);
}

test "test eval 2" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input = "1+2*3+5*1";
    var lexer = try lex(input, allocator);
    var parsed = try parse(lexer, allocator, 0);
    var evaled = eval(parsed);
    std.debug.assert(evaled == 12);
}

test "test eval 3" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input = "1+2*3+5*1+3";
    var lexer = try lex(input, allocator);
    var parsed = try parse(lexer, allocator, 0);
    var evaled = eval(parsed);
    std.debug.assert(evaled == 15);
}

test "test eval with paren" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input = "(1+2)*3";
    var lexer = try lex(input, allocator);
    var parsed = try parse(lexer, allocator, 0);
    var evaled = eval(parsed);
    std.debug.assert(evaled == 9);
}

test "test eval with unary negatives" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var input = "(1+2)*-3";
    var lexer = try lex(input, allocator);
    var parsed = try parse(lexer, allocator, 0);
    var evaled = eval(parsed);
    std.debug.assert(evaled == -9);
}
