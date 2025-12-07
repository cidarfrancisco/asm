# 🎯 INSTRUCCIONES PARA PROBAR EL PROYECTO


## Instalar dependencias
### Habilitar arquitectura i386
sudo dpkg --add-architecture i386
sudo apt update
 
### Instalar bibliotecas para compilar en 32 bits
sudo apt install gcc-multilib g++-multilib libc6-dev-i386
 
### Instalar una herramienta de Linux para convertir archivos bpm a png para verificar funcionamiento correcto
sudo apt install imagemagick
 
## ✅ TODO LISTO - Sigue estos pasos:

### **1. Compilar el proyecto**
```bash
cd ProyectoArqui2
make
```

**Resultado esperado:**
```
Compilando src/main.c...
Ensamblando src/asm/qr_decode.asm...
...
✓ Decodificador compilado
✓ Codificador compilado

======================================================
  ✓ Compilación exitosa
======================================================
```

---

### **2. Prueba rápida (Manual)**

#### **Paso A: Codificar texto**
```bash
./qr_encoder "Hola Mundo"
```

**Verás:**
```
[1/4] Codificando texto...
      Texto: "Hola Mundo" (10 caracteres)
      ✓ Texto codificado exitosamente

[2/4] Generando matriz QR...
      ✓ Patrones base generados

[3/4] Colocando datos en matriz...
      ✓ Datos colocados en patrón zigzag

[4/4] Guardando archivo PBM...
      Archivo: qr_output.pbm
      ✓ Archivo guardado correctamente
```

#### **Paso B: Decodificar QR**
```bash
./qr_decoder qr_output.pbm
```

**Verás:**
```
[1/3] Cargando archivo PBM...
      ✓ Archivo cargado correctamente

[2/3] Decodificando código QR...
      ✓ Decodificación completada

[3/3] Resultado:
---------------------------------------------------
  Texto decodificado:
  "Hola Mundo"
---------------------------------------------------
```

---

### **3. Pruebas automáticas (Recomendado)**

```bash
chmod +x test_qr.sh
./test_qr.sh
```

Esto ejecuta 4 pruebas:
1. Texto simple: "Hola"
2. Texto con espacios: "Hola TEC 2025"
3. Texto largo: "Costa Rica Pura Vida"
4. Máximo (32 caracteres)

---

### **4. Verificar integración ECC**

El sistema **automáticamente**:
- ✅ **Al codificar:** Genera 12 bytes de paridad (8 fila + 4 columna)
- ✅ **Al decodificar:** Detecta y corrige hasta 1 error

Para verificar:
```bash
# Codificar
./qr_encoder "Test ECC" test_ecc.pbm

# Decodificar (sin errores)
./qr_decoder test_ecc.pbm
```

**Si todo funciona, verás el texto original decodificado correctamente.**

---

## 🔍 ¿Qué cambios se hicieron?

### **Archivos nuevos:**
1. `src/encoder_main.c` - Programa principal del codificador
2. `src/asm/ecc_parity2d.asm` - Sistema de corrección de errores
3. `test_qr.sh` - Script de pruebas
4. `README.md` - Documentación completa
5. `ECC_INFO.md` - Documentación técnica ECC
6. `INSTRUCCIONES_PRUEBA.md` - Este archivo

### **Archivos modificados:**
1. `src/asm/qr_encode_data.asm` - Integrado ECC en codificación
2. `src/asm/qr_decode_data.asm` - Integrado ECC en decodificación
3. `makefile` - Soporte para ambos ejecutables

### **Sistema ECC:**
- ✅ Reemplazó Reed-Solomon por Paridad 2D
- ✅ Mucho más simple (250 líneas vs 500+)
- ✅ Corrige 1 error automáticamente
- ✅ 12 bytes overhead (vs 22 de RS)

---

## 🚨 Si algo falla:

### **Error de compilación:**
```bash
make clean
make
```

### **Archivos faltantes:**
Verifica que existan:
- `io.mac` (en raíz)
- `io.o` (en raíz)

### **Error de permisos:**
```bash
chmod +x qr_encoder
chmod +x qr_decoder
chmod +x test_qr.sh
```

### **El decodificador no funciona:**
- Verifica que el PBM sea formato P1
- Verifica tamaño 25×25
- Prueba con un QR recién generado

---

## 📝 Notas importantes:

1. **Límite de texto:** Máximo 32 caracteres
2. **Formato:** Solo modo BYTE (caracteres ASCII)
3. **Corrección:** Solo 1 error por bloque
4. **Archivos:** Formato PBM P1 (ASCII)

---

## ✨ Listo para entregar:

- ✅ Codificador funcional
- ✅ Decodificador funcional
- ✅ Corrección de errores integrada
- ✅ Pruebas automáticas
- ✅ Documentación completa

**¡El proyecto está completo y listo para probar!**
