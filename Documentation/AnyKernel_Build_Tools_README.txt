Automated bash script build tools

To build:
Modify build-config and update the following

TOOLCHAINDIR= 

TOOLCHAIN=

VERSION=

N_CORES=

To match your building environment, kernel vanity & number of brunching cpu cores

Create the following directory with "mkdir -p"
~/rez/updates

The scripting will also create an sha1 output of arch/arm/zImage in the root of your full building directory.

See the following links & files for more information:

https://github.com/Snuzzo/AnyKernel_Build_Tools
https://github.com/crpalmer/android-kernel-build-tools
