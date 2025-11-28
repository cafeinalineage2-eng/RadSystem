#!/usr/bin/env bash

echo "=== Sistema de Gestión ==="
echo "1) Placas control"
echo "2) Inventario Radiadores"
echo "3) Inventario Tanques"
echo "0) Salir"
read -p "Seleccione una opción: " opcion

case $opcion in
  1) ./bin/Systema1.sh ;;
  2) ./bin/systema2.sh ;;
  3) ./bin/systema3.sh ;;
  0) echo "Saliendo..."; exit ;;
  *) echo "Opción inválida. Intente de nuevo." ;;
esac