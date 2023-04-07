# author:509
# lazy & dirty version for emergency run rtl without ordering files
# inspire by WeiCheng14159

# files you dont need to synthesize
TB_TOP_FILE	=	testfixture.sv
# files you want synthesize
TOP_FILE	=	AEC.v
# top module
TOP			=	AEC
# string when you pass
PASS_STR	=	"Your score is 100"

#constrain
SDC			=	$(TOP).sdc
#irun common parameter
SIM_PARA	=	+access+r +define+FSDB_FILE=\"$(TOP).fsdb\"

all $(TOP): pre syn gate
.PHONY: all pre syn gate nw clean
default:
	@echo "pre		=> Run RTL simulation"
	@echo "nw		=> Run nWave"
	@echo "syn		=> Run synthesize in interactive mode"
	@echo "gate		=> Run gate-level simulation"
	@echo "clean	=> Clear file after synthesize"

pre:
	irun $(TB_TOP_FILE) $(TOP_FILE) $(SIM_PARA) -append_log
	mv irun.log pre.log
	grep -e $(PASS_STR) pre.log

# please use Ctrl+Z , bg , fg instead add & behind command
nw:
	nWave -f *.fsdb -sswr signal.rc +access+r

syn syn/$(TOP)_syn.v:
ifneq ($(wildcard ./syn),)
	dc_shell -f syn/syn.tcl -output_log_file syn.log -x \
	"	set top $(TOP); \
		set src_file $(TOP_FILE); \
		set sdc_file $(SDC); \
	";
else
	@echo "syn folder with syn.tcl & tsmc13_neg.v inside require!"
endif

gate: syn/$(TOP)_syn.v
	irun $(TB_TOP_FILE) syn/$(TOP)_syn.v $(SIM_PARA) \
		-v syn/tsmc13_neg.v \
		+define+SDF \
		+define+SDFFILE=\"syn/$(TOP)_syn.sdf\" \
		-append_log
	mv irun.log gate.log

clean:
	rm ./*.err ./*.log syn/$(TOP)_syn* *.fsdb irun.history -f

