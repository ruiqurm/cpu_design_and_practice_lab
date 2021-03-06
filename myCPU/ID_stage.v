`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    , // 执行阶段允许
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid, // if_to_id valid
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  , // {指令，当前地址}
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    
    //旁路
    input [`ES_TO_ID_BYPASS-1:0] es_to_id_bypass,
    input [`MS_TO_ID_BYPASS-1:0] ms_to_id_bypass,
    input [`WS_TO_ID_BYPASS-1:0] ws_to_id_bypass
);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;


wire        inst_addu;
wire        inst_addiu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;

wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;

assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {alu_op      ,  //135:124
                       load_op     ,  //123:123 数据ram读使能
                       src1_is_sa  ,  //122:122
                       src1_is_pc  ,  //121:121
                       src2_is_imm ,  //120:120
                       src2_is_8   ,  //119:119
                       gr_we       ,  //118:118
                       mem_we      ,  //117:117 数据ram写使能
                       dest        ,  //116:112
                       imm         ,  //111:96
                       rs_value    ,  //95 :64
                       rt_value    ,  //63 :32
                       ds_pc          //31 :0
                      };
                      // 送给alu的



assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if(reset==1) ds_valid = 0;
	else ds_valid <= fs_to_ds_valid;// 缺少给dsvlid的赋值
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end



assign op   = ds_inst[31:26];// opcode
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];// 立即数
assign jidx = ds_inst[25: 0];// instruction index

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

// 判断

assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];

assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal;
assign alu_op[ 1] = inst_subu;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_sll;
assign alu_op[ 9] = inst_srl;
assign alu_op[10] = inst_sra;
assign alu_op[11] = inst_lui;

assign load_op = inst_lw;// 缺

assign src1_is_sa   = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal;
assign src2_is_imm  = inst_addiu | inst_lui | inst_lw | inst_sw;
assign src2_is_8    = inst_jal;
assign res_from_mem = inst_lw;
assign dst_is_r31   = inst_jal;
assign dst_is_rt    = inst_addiu | inst_lui | inst_lw;
assign gr_we        = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr;
assign mem_we       = inst_sw; 

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

wire es_to_id_bypass_valid;
wire [4:0] es_to_id_bypass_reg;
wire [31:0] es_to_id_bypass_data;
wire es_to_id_is_inst_load;

wire ms_to_id_bypass_valid;
wire [4:0] ms_to_id_bypass_reg;
wire [31:0]ms_to_id_bypass_data;

wire ws_to_id_bypass_valid;
wire [4:0] ws_to_id_bypass_reg;
wire [31:0] ws_to_id_bypass_data;

assign es_to_id_is_inst_load = es_to_id_bypass[32];

assign es_to_id_bypass_valid = es_to_id_bypass[38];
assign ms_to_id_bypass_valid = ms_to_id_bypass[37];
assign ws_to_id_bypass_valid = ws_to_id_bypass[37];

assign es_to_id_bypass_reg = es_to_id_bypass[37:33];
assign ms_to_id_bypass_reg = ms_to_id_bypass[36:32];
assign ws_to_id_bypass_reg = ws_to_id_bypass[36:32];


assign es_to_id_bypass_data = es_to_id_bypass[31:0];
assign ms_to_id_bypass_data = ms_to_id_bypass[31:0];
assign ws_to_id_bypass_data = ws_to_id_bypass[31:0];

assign ds_ready_go    = ~(
    (es_to_id_bypass_valid && es_to_id_is_inst_load && ~src1_is_pc && rs == es_to_id_bypass_reg && rs!=0 )               ||
    (es_to_id_bypass_valid &&  es_to_id_is_inst_load && ~src2_is_imm && ~src2_is_8 &&  rt == es_to_id_bypass_reg && rt!=0)            
);
// assign debug_signal_sss = ;

// assign ds_ready_go    =  ~(es_to_id_is_inst_load && ~src1_is_pc && rs == es_to_id_bypass_reg && rs!=0 ||
//                            es_to_id_is_inst_load && ~src2_is_imm && ~src2_is_8 &&  rt == es_to_id_bypass_reg && rt!=0
//                           );

assign rs_value = (es_to_id_bypass_valid &&rs!=0 && rs == es_to_id_bypass_reg)? es_to_id_bypass_data:
                  (ms_to_id_bypass_valid &&rs!=0 && rs == ms_to_id_bypass_reg)? ms_to_id_bypass_data:
                  (ws_to_id_bypass_valid && rs!=0 && rs == ws_to_id_bypass_reg)? ws_to_id_bypass_data:
                  rf_rdata1;

assign rt_value = (es_to_id_bypass_valid && rt!=0 && rt == es_to_id_bypass_reg)? es_to_id_bypass_data:
                  (ms_to_id_bypass_valid && rt!=0 &&rt == ms_to_id_bypass_reg)? ms_to_id_bypass_data:
                  (ws_to_id_bypass_valid && rt!=0 && rt == ws_to_id_bypass_reg)? ws_to_id_bypass_data:
                  rf_rdata2;


assign rs_eq_rt = (rs_value == rt_value);
assign br_taken = (   inst_beq  &&  rs_eq_rt 
                   || inst_bne  && !rs_eq_rt
                   || inst_jal
                   || inst_jr
                  ) && ds_valid;
                  //满足跳转
assign br_target = (inst_beq || inst_bne) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) : // 立即数左移两位，加上next_pc
                   (inst_jr)              ? rs_value :
                  /*inst_jal*/              {fs_pc[31:28], jidx[25:0], 2'b0}; //pc的高位 和 立即数拼起来

endmodule
