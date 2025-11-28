#!/bin/bash

ARCHIVO="data/inventario2024radiadorestropico.csv"
HISTORIAL="movimientos.csv"

# Crear historial si no existe
if [ ! -f "$HISTORIAL" ]; then
    echo "CODIGO,DESCRIPCION,FECHA_HORA,TIPO,CANTIDAD" > "$HISTORIAL"
fi

# Mostrar encabezado formateado
mostrar_encabezado() {
    printf "%-10s %-40s %-8s %-8s %-8s\n" "CODIGO" "DESCRIPCION" "ENTRADAS" "SALIDAS" "SALDO"
    echo "--------------------------------------------------------------------------------"
}

# Buscar por código en cualquier columna
buscar_codigo() {
    read -p "Ingrese el código a buscar: " codigo
    mostrar_encabezado
    awk -F',' -v cod="$codigo" '
    BEGIN {IGNORECASE=1}
    NR>1 {
        for(i=1; i<=NF; i++) {
            gsub(/^ +| +$/, "", $i)
            if (toupper($i) == toupper(cod)) {
                printf "%-10s %-40s %-8s %-8s %-8s\n", $1, $2, $3, $4, $5
                exit
            }
        }
    }
    ' "$ARCHIVO"
}

# Buscar por marca o modelo parcial
buscar_por_marca() {
    read -p "Ingrese la marca o modelo a buscar (ej. TOYOTA): " marca
    mostrar_encabezado
    awk -F',' -v marca="$marca" '
    BEGIN {IGNORECASE=1}
    NR>1 {
        gsub(/^ +| +$/, "", $2)
        if (index(toupper($2), toupper(marca)) > 0) {
            printf "%-10s %-40s %-8s %-8s %-8s\n", $1, $2, $3, $4, $5
        }
    }
    ' "$ARCHIVO"
}

# Registrar en historial
registrar_historial() {
    local codigo="$1"
    local descripcion="$2"
    local tipo="$3"
    local cantidad="$4"
    local fecha=$(date +"%d-%m-%Y %H:%M:%S")
    echo "$codigo,$descripcion,$fecha,$tipo,$cantidad" >> "$HISTORIAL"
}

# Agregar entrada
agregar_entrada() {
    read -p "Ingrese el código: " codigo
    read -p "Cantidad a ingresar: " cantidad
    awk -F',' -v OFS=',' -v cod="$codigo" -v cant="$cantidad" '
    BEGIN {IGNORECASE=1; found=0}
    NR==1 {print; next}
    {
        for(i=1; i<=NF; i++) {
            gsub(/^ +| +$/, "", $i)
            if (toupper($i) == toupper(cod)) {
                $3 += cant
                $5 += cant
                desc=$2
                found=1
                break
            }
        }
        print
    }
    END { if(found==0) print "ERROR: Código no encontrado" > "/dev/stderr" }
    ' "$ARCHIVO" > tmp && mv tmp "$ARCHIVO"

    desc=$(awk -F',' -v cod="$codigo" 'BEGIN{IGNORECASE=1} NR>1 {for(i=1;i<=NF;i++){gsub(/^ +| +$/,"",$i); if(toupper($i)==toupper(cod)){print $2; exit}}}' "$ARCHIVO")
    registrar_historial "$codigo" "$desc" "ENTRADA" "$cantidad"
    echo "✅ Entrada registrada."
}

# Registrar salida
registrar_salida() {
    read -p "Ingrese el código: " codigo
    read -p "Cantidad a retirar: " cantidad
    awk -F',' -v OFS=',' -v cod="$codigo" -v cant="$cantidad" '
    BEGIN {IGNORECASE=1; found=0; ok=1}
    NR==1 {print; next}
    {
        for(i=1; i<=NF; i++) {
            gsub(/^ +| +$/, "", $i)
            if (toupper($i) == toupper(cod)) {
                if($5 >= cant) {
                    $4 += cant
                    $5 -= cant
                } else {
                    print "ERROR: Stock insuficiente" > "/dev/stderr"
                    ok=0
                }
                desc=$2
                found=1
                break
            }
        }
        print
    }
    END { if(found==0) print "ERROR: Código no encontrado" > "/dev/stderr" }
    ' "$ARCHIVO" > tmp && mv tmp "$ARCHIVO"

    if [ $? -eq 0 ]; then
        desc=$(awk -F',' -v cod="$codigo" 'BEGIN{IGNORECASE=1} NR>1 {for(i=1;i<=NF;i++){gsub(/^ +| +$/,"",$i); if(toupper($i)==toupper(cod)){print $2; exit}}}' "$ARCHIVO")
        registrar_historial "$codigo" "$desc" "SALIDA" "$cantidad"
        echo "✅ Salida registrada."
    fi
}

# Menú interactivo
while true; do
    clear
    echo "=============================="
    echo "   📦 GESTIÓN DE INVENTARIO"
    echo "=============================="
    echo "1) Buscar por código"
    echo "2) Registrar entrada"
    echo "3) Registrar salida"
    echo "4) Ver historial de movimientos"
    echo "5) Buscar por marca o modelo"
    echo "6) Salir"
    echo "------------------------------"
    read -p "Seleccione una opción: " opcion

    case $opcion in
        1) buscar_codigo ;;
        2) agregar_entrada ;;
        3) registrar_salida ;;
        4) column -s, -t "$HISTORIAL" | less ;;
        5) buscar_por_marca ;;
        6) echo "Saliendo..."; break ;;
        *) echo "Opción inválida." ;;
    esac

    echo
    read -p "Presione ENTER para continuar..."
done