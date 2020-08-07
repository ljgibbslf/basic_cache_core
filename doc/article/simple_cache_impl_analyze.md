# 动手写一个基础 cache IP（二）：解析与仿真

在前一篇译文中，翻译了机组黑皮书的进阶内容 5.12 章：实现一个基础 cache，并整理了代码。

在本篇原创文章中，笔者将对此前整理的代码进行一番解析。此外，写一个仿真脚本，在 modelsim 10.5 上运行起来计组黑皮书提供的 testbench ，结合仿真结果，更深入了解这个简单的高速缓存模块。

### 相关链接

**在线内容**

链接：https://booksite.elsevier.com/9780124077263/appendices.php

**源码整理**

笔者将代码整理在 GitHub 上：https://github.com/ljgibbslf/basic_cache_core/tree/master/refer

### 结构

计组黑皮书（以下简称“书”）提供的源文件组成一个结构如下的模块。

#### 模块结构

![image-20200807144824446](D:\workspace_c\pro_cache_cntr\basic_cache_core\doc\article\img\simple_cache_impl_analyze\image-20200807144824446.png)

顶层模块为 dm_cache_fsm，其中的状态机控制了整个模块的功能，包括 **cache 存储访问**、**主存访问**、**CPU请求响应**等功能。在其中例化了 2 个 cache 存储模块，dm_cache_tag/data 模块，分别存储 cache 条目中的标签以及数据。

模块顶层按照方向分为 2 组信号，分别前往 CPU 以及主存 MEM，各自包括 1 个请求信号以及数据信号。外部信号连接至 FSM。

FSM 则通过一组 REQ 以及读写数据信号与 tag/data 模块连接，data 模块信号与 tag 模块一致，图中未画出。

#### 仿真平台结构

配合书中提供的 testbench，搭建起一个结构如下的 cache 模块仿真验证平台。

![image-20200807144800936](D:\workspace_c\pro_cache_cntr\basic_cache_core\doc\article\img\simple_cache_impl_analyze\image-20200807144800936.png)

Testbench 产生 CPU 端请求信号激励，观察待测试的高速缓存模块返回 CPU 的数据。在 tb 中设计了一个“伪”主存模块 sim_mem，使用寄存器模拟外部的主存。

### 模块解析

整个验证仿真平台可分为几类模块，本文依次来看

- 控制状态机 （dm_cache_fsm）
- 存储模块 (dm_cache_tag/data  , sim_mem)
- 激励产生模块（tb_refer_simple_cache）

#### 存储模块

存储模块中开辟了一段寄存器空间，根据读地址返回相应的寄存器数据。在写使能有效的情况下，将写数据写入寄存器，代码如下：

```verilog
module dm_cache_data(
    input  bit clk,     
    input  cache_req_type  data_req,//data request/command, e.g. RW, valid    
    input  cache_data_type data_write, //write port (128-bit line)     
    output cache_data_type data_read
    ); //read port  

timeunit 1ns; timeprecision 1ps;  
    
cache_data_type data_mem[0:1023];  
    
// initial  begin    
//     for (int i=0; i<1024; i++)           
//         data_mem[i] = '0;  
// end  

assign  data_read  =  data_mem[data_req.index];  

always_ff  @(posedge(clk))  begin    
    if  (data_req.we)      
        data_mem[data_req.index] <= data_write;  
end
```

原代码中的 initial 块会在笔者的仿真环境中报错：data_mem 变量在超过一个过程块中被赋值。不知道是否在其他仿真环境，或者不同的仿真设置可以允许这种写法，欢迎读者在评论区指出。

sim_mem 模块基本代码与上述模块类似，增加了一个可配置的读写访问延迟 MEM_DELAY，用于模拟主存的延迟。

```verilog
	localparam MEM_DELAY = 100;
	....
				##MEM_DELAY;
                if (req.rw)
                        mem[req.addr] = req.data;
                else begin
                        data.data = mem[req.addr];             
                end
    ....
```

#### 控制状态机

在状态机空闲状态时，为各信号赋初值。置低 tag/data 两个缓存模块的写使能信号，并将索引信号与 CPU 端口的地址信号相关字段连接。

另一方面，为主存接口信号准备写入地址与数据。

```verilog
/*-------------------------default values for all signals------------*/   
    /*no state change by default*/    
    vstate = rstate;                     
    v_cpu_res = '{0, 0}; tag_write = '{0, 0, 0};     
    
    /*read tag by default*/    
    tag_req.we = '0;                 /*direct map index for tag*/     
    tag_req.index = cpu_req.addr[13:4];    
    
    /*read current cache line by default*/    
    data_req.we  =  '0;    
    /*direct map index for cache data*/    
    data_req.index = cpu_req.addr[13:4];       
    
    /*memory request address (sampled from CPU request)*/    
    v_mem_req.addr = cpu_req.addr;     
    /*memory request data (used in write)*/    
    v_mem_req.data = data_read;     
    v_mem_req.rw  =  '0;
```

主存接口的位宽为 4 个字，由于 CPU 接口位宽为 1 个字，因此每次只要修改主存中的单个字。在实现中，首先读取主存该地址上的数据，data_read,然后根据 CPU 请求地址的字偏移（cpu_req.addr[3:2]），修改单个字后组成写入主存的数据：data_write。

同理，在 4 个字的读数据中，根据 CPU 请求地址的字偏移，每次只返回 CPU 单个字。

```verilog
/*modify correct word (32-bit) based on address*/    
    data_write = data_read;            
    case(cpu_req.addr[3:2])    
        2'b00:data_write[31:0]  =  cpu_req.data;    
        2'b01:data_write[63:32]  =  cpu_req.data;    
        2'b10:data_write[95:64]  =  cpu_req.data;    
        2'b11:data_write[127:96] = cpu_req.data;    
    endcase    
    
    /*read out correct word(32-bit) from cache (to CPU)*/    
    case(cpu_req.addr[3:2])    
        2'b00:v_cpu_res.data  =  data_read[31:0];   
        2'b01:v_cpu_res.data  =  data_read[63:32];    
        2'b10:v_cpu_res.data  =  data_read[95:64];    
        2'b11:v_cpu_res.data  =  data_read[127:96];    
    endcase 
```

cache 控制状态机共包括 4 个状态：

- 



![Image](https://pic4.zhimg.com/80/v2-719846b7bd0db2b6cc296bebd682897f.png)

#### 激励产生模块

### 仿真

#### 脚本与运行

笔者为书中简单的 cache 模块编写了一个 modelsim 的运行 do 脚本，在 win 平台上可以直接运行一个 bat 脚本启动仿真。这些脚本都位于 github 仓库的 sim 目录中。

笔者在 modelsim 10.5 环境测试中，发现黑皮书在网上资源中提供的 testbench 似乎有一些问题，最主要的似乎是将 cpu 写为了 ui，导致无法直接仿真，因此笔者对 testbench 做了一些修改，才运行起仿真。

#### 仿真结果分析