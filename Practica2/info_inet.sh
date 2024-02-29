#!/bin/bash

exec > log_inet.log 2>&1

    # Sistema Operatiu - $SO
    funcio_SO() {
        versio_SO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"')
        echo $versio_SO
    }

    # Data de compilació - $data_compilacio
    funcio_data_compilacio() {
        data_compilacio=$(stat -c '%y' "$0" | cut -d' ' -f1)
        echo $data_compilacio
    }

    # Hora inici  - $hora_inici
    funcio_hora_inici() {
        hora_inici=$(date +'%H:%M:%S')
        echo $hora_inici
    }

    # Hora final  - $hora_final
    funcio_hora_final() {
        hora_final="$(date '+%H:%M:%S')"
        echo $hora_final
    }
    

    # RESULTATS
    versio_SO=$(funcio_SO)
    data_compilacio=$(funcio_data_compilacio)
    hi=$(funcio_hora_inici)
    hf=$(funcio_hora_final)

    # Contingut taula inicial
    taula_inicial=(
       "Analisi de les interficies del sistema realitzada per l'usuari root de l'equip debian."
        "Sistema operatiu $versio_SO."
        "Versio del script 0.35 compilada el $data_compilacio."
        "Analisi iniciada en data $(date +'%Y-%m-%d') a les $hi i finalitzada en data $(date +'%Y-%m-%d') a les $hf.")

    # Determina la longitud de la linia més llarga
    long_max=0
    for linia in "${taula_inicial[@]}"; do
        (( ${#linia} > long_max )) && long_max=${#linia}
    done
    
    # Crea un separador dinàmic basat en la longitud màxima de la taula_inicial
    separador_linia=$(printf '%*s' "$long_max" | tr ' ' '-')
    # Ajustem l'emplenament i els marges
    long_ajustada=$((long_max + 2)) # 1 espai d'emplenament a cada costat
    # Mostra per pantalla el marge superior
    printf '╔'
    printf '═%.0s' $(seq 1 $long_ajustada)
    printf '╗\n'
    # Mostra per pantalla una línia amb emplenament
    print_linia() {
        printf "║ %-${long_max}s ║\n" "$1"
    }
    # Mostra per patalla el separador de capçalera
    print_linia "$separador_linia"

    # Mostra la taula_inicial and els separadors dinàmics
    for linia in "${taula_inicial[@]}"; do
        print_linia "$linia"
    done

    # Imprimeix el separador final
    print_linia "$separador_linia"
    # Mostra el marge inferior
    printf '╚'
    printf '═%.0s' $(seq 1 $long_ajustada)
    printf '╝\n'

#Variable global - tipus de adrecament: noconfig, dinamic,estatic,loopback
tipus=""

print_horizontal_line() {
  local length=$1
    printf "┌"
    printf '─%.0s' $(seq 1 $length)
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
    echo $((max_len + 1)) # Add some padding
}
 #ABANS Mirar si paquets per execucio instalats
funcio_verifica_paquets() {
    if ! command -v $1 &> /dev/null; then
        echo "El paquet $1 no esta instal·lat, shaura d'instalar per fer totes les proves amb exit"
        exit 1
    fi
}

funcio_verifica_paquets curl
funcio_verifica_paquets whois
funcio_verifica_paquets bc
funcio_verifica_paquets dnsutils


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
        mode=$(ip link show $1 | grep -o 'PROMISC' | head -n1)
        if [ -z $mode]; then
            mode="normal"   #trobat que esta mode normal
        else 
            mode="promisu"  #trobat que esta mode promiscu
        fi
        #Trobar el mtu de la interficie
        mtu=$(ip addr show "$1" | grep 'mtu' | cut -d ' ' -f5 )
        mode_interficie="$mode, amb mtu $mtu "
        
        echo $mode_interficie
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
            tipus="noconfig"
            return 0
        fi

        # Cas LOOPBACK
        if ip addr show "$1" | grep -q "LOOPBACK"; then
            echo "loopback (fitxer /etc/network/interfaces)"
            tipus="loopback"
            return 0
        fi

        # Cas DHCP
        # Comprovar si hi ha fitxers de DHCP per a la interfície
        if grep -q "iface $1 inet dhcp" /etc/network/interfaces; then
            # Si és DHCP, buscar la seva adreça DHCP
            local dhcp_address=$(ip addr show "$1" | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/')
            echo "dinamic (DHCP $dhcp_address)"
            tipus="dinamic"
            return 0

        # Cas ESTATIC - Fet manualment
        else
            echo "estatic (des de la consola)"
            tipus="estatic"
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
        # Verificar si l'interfície existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "-"
            return 0
        fi

        #Agafar la ip mascara 
        local ip_mask=$(ip addr show "$1" | awk '/inet / {print $2}')

        # Aconseguir la ip de la interficie i de la xarxa
        local ip_address=$(echo "$ip_mask" | cut -d'/' -f1)
        local network_prefix=$(echo "$ip_mask" | cut -d'/' -f2)

        #Aconseguir la adreca de la xarxa amb el prefix trobat anteriorment
        local network_address=$(echo "$ip_address" | awk -F'.' -v np="$network_prefix" '{
            for (i=1; i<=NF; i++) {
                if (i <= int(np/8)) {
                    printf "%d", $i
                } else {
                    printf "0"
                }
                if (i < NF) printf "."
            }
            printf "\n"
        }')
        #treure els 3 ultims digits per aconseguir base del rang
         local network_nonumt=$(echo "$network_address" | rev | cut -c 2- | rev)

        # Resultat adreca de la xarxa i el seu rang del .1 al .254
        echo "${network_address:-"-"} [${network_nonumt}1 - ${network_nonumt}254]"
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
        new_broadcast=${new_broadcast%?} #treure ultim punt

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
        # Obtenir la porta d'enllaç per defecte (gateway) per a l'interfície especificada
        if grep -q "iface $1 inet dhcp" /etc/network/interfaces; then
                gateway=$(ip route show default dev "$1" | awk '/via/ {print $3}')
        else
            gateway=$(awk '/gateway/ {print $2}' /etc/network/interfaces | head -n1)
        fi

        # Comprovar si la porta d'enllaç és buida o no vàlida
        if [ -z "$gateway" ] || [[ ! "$gateway" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "-"
            return 1
        fi

        echo $gateway
    }

    #Nom dns - $nom_dns
    # nom donat pel sistema dns utilitzat
    funcio_dns_nom() {
        nom_dns=$
    }

    #Ip publica -$ipp
    funcio_ipp(){
        #buscar ip publica de la xarxa
        local public_ip=$(curl -s https://ifconfig.me/ip)
        if [ -z $public_ip ]; then
        echo "-"
        else 
            echo "$public_ip [-]"
        fi
    }

    #Deteccio Nat
    funcio_nat(){
        echo
    }

    #Nom domini- $nom_dom
    funcio_dom(){
        #buscar ip publica de la xarxa
        local public_ip=$(curl -s https://ifconfig.me/ip)
        if [ -z "$public_ip" ]; then
            echo "No hi ha ip publica"
            return 1
        fi
        #buscar el domini de la adreca ip publica de la xarxa 
        local dom=$(curl -s "https://api.hackertarget.com/reverseiplookup/?q=$public_ip")
        if [ -z "$dom" ]; then
            echo "-"
            return 1
        fi

        echo $dom
    }

    #Info entitat -
    funcio_xarxa_ent(){
        local public_ip=$(curl -s https://ifconfig.me/ip)
        xarxa=$(whois $ip_publica | grep -i 'inetnum|netname' | head -n 2)
        if [ -z $xarxa ]; then #si info entitat buida
            echo "-"
        else 
            echo $xarxa 
        fi
    }

    #Entitat propietaria
    funcio_entitat(){
        #trobar la ip publica de la xarxa 
        local ip_publica==$(curl -s https://ifconfig.me/ip)
        #trobar el propietari de la xarxa
        owner=$(whois $ip_publica | grep -i 'owner' | head -n 1)
        if [ -z $owner ]; then
            echo "-"
        else 
            echo $owner
        fi
    }

    funcio_trafic_rebut(){
        interface=$1
        # Obté l'informació de tràfic
        rx_bytes=$(ip -s link show $interface | awk '/RX:/ {getline; print $1}')
        rx_packets=$(ip -s link show $interface | awk '/RX:/ {getline; print $2}')
        rx_errors=$(ip -s link show $interface | awk '/RX:/ {getline; print $3}')
        rx_descartats=$(ip -s link show $interface | awk '/RX:/ {getline; print $4}')
        rx_perduts=$(ip -s link show $interface | awk '/RX:/ {getline; print $5}')
        
        # Si hi ha més de 1024 bits ho transforma a kb
        rx_bytes_kb=$(echo "$rx_bytes/1024" | bc)

        # Return traffic information as an array
        echo "$rx_bytes_kb $rx_packets $rx_errors $rx_descartats $rx_perduts"
    }

    funcio_trafic_transmes(){
        interface=$1
        # Obté l'informació de tràfic
        tx_bytes=$(ip -s link show $interface | awk '/TX:/ {getline; print $1}')
        tx_packets=$(ip -s link show $interface | awk '/TX:/ {getline; print $2}')
        tx_errors=$(ip -s link show $interface | awk '/TX:/ {getline; print $3}')
        tx_descartats=$(ip -s link show $interface | awk '/TX:/ {getline; print $4}')
        tx_perduts=$(ip -s link show $interface | awk '/TX:/ {getline; print $5}')
        
        # Si hi ha més de 1024 bits ho transforma a kb
        tx_bytes_kb=$(echo "$tx_bytes/1024" | bc)

        # Return traffic information as an array
        echo "$tx_bytes_kb $tx_packets $tx_errors $tx_descartats $tx_perduts"
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

    trafic_rebut_info=($(funcio_trafic_rebut $interficie))
    t_rebut=${trafic_rebut_info[0]}
    paq_rebut=${trafic_rebut_info[1]}
    errors_rebut=${trafic_rebut_info[2]}
    descartats_rebut=${trafic_rebut_info[3]}
    perduts_rebut=${trafic_rebut_info[4]}

    trafic_transmes_info=($(funcio_trafic_transmes $interficie))
    t_transmes=${trafic_transmes_info[0]}
    paq_transmes=${trafic_transmes_info[1]}
    errors_transmes=${trafic_transmes_info[2]}
    descartats_transmes=${trafic_transmes_info[3]}
    perduts_transmes=${trafic_transmes_info[4]}

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
    )

    if [ "$tipus" != "loopback" ] && [ "$tipus" != "noconfig" ]; then
        ip_publica=$(funcio_ipp $interficie)
        dic_nat=$(funcio_nat $interficie)
        nom_dom=$(funcio_dom $interficie)
        xarxa_entitat=$(funcio_xarxa_ent $interficie)
        entitat=$(funcio_entitat $interficie)

        resultats+=(
            "Adreça IP pública:         $ip_publica"
            "Detecció de NAT:           $dic_nat"
            "Nom del domini:            $nom_dom"
            "Xarxes de l'entitat:       $xarxa_entitat"
            "Entitat propietària:       $entitat"
        )
    fi

    resultats+=(
        "Tràfic rebut:              $t_rebut Kbytes [$paq_rebut paquets] ($errors_rebut errors, $descartats_rebut descartats i $perduts_rebut perduts)"
        "Tràfic transmès:           $t_transmes Kbytes [$paq_transmes paquets] ($errors_transmes errors, $descartats_transmes descartats i $perduts_transmes perduts)"
        "Velocitat de Recepció:     $vel_recep bytes/s [ paquets/s]"
        "Velocitat de Transmissió:  $vel_trans bytes/s [ paquets/s]"
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

