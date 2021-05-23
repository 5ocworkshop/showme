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

VERSION="0.1"

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
}

header() {
	echo ""
	echo "$1"
	echo ""
}

# Check for pre-requisite packages and install if not present
if [ ! -e /usr/bin/wget ] || [ ! -e /usr/sbin/ethtool ]; then
	echo "WARN: wget and/or ethtool are not installed, installing..."
	echo "		Please provide password when promted"
	sudo apt-get install wget ethtool
fi

TIMESTAMP=$( date )


echo ""
echo "==============================================================================="
echo "showme: PrintNC show command for easily displaying debug info for Discord help."
echo "==============================================================================="
echo ""
echo "Version $VERSION - Launched as: $0 $@"
echo "$TIMESTAMP for host: $( hostname ) by showme ver. 0.1"
echo ""
echo "For a complete list of options, please see $0 help"
echo "==============================================================================="

# If no options specified, display the help
if [[ $# -eq 0 ]]
then
	show_help
fi

# While there are more than zero options, iterate through the responses and execute as appropriate
while [[ $# -gt 0 ]] ;
do
    OPTION="$1";
    shift;              #expose next argument
    case "$OPTION" in
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

	*) echo >&2 "Invalid option: $OPTION "
		show_help
		exit 1
		;;
   esac
done

echo ""
echo "*** END CUT HERE, DO NOT PASTE TEXT BELOW THIS WHEN SHARING **"
echo "If requested, please paste the relevant sections in to the PrintNC discord for help with troubleshooting."
echo ""
echo "PrintNC is a cooperative community, not a business.  Fellow community members are happy to help, but please"
echo "remember the help you received and extend the same offer when you see an opportunity to help the next person."
echo ""

## END OF SECTION TO CUT AND PASTE TO YOUR SYSTEM ##
