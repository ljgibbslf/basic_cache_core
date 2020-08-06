//////////////////////////////////////////////////////////////////////////////////
// Author:        Computer Organization and Design 5.12
// Editor:        ljgibbs / lf_gibbs@163.com
// Edit Date: 2020/08/06 
// Design Name: basic_cache_controller
// Module Name: dm_cache_tag
// Description:
//      cache tag 存储，单端口，1024 个块，每个块中存放标志位以及tag
//          以 tag_req 中的 index ，作为地址访问存储单元
// Dependencies: 
//      
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////
/*cache: tag memory, single port, 1024 blocks*/
module dm_cache_tag(
    input  bit clk, //write clock    
    input  cache_req_type tag_req, //tag request/command, e.g. RW, valid    
    input  cache_tag_type tag_write,//write port        
    output cache_tag_type tag_read
    );//read port  

timeunit 1ns; timeprecision 1ps;  

cache_tag_type tag_mem[0:1023];  

initial  begin      
    for (int i=0; i<1024; i++)       
        tag_mem[i] = '0;  
end  

assign tag_read = tag_mem[tag_req.index]; 

always_ff  @(posedge(clk))  begin    
    if  (tag_req.we)      
        tag_mem[tag_req.index] <= tag_write;  
    end
endmodule
