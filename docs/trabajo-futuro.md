# Trabajo futuro

1. **PGM binario (P5) y color (PPM P3/P6).** Son los formatos más comunes; P6 implicaría `type Pixel = (Int, Int, Int)` y filtros por canal.
2. **Arreglos o `Data.Vector` para rendimiento.** Las listas tienen acceso O(n); con arreglos inmutables el desenfoque y las rotaciones serían mucho más rápidos en fotos grandes.
3. **Detección de bordes con Sobel.** Es otra convolución 3x3, así que reutiliza la idea de `blur` con otra matriz de pesos.
4. **Huffman o LZ77 además de RLE.** RLE solo gana con regiones planas (como tras `threshold`); en fotos reales Huffman o LZ77 comprimen mejor.
5. **Procesamiento en paralelo.** Al ser funciones puras, las filas se pueden procesar en paralelo (por ejemplo con `Control.Parallel.Strategies`) sin riesgo de condiciones de carrera.
6. **Pruebas por propiedades con QuickCheck.** Comprobar con miles de imágenes aleatorias leyes como `decompress . compress == id` o `rotateLeft . rotateRight == id`.
7. **Bordes en el desenfoque.** Hoy `blur` reduce la imagen 2 píxeles por lado; se podría repetir el borde para conservar el tamaño.
8. **Guardar el archivo comprimido.** Definir un formato de texto para `Compressed` y poder abrirlo y descomprimirlo desde la GUI.
