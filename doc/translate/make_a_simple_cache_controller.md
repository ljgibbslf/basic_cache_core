#! https://zhuanlan.zhihu.com/p/170365725
# 动手写一个基础 cache IP

翻译与整理于《计算机组成与设计 硬件软件接口》（第五版）章 5.12 进阶内容：实现 cache 的前半部分。

该章为在线内容，链接：https://booksite.elsevier.com/9780124077263/appendices.php

------

本节基于书中第 5.9 节讨论的缓存设计方案，采用 SystemVerilog 实现一个简单的 cache ，源代码组织为八个图表。

> 注：书中代码以图表形式组织，译者已经将代码整理为文件形式，可以从译者的 github 获取：https://github.com/ljgibbslf/basic_cache_core/tree/master/refer

然后，详细介绍了一个缓存一致性协议的实现，以及实现的难点所在。（译者：该部分将在后续的文章中翻译）

### 简单 cache 特性

在书中的 5.9.1 节，列出了所要实现的简单 cache 的特性:


![Image](https://pic4.zhimg.com/80/v2-ba0697797e9190e65abd98338056c5ba.png)

其中比较重要的有几点：

- 直接映射的 cache 组织方式，每个地址对应于唯一的 cache 块
- 写回机制
- 写分配策略，即在写缺失时更新 cache 块
- 块大小为 4 个字，即 128 bit
- cache 大小为 16KB，即 1024 个块

### 简单 cache 的 SystemVerilog  实现

本节中使用的硬件描述语言是 SystemVerilog 。与以前版本的 Verilog 相比，本节实现中 SV 最大的变化是， SystemVerilog 借用了 C 语言的结构体语法（structure），使代码更易于阅读。后文的图 5.12.1 到 5.12.8 是缓存控制器的 SystemVerilog 具体描述。 

![Image](https://pic4.zhimg.com/80/v2-09963ec4290e17758b12b2a3765ada8b.png)

**图 5.12.1 为 cache 标签以及数据设计的 SystemVerilog 类型定义**。本实现中 tag 域位宽为 18 比特，index 域位宽为 10 比特，用于索引缓存块（cache block，支持至多 1024 个块），地址中还包括 2 比特（bits 3:2）用于在缓存块的四个字中选中相应的字。本实现剩余的定义在后图中。

![Image](https://pic4.zhimg.com/80/v2-e56fb65c79f8e9f7120c3ab4026b2791.png)


**图 5.12.1 为 cache-cpu 以及 chche-memory 两个接口 SystemVerilog 类型定义**。两个接口的实现几乎相同，区别在于 cache-cpu 间的接口设计为 32 比特，而 cache 与主存间的接口位宽为 128 比特。

图 5.12.1 以及图 5.12.2 中的代码定义了后续所使用的  cache 各类结构体。比如，cache 标签结构体（cache_tag_type）包括有效位 valid 以及一个脏位 dirty，以及 18 比特的 tag 域（[TAGMSB:TAGLSB] tag）。

> 译注：上述内容整理为 cache_def.sv

图 5.12.3 是整个 cache 的原理图，其中采用 SV 变量的名字标注了各个组成部分。

![Image](https://pic4.zhimg.com/80/v2-88e2cefc7ad6dd286d806a24cb502931.png)

上图中省略了 cache tag&data memory 的写使能信号，以及写数据选择器的选择控制信号。不同于为 cache 中的四个字单独设计分离的写使能信号，实现中首先将该地址原先的值读出，修改所需的字后，再以 128 比特为一个整体写入 cache 中。

图 5.12.4 分别为 cache 的数据与标签定义了 2 个模块，dm_cache_data 以及 dm_cache_tag ，在这两个模块中，读取操作可以随时进行，但是写操作必须发送在写使能有效的时钟上升沿。 

![Image](https://pic4.zhimg.com/80/v2-16418f4d4c7cdea21be5442a410188a1.png)
> 译注：上述内容分别整理为 dm_cache_data.sv 以及 dm_cache_tag.sv

图 5.12.5 定义了 cache 控制状态机 FSM 的输入、输出信号和状态机各个状态。

输入信号包括 2 个方向：来自CPU的请求（cpu_req）和来自主存的响应（mem_data）。输出信号包括对CPU的响应（cpu_res）和对主存的请求（mem_req）。

图中还声明了 FSM 的内部变量。例如，FSM 的当前状态寄存器和下一状态寄存器，分别为 rstate 和 vstate。

![Image](https://pic4.zhimg.com/80/v2-9e91a4050c9dd79b27687927305903ea.png)

图 5.12.6 列出了控制信号的默认值，包括：当前从块中读取的数据字，以及等待写入的数据字等等。默认状态下，缓存写入使能信号设置为低电平。这些变量在每个周期中都会更新，所以缓存的写使能信号置起后，比如 tag_req.we ，只会在 1 个周期内有效，之后将由状态机置低。

![Image](https://pic4.zhimg.com/80/v2-4be90d8d00acd45527da81aa5bf762ab.png)

后续两张图片中的代码实现了状态机的主体部分：case(rstate)，一个巨大的 case 语句，包括 4 个状态。

图 5.12.7 中的状态机代码从初始状态（idle）开始实现。在 idle 状态中，FSM 只是做了一点微小的工作，在 CPU 发出一次有效的请求后，转至 cache 标签比较状态： compare_tag 。

在标签比较状态中，FSM 检查其访问的 cache 块中的 tag 域是否与请求一致，以及该 cache 块是否有效。如果一切都 OK，即 cache 命中（hit），那么 FSM 首先置起 cache 就绪信号（v_cpu_res.ready）。（译注：读操作中，无论如何都会返回该 cache 位置上的数据，cpu 根据就绪信号判断当前的数据是否有效）。如果是写操作，那么 FSM 会置起该块的有效位与脏位，并返回 IDLE 状态。

如果没有命中（cache miss），那么 FSM 着手清除该地址上原先的表项，包括内容以及标志位，用于分配空间给新的请求。如果块本身就是空的或者无效的，那么直接转入空间分配状态：Allocate。

![Image](https://pic4.zhimg.com/80/v2-d1784face301118e4112582aae1fb336.png)

图 5.12.8 中的代码继续标志比较状态的部分。如果待替换的块是脏的（dirty），那么转至写回状态（write_back）。

图中包括空间分配状态（Allocate）的实现，该状态中从主存读取新块。FSM 一直等待在该状态，直到内存准备就绪，返回新的一块数据；接着，FSM 转入标志比较状态。图中还包括写回状态（write_back）的实现。如图所示，写回状态只是将脏块写入内存，在写入完成后，转至空间分配状态。

图中最后一部分的时序代码用于在时钟上升沿，将 FSM 转入下一状态。或者回到初始状态，如果 rst 置起。
> 译注：上述内容整理为 dm_cache_fsm.sv

![Image](https://pic4.zhimg.com/80/v2-769006c2f1d0296d55ec3d2da0efdd5d.png)

本书的在线材料包括一个测试用例模块（testbench），该模块将有助于检查这些图中的代码。本文中的 SystemVerilog 实现可用于在 FPGA 中创建一个缓存控制器以及其缓存。

> testbench 也整合至译者的 github 仓库了，可以在 tb 目录下查看

### cache FSM 状态转移图

对应于上述实现，书中在章 5.9 提供了 cache 控制 FSM 的状态转移图。

![Image](https://pic4.zhimg.com/80/v2-719846b7bd0db2b6cc296bebd682897f.png)

### 总结
本文整理翻译了 5.12 前半部分的内容，后续会在基础 cache 的代码上，跟着书一步步实现更高级的 cache。
