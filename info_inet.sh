#!/bin/bash

#exec > test.log 2>&1

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

#Maxima longitud linea a inprimir
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
        local vendor_file="/sys/class/net/${i}/device/vendor" #buscar codi id fabricant
        local pci_database="/usr/share/misc/pci.ids"            #buscar en bases de dades el nom 

        if [ -f "${vendor_file}" ]; then
            #Si existeix llegir el id del fabricant
            local vendor_id=$(cat "${vendor_file}")
            
            # Treure '0x' si estan
            vendor_id=${vendor_id#0x}
            
            # Buscar en les bades de dades de pci el codi del fabricant
            local manufacturer=$(grep -i "^${vendor_id}" "${pci_database}" | awk '{$1=""; print $0}' | sed 's/^\s*//')
            
            # Si el fabricant es ta desconegur
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
        #Ip link per buscar la mac de la interficie donada
       mac=$( ip link show "$1" | grep "link/" |awk '{printf $2}' )
        if [ -z "$mac" ]; then  # Si retorna una mac buida
            echo "Cap mac trobada"
        else 
            echo "$mac"
        fi
    }

    #Estat interficie - $estat_interficie
    funcio_estat(){
        #Ip addr per buscar lestat de la maquina UP o DOWN
        estat=$(ip addr show "$1" 2>/dev/null | grep -Po 'state \K[^ ]+')
        if [ -z "$estat" ] || [ "$estat" == "DOWN" ]; then #Depenen estat echo diferents 
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

    # adreçament - $adrecament
    funcio_adrecament() {
        adrecament=$
    }

    #Adreca ip i mascara - $ip_masc
    funcio_ip_mascara() {
        adip_masc=$
    }

    #Adreca de xarxa - $adxarxa
    funcio_xarxa() {
        adxarxa=$
    }

    #Adreça de broadcast - $broadcast
    funcio_broadcast() {
        broadcast=$
    }

    #Adreça gateway per defecte - $gateway
    funcio_gateway() {
        gateway=$
    }

    #Nom dns - $nom_dns
    funcio_dns_nom() {
        nom_dns=$
    }

    funcio_trafic(){
        interface=$1
        # Get traffic information using ifconfig
        rx_bytes=$(ip -s link show $interface | awk '/RX:/{print $2}' | cut -d' ' -f1)
        tx_bytes=$(ip -s link show $interface | awk '/TX:/{print $2}' | cut -d' ' -f1)
        rx_packets=$(ip -s link show $interface | awk '/RX:/{print $1}' | cut -d' ' -f1)
        tx_packets=$(ip -s link show $interface | awk '/TX:/{print $1}' | cut -d' ' -f1)
        # Return traffic information as an array
        echo "$rx_bytes $tx_bytes $rx_packets $tx_packets"
    }

# Llistat de totes les interficies de la maquina


for interficie in $(ls /sys/class/net); do

    # TITOL INTERFÍCIE


    #RESULTATS
    fabricant=$(funcio_fabricant $interficie)
    mac=$(funcio_mac $interficie)
    estat=$(funcio_estat $interficie)
    mode_interficie=$(funcio_mode $interfice)

    adrecament=$(funcio_adrecament $interfice)
    ip_masc=$(funcio_ip_mascara $interficie)
    adxarxa=$(funcio_xarxa $interficie)
    broadcast=$(funcio_broadcast $interficie)
    gateway=$(funcio_gateway $interficie)
    nom_dns=$(funcio_dns_nom $interficie)

    trafic_info=($(funcio_trafic $interficie))
    t_rebut=${trafic_info[0]}
    t_transmes=${trafic_info[1]}
    vel_recep=${trafic_info[2]}
    vel_trans=${trafic_info[3]}

    # Print dels resultats
    resultats=(
        "titotl : Configuració de la interfície $interficie."

        "Interfície:                $interficie"
        "Fabricant:                 $fabricant"
        "Adreça MAC:                $mac"
        "Estat de la interfície:    $estat"
        "Mode de la interfície:     $mode_interficie"
       
        ""
        "Adreçament:                $adrecament"
        "Adreça IP / màscara:       $ip_masc"
        "Adreça de xarxa:           $adxarxa"
        "Adreça broadcast:          $broadcast"
        "Gateway per defecte:       $gateway"
        "Nom DNS:                   $nom_dns"
       
        ""

        "Adreça IP pública:         "
        "Detecció de NAT:           "
        "Nom del domini:            "
        "Xarxes de l'entitat:       "
        "Entitat propietària:       "
       
        "" #Possible ruta involucrada

        "Tràfic rebut:              $t_rebut"
        "Tràfic transmès:           $t_transmes"
        "Velocitat de Recepció:     $vel_recep"
        "Velocitat de Transmissió:  $vel_trans"
    )

    # Determine the max length of the details
    table_width=$(get_max_length "${resultats[@]}")

    # Print the table for the current interface
    print_horizontal_line $table_width
    print_middle_line $table_width
    print_separator $table_width
    for detail in "${resultats[@]}"; do
        print_row $table_width "$detail"
    done
    print_separator $table_width
    print_middle_line $table_width
    print_horizontal_line $table_width
    echo # Newline for spacing between tables
done
