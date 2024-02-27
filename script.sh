#!/bin/bash
# La cridem al principi de tot perquè ens calculi la hora només començar l'script]
hora_inici=$(funcio_hora_inici)
# OPCIONS A BUSCAR

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

    # RESULTATS
    versio_SO=$(funcio_SO)
    data_compilacio=$(funcio_data_compilacio)

# Contingut taula inicial
taula_inicial=(
    "Analisi de les interficies del sistema realitzada per l'usuari root de l'equip debian."
    "Sistema operatiu $versio_SO."
    "Versio del script 0.05 compilada el $data_compilacio."
    "Analisi iniciada en data $(date +'%Y-%m-%d') a les $hora_inici i finalitzada en data $(date +'%Y-%m-%d') a les $hora_final [s]."
)

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
    hora_final="$(date '+%H:%M:%S')"
    print_linia "$linia"
done

# Imprimeix el separador final
print_linia "$separador_linia"

# Mostra el marge inferior
printf '╚'
printf '═%.0s' $(seq 1 $long_ajustada)
printf '╝\n'