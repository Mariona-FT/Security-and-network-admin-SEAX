#!/bin/bash

print_horizontal_line() {
    printf "┌"
    printf '─%.0s' $(seq 1 $1)
    printf "┐\n"
}

print_middle_line() {
    printf "│"
    printf ' %.0s' $(seq 1 $1)
    printf "│\n"
}

print_separator() {
    printf "│"
    printf '─%.0s' $(seq 1 $1)
    printf "│\n"
}

print_row() {
    printf "│ %-$(($1 - 2))s │\n" "$2"
}

# Determine the longest line for dynamic table width
get_max_length() {
    max_len=0
    for str in "$@"; do
        current_len=${#str}
        if (( current_len > max_len )); then
            max_len=$current_len
        fi
    done
    echo $((max_len + 4)) # Add some padding
}

 #OPCIONS A BUSCAR

    #interficie - $interficie


    #Fabricant - $fabricant
    funcio_fabricant(){
        fabricant=$
        
        local i="$1"
        local vendor_file="/sys/class/net/${i}/device/vendor"
        local pci_database="/usr/share/misc/pci.ids"

        # Check if the vendor file exists for the interface
        if [ -f "${vendor_file}" ]; then
            # Read the vendor ID
            local vendor_id=$(cat "${vendor_file}")
            
            # Remove leading '0x' from vendor ID if present
            vendor_id=${vendor_id#0x}
            
            # Lookup the vendor ID in the PCI database
            local manufacturer=$(grep -i "^${vendor_id}" "${pci_database}" | awk '{$1=""; print $0}' | sed 's/^\s*//')
            
            # Check if a manufacturer was found
            if [ -n "${manufacturer}" ]; then
                echo "${manufacturer}"
            else
                echo "Fabricant desconegut"
            fi
        else
            echo "Fitxer del fabricant no trobat"
        fi
    }

    #Adreça mac - $mac
    funcio_mac() {
       mac=$( ip link show "$1" | grep "link/" |awk '{printf $2}' )
        if [ -z "$mac" ]; then
            echo "Cap mac trobada"
        else 
            echo "$mac"
        fi
    }

    #Estat interficie - $estat_interficie
    funcio_estat(){
        estat=$(ip addr show "$1" 2>/dev/null | grep -Po 'state \K[^ ]+')
        if [ -z "$estat" ] || [ "$estat" == "DOWN" ]; then
            echo "DOWN (no responent...)"
        else
            echo "UP (responent...)"
        fi
    }

    #Mode interficie - $mode_interficie
    funcio_mode(){
        mode_interficie=$
         mtu=$(cat /sys/class/net/$interficie/mtu)
    }


# List all network interfaces
for interficie in $(ls /sys/class/net); do
    # Perform the operations

    # TITOL INTERFÍCIE


    #RESULTATS
    fabricant=$(funcio_fabricant $interficie)
    mac=$(funcio_mac $interficie)
    estat=$(funcio_estat $interficie)
    mode_interficie=$(funcio_mode $interfice)

   # mac=$(cat /sys/class/net/$interficie/address)

    #fabricante="Unknown" # Placeholder, replace with the command to get the actual manufacturer
    #estado=$(cat /sys/class/net/$interficie/operstate)
    #estado="UNKNOWN (responent...)" # Replace with actual condition
    mtu=$(cat /sys/class/net/$interficie/mtu)

    # Collect all details
    details=(
        "titotl : Configuració de la interfície $interficie."

        "Interfície:                $interficie"
        "Fabricant:                 $fabricant"
        "Adreça MAC:                $mac"
        "Estat de la interfície:    $estat"
        "Mode de la interfície:     $mode_interficie"
        "Adreçament:                Unknown"
        "Adreça IP / màscara:       Unknown"
        "Adreça de xarxa:           Unknown"
        "Adreça broadcast:          Unknown"
        "Gateway per defecte:       Unknown"
        "Nom DNS:                   Unknown"
        "Tràfic rebut:              Unknown"
        "Tràfic transmès:           Unknown"
        "Velocitat de Recepció:     Unknown"
        "Velocitat de Transmissió:  Unknown"
    )

    # Determine the max length of the details
    table_width=$(get_max_length "${details[@]}")

    # Print the table for the current interface
    print_horizontal_line $table_width
    print_middle_line $table_width
    print_separator $table_width
    for detail in "${details[@]}"; do
        print_row $table_width "$detail"
    done
    print_separator $table_width
    print_middle_line $table_width
    print_horizontal_line $table_width
    echo # Newline for spacing between tables
done
