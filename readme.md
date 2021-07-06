# lab6
这个lab的任务是拓展非跳转和非读取指令。  
算术和逻辑运算指令因为不需要考虑例外，只需要加上译码就行了。需要注意的一个是`ANDI`,`ORI`,`XORI`这几个指令和其他不一样，是采用零拓展的，因此需要特别处理一下
```verilog
wire [15:0] alu_op;
wire src2_is_unsigned_imm;
wire  [3:0] hilo;

assign ds_to_es_bus = {hilo        ,  //144:141
                       alu_op      ,  //140:125 添加乘除2bit
                       load_op     ,  //124:124 
                       src1_is_sa  ,  //123:123
                       src1_is_pc  ,  //122:122
                       src2_is_unsigned_imm,//121:121
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
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13];		
assign alu_op[ 0] = inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_add | inst_addi;
assign alu_op[ 1] = inst_subu| inst_sub;
assign alu_op[ 2] = inst_slt| inst_slti;
assign alu_op[ 3] = inst_sltu| inst_sltiu;
assign alu_op[ 4] = inst_and| inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or| inst_ori;
assign alu_op[ 7] = inst_xor| inst_xori;
assign alu_op[ 8] = inst_sll| inst_sllv;
assign alu_op[ 9] = inst_srl| inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_mult;
assign alu_op[13] = inst_multu;
assign alu_op[14] = inst_div;
assign alu_op[15] = inst_divu;			
assign src2_is_imm  = inst_addiu |inst_lui | inst_lw | inst_sw | inst_addi  |inst_slti | inst_sltiu;
assign src2_is_unsigned_imm =  inst_andi | inst_ori | inst_xori;
assign hilo   = {inst_mfhi,inst_mflo,inst_mthi,inst_mtlo};

```

`EXE`部分也是类似：
```verilog
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
assign es_alu_src2 = es_src2_is_unsigned_imm?{{16{1'b0}}, es_imm[15:0]}: // 如果是and or xor 做0拓展
                     es_src2_is_imm ? {{16{es_imm[15]}}, es_imm[15:0]} : // 立即数做符号拓展
                     es_src2_is_8   ? 32'd8 : //特殊数字
                                      es_rt_value;

```
比较麻烦的是添加乘法和除法。这边我直接采用了调用IP的方式。

对于乘法，直接乘起来就可以。并且这个乘法只需要消耗单周期延迟，因此直接在alu里面写上乘法就行了。

对于除法，书上指出直接用运算符推导的部件时序会比较差，因此要手动添加。这里生成的IP核是用AXI接口进行使用的，因此`EXE`阶段调用时要进行握手。

一开始我在ALU里添加除法，因为要握手，就要给ALU添加时序；并且，由于外面要进行阻塞，外面就需要获取ALU的状况，在完成时，ALU要通知`EXE`，而`EXE`也要让`ALU`停下来，这样相当于又要做一次握手；于是我就把除法器从ALU中移出来了

关于握手，我是这样操作的：检测到除法操作时，阻塞`EXE`，同时状态机进入握手状态；尝试和被除数有效和除数有效握手，注意这里被除数(`dividend`)和(`divisor`)的顺序。rs是`dividend`，而rt是`divisor`。握手我用组合逻辑检测，一旦两边都握手成功，就撤下`valid`信号，同时状态机进入等待状态，直到`m_axis_dout_tvalid`返回有效位置。这时读取结果，状态机进入初始阶段，下一拍后，继续执行流水线。取到结果后，把`hi`和`lo`保存到相应的寄存器中。因为这里除法是和alu分离的，要记得用选择器选择最后的结果。
```verilog
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
```
最后这里握手的波形是这样的：         
![](https://i.loli.net/2021/07/06/EosFrAwbt9Ni1eZ.png)

此处握手时间很长，后面看了一下跟踪的实现，时间也挺长，但是要稍微快30%.            
![](https://i.loli.net/2021/07/06/L5ZR1XGAlMN2nC7.png)