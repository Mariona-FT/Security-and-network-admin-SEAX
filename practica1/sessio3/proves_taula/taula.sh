#!/bin/bash

# Esborra el contingut de taula.log si existeix
> taula.log

#!/bin/bash

input_file="log_scan.txt"
declare -A unique_ssids
declare -A unique_channels

# Read each line from the input file
while IFS= read -r line; do
    if [[ $line =~ SSID:\ (.+) ]]; then
        ssid="${BASH_REMATCH[1]}"
        unique_ssids["$ssid"]=1
    elif [[ $line =~ channel:\ ([0-9]+) ]]; then
        channel="${BASH_REMATCH[1]}"
        unique_channels["$channel"]=1
    fi
done < "$input_file"

num_ssids=${#unique_ssids[@]}
num_channels=${#unique_channels[@]}

# Now, you can add this information to your taula.log
echo "                              S'ha detectat $num_ssids xarxes en $num_channels canals a la interfície wlan0, wlan0." > taula.log


# Afegeix la capçalera a taula.log
echo " ------------------------------------------------------------------------------------------------------------------------------------- " >> taula.log
echo "       SSID                     canal  freqüència    senyal     v. max.   xifrat    algorismes xifrat       Adreça MAC           fabricant        " >> taula.log
echo " ------------------------------------------------------------------------------------------------------------------------------------- " >> taula.log 

# Funció per processar l'arxiu d'entrada
process_file() {
    input_file="log_scan.txt"
    output_file="taula.log"

    #Inicialitzar vector de informacio de la xarxa
    declare -A xarxa
    keys=("admac" "ssid" "channel" "freq" "signal" "v_max" "xif" "al_xif" "fab")
    info_rsn=0

    while IFS= read -r line; do
        # Si linia comenca amb BSS - Nova xarxa 
        if [[ $line =~ BSS\ ([0-9a-fA-F:]+) ]]; then
            # Si no es la primera xarxa trobada - treu la informació de l'antiga xarxa
            if [ ${xarxa[admac]+_} ]; then
            echo -e "${xarxa[ssid]}\t\t ${xarxa[channel]}\t${xarxa[freq]} MHz ${xarxa[signal]} dBm \t ${xarxa[v_max]} Mbps\t ${xarxa[xif]}\t ${xarxa[al_xif]}\t\t ${xarxa[admac]}\t ${xarxa[fab]}" >> "$output_file"
            fi
            # Netejar els valors i donar valors inicials
            unset xarxa
            declare -A xarxa
            for key in "${keys[@]}"; do
            case "$key" in
                "xif")
                    xarxa["$key"]="sense" ;;
                *)
                    xarxa["$key"]="." ;;
            esac
        done
        #Troba la mac de la xarxa 
            xarxa["admac"]=${BASH_REMATCH[1]}
        #Troba el ssid de la xarxa
        elif [[ $line =~ SSID:\ (.+) ]]; then
            xarxa["ssid"]=${BASH_REMATCH[1]} 
        #Troba el num del canal de la xarxa
        elif [[ $line =~ ' * primary channel: '([[:alnum:]]+) ]]; then
            xarxa["channel"]=${BASH_REMATCH[1]}
        #Troba frequencia de la xarxa 
        elif [[ $line =~ freq:\ ([0-9.]+) ]]; then
            xarxa["freq"]=${BASH_REMATCH[1]}
        #Troba la senyal de la xarxa
        elif [[ $line =~ signal:\ (-[0-9]+) ]]; then
            xarxa["signal"]=${BASH_REMATCH[1]}
        #Troba la velocitat maxima de la xarxa
        elif [[ $line =~ 'Supported rates:' ]]; then
            vm=$(grep -oP '\b[0-9]+(\.[0-9]+)?(?=\s*\*?\s*$)' <<< "$line" | tail -n 1)
            xarxa["v_max"]=$vm
        #Troba el xifrat de la xarxa
        elif [[ $line =~ 'WEP' || $line =~ 'WPA' || $line =~ 'TKIP' || $line =~ 'AES' ]]; then
                    xarxa["xif"]=""
                    encryption_method=$(grep -oP '(WEP|WPA|TKIP|AES)' <<< "$line")
                    wpa_version=$(grep -oP '\b[0-9]+(\.[0-9]+)?(?=\s*\*?\s*$)' <<< "$line" | tail -n 1) #treure versio
                    encryption_method+="$wpa_version"
                    xarxa["xif"]+="$encryption_method"        
        #Troba els algorismes xifrats - estaran despres de la linia RSN  - sino no son els algorismes de la xarxa
        elif [[ $line =~ 'RSN:' ]]; then
            info_rsn=1
            xarxa["al_xif"]=""
        elif [[ $line =~ 'Group cipher: '(.+) && $info_rsn -eq 1 ]]; then #si abans linia RSN - si algorisme xifrat
            xarxa["al_xif"]="${BASH_REMATCH[1]}-"
        elif [[ $line =~ 'Pairwise ciphers: '(.+) && $info_rsn -eq 1 ]]; then #si abans linia RSN - si algorisme xifrat
            xarxa["al_xif"]+="${BASH_REMATCH[1]}-"
        elif [[ $line =~ 'Authentication suites: '(.+) && $info_rsn -eq 1 ]]; then #si abans linia RSN - si algorisme xifrat
            xarxa["al_xif"]+="${BASH_REMATCH[1]}"
            info_rsn=0
        #Troba el fabricant de la xarxa
        elif [[ $line =~ ' * Manufacturer: '([[:alnum:]]+) ]]; then
            xarxa["fab"]=${BASH_REMATCH[1]}
fi
    done < "$input_file"

    # Print the information of the last BSS entry
    if [ ${xarxa[admac]+_} ]; then
            echo -e "${xarxa[ssid]}\t\t ${xarxa[channel]}\t${xarxa[freq]} MHz ${xarxa[signal]} dBm \t ${xarxa[v_max]} Mbps\t ${xarxa[xif]}\t ${xarxa[al_xif]}\t\t ${xarxa[admac]}\t ${xarxa[fab]}" >> "$output_file"
    fi
}


# Call the function to process the input file
process_file