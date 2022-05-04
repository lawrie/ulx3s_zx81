`timescale 1ns / 1ps
`default_nettype none

module zx81 #(
    parameter c_usb          = 1,  // Use USB connector to PS/2
  ) (
    input wire         clk_25mhz,
    input wire         usb_fpga_bd_dp,
    input wire         usb_fpga_bd_dn,
    inout [27:0]       gpio,
    output wire        usb_fpga_pu_dp,
    output wire        usb_fpga_pu_dn,
    output wire [3:0]  led,
    output wire[3:0]   gpdi_dp
  );

  wire ear;
  wire mic,spk;

  assign gpio[18] = spk;
  assign gpio[19] = mic;

  wire        hsync;
  wire        vsync;

  wire video; // 1-bit video signal (black/white)

  // Set usb to PS/2 mode
  assign usb_fpga_pu_dp = 1;
  assign usb_fpga_pu_dn = 1;

  // Power-on RESET (8 clocks)
  reg [7:0] poweron_reset = 8'h00;
  always @(posedge clk_sys) begin
    poweron_reset <= {poweron_reset[6:0],1'b1};
  end

    localparam pixel_clock = 12500000; // 12.5 MHz slower than original, screen stable
  //localparam pixel_clock = 13000000; // 13 MHz original, screen jitters

  wire clk_dvi;
  wire clk_sys;
  wire [3:0] clocks;
  ecp5pll
  #(
   .in_hz  ( 25*1000000),
   .out0_hz(pixel_clock*10),
   .out1_hz(pixel_clock)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks)
  );
  assign clk_dvi = clocks[0];
  assign clk_sys = clocks[1];

  wire [10:0] ps2_key;

  // Video timing
  wire vde;
  // The ZX80/ZX81 core
  fpga_zx81 the_core (
    .clk_sys(clk_sys),
    .reset_n(poweron_reset[7]),
    .ear(ear),
    .ps2_key(ps2_key),
    .video(video),
    .hsync(hsync),
    .vsync(vsync),
    .vde(vde),
    .mic(mic),
    .spk(spk),
    .zx81(1'b1),
    .led(led)
  );

  // Get PS/2 keyboard events
  ps2 ps2_kbd (
     .clk(clk_sys),
     .ps2_clk(c_usb ? usb_fpga_bd_dp : gpio[3]),
     .ps2_data(c_usb ? usb_fpga_bd_dn : gpio[26]),
     .ps2_key(ps2_key)
  );

  // Convert VGA to DVI
  HDMI_out vga2dvid (
    .pixclk(clk_25mhz),
    .pixclk_x5(clk_dvi),
    .red({8{video}}),
    .green({8{video}}),
    .blue({8{video}}),
    .hSync(hsync),
    .vSync(vsync),
    .vde(vde),
    .gpdi_dp(gpdi_dp)
  );

endmodule
