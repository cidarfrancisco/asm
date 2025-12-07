#!/bin/bash
# Script de prueba para el sistema de códigos QR

echo "======================================================"
echo "  PRUEBA DE SISTEMA QR - CODIFICADOR Y DECODIFICADOR"
echo "======================================================"
echo ""

# Verificar que los ejecutables existen
if [ ! -f "./qr_encoder" ]; then
    echo "✗ Error: qr_encoder no encontrado"
    echo "  Ejecuta 'make' primero"
    exit 1
fi

if [ ! -f "./qr_decoder" ]; then
    echo "✗ Error: qr_decoder no encontrado"
    echo "  Ejecuta 'make' primero"
    exit 1
fi

# Prueba 1: Texto simple
echo "[PRUEBA 1] Texto simple: 'Hola'"
echo "----------------------------------------"
./qr_encoder "Hola" test1.pbm
if [ $? -eq 0 ]; then
    echo ""
    echo "Decodificando..."
    ./qr_decoder test1.pbm
    echo ""
fi

# Prueba 2: Texto con espacios
echo ""
echo "[PRUEBA 2] Texto con espacios: 'Hola TEC 2025'"
echo "----------------------------------------"
./qr_encoder "Hola TEC 2025" test2.pbm
if [ $? -eq 0 ]; then
    echo ""
    echo "Decodificando..."
    ./qr_decoder test2.pbm
    echo ""
fi

# Prueba 3: Texto más largo
echo ""
echo "[PRUEBA 3] Texto largo (20 caracteres)"
echo "----------------------------------------"
./qr_encoder "Costa Rica Pura Vida" test3.pbm
if [ $? -eq 0 ]; then
    echo ""
    echo "Decodificando..."
    ./qr_decoder test3.pbm
    echo ""
fi

# Prueba 4: Máximo permitido (32 caracteres)
echo ""
echo "[PRUEBA 4] Máximo (32 caracteres)"
echo "----------------------------------------"
./qr_encoder "12345678901234567890123456789012" test4.pbm
if [ $? -eq 0 ]; then
    echo ""
    echo "Decodificando..."
    ./qr_decoder test4.pbm
    echo ""
fi

echo ""
echo "======================================================"
echo "  PRUEBAS COMPLETADAS"
echo "======================================================"
echo ""
echo "Archivos generados:"
ls -lh test*.pbm 2>/dev/null
echo ""
echo "Para limpiar archivos de prueba:"
echo "  rm test*.pbm"
echo ""
