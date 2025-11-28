#!/bin/bash

archivo="data/Controlplacas025.csv"

# Función para mostrar el archivo completo
mostrar_archivo() {
    echo "📜 Contenido del archivo"
    echo "---"
    if [ ! -f "$archivo" ]; then
        echo "El archivo '$archivo' no existe."
    else
        cat "$archivo"
    fi
    echo "---"
}

# Función para buscar un registro por placa
buscar_registro() {
    read -p "Introduce la placa a buscar: " placa
    echo "---"
    if grep -i ",$placa," "$archivo"; then
        echo "---"
        echo "✅ Registro encontrado."
    else
        echo "❌ Registro no encontrado."
    fi
    echo "---"
}

# Función para editar un registro por placa
editar_placa() {
    echo "🛠️ Editar registro por placa"
    read -p "Introduce la placa del registro a editar: " placa
    if ! grep -i ",$placa," "$archivo"; then
        echo "❌ No se encontró ningún registro con esa placa."
        return
    fi
    
    # Muestra los registros que coinciden con la placa
    grep -i ",$placa," "$archivo"
    echo "---"
    
    read -p "Introduce el número de línea a editar (ej. 2): " linea
    
    # Verificamos si la línea existe
    if [[ ! "$linea" =~ ^[0-9]+$ ]] || [ "$linea" -lt 2 ] || [ "$linea" -gt $(wc -l < "$archivo") ]; then
        echo "❌ Número de línea inválido."
        return
    fi

    echo "---"
    echo "Introduzca los nuevos datos para la línea $linea:"
    read -p "Modelo: " nuevo_modelo
    read -p "Placa: " nueva_placa
    read -p "Servicio / Descripción: " nuevo_servicio
    read -p "Fecha (DD-MM-AA): " nueva_fecha
    read -p "Costo: " nuevo_costo
    
    # Validar que los campos no estén vacíos
    if [ -z "$nuevo_modelo" ] || [ -z "$nueva_placa" ] || [ -z "$nuevo_servicio" ] || [ -z "$nueva_fecha" ] || [ -z "$nuevo_costo" ]; then
        echo "❌ Todos los campos deben ser rellenados."
        return
    fi

    # Usamos sed para reemplazar la línea completa
    sed -i "${linea}s/.*/${nuevo_modelo},${nueva_placa},${nuevo_servicio},${nueva_fecha},${nuevo_costo}/" "$archivo"
    echo "✅ Registro actualizado correctamente."
    echo "---"
}

# Función para agregar un nuevo registro
agregar_registro() {
    echo "➕ Agregar nuevo registro"
    read -p "Modelo: " modelo
    read -p "Placa: " placa
    read -p "Servicio / Descripción: " servicio
    read -p "Fecha (DD-MM-AA): " fecha
    read -p "Costo: " costo
    
    # Validar que los campos no estén vacíos
    if [ -z "$modelo" ] || [ -z "$placa" ] || [ -z "$servicio" ] || [ -z "$fecha" ] || [ -z "$costo" ]; then
        echo "❌ Todos los campos deben ser rellenados."
        return
    fi
    
    echo "$modelo,$placa,$servicio,$fecha,$costo" >> "$archivo"
    echo "✅ Registro agregado correctamente."
    echo "---"
}

# Función para agrupar registros por servicio
agrupar_por_servicio() {
    echo "📋 Registros agrupados por servicio"
    echo "---"
    tail -n +2 "$archivo" | awk -F',' '
        {
            # Sumar el costo al tipo de servicio, manejando valores nulos o vacíos
            costo = $5
            if (costo == "" || costo == "Null") {
                costo = 0
            }
            servicios[$3] += costo
        }
        END {
            # Iterar a través de los servicios e imprimir el resultado
            for (servicio in servicios) {
                printf "%s: $$ %.2f\n", servicio, servicios[servicio]
            }
        }
    ' | sort
    echo "---"
}

# La función mejorada para el control de costos
control_costos () {
    echo "📊 Control de costos"
    echo "---"

    # Costo total historico
    echo "Monto Total Historico:"
    # Excluye la primera línea (encabezado) y usa awk para sumar el costo (columna 5)
    costo_total=$(tail -n +2 "$archivo" | awk -F',' '
        {
            # Limpiamos el valor del costo, convirtiendo 'Null' y vacíos a 0
            costo = $5
            if (costo == "" || costo == "Null") {
                costo = 0
            }
            total += costo
        }
        END {
            printf "%.2f", total
        }
    ')
    
    # Manejo de casos si el resultado es nulo
    if [ -z "$costo_total" ]; then
        costo_total="0.00"
    fi
    echo "$$ $costo_total"
    echo "---"

    # Costos por mes
    echo "Costos por Mes:"
    tail -n +2 "$archivo" | awk -F',' '
        {
            # Limpiamos el valor del costo, convirtiendo 'Null' y vacíos a 0
            costo = $5
            if (costo == "" || costo == "Null") {
                costo = 0
            }
            
            # Procesamos la fecha. Dividimos por '-' para obtener DD, MM, AA
            split($4, fecha_array, "-")
            # Reorganizamos a AA-MM para que el ordenamiento sea cronológico
            mes_anio = fecha_array[3] "-" fecha_array[2]

            # Sumamos el costo al mes y año correspondiente
            costos_por_mes[mes_anio] += costo
        }
        END {
            # Creamos y ordenamos un array con las fechas
            n = asorti(costos_por_mes, fechas_ordenadas)
            
            # Iteramos sobre los índices ordenados para imprimir el resultado
            for (i=1; i<=n; i++) {
                mes = fechas_ordenadas[i]
                printf "%s: $$ %.2f\n", mes, costos_por_mes[mes]
            }
        }
    '
    echo "---"
}

# MENU INTERACTIVO
while true; do
    echo ""
    echo "Menu - Gestion de $archivo"
    echo "1. Ver archivo"
    echo "2. Buscar registro"
    echo "3. Editar por placa"
    echo "4. Agregar nuevo registro"
    echo "5. Agrupar por servicio"
    echo "6. Control de costos"
    echo "7. Salir"
    read -p "Elige una opcion [1-7]: " opcion

    case "$opcion" in
        1) mostrar_archivo ;;
        2) buscar_registro ;;
        3) editar_placa ;;
        4) agregar_registro ;;
        5) agrupar_por_servicio ;;
        6) control_costos ;;
        7) echo "¡Hasta pronto!"; break ;;
        *) echo "❌ Opcion no valida" ;;
    esac
done
