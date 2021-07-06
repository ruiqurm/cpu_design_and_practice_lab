`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    output [`ES_TO_DS_BYPASS-1:0] es_to_ds_bypass
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [15:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_unsigned_imm;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
wire [ 3:0] es_hilo       ;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_div;
wire        inst_divu;

assign {inst_mfhi,inst_mflo,inst_mthi,inst_mtlo} = es_hilo;
assign {es_hilo        ,  //144:141
        es_alu_op      ,  //140:125
        es_load_op     ,  //124:124
        es_src1_is_sa  ,  //123:123
        es_src1_is_pc  ,  //122:122
        es_src2_is_unsigned_imm,//121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_result;
wire        es_res_from_mem;
wire [31:0] es_alu_hi;
reg [31:0] hi;
reg [31:0] lo;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70 读操作
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result  ,  //63:32
                       es_pc             //31:0
                      };

// div result
assign inst_div   = es_alu_op[14];
assign inst_divu  = es_alu_op[15];

wire [63:0] signed_div_result;
wire [63:0] unsigned_div_result;
reg div_s_axis_divisor_tvalid;
reg div_s_axis_dividend_tvalid;
wire div_m_axis_dout_tvalid;
wire div_s_axis_divisor_tready;//divisor握手成功
wire div_s_axis_dividend_tready;//dividend握手成功

reg udiv_s_axis_divisor_tvalid;
reg udiv_s_axis_dividend_tvalid;
wire udiv_s_axis_divisor_tready;//握手成功
wire udiv_s_axis_dividend_tready;//dividend握手成功
wire udiv_m_axis_dout_tvalid;

reg[2:0] div_ps; // 0-正常 1-除法握手阶段 2-无符号除法握手阶段 3-除法等待结果阶段 4-无符号除法等待结果阶段
reg[2:0] div_ns;
wire[1:0] handshake;
parameter DIV_IDLE = 0;
parameter DIV_SIGNED_HANDSHAKE = 1;
parameter DIV_UNSIGNED_HANDSHAKE = 2;
parameter DIV_SIGNED_WAITING = 3;
parameter DIV_UNSIGNED_WAITING = 4;
reg div_ok;
assign handshake[0] = (inst_div)? (div_s_axis_divisor_tready == div_s_axis_divisor_tvalid && div_s_axis_divisor_tvalid==1):
                      (inst_divu)? (udiv_s_axis_divisor_tready == udiv_s_axis_divisor_tvalid && udiv_s_axis_divisor_tvalid==1):
                      1'b0;
assign handshake[1] = (inst_div)? (div_s_axis_dividend_tready == div_s_axis_dividend_tvalid && div_s_axis_dividend_tvalid==1):
                      (inst_divu)? (udiv_s_axis_dividend_tready == udiv_s_axis_dividend_tvalid && udiv_s_axis_dividend_tvalid==1):
                      1'b0;                      


// 组合逻辑，确认下一状态
always @(*) begin
  if(div_ps==DIV_IDLE)begin
    div_ok = 1'b0;
    if(inst_div)div_ns<=DIV_SIGNED_HANDSHAKE;
    else if(inst_divu)div_ns<=DIV_UNSIGNED_HANDSHAKE;
    else div_ns<=DIV_IDLE;
  end

  else if(div_ps==DIV_SIGNED_HANDSHAKE)begin
    if(handshake==2'b11)div_ns <= DIV_SIGNED_WAITING;
    else div_ns<=DIV_SIGNED_HANDSHAKE;
  end
  else if(div_ps==DIV_UNSIGNED_HANDSHAKE)begin
    if(handshake==2'b11)div_ns<=DIV_UNSIGNED_WAITING;
    else div_ns<=DIV_UNSIGNED_HANDSHAKE;
  end
  else if(div_ps == DIV_SIGNED_WAITING)
    if(div_m_axis_dout_tvalid)begin
      div_ns <= DIV_IDLE;
      div_ok<= 1'b1;
    end
    else div_ns <= DIV_SIGNED_WAITING;
  else if(div_ps == DIV_UNSIGNED_WAITING)begin
    if(udiv_m_axis_dout_tvalid)begin
      div_ns <= DIV_IDLE;
      div_ok <= 1'b1;
    end
    else div_ns <= DIV_UNSIGNED_WAITING;
  end
  else 
    div_ns <= DIV_IDLE;
end
always @(posedge clk) begin
    div_ps <= div_ns;
end

always @(posedge clk) begin
    if(div_ps == DIV_SIGNED_HANDSHAKE)begin
      if(!div_s_axis_divisor_tready)begin
        div_s_axis_divisor_tvalid  <= 1'b1;
      end
      else begin
        div_s_axis_divisor_tvalid  <= 1'b0;
      end

      if(!div_s_axis_dividend_tready)begin
        div_s_axis_dividend_tvalid  <= 1'b1;
      end
      else begin
        div_s_axis_dividend_tvalid  <= 1'b0;

      end   
    end
    else if(div_ps == DIV_UNSIGNED_HANDSHAKE) begin
      if(!udiv_s_axis_divisor_tready)begin
        udiv_s_axis_divisor_tvalid  <= 1'b1;
      end
      else begin
        udiv_s_axis_divisor_tvalid  <= 1'b0;
      end
      if(!udiv_s_axis_dividend_tready)begin
        udiv_s_axis_dividend_tvalid  <= 1'b1;
      end
      else begin
        udiv_s_axis_dividend_tvalid  <= 1'b0;
      end     
    end
    else begin
      div_s_axis_divisor_tvalid  <= 1'b0;
      div_s_axis_dividend_tvalid <= 1'b0;
      udiv_s_axis_divisor_tvalid  <= 1'b0;
      udiv_s_axis_dividend_tvalid  <= 1'b0;
    end
end

my_signed_div my_signed_div1(
 .aclk                    (clk),
 .s_axis_divisor_tvalid   (div_s_axis_divisor_tvalid),
 .s_axis_divisor_tready   (div_s_axis_divisor_tready),
 .s_axis_divisor_tdata    (es_alu_src2),
 .s_axis_dividend_tvalid  (div_s_axis_dividend_tvalid),
 .s_axis_dividend_tready  (div_s_axis_dividend_tready),
 .s_axis_dividend_tdata   (es_alu_src1),
 .m_axis_dout_tvalid      (div_m_axis_dout_tvalid),
 .m_axis_dout_tdata       (signed_div_result)
);   

my_unsigned_div my_unsigned_div1(
 .aclk                    (clk),
 .s_axis_divisor_tvalid   (udiv_s_axis_divisor_tvalid),
 .s_axis_divisor_tready   (udiv_s_axis_divisor_tready),
 .s_axis_divisor_tdata    (es_alu_src2),
 .s_axis_dividend_tvalid  (udiv_s_axis_dividend_tvalid),
 .s_axis_dividend_tready  (udiv_s_axis_dividend_tready),
 .s_axis_dividend_tdata   (es_alu_src1),
 .m_axis_dout_tvalid      (udiv_m_axis_dout_tvalid),
 .m_axis_dout_tdata       (unsigned_div_result)
);   

assign es_ready_go    = ((inst_div || inst_divu) && div_ok ) ||
                        ~(inst_div || inst_divu);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_unsigned_imm?{{16{1'b0}}, es_imm[15:0]}: // 如果是and or xor 做0拓展
                     es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} : // 立即数做符号拓展
                     es_src2_is_8   ? 32'd8 : //特殊数字
                                      es_rt_value;

alu u_alu(
    // .clk        (clk),
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    // .ok         (ok)       ,
    .hi         (es_alu_hi)   
    );

assign es_result =  (inst_mfhi)?hi:
                    (inst_mflo)?lo:
                    (inst_div)?signed_div_result[31:0]:
                    (inst_divu)?unsigned_div_result[31:0]:
                    es_alu_result;
//旁路
assign es_to_ds_bypass = {es_valid&es_gr_we,es_dest,es_load_op,es_result};


assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we&&es_valid ? 4'hf : 4'h0; //写使能
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rt_value;


//hilo 

always @ (posedge clk) begin
    if((es_alu_op[14] || es_alu_op[15]))begin
        hi <= es_alu_op[14]? signed_div_result[31:0]: unsigned_div_result[31:0];
        lo <= es_alu_op[14]? signed_div_result[63:32]: unsigned_div_result[63:32];  
    end
    else if((es_alu_op[12] || es_alu_op[13]))begin
        hi <= es_alu_hi;
        lo <= es_alu_result;
    end
    else if(inst_mthi)begin
        hi <= es_rs_value;
    end
    else if(inst_mtlo)begin
        lo <= es_rs_value;
    end
end

endmodule
