# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\Xilinx\VivadoProjects\ece385-final-project\paperSynthesis\workspace\paper_synth_top\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\Xilinx\VivadoProjects\ece385-final-project\paperSynthesis\workspace\paper_synth_top\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {paper_synth_top}\
-hw {C:\Xilinx\VivadoProjects\ece385-final-project\paperSynthesis\paper_synth_top.xsa}\
-out {C:/Xilinx/VivadoProjects/ece385-final-project/paperSynthesis/workspace}

platform write
domain create -name {standalone_microblaze_0} -display-name {standalone_microblaze_0} -os {standalone} -proc {microblaze_0} -runtime {cpp} -arch {32-bit} -support-app {hello_world}
platform generate -domains 
platform active {paper_synth_top}
platform generate -quick
platform clean
platform generate
platform generate
platform clean
platform clean
platform active {paper_synth_top}
platform active {paper_synth_top}
platform config -updatehw {C:/Xilinx/VivadoProjects/ece385-final-project/paperSynthesis/paper_synth_top.xsa}
platform clean
platform generate
platform active {paper_synth_top}
platform config -updatehw {C:/Xilinx/VivadoProjects/ece385-final-project/paperSynthesis/paper_synth_top.xsa}
platform clean
platform generate
platform active {paper_synth_top}
platform config -updatehw {C:/Xilinx/VivadoProjects/ece385-final-project/paperSynthesis/paper_synth_top.xsa}
platform clean
platform generate
platform config -updatehw {C:/Xilinx/VivadoProjects/ece385-final-project/paperSynthesis/paper_synth_top.xsa}
platform clean
platform generate
platform config -updatehw {C:/Xilinx/VivadoProjects/ece385-final-project/paperSynthesis/paper_synth_top.xsa}
platform clean
platform generate
