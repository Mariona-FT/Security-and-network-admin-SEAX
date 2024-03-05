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
    keys=("admac" "ssid" "channel" "freq" "signal" "v_max" "xif" "sta_channel_width" "fab")

    # Read each line from the input file
    while IFS= read -r line; do
        # Check if the line contains a BSS entry
        if [[ $line =~ BSS\ ([0-9a-fA-F:]+) ]]; then
            # If not the first BSS entry, print previous BSS information
            if [ ${bss_info[admac]+_} ]; then
                print_bss_info
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
        elif [[ $line =~ ' Maximum RX AMPDU length' ]]; then
            bss_info["v_max"]=${BASH_REMATCH[1]}
        
        elif [[ $line =~ 'HT\ operation:\'  ]]; then
                    al_xif=${line#*: }
            #bss_info["v_max"]=$(grep -oP' \K[0-9]+' <<< "$al_xif")
            bss_info["xif"]=$(grep -oP 'Supported rates: \K[0-9]+.[0-9]+' <<< "$al_xif")
           # bss_info["fab"]=$(grep -oP 'Manufacturer: \K\w+' <<< "$al_xif")
           # bss_info["channel"]=$(grep -oP ' * primary channel: \K\d+' <<< "$al_xif")
            bss_info["sta_channel_width"]=$(grep -oP 'STA channel width: \K\S+' <<< "$al_xif")
        fi
    done < "$input_file"

    # Print the information of the last BSS entry
    if [ ${bss_info[admac]+_} ]; then
        print_bss_info
    fi

    echo "Processing complete. Output saved to $output_file"
}

# Function to print BSS information
print_bss_info() {
    echo -e " HOLA ${bss_info[ssid]}\t${bss_info[channel]}\t${bss_info[freq]}\t${bss_info[signal]} dBm\t${bss_info[v_max]}\t${bss_info[xif]}\t${bss_info[sta_channel_width]}\t${bss_info[admac]}\t${bss_info[fab]}" >> "$output_file"
}

# Call the function to process the input file
process_file