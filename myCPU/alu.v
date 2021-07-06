
module alu(
  // input         clk,
  input  [15:0] alu_op,
  input  [31:0] alu_src1,
  input  [31:0] alu_src2,
  // output        ok,
  output [31:0] hi,
  output [31:0] alu_result
);

wire op_add;   //加法操作
wire op_sub;   //减法操作
wire op_slt;   //有符号比较，小于置位
wire op_sltu;  //无符号比较，小于置位
wire op_and;   //按位与
wire op_nor;   //按位或非
wire op_or;    //按位或
wire op_xor;   //按位异或
wire op_sll;   //逻辑左移
wire op_srl;   //逻辑右移
wire op_sra;   //算术右移
wire op_lui;   //立即数置于高半部分

wire op_mult; //乘法
wire op_multu; //乘法
// wire op_div;  //除法
// wire op_divu;  //除法

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];

assign op_mult = alu_op[12];
assign op_multu= alu_op[13];
// assign op_div  = alu_op[14];
// assign op_divu = alu_op[15];
// always @(clk)begin
//   op_div <= alu_op[14];
// end

wire [31:0] add_sub_result; 
wire [31:0] slt_result; 
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result; 
wire [63:0] sr64_result; 
wire [31:0] sr_result; 


// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = {alu_src2[15:0], 16'b0};

// SLL result 
assign sll_result = alu_src2 << alu_src1[4:0];

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src2[31]}}, alu_src2[31:0]} >> alu_src1[4:0];

assign sr_result   = sr64_result[31:0];

// MULT,MULTU result
wire [32:0] mult_src1;//多1位
wire [32:0] mult_src2;
wire [32:0] multu_src1;//多1位
wire [32:0] multu_src2;

wire [63:0] unsigned_prod;
wire [63:0] signed_prod;

wire [1:0]no_use;
assign mult_src1 = {alu_src1[31],alu_src1};
assign mult_src2 = {alu_src2[31],alu_src2};
assign multu_src1 = {1'b0,alu_src1};
assign multu_src2 = {1'b0,alu_src2};

assign {no_use,signed_prod} = $signed(mult_src1) * $signed(mult_src2);
assign {no_use,unsigned_prod} = $signed(multu_src1) * $signed(multu_src2);

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_multu}} & unsigned_prod[31:0])
                  | ({32{op_mult}} & signed_prod[31:0]);
assign hi        =  ({32{op_multu}} & unsigned_prod[63:32])
                 | ({32{op_mult}}  & signed_prod[63:32]) ;
// assign ok   = (op_div || op_divu) ? div_ok: 1'b1;                
endmodule
