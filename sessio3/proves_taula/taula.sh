#!/bin/bash

# Clear the content of taula.log if it exists
> taula.log

# Add header to taula.log
echo " ------------------------------------------------------------------------------------------------------------------------------------- " >> taula.log
echo "       SSID          canal  freqüència    senyal     v. max.   xifrat    algorismes xifrat       Adreça MAC           fabricant        " >> taula.log
echo " ------------------------------------------------------------------------------------------------------------------------------------- " >> taula.log 

# Function to process the input file
# Function to process the input file
# Function to process the input file
# Function to process the input file
process_file() {
    input_file="log_scan.txt"
    output_file="taula.log"

    # Initialize variables to store BSS information
    declare -A bss_info
    keys=("admac" "ssid" "channel" "freq" "signal" "v_max" "xif" "al_xif" "fab")
    # for key in "${keys[@]}"; do
    #     bss_info["$key"]=""
    # done
    info_rsn=0

    # Read each line from the input file
    while IFS= read -r line; do
        # Check if the line contains a BSS entry
        if [[ $line =~ BSS\ ([0-9a-fA-F:]+) ]]; then
            # If not the first BSS entry, print previous BSS information
            if [ ${bss_info[admac]+_} ]; then
            echo -e "${bss_info[ssid]}\t\t ${bss_info[channel]}\t${bss_info[freq]} MHz ${bss_info[signal]} dBm ${bss_info[v_max]} Mbps\t ${bss_info[xif]}\t ${bss_info[al_xif]}\t\t ${bss_info[admac]}\t ${bss_info[fab]}" >> "$output_file"

            fi
            # Clear the BSS information for the new entry
            unset bss_info
            declare -A bss_info
            bss_info["admac"]=${BASH_REMATCH[1]}
        elif [[ $line =~ freq:\ ([0-9.]+) ]]; then
            bss_info["freq"]=${BASH_REMATCH[1]}
        elif [[ $line =~ SSID:\ (.+) ]]; then
            bss_info["ssid"]=${BASH_REMATCH[1]}
        elif [[ $line =~ signal:\ (-[0-9]+) ]]; then
            bss_info["signal"]=${BASH_REMATCH[1]}
        elif [[ $line =~ ' * Manufacturer: '([[:alnum:]]+) ]]; then
            bss_info["fab"]=${BASH_REMATCH[1]}
        elif [[ $line =~ ' * primary channel: '([[:alnum:]]+) ]]; then
            bss_info["channel"]=${BASH_REMATCH[1]}
        elif [[ $line =~ 'Maximum RX AMPDU length' ]]; then
            echo "aa"
            bss_info["v_max"]=$(grep -oP 'Maximum RX AMPDU length \K[0-9]+' <<< "$line")
        elif [[ $line =~ 'RSN:' ]]; then
            info_rsn=1
            echo "rsn" $info_rsn
        elif [[ $line =~ 'Group cipher: '(.+) && $info_rsn -eq 1 ]]; then
            bss_info["al_xif"]+="${BASH_REMATCH[1]}-"
        elif [[ $line =~ 'Pairwise ciphers: '(.+) && $info_rsn -eq 1 ]]; then
            bss_info["al_xif"]+="${BASH_REMATCH[1]}-"
        elif [[ $line =~ 'Authentication suites: '(.+) && $info_rsn -eq 1 ]]; then
            bss_info["al_xif"]+="${BASH_REMATCH[1]}"
            info_rsn=0
        
        elif [[ $line =~ 'WEP' || $line =~ 'WPA' || $line =~ 'TKIP' || $line =~ 'AES' ]]; then
            echo "bb"
            encryption_method=$(grep -oP '(WEP|WPA|TKIP|AES)' <<< "$line")
            if [[ $line =~ 'WPA: *Version: ([0-9]+)' ]]; then
                wpa_version=${BASH_REMATCH[1]}
                encryption_method+=" WPA$wpa_version"
            fi
            bss_info["xif"]+="$encryption_method "
        fi
    done < "$input_file"

    # Print the information of the last BSS entry
    if [ ${bss_info[admac]+_} ]; then
        echo -e "${bss_info[ssid]}\t\t ${bss_info[channel]}\t${bss_info[freq]} MHz  ${bss_info[signal]} dBm ${bss_info[v_max]} Mbps\t ${bss_info[xif]}\t ${bss_info[al_xif]}\t\t ${bss_info[admac]}\t ${bss_info[fab]}" >> "$output_file"
    fi

    echo "Processing complete. Output saved to $output_file"
}


# Call the function to process the input file
process_file