//simulated memory
import cache_def::*; 

`timescale 1ns/1ps

class rand_cl;
   rand bit [127:0] v;
endclass

module sim_mem(input bit clk,
               input  mem_req_type  req,
               output mem_data_type data);
        default clocking cb @(posedge clk);
        endclocking
 
        localparam MEM_DELAY = 100;

        bit [127:0] mem[*];
        rand_cl rand_data = new();

        always @(posedge clk) begin
              data.valid = '0;

              if (!mem.exists(req.addr)) begin        //random initialize DRAM data on-demand 
                      rand_data.randomize();
                      mem[req.addr] = rand_data.v;     
              end


              if (req.valid) begin
                $display("%t: [Memory] %s @ addr=%x with data=%x", $time, (req.rw) ? "Write" : "Read", req.addr, 
                        (req.rw) ? req.data : mem[req.addr]);
                ##MEM_DELAY;
                if (req.rw)
                        mem[req.addr] = req.data;
                else begin
                        data.data = mem[req.addr];             
                end

                $display("%t: [Memory] request finished", $time);
                data.valid = '1;                                
              end
        end 
endmodule 


module test_main;
        bit clk;       
        initial forever #2 clk = ~clk; 

        mem_req_type    mem_req;        
        mem_data_type   mem_data;
        iu_req_type     iu_req;
        iu_result_type  iu_res;
       
        bit     rst;
        
        default clocking cb @(posedge clk);
        endclocking
 
        //simulated CPU
       program sim_cpu;
        initial begin
               rst = '0;
               ##5;                           
               rst = '1;
               ##10;
               rst = '0;

               iu_req = '{default:0};
               
               //note that: The CPU needs to reset all cache tags in a real ASIC implementation
               //In this testbench, all tags are automatically initialized to 0 because the use of the systemverilog bit data type
               //For an FPGA implementation, all RAMs are initialized to be 0 by default.
               //read clean miss (allocate)                
               $timeformat(-9, 3, "ns", 10);

               iu_req.rw = '0;
               iu_req.addr[13:4] = 2;           //index 2
               iu_req.addr[31:14] = 'h1234;
               iu_req.valid = '1;
               $display("%t: [CPU] read addr=%x", $time, iu_req.addr);
               wait(iu_res.valid == '1);
               $display("%t: [CPU] get data=%x", $time, iu_res.data);
               iu_req.valid = '0;
               ##5;

               //read hit clean line
               iu_req.addr[3:0] = 8;
               iu_req.valid = '1;
               $display("%t: [CPU] read addr=%x", $time, iu_req.addr); 
               wait(iu_res.valid == '1);
               $display("%t: [CPU] get data=%x", $time, iu_res.data); 
               iu_req.valid = '0;
               ##5;
 
               //write hit clean line (cache line is dirty afterwards)
               iu_req.rw = '1;
               iu_req.addr[3:0] = 'ha;
               iu_req.data = 32'hdeadbeef;
               iu_req.valid = '1;
               $display("%t: [CPU] write addr=%x with data=%x", $time, iu_req.addr, iu_req.data);
               wait(iu_res.valid == '1);
               $display("%t: [CPU] write done", $time); 
               iu_req.valid = '0;
               ##5;
 
               //write conflict miss (write back then allocate, cache line dirty)
               iu_req.addr[31:14] = 'h4321;               
               iu_req.data = 32'hcafebeef;
               iu_req.valid = '1;
               $display("%t: [CPU] write addr=%x with data=%x", $time, iu_req.addr, iu_req.data); 
               wait(iu_res.valid == '1);
               $display("%t: [CPU] write done", $time);
               iu_req.valid = '0;
               ##5;
 
               //read hit dirty line
               iu_req.rw = '0;
               iu_req.addr[3:0] = '0;
               iu_req.valid = '1; 
               $display("%t: [CPU] read addr=%x", $time, iu_req.addr);
               wait(iu_res.valid == '1);
               $display("%t: [CPU] get data=%x", $time, iu_res.data); 
               iu_req.valid = '0;
               ##5;
 
               //read conflict miss dirty line (write back then allocate, cache line is clean)  
               iu_req.addr[31:14] = 'h5678;
               iu_req.addr[3:0] = 4;
               iu_req.valid = '1;
               $display("%t: [CPU] read addr=%x", $time, iu_req.addr); 
               wait(iu_res.valid == '1);
               $display("%t: [CPU] get data=%x", $time, iu_res.data); 
               iu_req.valid = '0;
               ##5; 

               $finish();
         end
        endprogram
        
        dm_cache_fsm dm_cache_inst(.*);
        sim_mem      dram_inst(.*, .req(mem_req), .data(mem_data));
endmodule
