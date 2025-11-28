#!/bin/bash

# --- Configuración ---
# El nombre del archivo CSV que me proporcionaste.
# ¡Las comillas son VITALES porque el nombre tiene espacios!
ARCHIVO_CSV="data/inventario 2024 tanques tropico - Copy.csv"

# --- Colores (para una interfaz más amigable) ---
BOLD=$(tput bold)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
NC=$(tput sgr0) # No Color

# --- Función de Verificación Inicial ---
# Verifica que el archivo CSV proporcionado exista.
inicializar_csv() {
    if [ ! -f "$ARCHIVO_CSV" ]; then
        echo "${RED}ERROR: ¡Archivo '$ARCHIVO_CSV' no encontrado!${NC}"
        echo "Asegúrate de que este script esté en la misma carpeta que tu archivo CSV."
        exit 1
    fi
    echo "${GREEN}Archivo '$ARCHIVO_CSV' cargado correctamente.${NC}"
    sleep 1
}

# --- Función de Pausa ---
pausar() {
    echo ""
    read -p "${BOLD}Presiona [Enter] para continuar...${NC}"
}

# --- 1. Visualizar Todo el Inventario ---
visualizar_todo() {
    clear
    echo "--- ${BOLD}${BLUE}Inventario Completo (Visualización)${NC} ---"
    echo "El archivo es ancho. Usa las flechas [<-] y [->] para desplazarte."
    echo "Presiona [q] para salir de esta vista."
    pausar

    # Usamos 'column' para formatear el CSV como tabla.
    # Usamos 'less -S' para que no se partan las líneas (permite scroll horizontal)
    cat "$ARCHIVO_CSV" | column -t -s "," | less -S
}

# --- 2. Buscar por Marca (en Descripción) ---
buscar_por_marca() {
    clear
    echo "--- ${BOLD}${BLUE}Buscar Producto por Marca/Descripción${NC} ---"
    read -p "Introduce la marca o término a buscar (ej: HYUNDAI): " termino

    if [ -z "$termino" ]; then
        echo "${RED}No has introducido ningún término.${NC}"
        pausar
        return
    fi

    # Usamos awk.
    # -F',' -> Delimitador es la coma.
    # -v term="$termino" -> Pasa la variable de bash 'termino' a awk 'term'
    # BEGIN{IGNORECASE=1} -> Hace la búsqueda insensible a mayúsculas/minúsculas.
    # NR==1 -> Imprime siempre la cabecera (línea 1).
    # $2 ~ term -> Si la columna 2 (DESCRIPCION) CONTIENE el término (¡ESTA ERA LA LÍNEA CON EL ERROR!)
    # {print} -> Imprime la línea.
    
    local resultados=$(awk -F',' -v term="$termino" 'BEGIN{IGNORECASE=1} NR==1 || $2 ~ term {print}' "$ARCHIVO_CSV")

    # Comparamos si el número de líneas es menor o igual a 1 (solo la cabecera)
    if [ "$(echo "$resultados" | wc -l)" -le 1 ]; then
        echo "${RED}No se encontraron productos que coincidan con '$termino'.${NC}"
        pausar # <-- ¡AQUÍ FALTABA UNA PAUSA!
    else
        echo "${GREEN}Resultados encontrados para '$termino':${NC}"
        echo "Usa las flechas [<-] y [->] para desplazarte. Presiona [q] para salir."
        
        # Quitamos una pausa innecesaria que había aquí y lanzamos 'less'
        echo "$resultados" | column -t -s "," | less -S
    fi
    
    # 'less' ya actúa como una pausa, así que no necesitamos 'pausar' después.
}
    # Nota: No usamos 'pausar' aquí porque 'less' ya pausa la pantalla.


# --- 3. Administrar Inventario (Agregar / Eliminar) ---

## 3a. Agregar Producto
agregar_vehiculo() {
    clear
    echo "--- ${BOLD}${GREEN}Agregar Nuevo Producto${NC} ---"
    
    # Pedir datos clave
    while true; do
        read -p "Nuevo CÓDIGO (ej: HYTQ9999): " codigo
        if [ -z "$codigo" ] || [[ "$codigo" == *","* ]]; then
            echo "${RED}El CÓDIGO no puede estar vacío ni contener comas.${NC}"
        # Verificamos que el código no exista ya
        elif grep -q "^${codigo}," "$ARCHIVO_CSV"; then
            echo "${RED}ERROR: El CÓDIGO '$codigo' ya existe en el inventario.${NC}"
        else
            break
        fi
    done
    
    while true; do
        read -p "Descripción (ej: MITSUBISHI PANEL...): " desc
        [[ -n "$desc" && "$desc" != *","* ]] && break
        echo "${RED}La descripción no puede estar vacía ni contener comas.${NC}"
    done

    while true; do
        read -p "Cantidad Inicial (Entradas): " entradas
        [[ "$entradas" =~ ^[0-9]+$ ]] && break
        echo "${RED}Cantidad inválida. Debe ser un número entero (ej: 5).${NC}"
    done
    
    # Asignamos valores según la estructura de tu CSV
    local salidas=0
    local saldo=$entradas

    # Creamos la nueva línea replicando la estructura de tu archivo:
    # Col 1-5: Datos principales
    # Col 6: Vacía
    # Col 7-10: Copia de Código, Desc, Fecha (vacía), Cantidad (entradas)
    # Col 11: Vacía
    # Col 12-15: Copia de Código, Desc, Fecha (vacía), Cantidad (vacía)
    
    local nueva_linea
    nueva_linea="$codigo,$desc,$entradas,$salidas,$saldo,,"$codigo","$desc",,$entradas,,"$codigo","$desc",,"
    
    # Agregar la nueva línea al CSV
    echo "$nueva_linea" >> "$ARCHIVO_CSV"
    
    echo "${GREEN}¡Producto (CÓDIGO: $codigo) agregado exitosamente!${NC}"
    pausar
}

## 3b. Eliminar Producto
eliminar_vehiculo() {
    clear
    echo "--- ${BOLD}${RED}Eliminar Producto del Inventario${NC} ---"
    
    # Mostramos una vista rápida para que el usuario sepa qué CÓDIGO eliminar
    echo "Listado actual (primeras 10 entradas):"
    head -n 11 "$ARCHIVO_CSV" | column -t -s "," | sed 's/,,/, ,/g' # Pequeño truco para alinear mejor
    echo "..."
    echo ""

    read -p "Introduce el CÓDIGO exacto del producto a eliminar: " id_eliminar

    if [ -z "$id_eliminar" ]; then
        echo "${RED}No has introducido ningún CÓDIGO.${NC}"
        pausar
        return
    fi
    
    # Verificamos si el código existe antes de intentar borrar
    if grep -q "^${id_eliminar}," "$ARCHIVO_CSV"; then
        
        # Creamos un archivo temporal CON TODAS las líneas EXCEPTO la que coincide
        # El -v invierte la selección de grep
        # El ^ ancla la búsqueda al inicio de la línea (para que 'HYTQ1' no borre 'HYTQ10')
        grep -v "^${id_eliminar}," "$ARCHIVO_CSV" > "${ARCHIVO_CSV}.tmp"
        
        # Reemplazar el archivo original con el temporal
        mv "${ARCHIVO_CSV}.tmp" "$ARCHIVO_CSV"
        
        echo "${GREEN}Producto con CÓDIGO '$id_eliminar' eliminado exitosamente.${NC}"
    else
        echo "${RED}No se encontró ningún producto con el CÓDIGO '$id_eliminar'.${NC}"
    fi
    pausar
}

# --- 4. Menú Principal ---
mostrar_menu() {
    clear
    echo "=============================================="
    echo "  ${BOLD}Gestor de Inventario (Tanques Trópico)${NC} "
    echo "=============================================="
    echo "Archivo: ${BOLD}$ARCHIVO_CSV${NC}"
    echo ""
    echo "1. ${GREEN}Visualizar${NC} inventario completo"
    echo "2. ${BLUE}Buscar${NC} por marca/descripción"
    echo "3. ${GREEN}Agregar${NC} nuevo producto"
    echo "4. ${RED}Eliminar${NC} producto (por CÓDIGO)"
    echo "5. ${BOLD}Salir${NC}"
    echo "----------------------------------------------"
}

# --- Bucle Principal del Programa ---
inicializar_csv

while true; do
    mostrar_menu
    read -p "Selecciona una opción [1-5]: " opcion

    case $opcion in
        1)
            visualizar_todo
            ;;
        2)
            buscar_por_marca
            ;;
        3)
            agregar_vehiculo
            ;;
        4)
            eliminar_vehiculo
            ;;
        5)
            echo "${BOLD}Saliendo del programa. ¡Hasta luego!${NC}"
            exit 0
            ;;
        *)
            echo "${RED}Opción no válida. Inténtalo de nuevo.${NC}"
            sleep 1
            ;;
    esac
done