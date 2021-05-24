#!/bin/bash
# THIS IS THE SECOND LINE OF THE CUT & PASTE, YOU *MUST* INCLUDE THE #!/bin/bash line above
#
# Written for the PrintNC - DIY CNC Enthusiast Community
#
# showme is a command line utility to allow non-technical users to easily collect
# and share information from a variety of Linux system locations to make it easier
# for more experienced users to rapidly support new users over discord.
#
# Usage is: showme opt1 opt2 opt3 opt4 etc.
#
# Version: 0.1 - jac, May 22, 2021 - First public release, WIP
# Version: 0.2 - jac, Maye 24, 2021 - Second public release, added INI section support & all options, WIP
#
# TODO:	-Iterate through LinuxCNC directory and promopt to identify machine name if necessary
#	-Provide options to display machine.ini and machine.hal files
#	-Provide options to display a section (joint/axis) of machine.ini and machine.hal files
#	-Proviede last X numbers of key system log files
# 	-Anything else we regularly need
#	-Better error and exit handling
#	-Delinting
#	-Add PrintNC Discord Link and Wiki Linux (DONE)
#	-Add note about community, if you take, make sure to give (DONE)
#	-Add version info to header (DONE)
#	-Add a list of the actively loaded kernel modules (DONE)
#	-Have auto-adjusting 'show all' option
#	-Add color coding to improve section boundry visibility
#	-Add last 25 lines of syslog
#	-Add last 25 lines of .bash_history
#	-Auto self-updater
#		-Check for internet connection
#	-Move to /usr/local/bin
#	-Option to install my favorite packages in one setp
#	-Tab for command line completion?
#	-Use the 'fc -l -#` command for an option to display the last 20 commands typed

VERSION="0.21"

# Arrays / Configuration

# These are the local options that users can call this script with and a brief desc of each
declare -A LOCALOPTIONS=( \
[cpu]="The make and model of the CPU" \
[cpufull]="The full contents of /proc/cpuinfo" \
[kernel]="The kernel version" \
[modules]="Active kernel modules" \
[grub]="Grub configuration from /etc/default/grub" \
[bootoptions]="Parameters the kernel was last booted with" \
[interrupts]="System interuprt counters" \
[ip]="IP address configuration for all interfaces" \
[network]="Detailed networking configuration" \
[versions]="OS & LinuxCNC Version info" \
[package-versions]="Versions for all installed packages" \
[pstree]="The current process tree" \
[disk]="Disk space information (human readable)" \
[mem]="Available RAM Memory" \
[dmesg]="Kernel messages with human readable timestamps" \
[packets]="Network interface statistics/counters" \
[pci]="Summary of PCI/PCIe bus components" \
[pcifull]="Verbose list of PCI/PCIe bus components" \
[usb]="Summary of USB device info" \
[usbfull]="Verbose USB device info" \
[wiki]="Links to the PrintNC Wiki & Discord servers" \
[ini]="Displays (section) from your machinename.ini LinuxCNC config file" \
)

# These are defined sections of the LinuxCNC machine.ini master file that can be referenced
declare -A LCNC_MAIN_INI_OPTIONS=( \
# Why not genrate this from lines that start with [ ? - Maybe for the hal file, deferred
[x-axis]="X Axis & Joint 0" \
[y-axis]="Y Axis & Joints 1 & 2" \
[z-axis]="Z Axis & Joint 3" \
[all]="Full INI file" \
[SECTION-HEADING]="Where SECTION-HEADING is any valid (case sensitive) SECTION-heading present in the INI the LinuxCNC file" \
)

# Functions

show_help() {
		header "USAGE:"
		echo "$0 opt1 [opt2] [opt3]"
		echo "Where options are one or more of the following:"
		echo ""
		echo "Options (OS/System):"
		echo "		cpu | cpuinfo | processor	Displays the make and model of the CPU"
		echo "		cpufull | cpuall 		Displays the full /proc/cpuinfo"
		echo "		kernel | kernel-version		Displays the kernel version"
		echo "		modules				Displays the active kernel modules"
		echo "		grub				Displays grub configuration"
		echo "		cmdline | bootoptions		Displays the parameters the kernel was booted with"
		echo "		interrupts | irq | irqs		Display system interupt counters"
		echo "		ip				Displays IP adddress configuration"
		echo "		network | networking		Displays networking configuration"
		echo "		versions			Displays OS and LinuxCNC versions"
		echo "		package-versions 		Displays versions for all installed packages"
		echo "		processes | pstree		Displays the current process tree"
		echo "		disks | disk | df		Displays human readable disk space info"
		echo "		mem | memory | ram | free	Displays human readable RAM info"
		echo "		dmesg				Displays human time-stamped kernel messages"
		echo "		packets | ethstats		Displays network interface statistics/counters"
		echo "		pci | pcie			Displays summary of PCI/PCIe bus components"
		echo "		pcifull | pciefull		Displays verbose output of PCI/PCIe bus components"
		echo "		usb				Displays summary USB device information"
		echo "		usbfull				Displays verbose USB device information"
		echo "		wiki | discord			Displays the links to the PrintNC Wiki & Discord Servers"
		echo "		ini [section]			Diaplays [section] from your machinename.ini file"
}

header() {
	echo ""
	echo "$1"
	echo ""
}

# Get the section of an INI file between two strings
# Usage: get_ini_section string1 string2 filename.ini
# Check for correct # of arguments ariving or check in INI case section

get_ini_section() {
	sed -nr "/^\[$1\]/ { :l /^\s*[^#].*/ p; n; /^\[/ q; b l; }" $LCNC_CONFIG_DIR/"$2"/"$2".ini
}

# Check for pre-requisite packages and install if not present
if [ ! -e /usr/bin/wget ] || [ ! -e /usr/sbin/ethtool ]; then
	echo "WARN: wget and/or ethtool are not installed, installing..."
	echo "		Please provide password when promted"
	sudo apt-get install wget ethtool
fi

if [ "$1" == "options" ]; then
	echo "${!LOCALOPTIONS[@]}"
	exit 0
fi


if [ "$1" == "options-ini" ]; then
	echo "${!LCNC_MAIN_INI_OPTIONS[@]}"
	exit 0
fi

# Variables

TIMESTAMP=$( date )
LCNC_CONFIG_DIR="$HOME/linuxcnc/configs"
MACHINE_COUNT=$( ls -F $LCNC_CONFIG_DIR | grep / | wc -l )
INI_FLAG=0

if [ $MACHINE_COUNT == "1" ]; then
	MACHINE_NAME="$( ls -F $LCNC_CONFIG_DIR | grep / | sed 's/\///' )"
else
	echo "You have more than one machine, that is not yet supported by $0"
fi
echo ""
echo "PrintNC Support Tool - showme - Version $VERSION - Launched as: $0 $@"
echo "For a complete list of options, please see $0 help"
echo ""
echo "*** START CUT HERE ***"
echo "$TIMESTAMP for host: $( hostname )"

# If no options specified, display the help
if [[ $# -eq 0 ]]
then
	show_help
fi

#set -x
# While there are more than zero options, iterate through the responses and execute as appropriate
while [[ $# -gt 0 ]] ;
do
#    if [ "$1" == "ini" ]; then
    	OPTION1="$1"
	OPTION2="$2"
#	else
#    	OPTION="$1";
#	fi

    shift;              #expose next argument
    case "$OPTION1" in

	"ini")
		if [ ! -z "OPTION2" ]; then
		# Set this up for Y, X, Z and otherwise what is specific as an argument
		INI_SECTION="$OPTION2"
		case "$INI_SECTION" in
			"x-axis")
				INI_SECTION="AXIS_X"
				INI_JOINT="JOINT_0"
				;;

			"y-axis")
				INI_SECTION="AXIS_Y"
				INI_JOINT="JOINT_1 JOINT_2"
				;;

			"z-axis")
				INI_SECTION="AXIS_Z"
				INI_JOINT="JOINT_3"
				;;

			"all" | "All" | "ALL")
				cat $LCNC_CONFIG_DIR/$MACHINE_NAME/$MACHINE_NAME.ini
				;;
			*)
				echo "Option2 is $INI_SECTION"
				INI_JOINT=""
			;;

		esac
		# Need error checking for results being null
		header "$LCNC_CONFIG_DIR/$MACHINE_NAME.ini"
		get_ini_section "$INI_SECTION" "$MACHINE_NAME"

		for JOINT in $( echo $INI_JOINT ); do
			echo ""
			get_ini_section "$JOINT" "$MACHINE_NAME"
		done
		fi
		INI_FLAG=1
		;;

        "cpu" | "cpuinfo" | "processor")
		header "CPU MAKE & MODEL:"
                 grep -E 'model name' < /proc/cpuinfo
		;;

	"cpuall" | "cpufull")
		header "CPU FULL DETAILS:"
 		 cat /proc/cpuinfo
		;;

        "kernel" | "kernel-version")
		header "KERNEL VERSION:"
		 uname -a
		;;

        "modules" | "lsmod")
		header "KERNEL MODULES:"
		 lsmod
		;;

	"interrupts" | "irq" | "irqs")
		header "IRQ INTERUPTS:"
		cat /proc/interrupts
		;;


	"ip")
		header "IP ADDRESSES (provide passwd if prompted):"
		ip address
		;;

	"network" | "networking")
		header "ACTIVE NETWORKING CONFIGURATION (provide passwd if prompted):"
		ip address
		header "ROUTING INFORMATION:"
		ip route
		header "CONTENT OF /etc/network/interfaces:"
		echo "---"
		grep -vi wpa-psk < /etc/network/interfaces
		echo "## NOTE: Line containing WiFi password has been suppressed for security."
		echo "---"
		;;

	"cmdline" | "bootoptions")
		header "KERNEL BOOT TIME PARAMETERS AND OPTIONS (LIVE NOW):"
		cat /proc/cmdline
		;;

	"grub")
		header "GRUB CONFIGURATION:"
		echo "---"
		cat /etc/default/grub
		echo "---"
		;;

	"versions" | "os-version" | "os" | "linuxcnc-version" | "linuxcnc-versions" | "linuxcncversion")
		header "OS VERSION:"
		cat /etc/issue
		header "LINUXCNC PACKAGE VERSIONS:"
		apt list --installed | grep linuxcnc
		;;

	"package-versions" | "packageversions")
		header "ALL INSTALLED PACKAGE VERSIONS:"
		apt list --installed
		;;

	"processes" | "pstree")
		header "PROCESS TREE:"
		pstree -a
		;;

	"disk" | "disks" | "df")
		header "DISK USAGE:"
		df -h
		;;

	"mem" | "memory" | "ram" | "free")
		header "AVAILABLE MEMORY:"
		free -m
		;;

	"dmesg")
		header "KERNEL DMESG:"
		echo "Enter password when prompted."
		sudo dmesg -T
		;;

	"packets" | "ethstats")
		header "NETWORK INTERFACE PACKET STATS (IF AVAILABLE):"
		echo "Enter password when prompted."
		for IF in $( ls /sys/class/net); do
			header "INTERFACE: $IF"
			sudo ethtool -S "$IF"
		done
		;;

	"pci" | "pcie")
		header "PCI/PCIe BUS DEVICES (SUMMARY):"
		lspci
		;;

	"pcifull" | "pciefull")
		header "PCI/PCIe BUS DEVICES (VERBOSE):"
		lspci -vv
		;;

	"usb")
		header "USB BUS DEVICES (SUMMARY):"
		lsusb
		;;

	"usbfull")
		header "USB BUS DEVICES (SUMMARY):"
		lsusb -v
		;;

	"help" | "-h" | "--help")
		show_help
		;;

	"wiki" | "discord")
		header "PrintNC Wiki & Discord: https://wiki.printnc.info & https://discord.gg/RxzPna6"
		;; 

	*)
		if [ "$INI_FLAG" != "1" ]; then
			 echo >&2 "Invalid option: $OPTION "
			show_help
			exit 1
		fi
		;;
   esac
done
echo ""
echo "*** END CUT HERE ***"
echo "PrintNC is a co-op community, please document your problem & solution on wiki."
echo ""
## END OF SECTION TO CUT AND PASTE TO YOUR SYSTEM ##
