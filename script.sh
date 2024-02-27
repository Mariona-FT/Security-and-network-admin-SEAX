#!/bin/bash

# Store start time
start_time=$(date +%s)

# Function definitions

funcio_SO() {
    echo $(grep 'PRETTY_NAME' /etc/os-release | cut -d'=' -f2 | tr -d '"')
}

funcio_data_compilacio() {
    echo $(stat -c '%y' "$0" | cut -d' ' -f1)
}

funcio_hora_inici() {
    echo $(date +'%H:%M:%S')
}

funcio_hora_fi() {
    echo $(date +'%H:%M:%S')
}

# Calculate elapsed time in seconds
calc_elapsed_time() {
    end_time=$(date +%s)
    echo $((end_time - start_time))
}

# Retrieve system data
versio_SO=$(funcio_SO)
data_compilacio=$(funcio_data_compilacio)
hora_inici=$(funcio_hora_inici)

# Prepare the table content
taula_inicial=(
    "Analisi de les interficies del sistema realitzada per l'usuari root de l'equip debian."
    "Sistema operatiu $versio_SO."
    "Versio del script 0.120 compilada el $data_compilacio."
)

# Calculate the longest line length
long_max=0
for linia in "${taula_inicial[@]}"; do
    (( ${#linia} > long_max )) && long_max=${#linia}
done

# Create a dynamic separator based on the maximum length of taula_inicial
separador_linia=$(printf '%*s' "$long_max" | tr ' ' '-')

# Print table with formatting
{
    # Print upper border
    printf '╔'
    printf '═%.0s' $(seq 1 $((long_max + 2)))
    printf '╗\n'

    # Print header separator
    printf "║ %-${long_max}s ║\n" "$separador_linia"

    # Print initial table content
    for linia in "${taula_inicial[@]}"; do
        printf "║ %-${long_max}s ║\n" "$linia"
    done

    # Calculate and print final line with end time and elapsed time
    hora_fi=$(funcio_hora_fi)
    elapsed_time=$(calc_elapsed_time)
    final_line="Analisi iniciada en data $(date +'%Y-%m-%d') a les $hora_inici i finalitzada en data $(date +'%Y-%m-%d') a les $hora_fi [$elapsed_time s]."
    printf "║ %-${long_max}s ║\n" "$final_line"

    # Print final separator
    printf "║ %-${long_max}s ║\n" "$separador_linia"

    # Print lower border
    printf '╚'
    printf '═%.0s' $(seq 1 $((long_max + 2)))
    printf '╝\n'
} > output.txt

# Display the output
cat output.txt
