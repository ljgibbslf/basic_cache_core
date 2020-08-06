//////////////////////////////////////////////////////////////////////////////////
// Author:        Computer Organization and Design 5.12
// Editor:        ljgibbs / lf_gibbs@163.com
// Edit Date: 2020/08/06 
// Design Name: basic_cache_controller
// Module Name: dm_cache_data
// Description:
//      cache 数据存储，单端口，1024 个块，每个块中有一个 cache line
//          以 data_req 中的 index ，作为地址访问存储单元
// Dependencies: 
//      
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
module dm_cache_data(
    input  bit clk,     
    input  cache_req_type  data_req,//data request/command, e.g. RW, valid    
    input  cache_data_type data_write, //write port (128-bit line)     
    output cache_data_type data_read
    ); //read port  

timeunit 1ns; timeprecision 1ps;  
    
cache_data_type data_mem[0:1023];  
    
initial  begin    
    for (int i=0; i<1024; i++)           
        data_mem[i] = '0;  
end  

assign  data_read  =  data_mem[data_req.index];  

always_ff  @(posedge(clk))  begin    
    if  (data_req.we)      
        data_mem[data_req.index] <= data_write;  
end

endmodule