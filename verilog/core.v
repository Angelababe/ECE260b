// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 

// Note: in the original file, out and sum_out have no signal
// Add input sum_in in the module to receive the sum result of the other core
module core (clk, sum_out, sum_in, mem_in, out, ready_to_div, fifo_ext_rd, inst, reset); 

parameter col = 8;
parameter bw = 8;
parameter bw_psum = 2*bw+4; // TODO: at most 2*bw+2?
parameter pr = 16;

output [bw_psum+3:0] sum_out;
output [bw_psum*col-1:0] out;
output ready_to_div;
wire   [bw_psum*col-1:0] pmem_out;
input fifo_ext_rd;
input  [bw_psum+3:0] sum_in;
input  [pr*bw-1:0] mem_in;
input  clk;
input  [18:0] inst; 
input  reset;

wire  [pr*bw-1:0] mac_in;
wire  [pr*bw-1:0] kmem_out;
wire  [pr*bw-1:0] qmem_out;
wire  [bw_psum*col-1:0] pmem_in;
wire  [bw_psum*col-1:0] fifo_out;
wire  [bw_psum*col-1:0] sfp_in;
wire  [bw_psum*col-1:0] sfp_out;
wire  [bw_psum*col-1:0] array_out;
wire  [col-1:0] fifo_wr;
wire  ofifo_rd;
wire [3:0] qkmem_add;
wire [3:0] pmem_add;

wire  qmem_rd;
wire  qmem_wr; 
wire  kmem_rd;
wire  kmem_wr; 
wire  pmem_rd;
wire  pmem_wr; 

wire ofifo_valid;  // check whether the ofifo is valid (all the fifos in it are full)

assign ready_to_acc = inst[18];
assign sfd_sum_in = inst[17];
assign ofifo_rd = inst[16];
assign qkmem_add = inst[15:12];
assign pmem_add = inst[11:8];

assign qmem_rd = inst[5];
assign qmem_wr = inst[4];
assign kmem_rd = inst[3];
assign kmem_wr = inst[2];
assign pmem_rd = inst[1];
assign pmem_wr = inst[0];

assign mac_in  = inst[6] ? kmem_out : qmem_out;

// mac_array-> ofifo-> pmem -> sfp_row
assign sfp_in = pmem_out;
assign pmem_in = fifo_out;  
assign out = sfp_out;    // out is the normalized result generated by sfp module

mac_array #(.bw(bw), .bw_psum(bw_psum), .col(col), .pr(pr)) mac_array_instance (
        .in(mac_in), 
        .clk(clk), 
        .reset(reset), 
        .inst(inst[7:6]),     
        .fifo_wr(fifo_wr),   //output  
	.out(array_out)
);

ofifo #(.bw(bw_psum), .col(col))  ofifo_inst (
        .reset(reset),
        .clk(clk),
        .in(array_out),
        .wr(fifo_wr),
        .rd(ofifo_rd),
        .o_valid(fifo_valid),
        .out(fifo_out)
);


sram_w16 #(.sram_bit(pr*bw)) qmem_instance (
        .CLK(clk),
        .D(mem_in),
        .Q(qmem_out),
        .CEN(!(qmem_rd||qmem_wr)),
        .WEN(!qmem_wr), 
        .A(qkmem_add)
);

sram_w16 #(.sram_bit(pr*bw)) kmem_instance (
        .CLK(clk),
        .D(mem_in),
        .Q(kmem_out),
        .CEN(!(kmem_rd||kmem_wr)),
        .WEN(!kmem_wr), 
        .A(qkmem_add)
);

sram_w16 #(.sram_bit(col*bw_psum)) psum_mem_instance (
        .CLK(clk),
        .D(pmem_in),
        .Q(pmem_out), //no pmem_out in waveform
        .CEN(!(pmem_rd||pmem_wr)),
        .WEN(!pmem_wr), 
        .A(pmem_add)
);

//TODO: acc, div, fifo_ext_rd
sfp_row #(.col(col), .bw(bw), .bw_psum(bw_psum)) sfp_row_instance(
      .clk(clk),
      .acc(ready_to_acc),             //when to accumulate: pmem read stage pmem_wr=1, CEN==0 && WEN==0
      .div(sfd_sum_in),             //when to divide: after ext rd stage
//       .fifo_ext_rd(fifo_ext_rd),     //input, inform current core when to output to another core: after accumulate stage
//       .ready_to_div(ready_to_div), //output, when to ask another core to input its sum
      .sum_in(sum_in),  //24 bits input
      .sum_out(sum_out), //24 bits output
      .sfp_in(sfp_in),  //pmem out
      .sfp_out(sfp_out)); //out



  //////////// For printing purpose ////////////
  always @(posedge clk) begin
      if(pmem_wr)
         $display("Memory write to PSUM mem add %x %x ", pmem_add, pmem_in); 
  end



endmodule
