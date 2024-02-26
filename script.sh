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
for line in "${taula_inicial[@]}"; do
    (( ${#line} > long_max )) && long_max=${#line}
done

# Crea un separador dinàmic basat en la longitud màxima de taula_inicial
separator_line=$(printf '%*s' "$long_max" | tr ' ' '-')

# Adjust for padding and borders
adjusted_length=$((long_max + 2)) # 1 space padding on each side

# Print the top border
printf '╔'
printf '═%.0s' $(seq 1 $adjusted_length)
printf '╗\n'

# Function to print a line with padding
print_line() {
    printf "║ %-${long_max}s ║\n" "$1"
}

# Print the header separator
print_line "$separator_line"

# Print taula_inicial and dynamic separators
for line in "${taula_inicial[@]}"; do
    print_line "$line"
done

# Print the footer separator
print_line "$separator_line"

# Print the bottom border
printf '╚'
printf '═%.0s' $(seq 1 $adjusted_length)
printf '╝\n'
