#!/bin/bash

function show_help() {
  echo "Aquest script ens dona informació sobre la connectivitat en un equip destí donat amb"
  echo  "una ip de l'equip,  amb un port i un protocol ."
  echo "Genera el seu resultat en el fitxer: log_inet.log"
  echo "Genera 3 fitxers auxiliars anomenats: log_inet_s4_capc.log, log_inet_s4.log i log_scan.log"
  echo "Es necessita donar el permís d'execució de script:"
  echo "    chmod +x info_inet.sh"
  echo "" 
  echo "Requisits:"
  echo "            És necessari ser root per poder executar l'script"
  echo "            És necessari que el sistema operatiu sigui Debian"
  echo ""
  echo "Paquets necessaris a tenir instal·lats:"
  echo "curl"
  echo "whois"
  echo "bc"
  echo "dnsutils (dig)"
  echo "traceroute"
  echo "iw"
  echo "Per instal·lar-los utilitza la comanda:"
  echo "apt install <paquet>"
  echo ""
  echo "Opcions:"
  echo "  -h                Mostra aquesta ajuda i surt"
  echo ""
  echo "EXECUCIÓ: "
  echo " ./info_inet.sh adreca_ip  num_port/nom_protocol "
  echo "      adreca_ip: una ip amb els sets de 3 números dividits en punts xxx.xx.xxx.xx "
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
    funcio_verifica_paquets() {
        if ! command -v $1 &> /dev/null; then
            echo "  El paquet $1 no esta instal·lat, shaura d'instalar per fer totes les proves amb exit"
            exit 1
        fi
    }

    funcio_verifica_paquets whois



   
echo "Comencar a veure la configuracio del sistema.."

#****RECURSOS PER DEFECTE ***

#Funcio per obtenir la interfíce per defecte
get_default_interface() {
    local inter_def=$(ip route show default  | awk '{print $5}' | head -n 1) #ruta interfices per defectes
     if [ -z "$inter_def" ]; then  # Si retorna una interficie defecte buida
            echo "-"
        else 
            echo "$inter_def" 
        fi
}

#Funció per obtenir l'adreça MAC de la interfície per defecte
#   DEPEN funcio interfíce per defecte -$1
get_mac_address() {
    local inter_def=$1
    local mac_def=$(cat /sys/class/net/${inter_def}/address) #troba mac interficie donada
    if [ -z "$mac_def" ]; then  # Si retorna una mac defecte buida
        echo "-"
    else 
        echo "$mac_def" 
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
    local ip_def=$(ip addr show ${inter_def} | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
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
get_network_address() {
    local inter_def=$1
    local xarxa_def=$(ip route show default | grep ${inter_def} | grep -oP 'src \K[^ ]+')
    echo $xarxa_def
}

# Funció per obtenir el router per defecte
get_default_router() {
    local router_def=$(ip route show default | awk '/default/ {print $3}')
    echo $router_def
}

# Funció per comprovar la latència al router per defecte (ICMP ping)
get_router_response_time() {
    local router_def=$1
    local router_vel_def=$(ping -c 1 ${router_def} | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
    echo $router_vel_def
}

# Funció per comprovar l'accés a Internet (ICMP ping a un servidor conegut, p.ex. 8.8.8.8)
get_internet_access() {
    local router_acces_def=$(ping -c 1 8.8.8.8 | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
    echo $router_acces_def
}

# Funció per obtenir el servidor DNS per defecte
get_dns_server() {
    local dns_def=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}' | head -n 1)
    echo $dns_def
}

# Funció per comprovar la latència al servidor DNS per defecte (ICMP ping)
get_dns_response_time() {
    local dns_def=$1
    local dns_resp_def=$(ping -c 1 ${dns_def} | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
    echo $dns_resp_def
}

echo "Comprovar els recursos per defecte.."

#ADDR_IP
#PORT
#PROTO

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

echo "Adreça ip interfíce velocitat per defecte.."
#vm_def=$(get_ip_rtt $ADDR_IP)
 if [ "$vm_def" != "-" ]; then
        ip_dstat="ok"
    else
        ip_dstat="ko"
    fi

echo "Xarxa interfície per defecte.."
xarxa_def=$(get_network_address $ADDR_IP)
 if [ "$xarxa_def" != "-" ]; then
        xarxa_dstat="ok"
    else
        xarxa_dstat="ko"
    fi

cat >> log_inet_s4.log << EOF    
┌─────────────────────────────────────────────────────────┐
                                                                                         
  ---------------------------------------------------------------------------            
                       Estat dels recursos per defecte.                                  
  ---------------------------------------------------------------------------            
    Intefície per defecte definida:            [$in_dstat]    $inter_def                              
    Intefície per defecte adreça MAC:          [$mac_dstat]    $mac_def                  
    Intefície per defecte estat:               [$estat_dstat]    $estat_def                             
    Intefície per defecte adreça IP:           [$ip_dstat]    $ip_def                     
    Intefície per defecte adreça IP respon:    [$ipv_dstat]    rtt $vm_def ms                        
    Intefície per defecte adreça de xarxa:     [$xarxa_dstat]    $xarxa_def                       
                                    ---                                                      
    Router per defecte definit:                [$router_dstat]    $router_def                        
    Router per defecte respon:                 [$router_rtt_dstat]    rtt $router_vel_def ms                        
    Router per defecte té accés a Internet:    [$router_inte_dstat]    rtt $router_inte_def ms (a $router_acces_def)            
                                                                                            
    Servidor DNS per defecte definit:          [$dns_dstat]    $dns_def             
    Servidor DNS per defecte respon:           [$dns_resp_dstat]    $dns_resp_def                            
  ---------------------------------------------------------------------------            
                                                                                
EOF


#****RECURSOS DEDICATS ***
cat >> log_inet_s4.log << EOF    
 ----------------------------------------------------------------------           
                     Estat dels recursos dedicats.                                
 ----------------------------------------------------------------------           
    Interfície de sortida cap al destí:        [ok]    enp0s3                        
    Interfície de sortida adreça MAC:          [ok]    08:00:27:1d:97:61             
    Interfície de sortida estat:               [ok]    up                            
    Interfície de sortida adreça IP:           [ok]    10.1.1.143                    
    Interfície de sortida adreça IP respon:    [ok]    rtt 0.013 ms                  
    Interfície de sortida adreça de xarxa:     [ok]    10.1.1.0/24                   
                                                                                    
    Router de sortida cap al destí:            [ok]    << Mateixa xarxa >>           
    Router de sortida cap al destí respon:     [ko]    << Omès >>                    
    Router de sortida té accés a Internet:     [ko]    << Omès >>                    
 ----------------------------------------------------------------------       
EOF

#****RECURSOS DESTÍ ***
cat >> log_inet_s4.log << EOF    

 -------------------------------------------------------------------------------  
                             Estat de l'equip destí.                              
 -------------------------------------------------------------------------------  
    Destí nom DNS:                             [ok]    -                             
    Destí adreça IP:                           [ok]    10.1.1.222                    
    Destí port servei:                         [ok]    80/tcp http                   
                                                                                    
    Destí abastable:                           [ko]    << L'equip no respon >>       
    Destí respon al servei:                    [ko]    << El port no respon >>       
    Destí versió del servei:                   [ko]    << Versió no identificada >>  
 -------------------------------------------------------------------------------
└─────────────────────────────────────────────────────────┘                                                                                                                             
EOF

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

cat >> log_inet_s4.log << EOF    
        hola
EOF


    # RESULTATS CAPÇALERA
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
 ║                                                                         ║
 ║  ---------------------------------------------------------------------  ║
 ║   Anàlisi de connectivitat a l'equip $s1 en el port $num/$protocol.          ║
 ║  ---------------------------------------------------------------------  ║
 ║  Equip:                  $usuari [127.0.1.1]                            ║
 ║  Usuari:                 uid=0(root) gid=0(root) grups=0(root)          ║
 ║  Sistema operatiu:       $versio_SO                                     ║
 ║  Versió:                 info_connect.sh $versio_script ($data_compilacio)                 ║
 ║                          info_funcions.sh $versio_script2 ($data_compilacio2)          ║
 ║  Data d'inici:           $(date +'%Y-%m-%d') a les $hi                      ║
 ║  Data de finalització:   $(date +'%Y-%m-%d') a les $hf                      ║
 ║  Durada de les tasques:  $s s                                            ║
 ║  ---------------------------------------------------------------------  ║
 ║                                                                         ║
 ╚════════════════════════════════════════════════════════╝  

EOF

cat log_inet_s4_capc.log log_inet_s4.log >> log_inet.log
    # Overwrite the final log file with the capc log content
cat log_inet_s4_capc.log > log_inet.log

# Append the other log to the final log file
cat log_inet_s4.log >> log_inet.log


