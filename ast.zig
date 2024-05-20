pub const OperatorType = enum {
    Plus,
    Minus,
    Multiply,
    Divide,
};

pub const TokenType = enum { Operator, Integer, Invalid, LParen, RParen };

pub const TokenStruct = union(TokenType) {
    Operator: OperatorType,
    Integer: i32,
    Invalid: void,
    LParen: void,
    RParen: void,
};

pub const NodeType = enum {
    BinOp,
    Integer,
};

pub const BinOpStruct = struct {
    lhs: *TreeNode,
    rhs: *TreeNode,
    op: OperatorType,
};

pub const TreeNode = union(NodeType) {
    BinOp: BinOpStruct,
    Integer: i32, // only unsigned integers for now
};
