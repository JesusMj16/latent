# Explicación del código

Las funciones marcadas con **(escrita por Jesús)** son las que escribí yo antes
de trabajar con la IA. El resto se agregó alrededor respetando mi estilo.

Imagen de prueba que se usa en todo el documento:

```haskell
mini = [[0,50,100,150],[200,250,255,0],[10,20,30,40]]
miniText = "P2\n4 3\n255\n0 50 100 150\n200 250 255 0\n10 20 30 40\n"
```

## 1. Por qué el núcleo es puro y el IO está solo en app/

Una función pura siempre da el mismo resultado con la misma entrada y no toca
el mundo exterior (archivos, red, pantalla). En Haskell eso se ve en el tipo:
si la firma no tiene `IO`, la función es pura.

- Todo `src/` es puro: filtros, compresión, lectura y escritura del texto PGM y
  el protocolo. Por eso se prueban con `check`, comparando valores.
- `app/Server.hs` y `app/Main.hs` tienen el IO: leer archivos, abrir sockets e
  imprimir. Son delgados: reciben datos, llaman a una función pura y entregan
  el resultado.
- Ventaja: la misma función `handleRequest` sirve para el servidor, para las
  pruebas y serviría para cualquier otra interfaz.

No se usa `IORef`, `MVar`, `STRef` ni `unsafePerformIO`. Los "ciclos" son
recursión (`serve` se llama a sí misma, `recvChunks` también).

## 2. Módulo `Image` (src/Image.hs)

```haskell
type Image = [[Int]]          -- lista de filas; cada fila es una lista de grises
type Filter = Image -> Image  -- un filtro es cualquier función de imagen a imagen
```

### `onRows :: Int -> [Int] -> [[Int]]` (escrita por Jesús)
Parte una lista plana en filas de `n` elementos. Recursión: toma `n` con `take`,
y se llama otra vez con lo que sobra (`drop n`). Caso base: lista vacía.

Prueba de escritorio con `onRows 4 [0,50,100,150,200,250,255,0,10,20,30,40]`:

1. `take 4` da `[0,50,100,150]`; sigue con `onRows 4 [200,250,255,0,10,20,30,40]`
2. `take 4` da `[200,250,255,0]`; sigue con `onRows 4 [10,20,30,40]`
3. `take 4` da `[10,20,30,40]`; sigue con `onRows 4 []`
4. Caso base: `[]`
5. Resultado: `[[0,50,100,150],[200,250,255,0],[10,20,30,40]]`, que es `mini`.

### `width :: Image -> Int` y `height :: Image -> Int` (escritas por Jesús)
`width` es el largo de la primera fila (patrón `fila:_`); `height` es el número
de filas. Ambas regresan 0 con la imagen vacía.

### `clamp :: Int -> Int`
`max 0 (min 255 p)`: si `p` pasa de 255 queda en 255; si es negativo queda en 0.
Evita grises imposibles después de sumar brillo.

### `applyPixel :: (Int -> Int) -> Filter`
`map (map f)`: el `map` de afuera recorre filas y el de adentro los píxeles.
Recibe una función de un píxel y regresa un filtro: es una función de orden
superior. Gracias a la aplicación parcial, `applyPixel (+1)` ya es un `Filter`.

### `applyChain :: [Filter] -> Filter`
```haskell
applyChain [] = id
applyChain (f:fs) = applyChain fs . f
```
Con lista vacía no hace nada (`id`). Si no, aplica `f` primero y luego el resto
(la composición `g . f` aplica `f` antes que `g`). Por eso el orden es de
izquierda a derecha: `applyChain [f, g, h] = h . g . f`.

## 3. Módulo `Image.Pgm` (src/Image/Pgm.hs)

### `parsePgm :: String -> Image` (escrita por Jesús)
1. `lines` separa el texto en líneas.
2. `filter (not . isPrefixOf "#")` quita los comentarios (como `# Created by GIMP`).
3. `words (unwords ...)` junta todo y lo separa en palabras, sin importar si
   los píxeles vienen uno por línea (GIMP) o varios por línea.
4. El patrón `(_ : widthText : _ : _ : rest)` ignora `P2`, toma el ancho, ignora
   el alto y el máximo, y deja los píxeles en `rest`.
5. `map read rest` convierte a números y `onRows` los parte en filas.

Prueba de escritorio con `miniText`:

1. `lines` da `["P2","4 3","255","0 50 100 150","200 250 255 0","10 20 30 40"]`
2. No hay comentarios, `filter` no quita nada.
3. `words (unwords ...)` da `["P2","4","3","255","0","50","100","150","200",...]`
4. Patrón: `widthText = "4"`, `rest = ["0","50",...,"40"]`
5. `onRows 4 [0,50,...,40]` da `mini`.

`parsePgm` supone que el texto es correcto; quien revisa eso es `validatePgm`
en `Protocol`, antes de llamarla.

### `renderPgm :: Image -> String` (escrita por Jesús)
Arma el encabezado `["P2", "ancho alto", "255"]`, convierte cada fila con
`unwords (map show row)` y une todo con `unlines`. Es la inversa de `parsePgm`:
`parsePgm (renderPgm mini) == mini`.

## 4. Módulo `Image.Pointwise` (filtros píxel por píxel)

Todos son `applyPixel` con una función distinta:

- `negative = applyPixel (\p -> 255 - p)`: negro a blanco y al revés.
- `brightness n = applyPixel (clamp . (+ n))`: suma `n` y luego recorta. La
  composición `clamp . (+ n)` es "primero suma, luego clamp". `n` puede ser negativo.
- `threshold t = applyPixel (\p -> if p >= t then 255 else 0)`: blanco y negro.
- `intensity percent`: multiplica por el porcentaje (`p * percent div 100`) y
  recorta. `intensity 150` aclara, `intensity 50` oscurece.

Su firma `Int -> Filter` significa: dale un número y te regresa un filtro.

## 5. Módulo `Image.Geometry`

- `columns` (auxiliar, transpuesta): toma el primer elemento de cada fila
  (`concatMap (take 1)`) como nueva fila y repite con el resto de cada fila
  (`map (drop 1)`). Se detiene cuando las filas quedan vacías.
- `mirrorHorizontal = map reverse`: invierte cada fila.
- `mirrorVertical = reverse`: invierte el orden de las filas.
- `rotateRight = map reverse . columns`: transpuesta y luego cada fila al revés.
- `rotateLeft = reverse . columns`: transpuesta y luego el orden de filas al revés.

Prueba de escritorio de `rotateRight mini`:

1. `columns mini`:
   - primeros de cada fila: `[0,200,10]`; resto: `[[50,100,150],[250,255,0],[20,30,40]]`
   - primeros: `[50,250,20]`; luego `[100,255,30]`; luego `[150,0,40]`
   - filas vacías: termina. Resultado `[[0,200,10],[50,250,20],[100,255,30],[150,0,40]]`
2. `map reverse`: `[[10,200,0],[20,250,50],[30,255,100],[40,0,150]]`

Una imagen de 4x3 queda de 3x4. La primera fila del resultado es la primera
columna leída de abajo hacia arriba, que es lo que pasa al girar a la derecha.

## 6. Módulo `Image.Compression` (RLE)

`type Compressed = (Int, [(Int, Int)])`: el ancho y una lista de rachas
`(cantidad, valor)`. Se guarda el ancho para poder volver a partir en filas.

- `runs` (auxiliar): `span (== p) ps` separa los valores iguales al primero del
  resto. La racha es `(1 + length same, p)` y se sigue recursivamente con `rest`.
- `compress image = (width image, runs (concat image))`: aplana y codifica.
- `decompress (w, rs) = onRows w (concatMap (\(n, v) -> replicate n v) rs)`:
  expande cada racha con `replicate` y reutiliza mi `onRows`.
- `originalSize`: ancho por alto, el número de enteros de la imagen.
- `compressedSize`: **2 enteros por racha** (cantidad y valor). No se cuenta el
  ancho, igual que no se cuenta el encabezado en el tamaño original.

Prueba de escritorio de `compress (threshold 128 mini)`:

1. `threshold 128 mini = [[0,0,0,255],[255,255,255,0],[0,0,0,0]]`
2. `concat`: `[0,0,0,255,255,255,255,0,0,0,0,0]`
3. `runs`: `p = 0`, `span` da `same = [0,0]`, racha `(3,0)`
4. `p = 255`, `same = [255,255,255]`, racha `(4,255)`
5. `p = 0`, `same = [0,0,0,0]`, racha `(5,0)`; luego `runs [] = []`
6. Resultado: `(4,[(3,0),(4,255),(5,0)])`. 12 enteros pasan a 6.

RLE solo conviene con regiones planas: `mini` sin umbral tiene 12 rachas de 1
y "comprimida" ocupa 24 (más que la original). La foto de ejemplo baja a 35%
y con `threshold 128` a menos de 3%.

## 7. Módulo `Image.Convolution` (blur)

- `sums3 row = zipWith3 (\a b c -> a + b + c) row (drop 1 row) (drop 2 row)`:
  alinea la fila con ella misma recorrida 1 y 2 lugares y suma de 3 en 3.
  `zipWith3` se detiene en la lista más corta, por eso solo salen las ventanas completas.
- `blurRows top mid bottom`: suma las ventanas de las 3 filas y divide entre 9.
- `blur image = zipWith3 blurRows image (drop 1 image) (drop 2 image)`: la misma
  idea con filas. La imagen pierde 1 píxel en cada borde (2 de ancho y 2 de alto).

Prueba de escritorio de `blur mini`:

1. Solo hay un trío de filas: fila 0, 1 y 2.
2. `sums3 [0,50,100,150] = [0+50+100, 50+100+150] = [150,300]`
3. `sums3 [200,250,255,0] = [705,505]`
4. `sums3 [10,20,30,40] = [60,90]`
5. Sumas: `150+705+60 = 915`, `300+505+90 = 895`
6. `div 9`: `915 div 9 = 101`, `895 div 9 = 99`. Resultado `[[101,99]]`.

## 8. Módulo `Protocol` (src/Protocol.hs)

`handleRequest :: String -> String` es todo el protocolo, y es puro.

- `handleRequest` separa la primera línea (comando) del resto (PGM). Si el PGM
  no es válido responde `ERROR`; si sí, llama a `runCommand`.
- `runCommand`: `compress` da estadísticas; lo demás busca un filtro con `commandFilter`.
- `commandFilter :: [String] -> Maybe Filter`: pattern matching sobre las
  palabras del comando. `Nothing` significa comando desconocido. `fmap brightness (readInt n)`
  aplica `brightness` solo si el número se pudo leer.
- `chainFilters`: convierte cada paso de la cadena por recursión. Si un paso es
  `Nothing`, toda la cadena es `Nothing`.
- `splitOn`: parte el texto en cada coma (o cada `:`) con `break`.
- `readInt`: lee enteros con signo sin tronar (`read` truena con texto inválido).
- `validatePgm :: String -> Either String Image`: revisa con guardas que el
  formato sea `P2`, que el encabezado sean números, que el máximo sea 255, que
  haya exactamente ancho por alto píxeles y que todos estén entre 0 y 255.
  `Left` lleva el mensaje de error y `Right` la imagen.
- `statsResponse`: tamaños, número de rachas, porcentaje y `roundTrip`, que
  comprueba `decompress (compress image) == image`.
- `imageResponse`: si el resultado quedó vacío (por ejemplo `blur` de una imagen
  de 2x2) responde error en vez de mandar una imagen de 0x0.

## 9. app/: el IO delgado

### `readPgm` y `writePgm` (escritas por Jesús), en app/Main.hs
`readPgm` lee el archivo y aplica `parsePgm`; `writePgm` aplica `renderPgm` y escribe.

### Demo por consola (`main` de app/Main.hs)
Lee `examples/sample.pgm`, crea `output/`, y con `mapM_ (saveFiltered image) filters`
guarda una imagen por cada par `(nombre, filtro)`. Imprime tamaños con `sizeReport`.

### Servidor (app/Server.hs)
- `main`: abre el socket en `127.0.0.1:5000` y llama a `serve`.
- `serve`: acepta una conexión, la atiende dentro de `try` (si truena, imprime
  el error y sigue vivo), cierra y se llama a sí misma.
- `recvChunks`: lee pedazos hasta que `recv` regresa vacío (el cliente cerró su
  lado de escritura). `recvAll` los une con `B.concat`.
- `handleConnection`: convierte a `String`, imprime una línea de registro,
  llama a `handleRequest` y manda la respuesta.
- `forceString`: Haskell es perezoso; esta función obliga a calcular toda la
  respuesta para que un error se capture con `try` y se responda `ERROR`.

## 10. Cómo viaja una petición

1. En la GUI presiono "Negativo". `gui/app.py` arma el texto `"negative\n" + PGM`.
2. Python abre un socket a `127.0.0.1:5000`, manda el texto y cierra su lado de escritura.
3. `Server.hs` lee hasta EOF con `recvChunks`, convierte los bytes a `String`.
4. `handleRequest` (puro) valida, aplica `negative` y regresa `"IMAGE\nP2\n..."`.
5. El servidor manda la respuesta y cierra la conexión.
6. Python quita la línea `IMAGE`, convierte P2 a P5 solo para que Tk lo pueda
   dibujar (no cambia ningún valor) y lo muestra a la derecha.

## 11. Preguntas que te puede hacer el profesor

1. **¿Dónde se procesa la imagen?** Solo en Haskell. Python manda texto y muestra la respuesta; la única conversión que hace es P2 a P5 para que Tk lo dibuje, sin cambiar valores.
2. **¿Por qué tu código es funcional y no imperativo?** No hay variables que cambien ni ciclos; uso recursión, `map`, `zipWith3`, `span`, composición y aplicación parcial. Todo `src/` es puro.
3. **¿Qué significa `type Filter = Image -> Image`?** Que un filtro es solo una función. Por eso puedo guardarlos en listas y componerlos con `applyChain`.
4. **¿Cómo funciona `applyChain`?** Con lista vacía es `id`; si no, `applyChain fs . f`: aplica `f` y luego el resto. El orden es de izquierda a derecha.
5. **¿Qué es la aplicación parcial en tu proyecto?** `brightness 30` aún no recibe la imagen: es un `Filter` listo para aplicarse. Igual `applyPixel (+1)`.
6. **¿Por qué `blur` reduce la imagen?** Solo promedia donde cabe la ventana 3x3 completa; en los bordes faltan vecinos, así que se pierden 1 píxel por lado.
7. **¿Cuándo conviene RLE?** Con regiones planas. En la foto baja a 35%; tras `threshold` baja a menos de 3%. En imágenes con mucho detalle puede ocupar más que la original.
8. **¿Cómo sabes que la compresión no pierde información?** `roundTrip` comprueba `decompress (compress img) == img`, y hay pruebas que lo verifican.
9. **¿Qué pasa si mando un archivo roto?** `validatePgm` regresa `Left` con un mensaje, el servidor responde `ERROR ...` y sigue funcionando.
10. **¿Por qué el protocolo es `String -> String`?** Para que sea puro y se pueda probar sin red. El servidor solo mueve bytes; si cambio sockets por otra cosa, el protocolo no cambia.
