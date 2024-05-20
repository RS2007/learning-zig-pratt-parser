pub const OperatorType = enum {
    Plus,
    Minus,
    Multiply,
    Divide,
};

pub const TokenType = enum { Operator, Integer, Invalid };

pub const TokenStruct = union(TokenType) {
    Operator: OperatorType,
    Integer: u32,
    Invalid: void,
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
    Integer: u32, // only unsigned integers for now
};
