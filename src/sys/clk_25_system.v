  // diamond 3.7 accepts this PLL
  // diamond 3.8-3.9 is untested
  // diamond 3.10 or higher is likely to abort with error about unable to use feedback signal
  // cause of this could be from wrong CPHASE/FPHASE parameters
  module clk_25_system
  (
    input  clk_in,  // 25 MHz,      0 deg
    output pll_125, // 125 MHz,     0 deg
    output pll_75,  // 78.125 MHz,  0 deg
    output pll_25,  // 25 MHz,      0 deg
    output pll_33,  // 3.25521 MHz, 0 deg
    output locked
  );
  (* FREQUENCY_PIN_CLKI="25" *)
  (* FREQUENCY_PIN_CLKOP="125" *)
  (* FREQUENCY_PIN_CLKOS="78.125" *)
  (* FREQUENCY_PIN_CLKOS2="25" *)
  (* FREQUENCY_PIN_CLKOS3="3.25521" *)
  (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
  EHXPLLL #(
      .PLLRST_ENA("DISABLED"),
      .INTFB_WAKE("DISABLED"),
      .STDBY_ENABLE("DISABLED"),
      .DPHASE_SOURCE("DISABLED"),
      .OUTDIVIDER_MUXA("DIVA"),
      .OUTDIVIDER_MUXB("DIVB"),
      .OUTDIVIDER_MUXC("DIVC"),
      .OUTDIVIDER_MUXD("DIVD"),
      .CLKI_DIV(1),
      .CLKOP_ENABLE("ENABLED"),
      .CLKOP_DIV(5),
      .CLKOP_CPHASE(2),
      .CLKOP_FPHASE(0),
      .CLKOS_ENABLE("ENABLED"),
      .CLKOS_DIV(8),
      .CLKOS_CPHASE(2),
      .CLKOS_FPHASE(0),
      .CLKOS2_ENABLE("ENABLED"),
      .CLKOS2_DIV(25),
      .CLKOS2_CPHASE(2),
      .CLKOS2_FPHASE(0),
      .CLKOS3_ENABLE("ENABLED"),
      .CLKOS3_DIV(192),
      .CLKOS3_CPHASE(2),
      .CLKOS3_FPHASE(0),
      .FEEDBK_PATH("CLKOP"),
      .CLKFB_DIV(5)
    ) pll_i (
      .RST(1'b0),
      .STDBY(1'b0),
      .CLKI(clk_in),
      .CLKOP(pll_125),
      .CLKOS(pll_75),
      .CLKOS2(pll_25),
      .CLKOS3(pll_33),
      .CLKFB(pll_125),
      .CLKINTFB(),
      .PHASESEL0(1'b0),
      .PHASESEL1(1'b0),
      .PHASEDIR(1'b1),
      .PHASESTEP(1'b1),
      .PHASELOADREG(1'b1),
      .PLLWAKESYNC(1'b0),
      .ENCLKOP(1'b0),
      .LOCK(locked)
    );
endmodule
