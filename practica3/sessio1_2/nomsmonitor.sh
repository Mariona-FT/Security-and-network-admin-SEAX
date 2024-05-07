#!/bin/bash
# Obté l'adreça IP de la interfície activa
IP=$(ip -4 addr show scope global | grep inet | head -n1 | awk '{print $2}' | cut -d'/' -f1)

# Defineix les xarxes i els noms associats
if [[ $IP == 10.1.10.* ]]; then
    NEWNAME="monitordmz"
elif [[ $IP == 10.1.20.* ]]; then
    NEWNAME="monitorclients"
else
    NEWNAME="monitoradmin"
fi
# Obté el nom actual del host
CURRENTNAME=$(hostname)

# Comprova si el nou nom és diferent del nom actual
if [[ $CURRENTNAME != $NEWNAME ]]; then
    echo $NEWNAME | tee /etc/hostname
    hostname $NEWNAME
    echo "Canviat el nom de la màquina i reiniciant..."
    reboot
else
    echo "El nom de la màquina ja està configurat correctament. No es necessita reinici."
fi