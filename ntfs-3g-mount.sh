#!/usr/bin/env bash
#
# (Re-)Mount all or specified NTFS drives on an OSX environment by using the NTFS-3G driver (https://github.com/osxfuse/osxfuse/wiki/NTFS-3G) to enable read-write support.
#
# Prerequisites: Have macFuse & NTFS-3G installed. More information here: https://github.com/osxfuse/osxfuse/wiki/NTFS-3G#installation
#
# @author Aurelien Bourdon

# Script name
SCRIPT_NAME="$0"

# Exit status
HELP_WANTED_EXIT_STATUS=0
NO_ENOUGH_PREVILEDGES=10
NO_NTFS_DRIVE_CONNECTED_EXIT_STATUS=20
DISKUTIL_PARSING_ERROR_EXIT_STATUS=30
MOUNTING_ERROR_EXIT_STATUS=40

# Global configurations
VOLUME_NAMES_SEPARATOR=','

# User options
volumesFolderOption='/Volumes'
selectedVolumeNamesOption=''
unmountOnlyOption=false

# Get an XML list of currently connected NTFS drives
#
# @param nothing
# @return a list of currently connected NTFS drives in XML format, or exit in case of failure
function listAvailableNTFSDrives {
    local ntfsDrives; ntfsDrives=$(diskutil list -plist | xmllint --xpath '//dict/key[text() = "Content"]/following-sibling::*[1][text() = "Windows_NTFS"]/..' - 2> /dev/null) || error $NO_NTFS_DRIVE_CONNECTED_EXIT_STATUS 'No NTFS drive connected.'
    [ -z "$ntfsDrives" ] && error $DISKUTIL_PARSING_ERROR_EXIT_STATUS 'Unable to get information from available volumes'
    echo "<dicts>$ntfsDrives</dicts>"
}

# Select volume names to be mounted in read/write mode, based on list provided by the user in command line.
# In case of no selected volume names by user, then the full list of available NTFS drives is selected (see #listNTFSDrives for more details)
#
# @param $1, a list of currently available NTFS drive. See #listNTFSDrives for more details
# @return a list of desired volume
function selectVolumeNames {
    local ntfsDrives="$1"
    local requiredVolumeNames="$2"
    if [ -z "$requiredVolumeNames" ]; then
        local numberOfNtfsDrives; numberOfNtfsDrives=$(echo "$ntfsDrives" | xmllint --xpath 'count(//dict)' - 2> /dev/null) || error $DISKUTIL_PARSING_ERROR_EXIT_STATUS 'Unable to count the number of NTFS drives.'
        for driveNumber in $(seq 1 $numberOfNtfsDrives); do
            local volumeName; volumeName=$(echo "$ntfsDrives" | xmllint --xpath "//dict[$driveNumber]/key[text() = 'VolumeName']/following-sibling::*[1]/text()" - 2> /dev/null) || error $DISKUTIL_PARSING_ERROR_EXIT_STATUS 'Unable to get NTFS volume name.'
            requiredVolumeNames="$requiredVolumeNames$REQUIRED_VOLUME_NAMES_SEPARATOR$volumeName"
        done
    fi
    echo $requiredVolumeNames
}

# Mount provided NTFS drive in read & write mode by using procedure described here: https://github.com/osxfuse/osxfuse/wiki/NTFS-3G
#
# @param $1, the NTFS device identifier, ex /dev/disk2s1
# @param $2, the NTFS volume path that will be used, ex /Volumes/NTS_Drive
# @return nothing
function readWriteMount {
    local deviceIdentifier="$1"
    local mountPath="$2"

    # Unmount if necessary
    local existingMountPath; existingMountPath=$(diskutil info -plist "$deviceIdentifier" | xmllint --xpath '//dict/key[text() = "MountPoint"]/following-sibling::*[1]/text()' - 2> /dev/null)
    if [ $? -eq 0 ]; then
        echo -n "Unmounting existing '$volumeName'... "
        diskutil quiet unmount force "$deviceIdentifier" 2> /dev/null || error $MOUNTING_ERROR_EXIT_STATUS "Unable to unmount '$deviceIdentifier'."
        # Remove old mounting point folder if necessary. It should be an empty directory
        [ -e $existingMountPath ] && sudo rmdir $existingMountPath
        echo 'Done.'
    fi
    [ $unmountOnlyOption = true ] && return

    # Mount with NTFS-3G
    echo -n "Mounting '$volumeName' with NTFS-3G... "
    sudo mkdir "$mountPath" || error $MOUNTING_ERROR_EXIT_STATUS "Unable to create mount path '$mountPath'."
    sudo /usr/local/bin/ntfs-3g "$deviceIdentifier" "$mountPath" -o local -o allow_other -o auto_xattr -o auto_cache || error $MOUNTING_ERROR_EXIT_STATUS "Unable to mount NTFS volume '$mountPath'."
    echo "Successfully mounted to $mountPath."
}

# Process selected NTFS drives to be (re-)mount in read/write mode
#
# @param $1, the selected NTFS drives
# @param $2, the list of available NTFS drives (see #listNTFSDrives)
# @return nothing
function processNTFSDrives {
    local selectedVolumeNames="$1"
    local availableNTFSDrives="$2"
    while IFS=$VOLUME_NAMES_SEPARATOR read -a requiredVolumeName; do
        for volumeName in "${requiredVolumeName[@]}"; do
            [ -z "$volumeName" ] && continue
            local deviceIdentifier; deviceIdentifier=$(echo "$availableNTFSDrives" | xmllint --xpath "//dict/string[text() = '$volumeName']/../key[text() = 'DeviceIdentifier']/following-sibling::*[1]/text()" - 2> /dev/null) || error $DISKUTIL_PARSING_ERROR_EXIT_STATUS "Unable to find NTFS device '$volumeName'."
            local mountPath=$volumesFolderOption/$deviceIdentifier
            readWriteMount "/dev/$deviceIdentifier" "$mountPath"
        done
    done <<< "$selectedVolumeNames"
}

# Display help message
#
# @param nothing
# @return the helper message
function displayHelp {
    echo 'Utilitary to automate NTFS drives mounting in read/write mode on OSX environment, by using the NTFS-3G driver.'
    echo 'For more details, see https://github.com/osxfuse/osxfuse/wiki/NTFS-3G'
    echo ''
    echo "Usage: ${SCRIPT_NAME} [OPTIONS] [VOLUME NAMES...]"
    echo 'OPTIONS:'
    echo '      -h | --help                         Display this helper message.'
    echo '      -u | --unmount                      Unmount specified VOLUME NAMES. If VOLUME NAMES unspecified, then unmount all NTFS volumes currently mounted.'
    echo "      -f | --volumes-folder VOLUME PATH   Path to the volume folder to use to mount/re-mount NTFS drives. $volumesFolderOption by default"
    echo "VOLUME NAMES: list of volume names to be used. If unspecified, then use all NTFS drives currentlly connected."
}

# Parse user-given options and directly execute "self-contained" options
#
# @param $@ user options
# @return nothing
function parseOptions {
    while [[ $# -gt 0 ]]; do
        local argument="$1"
        case $argument in
            -h|--help)
                displayHelp
                exit $HELP_WANTED_EXIT_STATUS
                ;;
            -u|--unmount)
                unmountOnlyOption=true
                ;;
            -f|--volume-folder)
                volumesFolderOption="$2"
                shift
                ;;
            *)
                selectedVolumeNamesOption=$selectedVolumeNamesOption$VOLUME_NAMES_SEPARATOR"$argument"
                ;;
        esac
        shift
    done
}

# Dispay an error message by exiting with provided status
#
# @param $1 the exit status
# @param $2 the error message to display
# @return nothing
function error {
    echo "Error: $2"
    exit $1
}

# Main entry point
#
# @param $@ the command line arguments
# @return nothing
function main {
    # First, ask for priviledges to be able to manipulate drives
    [ $UID -eq 0 ] || error $NO_ENOUGH_PREVILEDGES 'Need priviledges. Please re-run with sudo.'

    # Second, parse options and fill any *Option global variables
    parseOptions "$@"

    # Finally process auto mount of selected NTFS drives
    local availableNTFSDrives; availableNTFSDrives=$(listAvailableNTFSDrives) || error $? "$availableNTFSDrives"
    local selectedVolumeNames; selectedVolumeNames=$(selectVolumeNames "$availableNTFSDrives" "$selectedVolumeNamesOption") || error $? "$selectedVolumeNames"
    processNTFSDrives "$selectedVolumeNames" "$availableNTFSDrives"
}

# Execute entry point by passing command line arguments
main "$@"