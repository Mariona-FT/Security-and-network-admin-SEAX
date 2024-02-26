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


    #Mode interficie - $mode_interficie



# List all network interfaces
for interficie in $(ls /sys/class/net); do
    # Perform the operations

    # TITOL INTERFÍCIE


    #RESULTATS
    mac=$(funcio_mac $interficie)
   # mac=$(cat /sys/class/net/$interficie/address)

    fabricante="Unknown" # Placeholder, replace with the command to get the actual manufacturer
    estado=$(cat /sys/class/net/$interficie/operstate)
    estado="UNKNOWN (responent...)" # Replace with actual condition
    mtu=$(cat /sys/class/net/$interficie/mtu)

    # Collect all details
    details=(
        "titotl : Configuració de la interfície $interficie."

        "Interfície:                $interficie"
        "Fabricant:                 $fabricante"
        "Adreça MAC:                $mac"
        "Estat de la interfície:    $estado"
        "Mode de la interfície:     normal, amb mtu $mtu"
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
