# Proyecto 2: Codificador y Decodificador de QR
**Arquitectura de Computadoras - TEC**

Sistema completo para generar y decodificar códigos QR versión 2 (25×25) con corrección de errores usando Paridad 2D.

---

## 📋 Requisitos

- **GCC** (compilador C, arquitectura 32 bits)
- **NASM** (ensamblador)
- **Make**
- Linux (32 o 64 bits con soporte multilib)

### Instalar dependencias (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install gcc-multilib nasm make
```

---

## 🔨 Compilación

```bash
make
```

Esto genera dos ejecutables:
- `qr_encoder` - Codificador (texto → QR)
- `qr_decoder` - Decodificador (QR → texto)

### Limpiar archivos generados:
```bash
make clean
```

### Recompilar desde cero:
```bash
make rebuild
```

---

## 🚀 Uso

### **Codificador**
```bash
./qr_encoder "texto" [archivo_salida.pbm]
```

**Ejemplos:**
```bash
./qr_encoder "Hola Mundo"
./qr_encoder "TEC 2025" mi_qr.pbm
```

**Límites:**
- Máximo 32 caracteres
- Genera archivo PBM formato P1 (ASCII)

### **Decodificador**
```bash
./qr_decoder archivo.pbm
```

**Ejemplo:**
```bash
./qr_decoder qr_output.pbm
```

---

## ✅ Prueba rápida

### Ciclo completo:
```bash
# 1. Codificar
./qr_encoder "Hola TEC" test.pbm

# 2. Decodificar
./qr_decoder test.pbm
```

**Resultado esperado:**
```
Texto decodificado:
"Hola TEC"
```

### Script de pruebas automáticas:
```bash
chmod +x test_qr.sh
./test_qr.sh
```

---

## 🏗️ Arquitectura

### **Fase 1: Patrones básicos**
- ✅ Detección de finder patterns
- ✅ Lectura de formato QR

### **Fase 2A: Codificación (Vale)**
- ✅ `qr_encode_data.asm` - Codifica texto a bits (modo BYTE)
- ✅ `qr_pbm.asm` - Genera matriz con patrones (finders, timing, alignment)
- ✅ Colocación de bits en patrón zigzag
- ✅ Integración con ECC Paridad 2D

### **Fase 2B: Decodificación (Melissa)**
- ✅ `qr_decode.asm` - Flujo principal de decodificación
- ✅ `qr_detect.asm` - Detección de finder patterns
- ✅ `qr_utils.asm` - Funciones auxiliares
- ✅ `qr_extract.asm` - Extracción de datos en zigzag
- ✅ `qr_decode_data.asm` - Decodificación de bits a texto
- ✅ Integración con ECC Paridad 2D

### **Sistema ECC: Paridad 2D**
- ✅ `ecc_parity2d.asm` - Detección y corrección de errores
- **Capacidad:** Corrige 1 error por bloque
- **Overhead:** 12 bytes (8 fila + 4 columna)
- **Total:** 44 bytes (32 datos + 12 paridad)

Ver `ECC_INFO.md` para detalles técnicos del sistema de corrección.

---

## 📁 Estructura del proyecto

```
ProyectoArqui2/
├── src/
│   ├── main.c              # Decodificador principal
│   ├── encoder_main.c      # Codificador principal
│   ├── file_utils.c/h      # Utilidades de archivos
│   └── asm/
│       ├── qr_decode.asm          # Decodificación principal
│       ├── qr_encode_data.asm     # Codificación de datos
│       ├── qr_pbm.asm             # Generación de matriz QR
│       ├── qr_detect.asm          # Detección de patrones
│       ├── qr_extract.asm         # Extracción de datos
│       ├── qr_decode_data.asm     # Decodificación bits→texto
│       ├── qr_utils.asm           # Utilidades compartidas
│       └── ecc_parity2d.asm       # Sistema de corrección ECC
├── io.mac              # Macros de I/O (proveído por profesor)
├── io.o                # Objeto I/O (proveído por profesor)
├── makefile            # Sistema de compilación
├── test_qr.sh          # Script de pruebas
├── ECC_INFO.md         # Documentación técnica ECC
└── README.md           # Este archivo
```

---

## 🔬 Detalles técnicos

### **Formato QR Versión 2**
- Tamaño: 25×25 módulos (625 bits)
- Patrones: 3 finders (7×7), 1 alignment (5×5), timing patterns
- Modo: BYTE (8 bits por carácter)
- Capacidad: 32 caracteres

### **Corrección de errores: Paridad 2D**
- Organiza 32 bytes en matriz 8×4
- Calcula XOR por fila (8 bytes)
- Calcula XOR por columna (4 bytes)
- **Detecta:** Múltiples errores
- **Corrige:** 1 error automáticamente

**Ventajas sobre Reed-Solomon:**
- ✅ Mucho más simple (~250 líneas vs 500+)
- ✅ Menos overhead (12 vs 22 bytes)
- ✅ Suficiente para QR de buena calidad
- ⚠️ Limitación: Solo 1 error (RS corrige hasta 11)

---

## 🐛 Solución de problemas

### Error: "make: command not found"
```bash
sudo apt-get install make
```

### Error: "nasm: command not found"
```bash
sudo apt-get install nasm
```

### Error al compilar (arquitectura 64 bits)
```bash
sudo apt-get install gcc-multilib
```

### Error al enlazar con io.o
Verificar que `io.o` e `io.mac` estén en la raíz del proyecto.

### QR no decodifica correctamente
1. Verificar que el archivo PBM sea formato P1
2. Verificar tamaño 25×25
3. Si hay múltiples errores, el ECC no podrá corregir (solo 1 error)

---

## 📊 Estado del proyecto

| Componente | Estado | Responsable |
|------------|--------|-------------|
| Codificación BYTE | ✅ | Vale |
| Generación de matriz | ✅ | Vale |
| Colocación zigzag | ✅ | Vale |
| ECC codificador | ✅ | Melissa |
| Detección de patrones | ✅ | Melissa |
| Extracción zigzag | ✅ | Melissa |
| Decodificación BYTE | ✅ | Melissa |
| ECC decodificador | ✅ | Melissa |
| Integración completa | ✅ | Ambas |

---

## 👥 Autores

- **Melissa** - Decodificación e integración ECC
- **Vale** - Codificación y generación de matriz

**Proyecto 2 - Arquitectura de Computadoras**
**Instituto Tecnológico de Costa Rica**
**2025**
# asm
