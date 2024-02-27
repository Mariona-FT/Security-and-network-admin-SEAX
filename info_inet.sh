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
 #ABANS Mirar si paquets per execucio instalats
    funcio_verifica_paquets() {
        if ! command -v curl >/dev/null 2>&1; then
            #echo "El paquet 'curl' no està instal·lat. Intentant instal·lar..."
            apt-get update && apt-get install -y curl
            if [ $? -ne 0 ]; then
            #  echo "Hi ha hagut un problema instal·lant 'curl'. Si us plau, comprova la teva connexió a internet i els teus permisos de sudo."
                exit 1
            fi
        else
           echo "'curl' ja està instal·lat."
        fi
    }

 #OPCIONS A BUSCAR

    #interficie - $interficie 
    funcio_titol(){
        # TITOL INTERFÍCIE
        # per $table table_width centra els echos
        local i=$1
        local table_width=$2
        # Calculate padding
        local title_length=$(( ${#i} + 33 )) # Length of "Configuració de la interfície " and spaces
        local padding=$(( ($table_width - $title_length) / 2 ))
        local line="│ $(printf -- '-%.0s' $(seq 1 $((table_width - 4)))) │" # Creates the horizontal line

        # Print the title with padding
        echo "$line"
        printf "│ %*s%s%*s│\n" $padding '' "Configuració de la interfície $i." $padding ''
        echo "$line"

    }

    #Nom interficie - $nom interficie
    #Treure el nom posat i el nom original
    funcio_nom() {
        local i=$1
        #busca nom original 
        local nom_og=$(ip addr show $i| grep -oP '(?<=altname )[^ ]+' || true) 

        if [ -z "$nom_og" ]; then # si NO te nom original posar els dos noms com resposta
            echo "$1 [ $1 ]"
        else
            echo "$1 [ $nom_og ]" # si te nom original passa els dos com a resposta
        fi
    }


    #Fabricant - $fabricant
    funcio_fabricant(){
        local interficie=$1
        
        # Obtenir l'adreça MAC de la interfície
        local ad_mac=$(ip link show "$interficie" | awk '/ether/ {print $2}')
        local oui=${ad_mac:0:8}  # Extreure els primers 3 octets (OUI) de l'adreça MAC
        
        # Cercar l'OUI a la base de dades de la IEEE Registration Authority
        local fabricant=$(curl -s "https://macaddress.io/database/oui?search=$oui" | grep -oP '(?<=organization":").*?(?=")' | head -1)
        
        # Comprovar si s'ha trobat la informació del fabricant
        if [ -n "$fabricant" ]; then
            echo "$fabricant"
        else
            echo "Desconegut"
        fi
    }

    #Adreça mac - $mac
    funcio_mac() {
        #Ip link per buscar la mac de la interficie donada
        mac=$( ip link show "$1" | grep "link/" |awk '{printf $2}' )
        if [ -z "$mac" ]; then  # Si retorna una mac buida
            echo "Cap mac trobada"
        else 
            echo $mac
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
    # estat de la interficie + passar la mtu 
    # Si funciona correctament: configurada, corrent electrica i activada --> NORMAL
    # sino retorna NO NORMAL
    funcio_mode(){
       # mode_interficie=$
        mtu=$(ip addr show "$1" | grep 'mtu' | cut -d ' ' -f5 )
        mode=", amb mtu $mtu"
        echo $mode
    }

    # adreçament - $adrecament
    # tipus adreçament: loopback ,estatic , dinamic, no configurada
    funcio_adrecament() {
            # Comprovar si la interfície existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "La interficie especificada no existeix"
            return 1
        fi

        # Cas NO CONFIGURAT
        if ! ip addr show "$1" | grep -q 'inet'; then
            echo "no configurat"
            return 0
        fi

        # Cas LOOPBACK
        if ip addr show "$1" | grep -q "LOOPBACK"; then
            echo "loopback (fitxer /etc/network/interfaces)"
            return 0
        fi

        # Cas DHCP
        # Comprovar si hi ha fitxers de DHCP per a la interfície
        if grep -q "iface $1 inet dhcp" /etc/network/interfaces; then
            # Si és DHCP, buscar la seva adreça DHCP
            local dhcp_address=$(ip addr show "$1" | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/')
            echo "dinamic (DHCP $dhcp_address)"
            return 0

        # Cas ESTATIC - Fet manualment
        else
            echo "estatic (des de la consola)"
            return 0
        fi
    }

    #Adreca ip i mascara - $ip_masc
    # passar ip amb mascara + (ip només  mascara nomes )
    funcio_ip_mascara() {
        # Verificar si l'interfície existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "-"
            return 0
        fi

        # Obtenir l'adreça IP i la màscara de l'interfície
        local ip_masc=$(ip addr show "$1" | awk '/inet / {print $2}')

        # Separar l'adreça IP
        local i=$(echo "$ip_masc" | cut -d'/' -f1)
        #Separar la mascara 
        local mascara=$(echo "$ip_masc" | cut -d'/' -f2)

        #Calculs per trobar la mascara en decimal
        local decimal_mask=$((0xffffffff << (32 - mascara) & 0xffffffff))
        local mascara_decimal=$(printf "%d.%d.%d.%d\n" $((decimal_mask >> 24 & 0xff)) $((decimal_mask >> 16 & 0xff)) $((decimal_mask >> 8 & 0xff)) $((decimal_mask & 0xff)))

        # Retornar l'adreça IP amb la mascara i les parts separades
        echo "$ip_masc ($i $mascara_decimal)"
    }

    #Adreca de xarxa - $adxarxa
    # adreça de xarxa + (ip de la xarxa + mascara i RANG d'aquesta)
    funcio_xarxa() {
        adxarxa=$
    }

    #Adreça de broadcast - $broadcast
    funcio_broadcast() {
        # Verificar si l'interficie existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "-"
            return 0
        fi

        # Obtenir l'adreça de difusió (broadcast) de l'interficie
        local broadcast=$(ip addr show "$1" | awk '/inet / {print $4}' | cut -d '/' -f1)
         # Obtenir l'adreça IP i la màscara de l'interfície
        local ip_mask=$(ip addr show "$1" | awk '/inet / {print $4}')
        local ip=$(echo "$ip_mask" | cut -d '/' -f1)

        # Comprovar si l'adreça IP és vàlida -casos error
        if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "-"
            return 1
        fi

        # Separar els octets de l'adreça IP
        IFS='.' read -r -a octets <<< "$ip"

        # Trobar mascara broadcast - si num diferent a 255==0 si num igual a 255=255
        local new_broadcast=""
        for octet in "${octets[@]}"; do
            if [ "$octet" = "255" ]; then
                new_broadcast+="$octet."
            else
                new_broadcast+="0."
            fi
        done
        new_broadcast=${new_broadcast%?}


        # Mostrar l'adreça de broadcast + la seva mascara
        echo "$broadcast ($new_broadcast)"
    }

    #Adreça gateway per defecte - $gateway
    funcio_gateway() {
        # Verificar si l'interficie existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "-"
            return 0
        fi
        # Obtenir la porta d'enllaç (gateway) de l'interfície
        local gateway=$(ip route show | awk '$1 == "default" && $5 == "'"$1"'" {print $3}')

        echo  $gateway
    }

    #Nom dns - $nom_dns
    # nom donat pel sistema dns utilitzat
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

    #ABANS
    #funcio_verifica_paquets

    #RESULTATS
    interfi=$(funcio_nom $interficie)
    fabricant=$(funcio_fabricant $interficie)
    mac=$(funcio_mac $interficie)
    estat=$(funcio_estat $interficie)
    mode_interficie=$(funcio_mode $interficie)

    adrecament=$(funcio_adrecament $interficie)
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
        "Interfície:                $inter"
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

    funcio_titol $interficie $table_width
    
    print_middle_line $table_width

    print_separator $table_width
    for detail in "${resultats[@]}"; do
        print_row $table_width "$detail"
    done
    print_separator $table_width
   # print_middle_line $table_width
   # print_horizontal_line $table_width
    echo # Newline for spacing between tables


done # final del bucle x cada interficie
