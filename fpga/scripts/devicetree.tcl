
set instrument_name [lindex $argv 0]

set proc_name [lindex $argv 1]

set repo_path [lindex $argv 2]

set vivado_version [lindex $argv 3]

set boot_args {console=ttyPS0,115200 root=/dev/mmcblk0p2 ro rootfstype=ext4 earlyprintk rootwait}

set hard_path tmp/$instrument_name.hard
set tree_path tmp/$instrument_name.tree

file mkdir $hard_path
file copy -force tmp/$instrument_name.hwdef $hard_path/$instrument_name.hdf

set_repo_path $repo_path

open_hw_design $hard_path/$instrument_name.hdf
create_sw_design -proc $proc_name -os device_tree devicetree

set_property CONFIG.kernel_version $vivado_version [get_os]
set_property CONFIG.bootargs $boot_args [get_os]

generate_bsp -dir $tree_path

close_sw_design [current_sw_design]
close_hw_design [current_hw_design]
