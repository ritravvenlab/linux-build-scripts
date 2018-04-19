#===============================================================================
# Custom fsbl compilation file                                          =
#===============================================================================
# Copyright (c) 2018 RIT RAVVENLAB. www.ritravvenlab.com                       =
# SPDX-License-Identifier: GPL-2.0-only [https://spdx.org/licenses/]           =                                                                                        
#===============================================================================

# Note: you will need to change this file drastically to match you design.  
# Things to change include your Vivado project directory, .hdf name, 
# final directory, etc..

cd /media/sf_ravvenShare/baseline/project/baseline.sdk
set hwdsgn [open_hw_design design_1_wrapper.hdf]
generate_app -hw $hwdsgn -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -sw fsbl -dir /ravvenlab/fsbl
exit