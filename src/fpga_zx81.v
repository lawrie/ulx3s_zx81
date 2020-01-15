`timescale 1ns / 1ps
`default_nettype none

module fpga_zx81 (
    input  wire clkram,
    input  wire clk65,
    input  wire clkcpu,
    input  wire reset,
    input  wire ear,
    input  wire [10:0] ps2_key,
    output wire video,
    output wire hsync,
    output wire vsync,
    output wire blank,
    output wire mic,
    output wire spk
);
	
   // Z80 buses
   wire [7:0]  DinZ80;
   wire [7:0]  DoutZ80;
   wire [15:0] AZ80;
	
   // Memory control signals
   wire iorq_n, mreq_n, int_n, rd_n, wr_n, wait_n, m1_n, int_n, rfsh_n, halt_n, nmi_n = 1;
   wire rom_enable, uram_enable, data_from_jace_oe;
   wire [7:0] dout_rom, dout_uram, data_from_jace;
    
   // Address multiplexer
   assign DinZ80 = rom_enable        ? dout_rom :
                   uram_enable       ? dout_uram :
                                      data_from_jace;

   // ZX81 Logic
   wire      nopgen = AZ80[15] & ~dout_uram[6] & halt_n;
   wire      data_latch_enable = rfsh_n & clkcpu & ~mreq_n;
   reg [7:0] ram_data_latch;
   reg       nopgen_store;
   reg [2:0] row_counter;
   reg       nmi_latch;
   reg       shifter_en;
   wire      shifter_start = mreq_n & nopgen_store & clkcpu & shifter_en & ~nmi_latch;
   reg [7:0] shifter_reg;
   reg       inverse;
   wire      video_out = (shifter_reg[7] ^ inverse);

   reg [7:0] cpu_din;

   always @* begin
	case({mreq_n, ~m1_n | iorq_n | rd_n})
	    'b01: cpu_din = (~m1_n & nopgen) ? 8'h00 : dout_uram;
	    'b10: cpu_din = data_from_jace;
	endcase
   end

   // Address decoder
   always @* begin
       rom_enable = 1'b0;
       uram_enable = 1'b0;
       if (mreq_n == 1'b0) begin
           if (AZ80 >= 16'h0000 && AZ80 <= 16'h1FFF)
               rom_enable = 1'b1;
           else if (AZ80 >= 16'h3000 && AZ80 <= 16'h3FFF)
               uram_enable = 1'b1;
       end
   end

   /* RAM */
   ram1k uram(
     .clk(clk65),
     .ce(uram_enable),
     .a(AZ80[9:0]),
     .din(DoutZ80),
     .dout(dout_uram),
     .we(~wr_n)
   );
		
   /* ROM */
   rom the_rom(
     .clk(clk65),
     .ce(rom_enable),
     .a(AZ80[12:0]),
     .din(DoutZ80),
     .dout(dout_rom),
     .we(~wr_n) //  & enable_write_to_rom)
   );
    
   /* CPU */
   tv80n cpu(
     // Outputs
    .m1_n(m1_n), 
    .mreq_n(mreq_n), 
    .iorq_n(iorq_n), 
    .rd_n(rd_n), 
    .wr_n(wr_n), 
    .rfsh_n(rfsh_n), 
    .halt_n(halt_n), 
    .busak_n(), 
    .A(AZ80), 
    .do(DoutZ80),
    // Inputs
    .di(DinZ80), 
    .reset_n(reset), 
    .clk(clkcpu), 
    .wait_n(wait_n), 
    .int_n(int_n), 
    .nmi_n(nmi_n), 
    .busrq_n(1'b1)
   );

   wire [4:0] key_data;
   wire [11:1] Fn;
   wire [2:0] mod;

   // Keyboard matrix
   keyboard the_keyboard (
     .reset(reset),
     .clk_sys(clkcpu),
     .ps2_key(ps2_key),
     .addr(AZ80),
     .key_data(key_data),
     .Fn(Fn),
     .mod(mod)
   );
  
endmodule

