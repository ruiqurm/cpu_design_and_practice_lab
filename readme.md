# lab5
第四章实践任务三  
参考了https://blog.csdn.net/jojo_it_journey/article/details/117431349 的博客

这个lab其实比较简单，但是当时由于没仔细看书，而且刚刚入门，犯了一堆很蠢的错误。

## 准备工作
首先需要完成lab3调试，如果调不出来可以参考https://blog.csdn.net/jojo_it_journey/article/details/117377366 的博客

建议把代码好好读一读，搞懂每个变量的作用和CPU到底怎么运行再往下。

lab4和lab5需要替换func_lab。具体的流程参考书上4.3.3 2重新定制inst_ram部分。
## 大致的思路
这个lab要求用前递解决流水线冲突问题。也就是说，把`EXE`,`MEM`,`WB`将要传给下一层的结果直接传给`ID`即可。传到`ID`后，`ID`比较一下寄存器，看是否与源寄存器相同，并且寄存器标号不为0，最后通过一个优先级的4-1选择器选择信号。

怎么传呢？需要理解的是，mycpu五个调用的阶段是同时在运行的，并且因为是流水线，它们是分别属于不同的指令的。因此只需要给`ID`加三个输入，给`EXE`,`MEM`,`WB`加三个输出，把它们连起来即可。

要传的数据是什么呢？首先需要有各阶段计算出的数据和寄存器的标号，例如`ms_dest,ms_final_result`、`es_dest,es_load_op,es_alu_result`，`ws_dest,ws_final_result`.其次还需要有valid信号，如果没有valid信号，直接对寄存器进行判断，这时候如果该阶段没有目的寄存器（值为`XXXX`），那么做逻辑判断似乎会恒为真。此外，还需要考虑寄存器编号是否为0或者寄存器是读寄存器还是写寄存器。

如果做了lab4再做lab5，以上的操作就足够了。但是如果直接跳过lab4，还需要考虑`Load-to-Branch`的问题，否则执行到一半就会报错。这一点在4.6.2有提到，但是作者是在**完成阻塞操作后**说的，当时我看的时候没注意，以为可以暂时先忽略。`Load-to-Branch`的主要原因是仿存的数据要到MEM阶段才有，而后续的ADD不能在`ID`阶段就取得相应寄存器的值，因此要停一拍。具体到实现上，可以在`EXE`阶段从旁路中传回是否是`load`指令，然后由`ID`在`ready_go`中决定是否要暂停流水线。

## 遇到的问题
由于刚上手HDL，我遇到了不少问题。

* 偏移量计算错误  
	```verilog
	assign es_to_id_bypass_reg = es_to_id_bypass[37:33];//寄存器是5位
	```
* 变量名打错  
	```verilog
	assign es_to_id_bypass_data = es_to_id_bypass[31:0];
	assign ms_to_id_bypass_data = es_to_id_bypass[31:0];//打错
	assign ws_to_id_bypass_data = es_to_id_bypass[31:0];//打错
	```
	这个其实很明显，但是我一直在用波形去查错，而不是直接看代码，所以调了一个小时没发现这个问题。最后我还是用波形找到的这个错误，因为我发现`es_to_id_bypass_data`、`ms_to_id_bypass_data`，`ws_to_id_bypass_data`不是对应的（正常来说，`ms_to_id_bypass_data`的下一拍就是现在的`es_to_id_bypass_data`）

* `Load-to-Branch`没有处理  
  上面说过了


