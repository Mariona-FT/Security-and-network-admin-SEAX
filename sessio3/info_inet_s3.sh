#!/bin/bash

#exec > log_inet.log 2>&1

    #COMPROVACIONS INICIALS

echo "Veure si es compleixen les comprovacions inicials.."
    #Usuari amb usuari root
    if [ "$(whoami)" = "root" ]; then
        echo "Usuari es root"
    else
        echo "Usuari NO  root"
        exit 1
    fi

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
    funcio_verifica_paquets dig
    
echo "Comencar a veure la configuracio del sistema.."

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
    versio_script=0.35
    hi=$(funcio_hora_inici)
    hf=$(funcio_hora_final)

cat << EOF > log_inet_s3.log
        
        ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
        ║                                                                                                                   ║
        ║  ------------------------------------------------------------------------------------------------------------     ║
        ║   Analisi de les interficies del sistema realitzada per l'usuari root de l'equip debian.                          ║
        ║    Sistema operatiu $versio_SO.                                                                                   ║    
        ║    Versio del script $versio_script compilada el $data_compilacio.                                                ║   
        ║    Analisi iniciada en data $(date +'%Y-%m-%d') a les $hi i finalitzada en data $(date +'%Y-%m-%d') a les $hf.)   ║
        ║  ------------------------------------------------------------------------------------------------------------     ║
        ║                                                                                                                   ║
        ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
EOF

 #OPCIONS A BUSCAR

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
        local i="$1"
        local vendor_file="/sys/class/net/${i}/device/vendor"
        local pci_database="/usr/share/misc/pci.ids"
        #Veure si existeix el fitxer del fabricant
        if [ -f "${vendor_file}" ]; then
            # Trobar el id del fabricant
            local vendor_id=$(cat "${vendor_file}")
            vendor_id=${vendor_id#0x}

            #Veure en la base de dades pci ell fabricant
            local manufacturer=$(grep -i "^${vendor_id}" "${pci_database}" | awk '{$1=""; print $0}' | sed 's/^\s*//')

            # Veure si existeix el fabricant el la base de dades
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
            echo $mac
        fi
    }

    #Estat interficie - $estat_interficie
    #MES ESTATS A MIRAR
    funcio_estat(){
        #Ip addr per buscar lestat de la maquina UP o DOWN
        estat=$(ip addr show "$1" 2>/dev/null | grep -Po 'state \K[^ ]+')
        if [ -z "$estat" ]; then
            echo "UNKNOWN"
        elif [ "$estat" == "DOWN" ]; then #Lestat interficie avall 
            echo "DOWN (no responent...)"
        else
            echo "UP (responent...)"    #Lestat interficie amunt
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
    # Resultat del tipus adreçament: loopback ,estatic , dinamic, no configurada
    funcio_adrecament() {
        # Comprovar si la interfície existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "La interficie especificada no existeix"
            return 1
        fi
        # Cas NO CONFIGURAT
        if ! ip addr show "$1" | grep -q 'inet'; then
            adrecament="no configurat"
        # Cas LOOPBACK
        elif ip addr show "$1" | grep -q "LOOPBACK"; then
            adrecament="loopback (fitxer /etc/network/interfaces) "
        # Cas DHCP
        # Comprovar si hi ha fitxers de DHCP per a la interfície    
        elif grep -q "iface $1 inet dhcp" /etc/network/interfaces; then
            local dhcp_address=$(ip addr show "$1" | grep 'inet ' | awk '{print $2}' | cut -f1 -d'/')
            adrecament="dinamic (DHCP $dhcp_address)"      
        # Cas ESTATIC - Fet manualment
        else
            adrecament="estatic (des de la consola)"
        fi
        echo $adrecament
    }

    #Aconseguir el tipus de la interficie
    # tipus adreçament: loopback ,estatic , dinamic, noconfig
    funcio_tipus() {
        # Comprovar si la interfície existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "La interficie especificada no existeix"
            return 1
        fi
        # Cas NO CONFIGURAT
        if ! ip addr show "$1" | grep -q 'inet'; then
            tipus="noconfig"
        # Cas LOOPBACK
        elif ip addr show "$1" | grep -q "LOOPBACK"; then
            tipus="loopback"
        # Cas DHCP    
        elif grep -q "iface $1 inet dhcp" /etc/network/interfaces; then
            tipus=$"dinamic"
        # Cas ESTATIC 
        else
            tipus="estatic"
        fi
        echo $tipus
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
        # Verificar si l'interficie existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "-"
            return 1
        fi

        # Verificar si hi ha l'adreça IP amb mascara de l'interfície
        local ip_mask=$(ip addr show "$1" | awk '/inet / {print $2}')
        if [ -z "$ip_mask" ]; then
            echo "No s'ha trobat cap adreça IP per a l'interfície."
            return 1
        fi

        # Separar l'adreça IP de la mascara
        local ip_address=$(echo "$ip_mask" | cut -d'/' -f1)
        local cidr_mask=$(echo "$ip_mask" | cut -d'/' -f2)

        # Convertir CIDR a màscara de subxarxa en decimal
        local mask=$((0xffffffff ^ ((1 << (32 - cidr_mask)) - 1)))
        local mask1=$((mask >> 24 & 0xff))
        local mask2=$((mask >> 16 & 0xff))
        local mask3=$((mask >> 8 & 0xff))
        local mask4=$((mask & 0xff))

        # Aplicar mascara de subxarxa a l'adreça IP per obtenir l'adreça de la xarxa
        IFS='.' read -r i1 i2 i3 i4 <<< "$ip_address"
        local network_address=$(printf "%d.%d.%d.%d\n" $(($i1 & $mask1)) $(($i2 & $mask2)) $(($i3 & $mask3)) $(($i4 & $mask4)))

        # Resultat adreca de la xarxa i el seu rang del .1 al .254
        echo "${network_address:-"-"} [ ${network_address%.*}.1 - ${network_address%.*}.254]"
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

    #Informacio de la entitat de la xarxa
    funcio_enitat_xarxa(){
        local public_ip=$(curl -s https://ifconfig.me/ip)
        xarxa=$(whois $ip_publica | grep -i 'inetnum|netname' | head -n 2)
        if [ -z $xarxa ]; then #si info entitat buida
            echo "-"
        else 
            echo $xarxa 
        fi
    }

    #Informacio Entitat propietaria
    funcio_entitat_prop(){
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
    echo "INTERFICIE A ANALITZAR : $interficie "

    #RESULTATS
    echo "SEGUIMENT DELS RESULTATS: " 
    echo "Trobant el nom .."
        inter=$(funcio_nom $interficie)
    echo "Trobant el fabricant.."
        fabricant=$(funcio_fabricant $interficie)
    echo "Trobant la mac.."
        mac=$(funcio_mac $interficie)
    echo "Trobant l'estat.."
        estat=$(funcio_estat $interficie)
    echo "Trobant el mode i la mtu.."
        mode_interficie=$(funcio_mode $interficie)
 
    echo "Trobant l'adreçament.."
        adrecament=$(funcio_adrecament $interficie)
    echo "Trobant el tipus.."
        tipus=$(funcio_tipus $interficie)


    echo "Trobant la ip amb la mascara .."
        ip_masc=$(funcio_ip_mascara $interficie)
    echo "Trobant ladreça de xarxa.."
        adxarxa=$(funcio_xarxa $interficie)
    echo "Trobant el broadcast.."
        broadcast=$(funcio_broadcast $interficie)
    echo "Trobant el gateway.."
        gateway=$(funcio_gateway $interficie)
    echo "Trobant el servidor dns.."
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
cat >> log_inet_s3.log << EOF
        
        ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
        │                                                                                                                            │
                                                        
                                                    Configuració de la interfície $interficie.
        │  -------------------------------------------------------------------------------------------------------------------------- │
                Interfície:                $inter
                Fabricant:                 $fabricant
                Adreça MAC:                $mac
                Estat de la interfície:    $estat
                Mode de la interfície:     $mode_interficie
            
                Adreçament:                $tipus - $adrecament
                Adreça IP / màscara:       $ip_masc
                Adreça de xarxa:           $adxarxa
                Adreça broadcast:          $broadcast
                Gateway per defecte:       $gateway
                Nom DNS:                   $nom_dns
        └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘  

EOF

    if [ "$tipus" != "loopback" ] && [ "$tipus" != "noconfig" ]; then
    echo "RESULTATS DE LA XARXA PUBLICA:"
    echo "Trobant la ip publica.."
        ip_publica=$(funcio_ipp $interficie)
    echo "Trobant la NAT.."
        dic_nat=$(funcio_nat $interficie)
    echo "Trobant el domini.."
        nom_dom=$(funcio_dom $interficie)
    echo "Trobant la xarxa de l'entiat.."
        xarxa_entitat=$(funcio_enitat_xarxa $interficie)
    echo "Trobant l'entitat propietaria.."
        entitat=$(funcio_entitat_prop $interficie)

cat >> log_inet_s3.log << EOF
                Adreça IP pública:         $ip_publica
                Detecció de NAT:           $dic_nat
                Nom del domini:            $nom_dom
                Xarxes de l'entitat:       $xarxa_entitat
                Entitat propietària:       $entitat
EOF
    fi

    # Print dels resultats
cat >> log_inet_s3.log << EOF
                Tràfic rebut:              $t_rebut Kbytes [$paq_rebut paquets] ($errors_rebut errors, $descartats_rebut descartats i $perduts_rebut perduts)
                Tràfic transmès:           $t_transmes Kbytes [$paq_transmes paquets] ($errors_transmes errors, $descartats_transmes descartats i $perduts_transmes perduts)
                Velocitat de Recepció:     $vel_recep bytes/s [ paquets/s]
                Velocitat de Transmissió:  $vel_trans bytes/s [ paquets/s]
        └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘  

EOF
    echo #separacio de les interficies trobades per terminal

    # # Determine the max length of the details
    # table_width=$(get_max_length "${resultats[@]}")

    # # Print the table for the current interface
    # print_horizontal_line $table_width
    
    # print_middle_line $table_width

    # funcio_titol $interficie $table_width
    
    # print_middle_line $table_width

    # print_separator $table_width
    # for detail in "${resultats[@]}"; do
    #     print_row $table_width "$detail"
    # done
    # print_separator $table_width

   # print_middle_line $table_width
   # print_horizontal_line $table_width
   # echo # Newline for spacing between tables

done # final del bucle x cada interficie

