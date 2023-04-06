# author:509
# lazy & dirty version for emergency run rtl without ordering files
# Not test synthesize because dont need to synthesize in this homework
# inspire by WeiCheng14159

# files you dont need to synthesize
TB_TOP_FILE	=	tb.v
# files you want synthesize
TOP_FILE	=	rails.v
# top module
TOP			=	rails
# simulate parameter(NEED ADD +nc64bit in CAID)
SIM_PARAMETER	=	+access+r +define+FSDB_FILE=\"$(TOP).fsdb\" 
SDF_PARAMETER	=	+define+SDF +define+SDFFILE=\"syn/$(TOP)_syn.sdf\"


.PHONY: all syn clean
default:
	@echo "pre		=> Run RTL simulation" (pre.log)
	@echo "nw		=> Run nWave"
	@echo "syn		=> Run synthesize in interactive mode" (syn.log)
	@echo "gate		=> Run gate-level simulation" (gate.log)
	@echo "clean	=> Clear file after synthesize"

pre:
	irun $(TB_TOP_FILE) $(TOP_FILE) $(SIM_PARAMETER) \
		+notimingcheck \
		-append_log
	mv irun.log pre.log

# please use Ctrl+Z , bg , fg 
# don't add "&" since it's hard to find and kill it in csh if it crash
nw:
	nWave -f *.fsdb -sswr signal.rc +access+r

syn:
ifneq ($(wildcard ./syn),)
	dcnxt_shell -f syn/syn.tcl | tee syn.log;
else
	@echo "syn folder with syn.tcl & tsmc13_neg.v inside require!"
endif

gate:
	irun $(TB_TOP_FILE) syn/$(TOP)_syn.v -v syn/tsmc13_neg.v $(SIM_PARAMETER) $(SDF_PARAMETER) \
		-append_log
	mv irun.log gate.log

clean:
	rm ./*.err ./*.log ./*.fsdb ./*.rc -f

