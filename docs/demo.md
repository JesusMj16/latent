# Guion del demo (3 minutos)

**Antes de entrar:** laptop cargada, Wi-Fi apagado, terminal abierta en `~/Proyectos/latent`,
`runghc -isrc app/Main.hs` ya corrido una vez (plan de respaldo en `output/`).

| Tiempo | Qué hago | Qué digo |
|---|---|---|
| 0:00 | Muestro la hoja impresa. | "Es un filtro y compresor de imágenes PGM. Todo el procesamiento es Haskell puro; Python solo es la ventana." |
| 0:20 | Corro `./run.sh`. Señalo la línea "Servidor Haskell escuchando en 127.0.0.1:5000". | "Esto compila el servidor Haskell, lo arranca y abre la GUI de tkinter." |
| 0:40 | Clic en **Abrir PGM** y elijo `examples/sample.pgm`. | "La imagen viaja como texto por el socket; Haskell la valida y me la regresa." |
| 1:00 | Clic en **Negativo**, luego **Rotar a la derecha**, luego **Desenfoque 3x3**. Señalo la terminal. | "Cada clic es una petición; en la terminal se ve que Haskell la atendió. El desenfoque reduce 2 píxeles por lado porque solo promedia donde cabe la ventana 3x3." |
| 1:30 | Escribo `-60` en brillo y Enter, luego **Aplicar umbral** con `128`. | "Los parámetros viajan en el comando. `brightness` es `applyPixel (clamp . (+ n))`." |
| 1:50 | En el campo chain dejo `brightness:30,rotateRight,threshold:128` y clic en **Aplicar cadena**. | "Una cadena es `applyChain`, que compone los filtros de izquierda a derecha con recursión." |
| 2:15 | Clic en **Comprimir**. Leo la tarjeta. Luego **Aplicar umbral**, **Seguir desde el resultado** y otra vez **Comprimir**. | "La foto baja a 35%. En blanco y negro hay rachas largas y baja a menos de 3%. `roundTrip True` comprueba que descomprimir da la original." |
| 2:40 | Escribo `sepia` en el campo de cadena y presiono Enter. Leo la línea roja de estado. | "Si el comando o el PGM están mal, Haskell responde ERROR, la GUI lo muestra en rojo y el servidor sigue vivo. Cada mensaje dice cuántos ms tardó Haskell." |
| 2:50 | Clic en **Guardar resultado**. | "Como trabajo futuro: P5, color, Sobel, Huffman y QuickCheck." |

**Si la GUI falla:** `runghc -isrc app/Main.hs` y abro los archivos de `output/` en GIMP.
**Si me preguntan por las pruebas:** `runghc -isrc test/Tests.hs`.
