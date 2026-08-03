#######################################################################
# Reproduce and locate Vivado hw_ila_data_* artifact creation.
#
# Usage examples:
#   vivado.bat -mode batch -source AI-work/scripts/repro_ila_artifact_location.tcl -tclargs refresh_only no_cd
#   vivado.bat -mode batch -source AI-work/scripts/repro_ila_artifact_location.tcl -tclargs upload_all no_cd
#   vivado.bat -mode batch -source AI-work/scripts/repro_ila_artifact_location.tcl -tclargs refresh_only cd_controlled <work_dir>
#
# Arguments:
#   action : refresh_only | upload_first | upload_all | upload_ila19_props
#   cdmode : no_cd | cd_controlled
#   work_dir: optional target directory for cd_controlled
#######################################################################

proc norm_dir {path} {
    return [file normalize $path]
}

proc list_hw_dirs {dir} {
    if {![file exists $dir]} {
        return {}
    }
    return [lsort [glob -nocomplain -type d [file join $dir "hw_ila_data_*"]]]
}

proc print_delta {label before after} {
    puts "${label}_BEFORE_COUNT=[llength $before]"
    puts "${label}_AFTER_COUNT=[llength $after]"
    foreach d $after {
        if {[lsearch -exact $before $d] < 0} {
            puts "${label}_NEW=$d"
        }
    }
}

set action [lindex $argv 0]
if {$action eq ""} {
    set action "refresh_only"
}

set cdmode [lindex $argv 1]
if {$cdmode eq ""} {
    set cdmode "no_cd"
}

set script_dir [file dirname [norm_dir [info script]]]
set proj_root  [norm_dir [file join $script_dir ".." ".."]]
set ltx_file   [file join $proj_root "AXI_DDR.runs" "impl_1" "ETH_TOP.ltx"]
set appdata_dir "C:/Users/Administrator/AppData/Roaming/Xilinx/Vivado"

set default_work_dir [file join $proj_root "AI-work" "features" "DL5_laser_sync" "DL5_UNIT_005" "out" "hw_debug" "ila_artifact_repro" "controlled_work"]
set work_dir [lindex $argv 2]
if {$work_dir eq ""} {
    set work_dir $default_work_dir
}
set work_dir [norm_dir $work_dir]

set initial_pwd [pwd]
puts "REPRO_ACTION=$action"
puts "REPRO_CDMODE=$cdmode"
puts "PROJECT_ROOT=$proj_root"
puts "LTX_FILE=$ltx_file"
puts "PWD_INITIAL=$initial_pwd"
puts "WORK_DIR=$work_dir"

set before_d       [list_hw_dirs "D:/"]
set before_appdata [list_hw_dirs $appdata_dir]
set before_pwd     [list_hw_dirs $initial_pwd]
set before_work    [list_hw_dirs $work_dir]

if {$cdmode eq "cd_controlled"} {
    file mkdir $work_dir
    cd $work_dir
} elseif {$cdmode ne "no_cd"} {
    error "Unknown cdmode '$cdmode'"
}

puts "PWD_ACTIVE=[pwd]"

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set dev [lindex [get_hw_devices xc7k325t_0] 0]
if {$dev eq ""} {
    set dev [lindex [get_hw_devices] 0]
}
if {$dev eq ""} {
    error "No hardware device found"
}

current_hw_device $dev
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $dev
    catch {set_property FULL_PROBES.FILE $ltx_file $dev}
}

refresh_hw_device -quiet -update_hw_probes true $dev
set ilas [get_hw_ilas -quiet]
puts "ILA_COUNT=[llength $ilas]"
puts "ILA_LIST=$ilas"

if {$action eq "upload_first"} {
    set ila [lindex $ilas 0]
    if {$ila ne ""} {
        puts "UPLOAD_FIRST_ILA=$ila"
        if {[catch {set data [upload_hw_ila_data $ila]} err]} {
            puts "UPLOAD_FIRST_ERROR=$err"
        } else {
            puts "UPLOAD_FIRST_DATA=$data"
        }
    }
} elseif {$action eq "upload_all"} {
    foreach ila $ilas {
        puts "UPLOAD_ILA=$ila"
        if {[catch {set data [upload_hw_ila_data $ila]} err]} {
            puts "UPLOAD_ERROR_$ila=$err"
        } else {
            puts "UPLOAD_DATA_$ila=$data"
        }
    }
} elseif {$action eq "upload_ila19_props"} {
    set ila [lindex [get_hw_ilas hw_ila_19 -quiet] 0]
    if {$ila eq ""} {
        error "hw_ila_19 not found"
    }
    puts "UPLOAD_PROPS_ILA=$ila"
    if {[catch {set data [upload_hw_ila_data $ila]} err]} {
        puts "UPLOAD_PROPS_ERROR=$err"
    } else {
        puts "UPLOAD_PROPS_DATA=$data"
        foreach p [lsort [list_property $data]] {
            if {[catch {set v [get_property $p $data]}]} {
                set v "<ERR>"
            }
            puts "DATA_PROP $p=$v"
        }
    }
} elseif {$action ne "refresh_only"} {
    error "Unknown action '$action'"
}

close_hw_manager

set after_d       [list_hw_dirs "D:/"]
set after_appdata [list_hw_dirs $appdata_dir]
set after_pwd     [list_hw_dirs $initial_pwd]
set after_work    [list_hw_dirs $work_dir]

print_delta "D_ROOT" $before_d $after_d
print_delta "APPDATA" $before_appdata $after_appdata
print_delta "INITIAL_PWD" $before_pwd $after_pwd
print_delta "WORK_DIR" $before_work $after_work
