#!/bin/bash

# Contingut taula inicial
taula_inicial=(
    "Analisi de les interficies del sistema realitzada per l'usuari root de l'equip debian."
    "Sistema operatiu Debian GNU/Linux 11 (bullseye)."
    "Versio del script 0.03 compilada el 07/02/2023."
    "Analisi iniciada en data 2023-02-12 a les 19:09:04 i finalitzada en data 2023-02-12 a les 19:09:21 [20s]."
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
    print_linia "$linia"
done

# Imprimeix el separador final
print_linia "$separador_linia"

# Mostra el marge inferior
printf '╚'
printf '═%.0s' $(seq 1 $long_ajustada)
printf '╝\n'
