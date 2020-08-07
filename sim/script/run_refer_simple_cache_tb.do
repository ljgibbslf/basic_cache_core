#////////////////////////////////////////////////////////////////////////////////
# Author:        ljgibbs / lf_gibbs@163.com
# Create Date: 2020/08/07 
# Design Name: basic_cache_core
# Module Name: run_refer_simple_cache_tb
# Description:
#      运行 简单 cache 的 Modelsim 脚本，使用书中的参考代码与 tb
#          - 使用相对路径
#          - 使用库 simple_cache_core
# Revision:
# Revision 0.01 - File Created
#////////////////////////////////////////////////////////////////////////////////

vlib simple_cache_core

# vlog -64 -incr -work simple_cache_core  "+incdir+../../rtl/inc" \
# "../../rtl/*.v" \
# "../../rtl/util/*.v" \

vlog -64 -incr -sv -work simple_cache_core  \
"../../refer/rtl/*.sv" \
"../../refer/tb/*.sv" \

vsim -voptargs="+acc" -t 1ps   -L unisims_ver -L unimacro_ver -L secureip -lib simple_cache_core simple_cache_core.tb_simple_cache;

add wave *

view wave
view structure
view signals
log -r /*

restart -f;run 2us
