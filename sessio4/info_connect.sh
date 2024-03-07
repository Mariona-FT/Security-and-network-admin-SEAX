#!/bin/bash

function show_help() {
  echo "Aquest script ens dona informació de totes les interfícies ethernet i wifi on s'està executant."
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
  echo " ./info_inet.sh     per executar el script"
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

