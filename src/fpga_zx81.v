`timescale 1ns / 1ps
`default_nettype none

module fpga_zx81 (
    input  wire clk_sys,
    input  wire reset,
    input  wire ear,
    input  wire [10:0] ps2_key,
    output wire video,
    output reg  hsync,
    output reg  vsync,
    output wire blank,
    output wire mic,
    output wire spk,
    output wire [7:0] led,
    output wire [7:0] led1,
    output reg [7:0] led2
);

   // Clock generation
   reg       ce_cpu_p;
   reg       ce_cpu_n;
   reg       ce_13, ce_65, ce_psg;
   reg [4:0] counter = 0;

   always @(negedge clk_sys) begin
     counter  <=  counter + 1'd1;
     ce_cpu_p <= !counter[3] & !counter[2:0];
     ce_cpu_n <=  counter[3] & !counter[2:0];
     ce_65    <= !counter[2:0];
     ce_13    <= !counter[1:0];
     ce_psg   <= !counter[4:0];
   end

   // Diagnostics
   assign led = {ce_cpu_p, rom_e, ram_e, ram_we, mreq_n, nopgen_store, nmi_latch};
   //assign led = cpu_din;
   assign led1 = key_data;

   always @(posedge clk_sys) led2 <= shifter_reg;

   // Audio: TODO
   assign mic = 0;
   assign spk = 0;
	
   // Memory control signals
   wire iorq_n, mreq_n, rd_n, wr_n, wait_n, m1_n, int_n, rfsh_n, halt_n, nmi_n;

   // Maskable interrupt
   wire int_n = addr[6];

   // ZX81 Logic
   reg [7:0]   cpu_din;
   wire [7:0]  cpu_dout;
   wire [15:0] addr;

   wire [4:0]  key_data;
   wire [11:1] Fn;
   wire [2:0]  mod;

   wire [7:0]  io_dout = kbd_n ? 8'hff : {3'b0, key_data};

   // When refresh is low, the ram_data_latch and row_counter are used to load
   // pixels corresponding to a character from the map in the rom
   wire [12:0] rom_a  = rfsh_n ? addr[12:0] : { addr[12:9], ram_data_latch[5:0], row_counter };

   // Indicator for zx80 or zx81
   reg         zx81 = 0;

   // Selector for memory size
   reg  [1:0]  mem_size = 2'b00; //00-1k, 01 - 16k 10 - 32k

   // Ram address
   reg  [15:0] ram_a;

   // Selector for 64k ram extension
   wire        ram_e_64k = &mem_size & (addr[13] | (addr[15] & m1_n));

   // Selector for rom
   wire        rom_e  = ~addr[14] & (~addr[12] | zx81) & ~ram_e_64k;

   // Selector for ram
   wire        ram_e  = addr[14] | ram_e_64k;

   // Write enable for ram
   wire        ram_we = ~wr_n & ~mreq_n & ram_e;

   // Selector for ouput data to ram
   wire  [7:0] ram_in = cpu_dout;

   // Selectors for data from ram or rom
   wire  [7:0] rom_out;
   wire  [7:0] ram_out;
   reg   [7:0] mem_out;

   // Address and data decoder
   always @* begin
     case({ rom_e, ram_e })
        'b10: mem_out = rom_out;
        'b01: mem_out = ram_out;
        default: mem_out = 8'd0;
     endcase

     case(mem_size)
        'b00: ram_a = { 6'b010000,             addr[9:0] }; //1k
        'b01: ram_a = { 2'b01,                 addr[13:0] }; //16k
        'b10: ram_a = { 1'b0, addr[15] & m1_n, addr[13:0] } + 16'h4000; //32k
        'b11: ram_a = { addr[15] & m1_n,       addr[14:0] }; //64k
	default: ram_a = 8'd0;
     endcase
     
     case({mreq_n, ~m1_n | iorq_n | rd_n})
       'b01: cpu_din = (~m1_n & nopgen) ? 8'h00 : mem_out;
       'b10: cpu_din = io_dout;
       default cpu_din = 8'hFF;
     endcase
   end

   // Video 
   // Generate a NOP when executing a display list
   wire      nopgen = addr[15] & ~ram_out[6] & halt_n;
   
   wire      data_latch_enable = rfsh_n & ce_cpu_n & ~mreq_n;
   reg [7:0] ram_data_latch;
   reg       nopgen_store;
   reg [2:0] row_counter;
   reg       nmi_latch;
   reg       shifter_en;
   wire      shifter_start = mreq_n & nopgen_store & ce_cpu_p & (~zx81 | ~nmi_latch);
   reg [7:0] shifter_reg;
   reg       inverse;
   wire      video_out = (shifter_reg[7] ^ inverse) & !back_porch_counter & csync;

   reg[4:0]  back_porch_counter = 1;
   reg       old_csync;
   reg       old_shifter_start;

   wire kbd_n = iorq_n | rd_n | addr[0];

   always @(posedge clk_sys) begin
     old_csync <= csync;
     old_shifter_start <= shifter_start;

     if (data_latch_enable) begin
       ram_data_latch <= mem_out;
       nopgen_store <= nopgen;
     end

     if (mreq_n & ce_cpu_p) inverse <= 0;

     if (~old_shifter_start & shifter_start) begin
       shifter_reg <= (~m1_n & nopgen) ? 8'h0 : mem_out;
       inverse <= ram_data_latch[7];
     end else if (ce_65) begin
       shifter_reg <= { shifter_reg[6:0], 1'b0 };
     end

     if (old_csync & ~csync) row_counter <= row_counter + 1'd1;
     if (~vsync_in) row_counter <= 0;

     if (~old_csync & csync) back_porch_counter <= 1;
     if (ce_65 && back_porch_counter) back_porch_counter <= back_porch_counter + 1'd1;

   end
	
   // ZX80 sync generator
   reg ic11,ic18,ic19_1,ic19_2;
   wire csync = ic11 & hsync_in; 
   wire vsync_in = ic11; 
   //wire csync = ic19_2; // ZX80 original
   reg old_m1_n;

   always @(posedge clk_sys) begin
     old_m1_n <= m1_n;
     
     if (~(iorq_n | wr_n) & (~zx81 | ~nmi_latch)) ic11 <= 1;
     if (~kbd_n & (~zx81 | ~nmi_latch)) ic11 <= 0;

     if (~iorq_n) ic18 <= 1;
     if (~ic19_2) ic18 <= 0;

     if (old_m1_n & ~m1_n) begin
       ic19_1 <= ~ic18;
       ic19_2 <= ic19_1;
     end

     if (~ic11) ic19_2 <= 0;
   end

   // ZX81 upgrade
   reg old_cpu_n;
   reg [7:0] sync_counter = 0;
   wire hsync_in = ~(sync_counter >= 16 && sync_counter <= 31);

   assign wait_n = ~(halt_n & ~nmi_n) | ~zx81;
   assign nmi_n = ~(nmi_latch & ~hsync_in) | ~zx81;
   
   always @(posedge clk_sys) begin
     old_cpu_n <= ce_cpu_n;

     if (old_cpu_n & ~ce_cpu_n) begin
       sync_counter <= sync_counter + 1'd1;
       if (sync_counter == 8'd206 | (~m1_n & ~iorq_n)) sync_counter <= 0;
     end

     if (zx81) begin
       if (~iorq_n & ~wr_n & (addr[0] ^ addr[1])) nmi_latch <= addr[1];
     end
   end

   /* RAM */
   ram1k ram(
     .clk(clk_sys),
     .ce(ram_e),
     .a(ram_a),
     .din(cpu_dout),
     .dout(ram_out),
     .we(~wr_n)
   );
		
   /* ROM */
   rom the_rom(
     .clk(clk_sys),
     .ce(rom_e),
     .a({(zx81 ? rom_a[12] : 2'h2), rom_a[11:0]}),
     .din(cpu_dout),
     .dout(rom_out),
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
    .A(addr), 
    .do(cpu_dout),
    // Inputs
    .di(cpu_din), 
    .reset_n(reset), 
    .clk(ce_cpu_p), 
    .wait_n(wait_n), 
    .int_n(int_n), 
    .nmi_n(nmi_n), 
    .busrq_n(1'b1)
   );

   // Keyboard matrix
   keyboard the_keyboard (
     .reset(reset),
     .clk_sys(clk_sys),
     .ps2_key(ps2_key),
     .addr(addr),
     .key_data(key_data),
     .Fn(Fn),
     .mod(mod)
   );

   scandoubler scandoubler (
     .clk(clk_sys),
     .ce_2pix(ce_13),
     .scanlines(0),
     .csync(csync),
     .v_in(video_out),
     .hs_out(hsync),
     .vs_out(vsync),
     .v_out(video)
);  
endmodule

