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
# Version: 0.30 - jac - May 27, 2021
#       -Initial suport for displaying LinuxCNC HAL config file
#		-showme hal string pattern matches supplied string (e.g. home, 7i96, etc)
#		-no string will match all
#       -Refined machine.ini parsing logic
#	-Changed versions command to use output of lsb_release -a
#	-Added headings option to show ini, to list all headings in the machine.ini file
#
# Verion: 0.41 - jac - May 31, 2021
#	-Ensure ownership, group and permissions set automatically on install to /usr/bin/
#	-Only set initial LinuxCNC variables if LinuxCNC config directory exists
#	-Added required packages pciutils and usbutils for probing buses for hardware
#	-Added alias for rm to be 'rm -i' to bashrc to enable confirmation of deletions for new users
#
# TODO:	-Iterate through LinuxCNC directory and promopt to identify machine name if necessary
#	-Better error and exit handling
#	-Add color coding to improve section boundry visibility (under consideration)
#	-Auto self-updater
#		-Check for internet connection
#	-Option to install recommended packages in one setp
#	-Consider when completions file is updated and how determined
#	-Add installation of Xanmod kernel (deferred, details on Wiki and Xanmod.org)
#	-Add option to set net.ifnames=0 in grub commandline
#		-Tricky as will break existing network config and require intervention

# Variables
VERSION="0.41"
COMP_VERSION="1"
TIMESTAMP=$( date '+%D - %T')
LCNC_CONFIG_DIR="$HOME/linuxcnc/configs"
MACHINE_COUNT=$( ls -F "$LCNC_CONFIG_DIR" | grep -c / )
SUBOPTION_FLAG=0 # The flag for arguments that have sub-arguments of their own
# Note, if you add a package you still need to add an explicit test for a binary further down
REQD_PACKAGES="wget ethtool pciutils usbutils"
# To be added in the future for suggested packages that this script isn't dependent on
#RECD_PACKAGES="locate zip unzip" 

if [ -d "$LCNC_CONFIG_DIR" ]; then
	if [ "$MACHINE_COUNT" == "1" ]; then
		MACHINE_NAME="$( ls -F "$LCNC_CONFIG_DIR" | grep / | sed 's/\///' )"
	else
		echo "You have more than one machine, selecting INI/HAL config file not yet supported by $0"
	fi
else
	echo "Looks like LinuxCNC hasn't been configured yet, so 'ini' and 'hal' options are not relveant."
fi

# Arrays / Configuration

# These are the local options that users can call this script with and a brief desc of each
declare -A LOCALOPTIONS=( \
[cpu]="The make and model of the CPU" \
[cpufull]="The full contents of /proc/cpuinfo" \
[kernel]="The kernel version" \
[modules]="Active kernel modules" \
[grub]="Grub configuration from /etc/default/grub" \
[cmdline]="Kernel boot Parameters the kernel was last booted with" \
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
[hal]="Displays (pattern) from your machinename.hal LinuxCNC HAL config file" \
[syslog]="Show last 50 lines of /var/log/syslog" \
[history]="Show last 50 lines of bash shell history" \
)


# INI - machine.ini
# These are defined sections of the LinuxCNC machine.ini master file that can be referenced
declare -A LCNC_MAIN_INI_OPTIONS=( \
# Why not generate this from lines that start with [ ? - Maybe for the hal file, deferred
[x-axis]="X Axis & Joint 0" \
[y-axis]="Y Axis & Joints 1 & 2" \
[z-axis]="Z Axis & Joint 3" \
[all]="Full INI file" \
[headings]="A list of all existing section headings" \
[SECTION-HEADING]="Where SECTION-HEADING is any valid (case sensitive) SECTION-heading present in the INI the LinuxCNC file" \
)

# Functions

enable_completions() {
#set -x
KEY="PNCSHOWME"
BASHRC="/etc/bash.bashrc"
COMPDIR="/usr/share/bash-completion/completions/"
# Only necessary to increment if new commands with sub-commands are added
# New top level commands auto-populate already
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

	# Add the version # to the bottom of the completions file
	# For use in future when determining if completions file requires updating
        echo "# COMPVERSION=$COMP_VERSION" >> $TMPFILE
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
# Alias the remove command to be interactive to avoid accidental deletions by new users
alias rm='rm -i'
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

# Dispay help options from array
show_help() {
		header "USAGE: $0 [tab] opt1 [opt2] [opt3]"
		echo "Where options are one or more of the following available for display:"
		echo ""

		for key in "${!LOCALOPTIONS[@]}"; do
  			printf "\\t\\t%-20s\\t\\t%s\\n" "$key" "${LOCALOPTIONS[$key]}"
		done | sort -t : -k 2n
}

# Formatting of output header
header() {
	echo ""
	echo "$1"
	echo ""
}

# INI - machine.ini
# Get the section of an INI file between two strings
# Usage: get_ini_section string1 string2 filename.ini
# Check for correct # of arguments ariving or check in INI case section

get_ini_section() {
	sed -nr "/^\\[$1\\]/ { :l /^\\s*[^#].*/ p; n; /^\\[/ q; b l; }" "$LCNC_CONFIG_DIR"/"$2"/"$2".ini
}

# HAL - machine.hal
# Get the lines from the machine.hal file that match pattern
# Uasge: get_hal_lines string1 filename
get_hal_lines() {
	grep "$1" "$LCNC_CONFIG_DIR"/"$2"/"$2".hal
}

# Begin Main

# If we don't exist in /usr/bin, install us there
if [ ! -f /usr/bin/showme ]; then
	# Should this use variables for portability in future?
	echo "Moving this command to /usr/bin so you can run it from anywhere on the system and enjoy [tab][tab] auto-completion."
	sudo cp "$0" /usr/bin/showme
	echo "Setting permissions on /usr/bin/showme"
	sudo chown root.root /usr/bin/showme
	sudo chmod 755 /usr/bin/showme
fi

# Check for pre-requisite packages and install if not present
if [ ! -e /usr/bin/wget ] || [ ! -e /usr/sbin/ethtool ] || [ ! -e /usr/bin/lspci ] || [ ! -e /usr/bin/lsusb ]; then
	echo ""
	echo "INFO: Installing required packages:"
	echo "$REQD_PACKAGES"
	echo ""
	echo "		Please provide password when promted"
	sudo apt-get install "$REQD_PACKAGES"
fi

# Option to display top level options, used for auto completion
if [ "$1" == "options" ]; then
	echo "${!LOCALOPTIONS[@]}"
	exit 0
fi

# Option to display ini sub-options, used for auto completion
if [ "$1" == "options-ini" ]; then
	echo "${!LCNC_MAIN_INI_OPTIONS[@]}"
	exit 0
fi

# Check & if necessary, update system bashrc for auto-completion
enable_completions

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
		# Set this up for X, Y (dual joints), Z and otherwise what is specific as an argument
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

			"headings")
				# Grab all the lines that start with [
				grep "^\[" "$LCNC_CONFIG_DIR"/"$MACHINE_NAME"/"$MACHINE_NAME".ini
				;;

			"all" | "All" | "ALL")
				header "FULL OUTPUT OF: $LCNC_CONFIG_DIR/$MACHINE_NAME/$MACHINE_NAME.ini"
				cat "$LCNC_CONFIG_DIR"/"$MACHINE_NAME"/"$MACHINE_NAME".ini
				INI_SECTION="ALL"
				;;
			*)
				INI_JOINT=""
			;;

		esac
		# If only sending sections, add the header and interate through related joints
                if [ "$INI_SECTION" != "ALL" ]; then
                        # No need to mention section name as it appears at the top of the file output
                        header "$LCNC_CONFIG_DIR/$MACHINE_NAME.ini"
                        get_ini_section "$INI_SECTION" "$MACHINE_NAME"

                        for JOINT in $INI_JOINT; do
                                echo ""
                                get_ini_section "$JOINT" "$MACHINE_NAME"
                        done
                        fi
                fi
                SUBOPTION_FLAG=1
                ;;

	"hal")
		if [ ! -z "$OPTION2" ]; then
			header "MATCHING PATTERN: $OPTION2 in $LCNC_CONFIG_DIR/$MACHINE_NAME/$MACHINE_NAME.hal" 
			get_hal_lines "$OPTION2" "$MACHINE_NAME"

		else
		 	header "DISPLAYING ALL LINES FROM: $LCNC_CONFIG_DIR/$MACHINE_NAME/$MACHINE_NAME.hal"
			cat "$LCNC_CONFIG_DIR/$MACHINE_NAME/$MACHINE_NAME.hal"
		fi
		SUBOPTION_FLAG=1
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
		header "IP ADDRESSES - provide passwd if prompted:"
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
		lsb_release -a
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
		if [ "$SUBOPTION_FLAG" != "1" ]; then
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
