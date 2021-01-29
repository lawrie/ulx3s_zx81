`timescale 1ns / 1ps
`default_nettype none

module zx81 (
    input wire         clk_25mhz,
    input wire         usb_fpga_bd_dp,
    input wire         usb_fpga_bd_dn,
    input wire         ear,

    output wire [3:0]  audio_l,
    output wire [3:0]  audio_r,

    output wire        usb_fpga_pu_dp,
    output wire        usb_fpga_pu_dn,
    output wire [7:0]  led,
    input  wire [6:0]  btn,

    output wire        hsync,
    output wire        vsync,
    output wire[3:0]   red,
    output wire[3:0]   green,
    output wire[3:0]   blue,
    output wire[3:0]   gpdi_dp,

    output wire[13:0]  gp,
    output wire[13:0]  gn
  );

  //assign led = ps2_key[7:0];

  assign gn[12] = hsync;
  assign gn[13] = vsync;

  // Set usb to PS/2 mode
  assign usb_fpga_pu_dp = 1;
  assign usb_fpga_pu_dn = 1;

  wire video; // 1-bit video signal (black/white)

  // Trivial conversion for audio
  wire mic,spk;
  assign audio_l = {4{spk}};
  assign audio_r = {4{mic}};
  

  // Power-on RESET (8 clocks)
  reg [7:0] poweron_reset = 8'h00;
  always @(posedge clk_sys) begin
    poweron_reset <= {poweron_reset[6:0],1'b1};
  end

    localparam pixel_clock = 12500000; // 12.5 MHz slower than original, screen stable
  //localparam pixel_clock = 13000000; // 13 MHz original, screen jitters

  wire clkdvi;
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
  assign clkdvi = clocks[0];
  assign clk_sys = clocks[1];

  wire [10:0] ps2_key;

  // Video timing
  wire vde;
  // The ZX80/ZX81 core
  fpga_zx81 the_core (
    .clk_sys(clk_sys),
    .reset_n(poweron_reset[7] & btn[0]),
    .ear(ear),
    .ps2_key(ps2_key),
    .video(video),
    .hsync(hsync),
    .vsync(vsync),
    .vde(vde),
    .mic(mic),
    .spk(spk),
    .led(led),
    .led1({gp[0], gp[1], gp[2], gp[3], gn[0], gn[1], gn[2], gn[3]}),
    .led2({gp[7], gp[8], gp[9], gp[10], gn[7], gn[8], gn[9], gn[10]})
  );

  assign red = video ? 4'b1111 : 4'b0000;
  assign green = video ? 4'b1111 : 4'b0000;
  assign blue = video ? 4'b1111 : 4'b0000;

  // Get PS/2 keyboard events
  ps2 ps2_kbd (
     .clk(clk_sys),
     .ps2_clk(usb_fpga_bd_dp),
     .ps2_data(usb_fpga_bd_dn),
     .ps2_key(ps2_key)
  );

  // Convert VGA to DVI
  HDMI_out vga2dvid (
    .pixclk(clk_25mhz),
    .pixclk_x5(clkdvi),
    .red({8{video[0]}}),
    .green({8{video[0]}}),
    .blue({8{video[0]}}),
    .hSync(hsync),
    .vSync(vsync),
    .vde(vde),
    .gpdi_dp(gpdi_dp)
  );

endmodule
