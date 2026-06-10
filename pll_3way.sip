set_global_assignment -entity "pll_3way" -library "lib_pll_3way" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_3way" -library "lib_pll_3way" -name IP_TOOL_VERSION "21.1"
set_global_assignment -entity "pll_3way" -library "lib_pll_3way" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_3way" -name SPD_FILE [file join $::quartus(sip_path) "pll_3way.spd"]

set_global_assignment -library "lib_pll_3way" -name MISC_FILE [file join $::quartus(sip_path) "pll_3way_sim/pll_3way.vho"]
