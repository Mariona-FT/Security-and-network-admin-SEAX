#!/bin/bash

#Hora inicial
hi=$(date +'%H:%M:%S')
#Borrar el .log de antics resultats  
> log_inet_s3.log

echo "COMPROVACIONS INICIALS"

echo "Veure si es compleixen les comprovacions inicials.."

    #Verificar suari amb usuari root
    if [ "$(whoami)" != "root" ]; then
         echo "Usuari no es root, NO es pot executar l'script"
        exit 1 # Atura l'execucio
    else
        echo "Usuari es root, SI es pot executar l'script" 
    fi

    #Verificar Sistema Operatiu
    SO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [[ $SO != *"Debian"* ]]; then
        echo "Aquest script nomes es pot executar en Debian. El sistema actual és: $SO"
        exit 1 # Atura l'execucio
    else
        echo "Sistema Operatiu Correcte : $SO"
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
    funcio_verifica_paquets whois
    funcio_verifica_paquets traceroute


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


 #OPCIONS A BUSCAR 
#/******************************************************************************************************/
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
    funcio_estat(){
        # Ip addr per buscar l'estat de la maquina UP o DOWN
        inte_est=$(ip addr show "$1" 2>/dev/null | grep -Po 'state \K[^ ]+')
        cable=$(ip link show "$1" | grep -c "NO-CARRIER")

        if [ "$inte_est" == "UP" ]; then  # interficie si esta configurada i amb senyal
            est="UP"  # L'estat interficie amunt
            if [ $cable -eq 0 ]; then
                estat="$est (responent.. amb senyal)"
            else
                estat="$est (responent.. sense senyal)"
            fi
        elif [ "$inte_est" == "DOWN" ]; then # L'estat interficie avall
            est="DOWN"
            if [ $cable -eq 0 ]; then
                estat="$est (responent.. amb senyal)"
            else
                estat="$est (responent.. sense senyal)"
            fi
        elif [ -z "$inte_est" ]; then
            estat="UNKNOWN (no responent.. sense senyal)"
        fi

        echo $estat
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


#/******************************************************************************************************/
    #Resultats de les INTERFICIES
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
  
    # Adreça de broadcast - $broadcast
    # adreça de broadcast + (la seva mascara)
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

        # Comprovar si l'adreça IP es valida
        if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "-"
            return 1
        fi
 
        # Separar els octets de l'adreça IP
        IFS='.' read -r -a octets <<< "$ip"

        # Trobar mascara broadcast - si num diferent a 255==0 si num igual a 255=255
        local masc_broadcast=""
        for octet in "${octets[@]}"; do
            if [ "$octet" = "255" ]; then
                masc_broadcast+="$octet."
            else
                masc_broadcast+="0."
            fi
        done

        masc_broadcast=${masc_broadcast%?} #treure ultim punt
        # Mostrar l'adreça de broadcast + la seva mascara
        echo "$broadcast ($masc_broadcast)"
    }

    #Adreça gateway per defecte - $gateway
    funcio_gateway() {
        # Verificar si l'interficie existeix
        if ! ip link show "$1" &>/dev/null; then
            echo "-"
            return 0
        fi
        # Obtenir la porta d'enllaç per defecte (gateway) per a l'interfície especificada
        # Si es dinamicament -mirar en fitxers amb dhcp
        if grep -q "iface $1 inet dhcp" /etc/network/interfaces; then
                gateway=$(ip route show default dev "$1" | awk '/via/ {print $3}')
        #Si es estaticament - mirar en fitxers gateway
        else
            gateway=$(awk '/gateway/ {print $2}' /etc/network/interfaces | head -n1)
        fi
        # Comprovar si la gateway es buida o no vàlida
        if [ -z "$gateway" ] || [[ ! "$gateway" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "-"
            return 1
        fi

        echo $gateway
    }

    #Nom dns - $nom_dns
    # Nom  donat pel sistema dns utilitzat - en sistema de fitxers /etc/hosts
    funcio_dns_nom() {
        # Trobar la ip de la xarxa 
        # Obtenir l'adreça IP i la màscara de l'interfície
        local ip_masc=$(ip addr show "$1" | awk '/inet / {print $2}')

        # Separar l'adreça IP
        local i=$(echo "$ip_masc" | cut -d'/' -f1)
        #Mirar si la ip de la xarxa es de la localhost -127.0.0.1
        if [[ "$i" == "127.0.0.1" ]]; then
            echo "localhost" #el nom del servidor dns sera aquest
        else
            #Trobar laltre nom del servidor dns que no sigui localhost - 127.0.1.1
            local dns_nom=$(grep -E "127.0.1.1" /etc/hosts | awk '{print $2}')
            if [[ -z "$dns_nom" ]]; then
                echo "Nom del DNS no trobat ($i)" # No hi ha nom de DNS
            else
                echo $dns_nom
            fi
        fi
    }

    #Ip publica -$ipp
    # adreça ip publica + [nom de lentitat de la ip publica]
    funcio_ippublic(){
        #buscar ip publica de la xarxa
        local public_ip=$(curl -s http://ipecho.net/plain)
        #buscar el nom de la ip publica -  nom dins dns
        local reverse_ip=$(dig -x $public_ip +short)       
        
        if [ -z $public_ip ]; then # si ippublica no configurada
                echo "- No sha trobat cap ip publica"
        else #si ippublica configurada retorna la ip + el nom entitat de la ip publica
            echo "$public_ip [ $reverse_ip ]"
        fi
    }

    #Deteccio Nat - $dic_nat
    # NAT no detectat 
    # NAT detectat - tornar numero routers i la ip publica + nom ip publica
    funcio_nat(){
        # Use traceroute to determine the number of hops to an external IP
        local local_ip=$(hostname -I | awk '{print $1}')
        #buscar ip publica de la xarxa
        local public_ip=$(curl -s http://ipecho.net/plain)
        #buscar el nom de la ip publica -  nom dins dns
        local reverse_ip=$(dig -x $public_ip +short)       

        #Utilitzar traceroute per trobar el numero de routers
        hops=$(traceroute -m 2 -q 1 8.8.8.8 | grep -o "(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\))" | wc -l)

        if [[ $hops -le 1 ]]; then
            if [[ $public_ip == $local_ip ]]; then # ip publica es igual a la local no es nat
                echo "NAT no detectat, la IP publica $public_ip es la mateixa que la IP local $local_ip. "
            else # error de un sol router - mirar
                echo "NAT detectat,nomes un hop sha trobat - possible error"
            fi
        else # NAT detectat - tornar numero routers i la ip publica + nom ip publica
            echo "NAT detectat, $hops routers involucrats [$local_ip -> ( $public_ip ($reverse_ip) ) ] "
        fi
    }

    #Nom domini- $nom_dom
    #Dos ultims termes del nom del dns - ex: orange.es
    funcio_dom(){
        # Trobar la ip de la xarxa 
        # Obtenir l'adreça IP i la màscara de l'interfície
        local ip_masc=$(ip addr show "$1" | awk '/inet / {print $2}')

        # Separar l'adreça IP
        local i=$(echo "$ip_masc" | cut -d'/' -f1)

        # Mirar si la ip de la xarxa és de la localhost - 127.0.0.1
        if [[ "$i" == "127.0.0.1" ]]; then
            echo "localhost" # el nom del servidor DNS serà aquest
        else
            # Trobar l'altre nom del servidor DNS que no sigui localhost - 127.0.1.1
            local dns_nom=$(grep -E "127.0.1.1" /etc/hosts | awk '{print $2}')
            if [[ -z "$dns_nom" ]]; then
                echo "- no hi ha DNS" # No hi ha nom de DNS
            else
                # Extract the last three terms of the DNS name
                dns_nom=$(echo "$dns_nom" | awk -F'.' '{print $(NF-2)"."$(NF-1)"."$NF}')
                echo "$dns_nom"
            fi
        fi
    }       

    #Informacio de la entitat de la xarxa
    # Trobar nom de la entitat
    # Trobar public ip - mascara + rang
    funcio_entitat_xarxa(){
        local public_ip=$(curl -s http://ipecho.net/plain)
        if [ -z "$public_ip" ]; then
            echo "- No hi ha Ip publica"
            return 1
        fi
        #Trobar el nom de la entitat de la xarxa
        local nom_entitat=$(whois "$public_ip" | grep 'netname' | awk '{print $2}')
        #Trobar la ip amb la mascara de la entitat de la xarxa - filtrat per retornar nomes els valors de la ip i mascara
        local ip=$(whois "$public_ip" |  grep -E 'CIDR|route'| awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?/{print $2}')
        #Trobar el rang de la entitat de la xarxa - fitrat nomes retorni els valors del rang
        local rang=$(whois "$public_ip" | grep 'inetnum' |awk -F':' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

        echo "${nom_entitat} ${ip} [$rang]"
    }

    #Informacio de la entitat propietaria
    # Trobar el nom de la entitat propietaria 
    funcio_entitat_prop(){
        local public_ip=$(curl -s http://ipecho.net/plain)
        if [ -z "$public_ip" ]; then
            echo "- No hi ha Ip publica"
            return 1
        fi
        #Trobar la informacio de la entitat propietaria - filtrat per nomes mostrar el nom daquesta
        local ent_prop=$(whois "$public_ip" | grep -E 'descr' | head -n 1 | awk '{$1=""; print $0}' | sed 's/^ //')

        echo "$ent_prop"
    }

#/******************************************************************************************************/
    #Resultats de WIFI

    #Tornar nom del dispositiu wifi  -$nom_w
    disp_wifi(){
        echo "1"
    }

    #Mode de treball de la wifi -$mode_w
    # tipus: managed ..
    mode_wifi(){
        echo "2"
    }

    #Potencia de transmissio wifi -$ptrans_w
    #Unitats  dBm
    pottrans_wifi(){
        echo "3"
    }
    
    #Si la wifi te connexió en una xarxa - $con_xarxa_w
    # Si NO te : No associat   
    # Si te :  xarxa associada --> es fara print resultat de la xarxa wifi        
    connexiox_wifi(){
        #"No associat"
        echo "11"
    } 

    #SSID de la xarxa - $ssid_w
    ssidxarxa_wifi(){
        echo "4"
    }

    #Canal de treball de la wifi -$canalt_w
    # Numero total + (frequencia MHz)
    canalt_wifi(){
        echo "5"
    }

    #Nivell de senyal de la wifi- $nivell_s_w
    #Unitats  dBm
    nivells_wifi(){
        echo "6"
    } 

    #Punt acces associat de la wifi -$punt_acces_w=
    funcio_pacces_wifi(){
        echo "7"
    }
       
    #Obtenir la velocitat recepcio i transmissio de la wifi 
    #Tornar en array : velocitat recepcio[0] velocitat transmsissio[1]
    #Unitats Mbit/s
    velocitat_wifi(){
        echo "8""9"
    }

#/******************************************************************************************************/
    #Resultats del TRAFIC
    # trafic rebut amb trafic transmes
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

        # Retornar resultats com un array
        echo "$rx_bytes_kb $rx_packets $rx_errors $rx_descartats $rx_perduts"
    }

    funcio_trafic_transmes(){
        interface=$1
        # Obté l'informació de tràfic
        tx_bytes=$(ip -s link show $interface | awk '/TX:/ {getline; print $1}')
        tx_packets=$(ip -s link show $interface | awk '/TX:/ {getline; print $2}')
        tx_errors=$(ip -s link show $interface | awk '/TX:/ {getline; print $3}')
        tx_descartats=$(ip -s link show $interface | awk '/TX:/ {getline; print $4}')
        tx_colisions=$(ip -s link show $interface | awk '/TX:/ {getline; print $6}')
        
        # Si hi ha més de 1024 bits ho transforma a kb
        tx_bytes_kb=$(echo "$tx_bytes/1024" | bc)

        # Retornar resultats com un array
        echo "$tx_bytes_kb $tx_packets $tx_errors $tx_descartats $tx_colisions"
    }
 
    #Resultats de les VELOCITATS
    # velocitat inicial amb velocitat final
    funcio_velocitat_inicial(){
        local interface=$1
        # Obté l'informació de la velocitat
        rx_bytes_inicial=$(cat /sys/class/net/$interface/statistics/rx_bytes)
        rx_paquets_inicial=$(cat /sys/class/net/$interface/statistics/rx_packets)
        tx_bytes_inicial=$(cat /sys/class/net/$interface/statistics/tx_bytes)
        tx_paquets_inicial=$(cat /sys/class/net/$interface/statistics/tx_packets)
        # Retornar resultats com un array
        echo $rx_bytes_inicial $rx_paquets_inicial $tx_bytes_inicial $tx_paquets_inicial
    }

    funcio_velocitat_final(){
        local interface=$1
        # Obté l'informació de la velocitat
        rx_bytes_final=$(cat /sys/class/net/$interface/statistics/rx_bytes)
        rx_paquets_final=$(cat /sys/class/net/$interface/statistics/rx_packets)
        tx_bytes_final=$(cat /sys/class/net/$interface/statistics/tx_bytes)
        tx_paquets_final=$(cat /sys/class/net/$interface/statistics/tx_packets)
        # Retornar resultats com un array
        echo $rx_bytes_final $rx_paquets_final $tx_bytes_final $tx_paquets_final
    }

# Llistat de totes les interficies de la maquina
for interficie in $(ls /sys/class/net); do
    echo "INTERFICIE A ANALITZAR : $interficie "
    inter_wifi=0 #Interficie inicialitzada a tipus NO WIFI - 0

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


    echo "Trobant els valors del tràfic.."
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
        col_transmes=${trafic_transmes_info[4]}

    echo "Trobant els valors de la velocitat.."
    info_velocitat_inicial=($(funcio_velocitat_inicial $interficie))
        sleep 3 # Esperar 3 segons entre mesures
    info_velocitat_final=($(funcio_velocitat_final $interficie))
    # Utilitzar per càlculs aritmètics
        velocitat_recepcio_bytes=$((info_velocitat_final[0] - info_velocitat_inicial[0]))
        velocitat_recepcio_paquets=$((info_velocitat_final[1] - info_velocitat_inicial[1]))
        velocitat_transmissio_bytes=$((info_velocitat_final[2] - info_velocitat_inicial[2]))
        velocitat_transmissio_paquets=$((info_velocitat_final[3] - info_velocitat_inicial[3]))

    #Retornar valors INICIALS x INTERFICIE
cat >> log_inet_s3.log << EOF    
    ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────┐                                                                                                                         
                                                
                                        Configuració de la interfície $interficie.
        ---------------------------------------------------------------------------------------------------------------
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
                                --------------------------------------------------  
EOF
   
    #Retornar valors si son de WIFI
   # if [ -d "/sys/class/net/$interficie/wireless" ]; then
        echo "RESULTATS DE LA INTERFICIE WIFI:"
        inter_wifi=1 # Interficie de tipus WIFI - 1

        echo "Trobant el nom de la wifi.."
            nom_w=$(disp_wifi $interficie)
        echo "Trobant la ip publica.."
            mode_w=$(mode_wifi $interficie)
        echo "Trobant la potencia transmissio.."
            ptrans_w=$(pottrans_wifi $interficie)
        echo "Trobant la connexio a xarxa.."
            con_xarxa_w=$(connexiox_wifi $interficie)
   
cat >> log_inet_s3.log << EOF
        Dispositiu Wi-Fi:          $nom_w                                                                                                              
        Mode de treball:           $mode_w                                                                                                           
        Potència de transmissió:   $ptrans_w                                                                                                           
        Connexio a la xarxa:       $con_xarxa_w

EOF
    #Si hi ha CONNEXIO A LA XARXA
        if [ $con_xarxa_w != "No associat" ]; then
            echo "WIFI AMB CONNEXIO A UNA XARXA"
            echo "Trobant la ssid de la xarxa.."
                ssid_w=$(ssidxarxa_wifi $interficie)
            echo "Trobant el canal de treball.."
                canalt_w=$(canalt_wifi $interficie)
            echo "Trobant el nivell de senyal.."
                nivell_s_w=$(nivells_wifi $interficie)
            echo "Trobant el punt d'acces associat.."
                punt_acces_w=$(funcio_pacces_wifi $interficie)
            echo "Trobant la velocitat recepcio i transmissio de la wifi.."
            vel_w=$(velocitat_wifi $interficie)
                vel_recep_w=vel_w[0]
                vel_trans_w=vel_w[1]

cat >> log_inet_s3.log << EOF                                                                                                                                                 
        SSID de la xarxa:          $ssid_w                                                                                                
        Canal de treball:          $canalt_w                                                                                                     
        Nivell de senyal:          $nivell_s_w                                                                                                            
        Punt d'accés associat:     $punt_acces_w                                                                                        
        Vel. Wi-Fi Recepció:       $vel_recep_w                                                                                                         
        Vel. Wi-Fi Transmissió:    $vel_trans_w
                                --------------------------------------------------
EOF
        fi
   #fi

    #Retornar valors si son de XARXA PÚBLICA
    if [ "$tipus" != "loopback" ] && [ "$tipus" != "noconfig" ]; then
        echo "RESULTATS DE LA XARXA PUBLICA:"
        
        echo "Trobant la ip publica.."
            ip_publica=$(funcio_ippublic $interficie)
        echo "Trobant la NAT.."
            dic_nat=$(funcio_nat $interficie)
        echo "Trobant el domini.."
            nom_dom=$(funcio_dom $interficie)
        echo "Trobant la xarxa de l'entiat.."
            xarxa_entitat=$(funcio_entitat_xarxa $interficie)
        echo "Trobant l'entitat propietaria.."
            entitat=$(funcio_entitat_prop $interficie)

cat >> log_inet_s3.log << EOF
        Adreça IP pública:         $ip_publica
        Detecció de NAT:           $dic_nat
        Nom del domini:            $nom_dom
        Xarxes de l'entitat:       $xarxa_entitat
        Entitat propietària:       $entitat
                                --------------------------------------------------
EOF
    fi 

    echo "Trobant si hi han rutes.."
    #Trobar si hi han rutes - concatenar resultats
    rutes=$(ip route | grep $interficie| tr '\n' ' ')
    if [ ! -z "$rutes" ]; then  #Si hi ha rutes treure el resultat en el log

cat >> log_inet_s3.log << EOF
        Rutes involucrades:         $rutes
EOF
    fi

    #Retornar els valors TRAFIC i VELOCITAT 
cat >> log_inet_s3.log << EOF
        
        ràfic rebut:              $t_rebut Kbytes [$paq_rebut paquets] ($errors_rebut errors, $descartats_rebut descartats i $perduts_rebut perduts)
        Tràfic transmès:           $t_transmes Kbytes [$paq_transmes paquets] ($errors_transmes errors, $descartats_transmes descartats i $col_transmes colisions)
        Velocitat de Recepció:     $velocitat_recepcio_bytes bytes/s [$velocitat_recepcio_paquets paquets/s]
        Velocitat de Transmissió:  $velocitat_transmissio_bytes bytes/s [$velocitat_transmissio_paquets paquets/s]
        
    └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘                                                                                                                             
EOF

    #TAULA de resultats de XARXES WIFI
    if [ "$inter_wifi" -eq 1 ]; then
        echo "CREANT TAULA XARXES WIFI.."

    #Capçalera de la taula
cat >> log_inet_s3.log << EOF
    ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────┐                                                                                                                         
                            S'ha detectat $num_x xarxes en $num_c canals a la interfície $interficie. 
  -------------------------------------------------------------------------------------------------------------------------------------   
        SSID          canal  freqüència    senyal     v. max.   xifrat    algorismes xifrat       Adreça MAC           fabricant       
  -------------------------------------------------------------------------------------------------------------------------------------   
EOF
    #for every xarxa in all of the channels do 

cat >> log_inet_s3.log << EOF
    $ssid       $canal      $freq          $seny      $v_max      $xif          $al_xif           $ad_mac             $fab
EOF


    #tancar taula
cat >> log_inet_s3.log << EOF
    └───────────────────────────────────────────────────────────────────────────────────────────────────────────┘
EOF
    
    fi #if interfice es wifi


    # RESULTATS CAPÇALERA
    usuari=$(hostname)
    versio_SO=$(funcio_SO)
    data_compilacio=$(funcio_data_compilacio)
    versio_script=0.35
    hf=$(date +'%H:%M:%S')
    si=$(date -d "$hi" +%s)
    sf=$(date -d "$hf" +%s)
    s=$((sf - si))

cat << EOF > log_inet_s3_capc.log
    ╔═════════════════════════════════════════════════════════════════════════════════════════════╗
                                                                                                                            
    --------------------------------------------------------------------------------------------------------------------------------         
            Analisi de les interficies del sistema realitzada per l'usuari root de l'equip $usuari.     
            Sistema operatiu $versio_SO.                                                                      
            Versio del script $versio_script compilada el $data_compilacio.                                                              
            Analisi iniciada en data $(date +'%Y-%m-%d') a les $hi i finalitzada en data $(date +'%Y-%m-%d') a les $hf [$s s].               
    --------------------------------------------------------------------------------------------------------------------------------         
                                                                                                                            
    ╚═════════════════════════════════════════════════════════════════════════════════════════════╝
EOF

cat log_inet_s3_capc.log log_inet_s3.log >> log_inet_s3_final.log
    # Overwrite the final log file with the capc log content
cat log_inet_s3_capc.log > log_inet_s3_final.log

# Append the other log to the final log file
cat log_inet_s3.log >> log_inet_s3_final.log


    echo #separacio de les interficies trobades per terminal

done # final del bucle x cada interficie
