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
#	-Add PrintNC Discord Link and Wiki Linux (DONE)
#	-Add version info to header (DONE)
#	-Add a list of the actively loaded kernel modules (DONE)
#
# Version: 0.23 - jac, May 24, 2021 - Second public release, added INI section support, WIP
#	-Tab for command line completion? (DONE!)
#		./showme [TAB] will display options for top level
#			AND
#		./showme ini [TAB] will display options for your machine ini file
#
#	-Provide options to display all of machine.ini file (DONE)
#		showme ini all
#	-Provide option to display specific axis (and associated joints) (DONE)
#		showme ini x-axis
#	-Provide options to display any section with named [HEADER] of machine.ini file (DONE)
#		showme ini HEADER # note, case sensitive for example
#		showme ini KINS # will return the KINS section if it exists
#	-Provide last 50 lines of main system log (DONE)
#		showme syslog
#	-Provide last 50 lines of typed commands (DONE)
#		showme history
#	-Changed IP address to only output ipv4 addresses
#	-Add note about community, if you receive, make sure to give too (DONE)
#	-Moved internal version control on to GitHub
#	-Restructured options to in to array for flexibility and extensibility
#	-Reduced size of header and footer, changed presentation of CUT marks
#
# TODO:	-Iterate through LinuxCNC directory and promopt to identify machine name if necessary
#	-Provide option to display  machinehal.hal files
#	-Better error and exit handling
#	-Add color coding to improve section boundry visibility (under consideration)
#	-Auto self-updater
#		-Check for internet connection
#	-Move to /usr/local/bin (use install?)
#	-Option to install recommended packages in one setp

VERSION="0.23"

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
[syslog]="Show last 50 lines of /var/log/syslog" \
[history]="Show last 50 lines of bash shell history" \
)

# These are defined sections of the LinuxCNC machine.ini master file that can be referenced
declare -A LCNC_MAIN_INI_OPTIONS=( \
# Why not generate this from lines that start with [ ? - Maybe for the hal file, deferred
[x-axis]="X Axis & Joint 0" \
[y-axis]="Y Axis & Joints 1 & 2" \
[z-axis]="Z Axis & Joint 3" \
[all]="Full INI file" \
[SECTION-HEADING]="Where SECTION-HEADING is any valid (case sensitive) SECTION-heading present in the INI the LinuxCNC file" \
)

# Functions

enable_completions() {
#set -x
KEY="PNCSHOWME"
BASHRC="/etc/bash.bashrc"
COMPDIR="/usr/share/bash-completion/completions/"
TMPFILE="/tmp/foo"
CHECK_COMP=$( grep "$KEY" "$BASHRC" )

if [ -z "$CHECK_COMP" ] && [ ! -f $BASHRC.back ]; then
	echo "TAB Autocomplete not enabled, enabling."
	# Need a test for internet access here
	sudo apt-get install bash-completion
# The completions file for this script
if [ ! -f $COMPDIR/showme ]; then
{
  # This is known as the 'herefile' trick
  ## EVERYTHING BELOW HERE UNTIL THE EOF IS LITERAL
  cat <<'EOF'
#/usr/bin/env bash
_showme() {
local cur prev

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  if [ $COMP_CWORD -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$(showme options)" -- $cur) )
  elif [ $COMP_CWORD -eq 2 ]; then
    case "$prev" in
      "ini")
        COMPREPLY=( $(compgen -W "$(showme options-ini)" -- $cur) )
        ;;
      "deploy")
        COMPREPLY=( $(compgen -W "all current" -- $cur) )
        ;;
      *)
        ;;
    esac
  fi

  return 0
} &&
complete -F _showme showme
EOF
} > $TMPFILE

	# Correct the file permissions before putting it in place
	sudo chown root.root $TMPFILE
	sudo chmod 0644 $TMPFILE
	sudo mv $TMPFILE $COMPDIR/showme
fi

	echo "Copying $BASHRC to $BASHRC.back"
	sudo cp $BASHRC $BASHRC.back
	# enable bash completion in interactive shells
	cat $BASHRC > $TMPFILE
{
# Everything below here until the EOF is LITERAL
cat << 'EOF'
## Added by PrintNC showme script KEY=PNCSHOWME for bash auto completion enable
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
## END PrintNC
EOF
} >> $TMPFILE
	sudo chown root.root $TMPFILE
	sudo chmod 0644 $TMPFILE
	sudo mv $TMPFILE $BASHRC
	echo "Confirming update:"
	grep "$KEY" "$BASHRC"
	echo ""
	echo "*** NOTE: Your $BASHRC has been updated, you will need to exit this terminal window and open it again to complete the installation."
	echo ""
fi
}

show_help() {
		header "USAGE: $0 [tab] opt1 [opt2] [opt3]"
		echo "Where options are one or more of the following available for display:"
		echo ""

		for key in "${!LOCALOPTIONS[@]}"; do
  			printf "\\t\\t%-20s\\t\\t%s\\n" "$key" "${LOCALOPTIONS[$key]}"
		done | sort -t : -k 2n
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
	sed -nr "/^\\[$1\\]/ { :l /^\\s*[^#].*/ p; n; /^\\[/ q; b l; }" "$LCNC_CONFIG_DIR"/"$2"/"$2".ini
}

# Begin Main

# If we don't exist in /usr/bin, install us there
if [ ! -f /usr/bin/showme ]; then
	echo "Moving this command to /usr/bin so you can run it from anywhere on the system and enjoy [tab][tab] auto-completion."
	sudo cp $0 /usr/bin/showme
fi

# Check for pre-requisite packages and install if not present
if [ ! -e /usr/bin/wget ] || [ ! -e /usr/sbin/ethtool ] || [ ! -e /usr/sbin/ethtool ]; then
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

# Check & if necessary, update system bashrc for auto-completion
enable_completions

# Variables
TIMESTAMP=$( date '+%D - %T')
LCNC_CONFIG_DIR="$HOME/linuxcnc/configs"
MACHINE_COUNT=$( ls -F "$LCNC_CONFIG_DIR" | grep -c / )
INI_FLAG=0 # The INI argument has sub-arguments of its own

if [ "$MACHINE_COUNT" == "1" ]; then
	MACHINE_NAME="$( ls -F "$LCNC_CONFIG_DIR" | grep / | sed 's/\///' )"
else
	echo "You have more than one machine, selecting config file not yet supported by $0"
fi

#clear

echo ""
echo "PrintNC COMMUNITY SUPPORT TOOL - showme - V. $VERSION - Launched as: $0 $@"
echo "For a complete list of options, please see $0 help. [TAB] Completion supported."
echo ""
# If no options specified, display the help
if [[ $# -eq 0 ]]
then
	show_help
	exit 0
fi

printf "\\t\\t\\t*** START CUT HERE ***\\n"
echo "$TIMESTAMP for host: $( hostname )"


# While there are more than zero options, iterate through the responses and execute as appropriate
while [[ $# -gt 0 ]] ;
do
    	OPTION1="$1"
	OPTION2="$2"

    shift;              #expose next argument
    case "$OPTION1" in

	"ini")
		if [ ! -z "$OPTION2" ]; then
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
				cat "$LCNC_CONFIG_DIR"/"$MACHINE_NAME"/"$MACHINE_NAME".ini
				;;
			*)
				INI_JOINT=""
			;;

		esac
		# Need error checking for results being null
		header "$LCNC_CONFIG_DIR/$MACHINE_NAME.ini"
		get_ini_section "$INI_SECTION" "$MACHINE_NAME"

		for JOINT in $INI_JOINT; do
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
		ip -4 address
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

	"syslog")
		header "LAST 50 LINES OF SYSLOG:"
		sudo tail -50 /var/log/syslog
		;;

	"history")
		header "LAST 50 COMMANDS:"
		tail -50 "$HOME"/.bash_history
		;;

	*)
		if [ "$INI_FLAG" != "1" ]; then
			 echo >&2 "Invalid option: $OPTION1 "
			show_help
			exit 1
		fi
		;;
   esac
done
echo ""
printf "\\t\\t\\t*** END CUT HERE ***\\n"
echo ""
echo "PrintNC is a co-op community, once resolved, please take the time to"
echo "document your problem & solution on the PrintNC wiki to help the next person."
echo ""
## END OF SECTION TO CUT AND PASTE TO YOUR SYSTEM ##
