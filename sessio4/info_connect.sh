#!/bin/bash

function show_help() {
  echo "Aquest script ens dona informació sobre la connectivitat en un equip destí donat amb"
  echo  "una ip de l'equip,  amb un port i un protocol ."
  echo "Genera el seu resultat en el fitxer: log_inet.log"
  echo "Genera 2 fitxers auxiliars anomenats: log_inet_s4_capc.log, log_inet_s4.log "
  echo "   pero son esborrats al final de l'execució."
  echo "Es necessita donar el permís d'execució de script:"
  echo "    chmod +x info_inet.sh"
  echo "" 
  echo "Requisits:"
  echo "            És necessari ser root per poder executar l'script"
  echo "            És necessari que el sistema operatiu sigui Debian"
  echo ""
  echo "Paquets necessaris a tenir instal·lats:"
  echo "whois"
  echo "bc"
  echo "traceroute"
  echo "Per instal·lar-los utilitza la comanda:"
  echo "apt install <paquet>"
  echo ""
  echo "Opcions:"
  echo "  -h                Mostra aquesta ajuda i surt"
  echo ""
  echo "EXECUCIÓ: "
  echo " ./info_inet.sh adreca_ip  num_port/nom_protocol "
  echo "      adreca_ip: una ip amb els sets de 3 números dividits en punts xxx.xxx.xxx.xxx "
  echo "      num_port: ha de ser un número entre el 0-65535  "
  echo "      nom_protocol: ha de ser tcp o udp i en minúscules (no es contemplen més opcions en xarxes IP) "
  echo "            en el mateix format de ser dividits per una barra(/) i sense espais entre ells  "

}

while getopts "h" opt; do
  case ${opt} in
    h )
      show_help
      exit 0
      ;;
    \? )
      echo "Opció invalida: $OPTARG" 1>&2
      show_help
      exit 1
      ;;
  esac
done

    # Processar els arguments- si no hi ha ip ni port/protcol error
if [ "$#" -ne 2 ]; then
    echo "Error: Número incorrecte d'arguments."
    show_help
    exit 1
fi

#Hora inicial
hi=$(date +'%H:%M:%S')
#Borrar el .log de antics resultats  
> log_inet_s4.log
> log_inet_s4_capc.log 
> log_inet.log

echo "COMPROVACIONS INICIALS"

echo "Veure si es compleixen les comprovacions inicials.."

    #Verificar suari amb usuari root
    if [ "$(whoami)" != "root" ]; then
         echo " Usuari no es root, NO es pot executar l'script"
        exit 1 # Atura l'execucio
    else
        echo "  Usuari es root, SI es pot executar l'script" 
    fi

    #Verificar Sistema Operatiu
    SO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [[ $SO != *"Debian"* ]]; then
        echo "Aquest script nomes es pot executar en Debian. El sistema actual és: $SO"
        exit 1 # Atura l'execucio
    else
        echo "  Sistema Operatiu Correcte : $SO"
    fi

    echo "Comprovar si els paràmetres donats son correctes.."
    #lectura paràmetres
    ADDR_IP=$1
    entrada=$2
    IFS='/' read -r PORT PROTO <<<$entrada #dividir port i protcol

    echo "  Entrada paràmetre ip:          $1"
    echo "  Entrada paràmetre port:        $PORT"
    echo "  Entrada paràmetre protocol:    $PROTO"
    
    # Funció per validar l'adreça IP
    validar_ip() {
    if ! [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Error: L'adreça IP proporcionada no és vàlida"
        exit 1
    fi
    }

    # Funció per validar el port
    validar_port() {
    if ! [[ $1 =~ ^[0-9]+$ ]] || [ $1 -lt 0 ] || [ $1 -gt 65535 ]; then
        echo "Error: El número de port ha de ser un valor entre 0 i 65535"
        exit 1
    fi
    }

    # Funció per validar el protocol
    validar_protocol() {
    if ! [[ $1 =~ ^(tcp|udp)$ ]]; then
        echo "Error: El protocol ha de ser 'tcp' o 'udp'"
        exit 1
    fi
    }

    validar_ip $ADDR_IP
    validar_port $PORT
    validar_protocol $PROTO

    #ABANS Mirar si paquets per execucio instalats
    echo "Comprovar si hi han els paquets necessaris instal·lats.."

    funcio_verifica_paquets() {
        if ! command -v $1 &> /dev/null; then
            echo "  El paquet $1 no esta instal·lat, shaura d'instalar per fer totes les proves amb exit"
            exit 1
        fi
    }

    funcio_verifica_paquets whois
    funcio_verifica_paquets bc
    funcio_verifica_paquets nmap


#***FUNCIONS RECURSOS PER DEFECTE ***

#Funcio per obtenir la interfíce per defecte
get_default_interface() {
    local inter_def=$(ip route show default  | awk '{print $5}' | head -n 1) #ruta interfices per defectes
     if [ -z "$inter_def" ]; then  # Si retorna una interficie defecte buida
            echo "-"
        else 
            echo $inter_def 
        fi
}

#Funció per obtenir l'adreça MAC de la interfície 
#   DEPEN funcio interfíce PER PARÀMETRE
get_mac_address() {
    local inter_def=$1
    local mac_def=$(cat /sys/class/net/${inter_def}/address) #troba mac interficie donada
    if [ -z "$mac_def" ]; then  # Si retorna una mac defecte buida
        echo "-"
    else 
        echo $mac_def 
    fi
}

# Funció per comprovar l'estat de la interfície per defecte
#   DEPEN funcio interfíce per defecte -$1
get_interface_status() {
    local inter_def=$1
    local  inte_est=$(ip addr show "$inter_def" 2>/dev/null | grep -Po 'state \K[^ ]+') #buscar el estat interficie
        if [ "$inte_est" == "UP" ]; then  # L'estat interfice amunt
            echo "up"
        elif [ "$inte_est" == "DOWN" ]; then # L'estat interficie avall
            echo "down"
        else
            echo "-"
        fi
}

# Funció per obtenir l'adreça IP de la interfície per defecte
#   DEPEN funcio interfíce per defecte -$1
get_ip_address() {
    local inter_def=$1
    local ip_def=$(ip addr show ${inter_def} | grep 'inet ' | awk '{print $2}' | cut -d/ -f1) #buscar dins ip addr la ip
    if [ -z "$ip_def" ]; then  # Si retorna una ip defecte buida
        echo "-"
    else 
        echo "$ip_def" 
    fi
}

# Funció per obtenir la latència a l'adreça IP per defecte (ICMP ping)
get_ip_rtt() {
    local ip_def=$1
    local vm_def=$(ping -c 1 ${ip_def} | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
    echo $vm_def
}

# Funció per obtenir la xarxa de la interfície per defecte
#   DEPEN funcio interfíce per defecte -$1
get_network_address() {
    local inter_def=$1
    # Verificar si hi ha l'adreça IP amb mascara de l'interfície
    #si es defecte la segona fila sera la ip de la xarxa+mascara
    local xarxa_def=$(ip route show | grep "$inter_def" | awk 'NR==2 {print $1}') #dins ip route show buscar la interficie per defecte
    if [ -z "$xarxa_def" ]; then # Si retorna xarxa per defecte buit
        echo "-"
    else 
        echo $xarxa_def
    fi

}

# Funció per obtenir el router per defecte
get_default_router() {
    local router_def=$(ip route show default | awk '/default/ {print $3}') # adreça ip del router per defecte
    if [ -z "$router_def" ]; then  # Si retorna un router per defecte buit
        echo "-"
    else 
        echo $router_def
    fi
}

# Funció per comprovar l'accés a Internet pel router per defecte
#   ping a un servidor conegut- 1.1.1.1
get_router_internet() {
    local target_ip=$1
    local temps_total=0
    local num_packets=10

    for ((i = 1; i <= $num_packets; i++)); do
         local response=$(ping -c 1 $target_ip | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}') #agafar el temps dels pings
        # Afegir el temps de resposta (en segons) al total
        temps_total=$(echo "$temps_total + $response" | bc)
    done

    # Calcular la mitjana en decimals
    local mitjana_t=$(echo "scale=3; $temps_total / $num_packets" | bc)

    echo $mitjana_t
}

# Funció per obtenir la llista dels servidor DNS per defecte
get_dns_servers() {
    local dns_servers=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}') #retornar llista de nameserver -dns
    if [ -z "$dns_servers" ]; then  # Si retorna una llista dns buida
        echo "-"
    else 
        echo $dns_servers
    fi
}

# Funció per obtenir el DNS per defecte
get_dns_default() {
    # per defecte sera el primer de la llista del resolv.conf
    local dns_servers=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}'| head -n 1)
    if [ -z "$dns_servers" ]; then  # Si retorna un dns per defecte buit
        echo "-"
    else 
        echo $dns_servers
    fi
}

#***FUNCIONS RECURSOS UTILITZATS ***
# Funció per obtenir la interfície utilitzada
# DEPEN de la ip destí donada -$1
get_util_interface(){
    local target_ip=$1
    #Trobar interfíce utilitzada per arribar ip
    local interface=$(ip route get "$target_ip" | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')
    if [ -z "$interface" ]; then #Si retorna interfície buida 
        echo "-"
    else
        echo $interface
    fi
}

#***FUNCIONS RECURSOS DESTÍ ***

get_associated_service() {
    local servei_associat=$(nmap -sV -p $PORT $ADDR_IP | awk '/SERVICE/{getline; print $3}')
    if [ -z "$servei_associat" ]; then
        echo "-"
    else 
        echo $servei_associat
    fi
}

get_service_version() {
    local versio_servei=$(nmap -sV -p $PORT $ADDR_IP | awk '/SERVICE/{getline; print $4}')
    if [ -z "$versio_servei" ]; then
        echo "<< Versió no identificada >>"
    else
        echo $versio_servei
    fi
}



   
echo "ANALITZANT ELS RECURSOS PER DEFECTE"

#*** RECURSOS PER DEFECTE ***
echo "Interficie per defecte.."
    inter_def=$(get_default_interface)
        if [ "$inter_def" != "-" ]; then
            in_dstat="ok"
        else
            in_dstat="ko"
        fi

echo "Adreça Mac per defecte.."
    mac_def=$(get_mac_address $inter_def) #passar nom interficie per defecte
        if [ "$mac_def" != "-" ]; then
            mac_dstat="ok"
        else
            mac_dstat="ko"
        fi

echo "Estat interfície per defecte.."
    estat_def=$(get_interface_status $inter_def) #passar nom interficie per defecte
    if [ "$estat_def" != "-" ] && [ "$estat_def" != "down" ]; then
            estat_dstat="ok"
        else
            estat_dstat="ko"
        fi

echo "Adreça IP per defecte.."
    ip_def=$(get_ip_address $inter_def) #passar nom interficie per defecte
    if [ "$ip_def" != "-" ]; then
            ip_dstat="ok"
        else
            ip_dstat="ko"
        fi

echo "Adreça ip per defecte respon.."
    vm_def=$(get_ip_rtt $ip_def)
    if [ "$vm_def" != "-" ]; then
            ipv_dstat="ok"
        else
            ipv_dstat="ko"
        fi

echo "Xarxa interfície per defecte.."
    xarxa_def=$(get_network_address $inter_def) #passar nom interficie per defecte
    if [ "$xarxa_def" != "-" ]; then
            xarxa_dstat="ok"
        else
            xarxa_dstat="ko"
        fi

echo "Router per defecte.."
    router_def=$(get_default_router)
    if [ "$router_def" != "-" ]; then
            router_dstat="ok"
        else
            router_dstat="ko"
        fi

echo "Adreça router per defecte respon.."
    router_vel_def=$(get_ip_rtt $router_def) #passar ip router per defecte
    if [ "$router_vel_def" != "-" ]; then
            router_rtt_dstat="ok"
        else
            router_rtt_dstat="ko"
        fi

echo "Adreça router per defecte a internet.."
    ad_internet="1.1.1.1"
    router_inte_def=$(get_router_internet $ad_internet )
    if [ "$router_vel_def" != "-" ]; then
            router_inte_dstat="ok"
        else
            router_inte_dstat="ko"
        fi

echo "Dns per defecte definit.."
    dns_def=$(get_dns_servers )
    if [ "$dns_def" != "-" ]; then
            dns_dstat="ok"
        else
            dns_dstat="ko"
        fi

echo "Dns per defecte definit respon.."
    dns_resp_def=$(get_dns_default )
    if [ "$dns_resp_def" != "-" ]; then
            dns_resp_dstat="ok"
        else
            dns_resp_dstat="ko"
        fi

cat >> log_inet_s4.log << EOF    
┌─────────────────────────────────────────────────────────┐
                                                                                         
 -------------------------------------------------------------------------------  
                        Estat dels recursos per defecte.                                  
 -------------------------------------------------------------------------------  
    Intefície per defecte definida:            [$in_dstat]    $inter_def                              
    Intefície per defecte adreça MAC:          [$mac_dstat]    $mac_def                  
    Intefície per defecte estat:               [$estat_dstat]    $estat_def                             
    Intefície per defecte adreça IP:           [$ip_dstat]    $ip_def                     
    Intefície per defecte adreça IP respon:    [$ipv_dstat]    rtt $vm_def ms                        
    Intefície per defecte adreça de xarxa:     [$xarxa_dstat]    $xarxa_def                       

    Router per defecte definit:                [$router_dstat]    $router_def                        
    Router per defecte respon:                 [$router_rtt_dstat]    rtt $router_vel_def ms                        
    Router per defecte té accés a Internet:    [$router_inte_dstat]    rtt $router_inte_def ms (a $ad_internet)            
                                                                                            
    Servidor DNS per defecte definit:          [$dns_dstat]    $dns_def             
    Servidor DNS per defecte respon:           [$dns_resp_dstat]    $dns_resp_def                            
 -------------------------------------------------------------------------------  
                                                                                
EOF

#*** RECURSOS DEDICATS ***

echo "ANALITZANT ELS RECURSOS DEDICATS"

echo "Interficie utilitzada.."
inter_rec=$(get_util_interface $ADDR_IP) #passar ip per trobar interfície q utilitza
    if [ "$inter_rec" != "-" ]; then
        in_rstat="ok"
    else
        in_rstat="ko"
    fi

echo "Adreça Mac interfície utilitzada.."
mac_rec=$(get_mac_address $inter_rec) #passar nom interficie UTILITZADA
    if [ "$mac_rec" != "-" ]; then
        mac_rstat="ok"
    else
        mac_rstat="ko"
    fi



cat >> log_inet_s4.log << EOF    
 -------------------------------------------------------------------------------  
                            Estat dels recursos dedicats.                                
 -------------------------------------------------------------------------------  
    Interfície de sortida cap al destí:        [$in_rstat]    $inter_rec                        
    Interfície de sortida adreça MAC:          [$mac_rstat]    $mac_rec            
    Interfície de sortida estat:               [ok]    up                            
    Interfície de sortida adreça IP:           [ok]    10.1.1.143                    
    Interfície de sortida adreça IP respon:    [ok]    rtt 0.013 ms                  
    Interfície de sortida adreça de xarxa:     [ok]    10.1.1.0/24                   
                                                                                    
    Router de sortida cap al destí:            [ok]    << Mateixa xarxa >>           
    Router de sortida cap al destí respon:     [ko]    << Omès >>                    
    Router de sortida té accés a Internet:     [ko]    << Omès >>                    
 -------------------------------------------------------------------------------  
EOF

#*** RECURSOS DESTÍ ***

echo "ANALITZANT ELS RECURSOS DESTÍ"

echo "Port i destins.."
servei_associat=$(get_associated_service) #passar nom interficie per defecte
 if [ "$servei_associat" != "-" ]; then
        port_servei_desti_estat="ok"
    else
        port_servei_desti_estat="ko"
    fi

echo "Versió del servei destí.."
versio_servei=$(get_service_version) #passar nom interficie per defecte
 if [ "$vm_versio_serveidef" != "<< Versió no identificada >>" ]; then
        versio_desti_estat="ok"
    else
        versio_desti_estat="ko"
    fi

cat >> log_inet_s4.log << EOF    

 -------------------------------------------------------------------------------  
                            Estat de l'equip destí.                              
 -------------------------------------------------------------------------------  
    Destí nom DNS:                             []    -                             
    Destí adreça IP:                           []    $ADDR_IP                    
    Destí port servei:                         [$port_servei_desti_estat]    $PORT/$PROTO $servei_associat                   
              
    Destí abastable:                           []    << L'equip no respon >>       
    Destí respon al servei:                    []    << El port no respon >>       
    Destí versió del servei:                   [$versio_desti_estat]    $versio_servei  
 -------------------------------------------------------------------------------  
└─────────────────────────────────────────────────────────┘                                                                                                                             
EOF
#*** RESULTATS CAPÇALERA ***
    

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

    usuari=$(hostname)
    versio_SO=$(funcio_SO)
    data_compilacio=$(funcio_data_compilacio)
    versio_script=2.08

    hf=$(date +'%H:%M:%S')
    si=$(date -d "$hi" +%s)
    sf=$(date -d "$hf" +%s)
    s=$((sf - si))

cat << EOF > log_inet_s4_capc.log
 ╔════════════════════════════════════════════════════════╗
                                                                          
   ---------------------------------------------------------------------  
    Anàlisi de connectivitat a l'equip $ADDR_IP en el port $PORT/$PROTO.          
   ---------------------------------------------------------------------  
   Equip:                  $usuari [127.0.1.1]                            
   Usuari:                 uid=0(root) gid=0(root) grups=0(root)          
   Sistema operatiu:       $versio_SO                                     
   Versió:                 info_connect.sh $versio_script ($data_compilacio)                 
                                
   Data d'inici:           $(date +'%Y-%m-%d') a les $hi                      
   Data de finalització:   $(date +'%Y-%m-%d') a les $hf                      
   Durada de les tasques:  $s s                                            
   ---------------------------------------------------------------------  
                                                                          
 ╚════════════════════════════════════════════════════════╝  

EOF

cat log_inet_s4_capc.log log_inet_s4.log >> log_inet.log
    # Overwrite the final log file with the capc log content
cat log_inet_s4_capc.log > log_inet.log

# Append the other log to the final log file
cat log_inet_s4.log >> log_inet.log

#BORRAR FITXERS COMPLEMENTARIS
cami="$(dirname "$0")"
fitxer1="$cami/log_inet_s4.log"
fitxer2="$cami/log_inet_s4_capc.log"

# Comprovar i esborrar el primer fitxer
if [ -f "$fitxer1" ]; then
    rm "$fitxer1"
    echo "Fitxer esborrat: $fitxer1"
else
    echo "El fitxer no existeix: $fitxer1"
fi

# Comprovar i esborrar el segon fitxer
if [ -f "$fitxer2" ]; then
    rm "$fitxer2"
    echo "Fitxer esborrat: $fitxer2"
else
    echo "El fitxer no existeix: $fitxer2"
fi

echo " ** Anàlisi completat! **"
echo "Les taules resultants estan guardades en el fitxer: log_inet.log"
