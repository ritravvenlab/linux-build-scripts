#===============================================================================
# Custom device tree compilation file                                          =
#===============================================================================
# Copyright (c) 2018 RIT RAVVENLAB. www.ritravvenlab.com                       =
# SPDX-License-Identifier: GPL-2.0-only [https://spdx.org/licenses/]           =                                                                                        
#===============================================================================

# Note: you will need to change this file drastically to match you design.  
# Things to change include your Vivado project directory, .hdf name, device tree
# repo location, final directory, etc..

cd /media/sf_ravvenShare/baseline/project/baseline.sdk
open_hw_design design_1_wrapper.hdf
set_repo_path /ravvenlab/device-tree-xlnx
create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0
generate_target -dir /ravvenlab/device_tree_generated
exit