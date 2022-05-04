PIN_DEF ?= ../../ulx4m_v002.lpf

DEVICE ?= um-45k

BUILDDIR = bin

TOP ?= top

compile: $(BUILDDIR)/toplevel.bit

prog: $(BUILDDIR)/toplevel.bit
	fujprog $^

dfu: $(BUILDDIR)/toplevel.bit
	dfu-util -a 0 -D  $^ -R

$(BUILDDIR)/toplevel.json: $(VERILOG)
	mkdir -p $(BUILDDIR)
	yosys \
	-p "read -sv $^" \
	-p "hierarchy -top ${TOP}" \
	-p "synth_ecp5 -json $@" \

$(BUILDDIR)/%.config: $(PIN_DEF) $(BUILDDIR)/toplevel.json
	nextpnr-ecp5 --${DEVICE} --package CABGA381 --timing-allow-fail --freq 25 --textcfg  $@ --json $(filter-out $<,$^) --lpf $<

$(BUILDDIR)/toplevel.bit: $(BUILDDIR)/toplevel.config
	ecppack --compress $^ $@

clean:
	rm -rf ${BUILDDIR}

.SECONDARY:
.PHONY: compile clean prog
