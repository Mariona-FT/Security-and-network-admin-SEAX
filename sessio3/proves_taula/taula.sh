#!/bin/bash

# Clear the content of taula.log if it exists
> taula.log

# Add header to taula.log
echo " ------------------------------------------------------------------------------------------------------------------------------------- " >> taula.log
echo "       SSID          canal  freqüència    senyal     v. max.   xifrat    algorismes xifrat       Adreça MAC           fabricant        " >> taula.log
echo " ------------------------------------------------------------------------------------------------------------------------------------- " >> taula.log 

# Function to process the input file
process_file() {
    input_file="log_scan.txt"
    output_file="taula.log"

    # Read each line from the input file
   while IFS= read -r line; do
        # Check if the line contains BSS and a MAC address
        if [[ $line =~ BSS\ ([0-9a-fA-F:]+) ]]; then
            admac=$line
            # Initialize variables to store information
            ssid=""
            channel=""
            freq=""
            signal=""
            v_max=""
            xif=""
            sta_channel_width=""
            fab=""
            # Extract other information for the current BSS entry
            while read -r subline; do
                if [[ $subline =~ freq:\ ([0-9.]+) ]]; then
                    freq=${BASH_REMATCH[1]}
                elif [[ $subline =~ SSID:\ (.+) ]]; then
                    ssid=${BASH_REMATCH[1]}
                elif [[ $subline =~ signal:\ (-[0-9]+) ]]; then
                    signal=${BASH_REMATCH[1]}
                fi
            done <<< "$line"
            # Extract additional information
            if [[ $line =~ HT\ operation:\  ]]; then
                al_xif=${line#*: }
                v_max=$(grep -oP 'Maximum RX AMPDU length \K[0-9]+' <<< "$al_xif")
                xif=$(grep -oP 'Supported rates: \K[0-9]+.[0-9]+' <<< "$al_xif")
                fab=$(grep -oP 'Manufacturer: \K\w+' <<< "$al_xif")
                channel=$(grep -oP 'primary channel: \K\d+' <<< "$al_xif")
                sta_channel_width=$(grep -oP 'STA channel width: \K\S+' <<< "$al_xif")
            fi
            # Echo the collected information for the current BSS entry
            echo -e " HOLA $ssid\t$channel\t$freq\t$signal dBm\t$v_max\t$xif\t$sta_channel_width\t$admac\t$fab" >> "$output_file"
        fi
    done < "$input_file"

    echo "Processing complete. Output saved to $output_file"
}

# Call the function to process the input file
process_file
