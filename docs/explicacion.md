# Cómo funciona latent, con pruebas de escritorio

Este documento explica el proyecto función por función. Cada una tiene tres partes:

1. **La idea**, contada con algo cotidiano.
2. **La prueba de escritorio**, con un ejemplo chiquito y todos los pasos a mano.
3. **Compruébalo tú**, la línea que puedes escribir en `ghci` para ver que el resultado es el mismo.

Las funciones que llevan la marca **Escrita por Jesús** son las que escribí yo antes de usar la IA.

---

## 0. Cómo leer las pruebas de escritorio

En Haskell una prueba de escritorio se hace **sustituyendo**, igual que en álgebra. Si sabes que `doble x = x + x`, entonces:

```
doble 3
= 3 + 3        -- sustituyo x por 3
= 6
```

Cada renglón que empieza con `=` es el mismo valor escrito de otra forma, cada vez más simple, hasta que ya no se puede simplificar. Eso es todo el truco. Con recursión es igual: la función se vuelve a llamar, la sustituyes otra vez, y así hasta llegar al caso base.

Para comprobar en `ghci`, abre una terminal en la carpeta del proyecto y carga el archivo del módulo:

```bash
ghci -isrc src/Image/Compression.hs
```

Así puedes usar todas las funciones de ese archivo, incluso las auxiliares como `runs`. Para salir escribe `:q`.

---

## 1. La imagen es una tabla de números

Una imagen en gris es una hoja cuadriculada. Cada cuadrito tiene un número del 0 al 255: el 0 es negro, el 255 es blanco y lo de en medio son grises.

En casi todo el documento usamos esta imagen de 4 columnas y 3 filas, llamada `mini`:

```
  0   50  100  150
200  250  255    0
 10   20   30   40
```

En Haskell es una lista de filas:

```haskell
mini = [[0,50,100,150],[200,250,255,0],[10,20,30,40]]

type Image  = [[Int]]          -- una lista de filas de enteros
type Filter = Image -> Image   -- una máquina: entra una imagen, sale otra
```

Que un filtro sea solo una función es la idea más importante del proyecto: los filtros se pueden guardar en listas y encadenar.

### `width` y `height`

**Escritas por Jesús.**

```haskell
width [] = 0
width (fila:_) = length fila

height [] = 0
height filas = length filas
```

**Prueba de escritorio**

```
width mini
= width ([0,50,100,150] : resto)    -- el patrón (fila:_) toma la primera fila
= length [0,50,100,150]
= 4

height mini
= length [[0,50,100,150],[200,250,255,0],[10,20,30,40]]
= 3                                  -- hay tres filas

width []
= 0                                  -- caso de la imagen vacía
```

**Compruébalo tú:** `ghci -isrc src/Image.hs` y luego `width [[0,50,100,150],[200,250,255,0],[10,20,30,40]]`

---

## 2. Leer y escribir el archivo

Un archivo PGM P2 es texto. Primero dice el formato, luego ancho y alto, luego el valor del blanco y al final los píxeles. GIMP además agrega un comentario que empieza con `#` y pone un número por renglón.

### `onRows`

**Escrita por Jesús.**

```haskell
onRows _ [] = []
onRows n lista = take n lista : onRows n (drop n lista)
```

La idea: tienes una tira larga de números y unas tijeras. Cortas los primeros `n`, esa es una fila, y repites con lo que sobró.

**Prueba de escritorio** con `onRows 3 [1,2,3,4,5,6,7]`

| Vuelta | Lista que recibe | `take 3` es la fila | `drop 3` es lo que sobra |
|---|---|---|---|
| 1 | `[1,2,3,4,5,6,7]` | `[1,2,3]` | `[4,5,6,7]` |
| 2 | `[4,5,6,7]` | `[4,5,6]` | `[7]` |
| 3 | `[7]` | `[7]` | `[]` |
| 4 | `[]` | caso base, regresa `[]` | |

Escrito como sustitución:

```
onRows 3 [1,2,3,4,5,6,7]
= [1,2,3] : onRows 3 [4,5,6,7]
= [1,2,3] : [4,5,6] : onRows 3 [7]
= [1,2,3] : [4,5,6] : [7] : onRows 3 []
= [1,2,3] : [4,5,6] : [7] : []
= [[1,2,3],[4,5,6],[7]]
```

Fíjate en la vuelta 3: `take 3 [7]` no truena aunque falten números, solo da lo que hay.

**Compruébalo tú:** `ghci -isrc src/Image.hs` y luego `onRows 3 [1..7]`

### `parsePgm`

**Escrita por Jesús.**

```haskell
parsePgm text = parseImage
    where
        allLines = lines text
        noComments = filter(not .isPrefixOf "#") allLines
        wordText = words(unwords noComments)
        ( _ : widthText: _ : _ : rest ) = wordText
        parseImage = (onRows (read widthText :: Int) (map read rest :: [Int]))
```

**Prueba de escritorio** con un archivo como los de GIMP, de 2 por 2:

```
P2
# Created by GIMP
2 2
255
10
20
30
40
```

| Paso | Qué hace | Cómo queda |
|---|---|---|
| `lines` | parte en renglones | `["P2","# Created by GIMP","2 2","255","10","20","30","40"]` |
| `filter` | quita los que empiezan con `#` | `["P2","2 2","255","10","20","30","40"]` |
| `unwords` | junta todo con espacios | `"P2 2 2 255 10 20 30 40"` |
| `words` | separa por palabras | `["P2","2","2","255","10","20","30","40"]` |
| patrón | `_` ignora `P2`, `widthText` toma `"2"`, ignora alto y 255 | `widthText = "2"`, `rest = ["10","20","30","40"]` |
| `map read rest` | palabras a números | `[10,20,30,40]` |
| `onRows 2` | corta en filas de 2 | `[[10,20],[30,40]]` |

El truco de `unwords` y luego `words` es que no importa si los números venían uno por renglón o varios: al final todo queda en una sola lista de palabras.

**Compruébalo tú:** `ghci -isrc src/Image/Pgm.hs` y luego `parsePgm "P2\n# Created by GIMP\n2 2\n255\n10\n20\n30\n40\n"`

### `renderPgm`

**Escrita por Jesús.**

```haskell
renderPgm image = listRender
    where
        headers = ["P2", unwords ([show(width image), show(height image)]), "255"]
        allRowsText = map (\row -> unwords (map show row)) image
        listRender = unlines(headers ++ allRowsText)
```

**Prueba de escritorio** con `renderPgm [[10,20],[30,40]]`

| Paso | Cómo queda |
|---|---|
| `width` y `height` | `2` y `2` |
| `headers` | `["P2", "2 2", "255"]` |
| `map show [10,20]` y luego `unwords` | `"10 20"` |
| `map show [30,40]` y luego `unwords` | `"30 40"` |
| `allRowsText` | `["10 20","30 40"]` |
| `headers ++ allRowsText` | `["P2","2 2","255","10 20","30 40"]` |
| `unlines` | `"P2\n2 2\n255\n10 20\n30 40\n"` |

Es el camino de regreso de `parsePgm`: si lees lo que escribió `renderPgm`, recuperas la misma imagen.

**Compruébalo tú:** `renderPgm [[10,20],[30,40]]`

### `readPgm` y `writePgm`

**Escritas por Jesús.** Viven en `app/Main.hs`. `readPgm` lee el archivo del disco y le pasa el texto a `parsePgm`. `writePgm` convierte la imagen con `renderPgm` y la escribe. Son las únicas que tocan archivos, por eso viven en `app/`.

---

## 3. Tres herramientas que usan todos los filtros

Viven en `src/Image.hs`.

### `clamp`: el tope

```haskell
clamp p = max 0 (min 255 p)
```

Como el tope de una puerta: no te deja pasar de 255 ni bajar de 0.

**Prueba de escritorio**

| `p` | `min 255 p` | `max 0` de eso | resultado |
|---|---|---|---|
| `-20` | `-20` | `0` | `0` |
| `128` | `128` | `128` | `128` |
| `300` | `255` | `255` | `255` |

**Compruébalo tú:** `ghci -isrc src/Image.hs` y luego `map clamp [-20,128,300]`

### `applyPixel`: el sello

```haskell
applyPixel f = map (map f)
```

Un sello que estampas en cada cuadrito. El `map` de afuera recorre filas, el de adentro recorre los píxeles de cada fila.

**Prueba de escritorio** con `applyPixel (+1) [[1,2],[3,4]]`

```
applyPixel (+1) [[1,2],[3,4]]
= map (map (+1)) [[1,2],[3,4]]
= [ map (+1) [1,2] , map (+1) [3,4] ]     -- el map de afuera, fila por fila
= [ [2,3] , [4,5] ]                       -- el map de adentro, píxel por píxel
```

Lo interesante: `applyPixel (+1)`, sin la imagen, ya es un filtro completo esperando su imagen. A eso se le llama **aplicación parcial**.

**Compruébalo tú:** `applyPixel (+1) [[1,2],[3,4]]`

### `applyChain`: la línea de producción

```haskell
applyChain [] = id
applyChain (f:fs) = applyChain fs . f
```

La imagen pasa por la primera estación, luego por la segunda, y así. `id` es la función que no cambia nada. El punto `.` quiere decir "primero lo de la derecha, luego lo de la izquierda".

**Prueba de escritorio** con `applyChain [brightness 100, threshold 200] [[0,150]]`

```
applyChain [brightness 100, threshold 200] [[0,150]]
= (applyChain [threshold 200] . brightness 100) [[0,150]]   -- segunda regla, f = brightness 100
= applyChain [threshold 200] (brightness 100 [[0,150]])     -- el punto: primero brightness
= applyChain [threshold 200] [[100,250]]                    -- 0+100 y 150+100
= (applyChain [] . threshold 200) [[100,250]]               -- segunda regla otra vez
= applyChain [] (threshold 200 [[100,250]])
= applyChain [] [[0,255]]                                   -- 100 no llega a 200, 250 sí
= id [[0,255]]                                              -- primera regla, lista vacía
= [[0,255]]
```

**¿Importa el orden?** Sí. Al revés da otra cosa:

```
applyChain [threshold 200, brightness 100] [[0,150]]
= brightness 100 (threshold 200 [[0,150]])
= brightness 100 [[0,0]]          -- ni 0 ni 150 llegan a 200
= [[100,100]]
```

Por eso decimos que la cadena va de izquierda a derecha.

**Compruébalo tú:** `ghci -isrc src/Image/Pointwise.hs`, luego `:module + *Image` y luego `applyChain [brightness 100, threshold 200] [[0,150]]`

---

## 4. Filtros que cambian cada píxel

Viven en `src/Image/Pointwise.hs`. Todos son el sello `applyPixel` con una regla distinta.

```haskell
negative          = applyPixel (\p -> 255 - p)
brightness n      = applyPixel (clamp . (+ n))
threshold t       = applyPixel (\p -> if p >= t then 255 else 0)
intensity percent = applyPixel (\p -> clamp (p * percent `div` 100))
```

**Prueba de escritorio** con la fila `[0,100,250]`. Cada columna es un píxel:

| Filtro | Regla | `0` | `100` | `250` |
|---|---|---|---|---|
| `negative` | `255 - p` | `255` | `155` | `5` |
| `brightness 30` | suma 30 y luego tope | `30` | `130` | `280` → `255` |
| `brightness (-50)` | resta 50 y luego tope | `-50` → `0` | `50` | `200` |
| `threshold 128` | ¿llega a 128? | no → `0` | no → `0` | sí → `255` |
| `intensity 50` | `p * 50 div 100` | `0` | `50` | `125` |
| `intensity 150` | `p * 150 div 100` y tope | `0` | `150` | `375` → `255` |

Sobre `brightness`: `clamp . (+ n)` se lee "primero suma n, luego clamp". Con el 250:

```
(clamp . (+ 30)) 250
= clamp ((+ 30) 250)
= clamp 280
= 255
```

La firma `brightness :: Int -> Filter` dice "dame un número y te regreso un filtro". `brightness 30` todavía no tiene imagen: es una receta a medio llenar, lista para meterse en una cadena.

**Compruébalo tú:** `ghci -isrc src/Image/Pointwise.hs` y luego `brightness 30 [[0,100,250]]`

---

## 5. Filtros que mueven los píxeles

Viven en `src/Image/Geometry.hs`. Los números no cambian de valor, solo de lugar. Para que se vea claro usamos una imagen de 3 por 2:

```
1  2  3
4  5  6
```

### Los espejos

```haskell
mirrorHorizontal = map reverse
mirrorVertical   = reverse
```

**Prueba de escritorio**

```
mirrorHorizontal [[1,2,3],[4,5,6]]
= map reverse [[1,2,3],[4,5,6]]
= [reverse [1,2,3], reverse [4,5,6]]
= [[3,2,1],[6,5,4]]                   -- cada fila al revés, como un espejo

mirrorVertical [[1,2,3],[4,5,6]]
= reverse [[1,2,3],[4,5,6]]
= [[4,5,6],[1,2,3]]                   -- las filas al revés, como un reflejo en el agua
```

### `columns`: leer la tabla por columnas

```haskell
columns [] = []
columns ([]:_) = []
columns rows = concatMap (take 1) rows : columns (map (drop 1) rows)
```

En cada vuelta toma el primer número de cada fila, con eso arma una fila nueva, y le quita ese número a cada fila.

**Prueba de escritorio** con `columns [[1,2,3],[4,5,6]]`

| Vuelta | Filas que recibe | `concatMap (take 1)` es la fila nueva | `map (drop 1)` es lo que queda |
|---|---|---|---|
| 1 | `[[1,2,3],[4,5,6]]` | `[1,4]` | `[[2,3],[5,6]]` |
| 2 | `[[2,3],[5,6]]` | `[2,5]` | `[[3],[6]]` |
| 3 | `[[3],[6]]` | `[3,6]` | `[[],[]]` |
| 4 | `[[],[]]` | la primera fila está vacía, regla `([]:_)`, regresa `[]` | |

```
columns [[1,2,3],[4,5,6]]
= [1,4] : columns [[2,3],[5,6]]
= [1,4] : [2,5] : columns [[3],[6]]
= [1,4] : [2,5] : [3,6] : columns [[],[]]
= [1,4] : [2,5] : [3,6] : []
= [[1,4],[2,5],[3,6]]
```

### Girar

```haskell
rotateRight = map reverse . columns
rotateLeft  = reverse . columns
```

**Prueba de escritorio**

```
rotateRight [[1,2,3],[4,5,6]]
= map reverse (columns [[1,2,3],[4,5,6]])
= map reverse [[1,4],[2,5],[3,6]]
= [[4,1],[5,2],[6,3]]

rotateLeft [[1,2,3],[4,5,6]]
= reverse (columns [[1,2,3],[4,5,6]])
= reverse [[1,4],[2,5],[3,6]]
= [[3,6],[2,5],[1,4]]
```

Dibujado:

```
original      rotateRight      rotateLeft
1  2  3          4  1             3  6
4  5  6          5  2             2  5
                 6  3             1  4
```

Toma una hoja, escribe la original y gírala a la derecha: el 1, que estaba arriba a la izquierda, termina arriba a la derecha. Eso dice la tabla. Y si giras a la izquierda lo que giraste a la derecha, regresas a la original.

**Compruébalo tú:** `ghci -isrc src/Image/Geometry.hs` y luego `columns [[1,2,3],[4,5,6]]` y `rotateRight [[1,2,3],[4,5,6]]`

---

## 6. El desenfoque

Vive en `src/Image/Convolution.hs`. Cada píxel se vuelve el promedio de su vecindario de 3 por 3, como cuando ves algo sin lentes.

```haskell
sums3 row = zipWith3 (\a b c -> a + b + c) row (drop 1 row) (drop 2 row)

blurRows top mid bottom = zipWith3 (\a b c -> (a + b + c) `div` 9) (sums3 top) (sums3 mid) (sums3 bottom)

blur image = zipWith3 blurRows image (drop 1 image) (drop 2 image)
```

`zipWith3` toma tres listas y va combinando el primero de cada una, luego el segundo de cada una, y así. Se detiene cuando se acaba la lista más corta.

### Prueba de escritorio de `sums3`

Con la primera fila de `mini`. Pongo las tres listas una debajo de otra para que se vean las columnas:

```
row         =  0   50   100   150
drop 1 row  = 50  100   150
drop 2 row  = 100 150
              ---  ---
suma        = 150  300          -- la tercera lista ya se acabó, ahí para
```

Cada columna son tres vecinos seguidos. Resultado: `[150,300]`.

### Prueba de escritorio de `blur mini`

`blur` hace el mismo truco pero con filas enteras:

```
image         = fila0  fila1  fila2
drop 1 image  = fila1  fila2
drop 2 image  = fila2
```

Solo se forma un grupo: `fila0, fila1, fila2`. Entonces:

| Paso | Primera ventana | Segunda ventana |
|---|---|---|
| `sums3` de la fila 0 `[0,50,100,150]` | `0+50+100 = 150` | `50+100+150 = 300` |
| `sums3` de la fila 1 `[200,250,255,0]` | `200+250+255 = 705` | `250+255+0 = 505` |
| `sums3` de la fila 2 `[10,20,30,40]` | `10+20+30 = 60` | `20+30+40 = 90` |
| suma de las tres | `150+705+60 = 915` | `300+505+90 = 895` |
| `div 9` | `101` | `99` |

Resultado: `[[101,99]]`.

**¿Por qué se encoge?** A los píxeles del borde les faltan vecinos. En lugar de inventarlos, solo calculamos donde cabe la ventana completa. Por eso se pierde un píxel por lado: de 4 por 3 pasamos a 2 por 1.

**Compruébalo tú:** `ghci -isrc src/Image/Convolution.hs` y luego `sums3 [0,50,100,150]` y `blur [[0,50,100,150],[200,250,255,0],[10,20,30,40]]`

---

## 7. La compresión RLE

Vive en `src/Image/Compression.hs`.

Si dictas por teléfono "cero, cero, cero, doscientos cincuenta y cinco, doscientos cincuenta y cinco..." te cansas. Es más fácil decir "tres ceros, cuatro doscientos cincuenta y cinco". Eso es RLE. A cada grupo de valores iguales seguidos le decimos **racha**.

```haskell
type Compressed = (Int, [(Int, Int)])   -- el ancho y la lista de rachas (cuántas, qué valor)
```

### `span`, la pieza clave

`span (== p) lista` camina por la lista mientras los números sean iguales a `p`, y la parte en dos: lo que caminó y lo que sobró.

```
span (== 0) [0,0,255,255,255,255,0,0,0,0,0]
= ([0,0], [255,255,255,255,0,0,0,0,0])
```

### `runs`

```haskell
runs [] = []
runs (p:ps) = (1 + length same, p) : runs rest
    where
        (same, rest) = span (== p) ps
```

**Prueba de escritorio** con `runs [0,0,0,255,255,255,255,0,0,0,0,0]`, que es `threshold 128 mini` aplanada.

| Vuelta | `p` | `ps` | `same` | `rest` | racha `(1 + length same, p)` |
|---|---|---|---|---|---|
| 1 | `0` | `[0,0,255,255,255,255,0,0,0,0,0]` | `[0,0]` | `[255,255,255,255,0,0,0,0,0]` | `(3,0)` |
| 2 | `255` | `[255,255,255,0,0,0,0,0]` | `[255,255,255]` | `[0,0,0,0,0]` | `(4,255)` |
| 3 | `0` | `[0,0,0,0]` | `[0,0,0,0]` | `[]` | `(5,0)` |
| 4 | | lista vacía | | | caso base, `[]` |

Se suma 1 porque `same` no incluye a `p`, y `p` también cuenta. Resultado: `[(3,0),(4,255),(5,0)]`.

### `compress`

```haskell
compress image = (width image, runs (concat image))
```

```
compress [[0,0,0,255],[255,255,255,0],[0,0,0,0]]
= (width ..., runs (concat ...))
= (4, runs [0,0,0,255,255,255,255,0,0,0,0,0])
= (4, [(3,0),(4,255),(5,0)])
```

### `decompress`

```haskell
decompress (w, rs) = onRows w (concatMap (\(n, v) -> replicate n v) rs)
```

**Prueba de escritorio** con `decompress (4,[(3,0),(4,255),(5,0)])`

| Paso | Cómo queda |
|---|---|
| `replicate 3 0` | `[0,0,0]` |
| `replicate 4 255` | `[255,255,255,255]` |
| `replicate 5 0` | `[0,0,0,0,0]` |
| `concatMap` los pega | `[0,0,0,255,255,255,255,0,0,0,0,0]` |
| `onRows 4` | `[[0,0,0,255],[255,255,255,0],[0,0,0,0]]` |

Regresamos exactamente a la imagen de antes. Y fíjate: para descomprimir usamos `onRows`, la misma función que escribí para leer archivos.

### Los tamaños

```haskell
originalSize image = width image * height image
compressedSize (_, rs) = 2 * length rs
```

| Imagen | `originalSize` | rachas | `compressedSize` | ¿Conviene? |
|---|---|---|---|---|
| `threshold 128 mini` | `4 * 3 = 12` | 3 | `2 * 3 = 6` | sí, la mitad |
| `mini` | `12` | 12, ningún vecino se repite | `2 * 12 = 24` | no, el doble |
| la foto `sample.pgm` | `32000` | `5759` | `11518` | sí, 35 por ciento |
| la foto con `threshold 128` | `32000` | `475` | `950` | sí, menos del 3 por ciento |

RLE gana cuando hay muchos píxeles iguales seguidos y pierde cuando todo cambia todo el tiempo.

**Compruébalo tú:** `ghci -isrc src/Image/Compression.hs` y luego `runs [0,0,0,255,255,255,255,0,0,0,0,0]` y `decompress (4,[(3,0),(4,255),(5,0)])`

---

## 8. El protocolo: la ventanilla

Vive en `src/Protocol.hs`.

Imagina una ventanilla de trámites. Te pasan una hoja: arriba dice qué quieren y abajo viene la imagen. La ventanilla revisa la imagen, hace el trámite y regresa otra hoja con el resultado o con el motivo del error. Esa ventanilla es una sola función pura:

```haskell
handleRequest :: String -> String
```

Antes de ver la función completa, veamos sus piezas.

### `splitOn`: cortar un texto en un separador

```haskell
splitOn sep text = case break (== sep) text of
    (piece, []) -> [piece]
    (piece, _ : rest) -> piece : splitOn sep rest
```

`break` es como `span` pero al revés: camina hasta encontrar el separador.

**Prueba de escritorio** con `splitOn ',' "brightness:30,rotateRight"`

```
splitOn ',' "brightness:30,rotateRight"
-- break da ("brightness:30", ",rotateRight"), sí hay coma
= "brightness:30" : splitOn ',' "rotateRight"
-- break da ("rotateRight", ""), ya no hay coma
= "brightness:30" : ["rotateRight"]
= ["brightness:30","rotateRight"]
```

### `readInt`: leer un número sin tronar

```haskell
readInt ('-' : ds) = fmap negate (readInt ds)
readInt ds
    | isNatural ds && length ds <= 9 = Just (read ds)
    | otherwise = Nothing
```

`read` truena si le das letras. `readInt` primero revisa y regresa un `Maybe`: `Just` con el número si se pudo, o `Nothing` si no. Piensa en `Maybe` como una caja que puede venir llena o vacía.

**Prueba de escritorio**

```
readInt "-15"
= fmap negate (readInt "15")      -- primera regla, empieza con '-'
= fmap negate (Just 15)           -- "15" son puros dígitos
= Just (-15)                      -- fmap aplica negate adentro de la caja

readInt "abc"
= Nothing                         -- "abc" no son dígitos, la guarda otherwise
```

### `commandFilter`: de palabras a filtro

```haskell
commandFilter ["negative"] = Just negative
commandFilter ["brightness", n] = fmap brightness (readInt n)
...
commandFilter ("chain" : parts) = fmap applyChain (chainFilters (splitOn ',' (concat parts)))
commandFilter _ = Nothing
```

Haskell prueba las reglas de arriba hacia abajo y usa la primera que encaje. La última, con `_`, atrapa todo lo que no reconoció.

**Prueba de escritorio**

| Palabras | Regla que encaja | Resultado |
|---|---|---|
| `["negative"]` | la primera | `Just negative` |
| `["brightness","30"]` | la de brightness | `fmap brightness (Just 30)` = `Just (brightness 30)` |
| `["brightness","abc"]` | la de brightness | `fmap brightness Nothing` = `Nothing` |
| `["sepia"]` | ninguna, cae en `_` | `Nothing` |

### `chainFilters` y `stepFilter`: armar una cadena

```haskell
chainFilters [] = Just []
chainFilters (step : steps) = case (stepFilter step, chainFilters steps) of
    (Just f, Just fs) -> Just (f : fs)
    _ -> Nothing
```

**Prueba de escritorio** con `chainFilters ["brightness:30","rotateRight"]`

```
chainFilters ["brightness:30","rotateRight"]
-- stepFilter "brightness:30" = commandFilter ["brightness","30"] = Just (brightness 30)
-- y falta resolver chainFilters ["rotateRight"]:
--     stepFilter "rotateRight" = Just rotateRight
--     chainFilters [] = Just []
--     los dos son Just, entonces Just [rotateRight]
-- los dos son Just, entonces:
= Just [brightness 30, rotateRight]
```

Si un solo paso falla, todo falla:

```
chainFilters ["brightness:30","foo"]
-- stepFilter "foo" = commandFilter ["foo"] = Nothing
-- chainFilters ["foo"] cae en el caso _
= Nothing
```

### `validatePgm`: el inspector

```haskell
validatePgm text = validateTokens (words (unwords (filter (not . isPrefixOf "#") (lines text))))
    where
        validateTokens ("P2" : w : h : m : pixels)
            | not (all isNatural [w, h, m]) = Left "encabezado invalido"
            | m /= "255" = Left "solo se admite valor maximo 255"
            | read w < 1 || read h < 1 = Left "ancho y alto deben ser mayores que 0"
            | length pixels /= read w * read h = Left ("se esperaban ... y llegaron ...")
            | not (all isPixel pixels) = Left "hay pixeles que no son numeros entre 0 y 255"
            | otherwise = Right (parsePgm text)
        validateTokens (magic : _)
            | magic /= "P2" = Left "solo se admite el formato PGM P2"
        validateTokens _ = Left "PGM incompleto"
```

Regresa un `Either`: `Left` con el error o `Right` con la imagen. Es una caja con dos compartimentos, uno para la mala noticia y otro para la buena. Primero saca las palabras igual que `parsePgm`, y luego revisa las guardas en orden. La primera que se cumpla decide.

**Prueba de escritorio** con cuatro archivos:

| Archivo | Palabras | Qué pasa | Resultado |
|---|---|---|---|
| `P2 4 3 255 1 2 3` | encaja la primera regla, `pixels = ["1","2","3"]` | las tres primeras guardas pasan; `3 /= 4 * 3`, la cuarta se cumple | `Left "se esperaban 12 pixeles y llegaron 3"` |
| `P5 4 3 255` | no empieza con `"P2"`, salta a la segunda regla | `"P5" /= "P2"` | `Left "solo se admite el formato PGM P2"` |
| `P2 4` | muy pocas palabras para la primera regla; en la segunda `magic` sí es `"P2"`, la guarda falla y salta a la tercera | | `Left "PGM incompleto"` |
| `P2 2 1 255 10 300` | encaja la primera, todo bien hasta los píxeles | `300` pasa de 255 | `Left "hay pixeles que no son numeros entre 0 y 255"` |

El tercer caso enseña algo: si ninguna guarda de una regla se cumple, Haskell sigue con la siguiente regla.

### `handleRequest`: la ventanilla completa

```haskell
handleRequest request = case lines request of
    [] -> errorResponse "peticion vacia"
    (commandLine : pgmLines) -> case validatePgm (unlines pgmLines) of
        Left message -> errorResponse message
        Right image -> runCommand (words commandLine) image
```

**Prueba de escritorio** con un negativo de 2 por 2:

```
negative
P2
2 2
255
0 100
200 255
```

| Paso | Qué pasa | Cómo queda |
|---|---|---|
| `lines` | separa renglones | `["negative","P2","2 2","255","0 100","200 255"]` |
| patrón | primer renglón es el comando | `commandLine = "negative"`, el resto es la imagen |
| `validatePgm` | todo en orden | `Right [[0,100],[200,255]]` |
| `runCommand` | no es `compress`, busca filtro | `commandFilter ["negative"] = Just negative` |
| aplica | `255 - p` a cada píxel | `[[255,155],[55,0]]` |
| `imageResponse` | no quedó vacía, arma la respuesta | `"IMAGE\nP2\n2 2\n255\n255 155\n55 0\n"` |

Con `compress` y la imagen de 4 por 1 `0 0 0 255` la respuesta es:

```
STATS
originalSize 4
compressedSize 4
runs 2
percent 100
roundTrip True
```

Hay 2 rachas, `(3,0)` y `(1,255)`, que ocupan 4 números, el mismo tamaño que la original. `roundTrip True` dice que al descomprimir salió idéntica.

Con un comando que no existe, como `sepia`, la respuesta es `ERROR comando desconocido: sepia`.

**Compruébalo tú:** `ghci -isrc src/Protocol.hs` y luego `handleRequest "negative\nP2\n2 2\n255\n0 100\n200 255\n"`

---

## 9. El servidor: el mensajero

Vive en `app/Server.hs`. Es un mensajero que no abre los paquetes: recibe bytes, se los da a `handleRequest` y entrega la respuesta.

### `recvChunks`: leer a pedazos

```haskell
recvChunks conn = do
  chunk <- recv conn 4096
  if B.null chunk
    then return []
    else fmap (chunk :) (recvChunks conn)
```

La red no entrega todo de golpe, entrega pedazos. Cuando Python termina de mandar, llega un pedazo vacío.

**Prueba de escritorio** con la foto, que pesa unos 123000 bytes. Supón que llega en pedazos A, B, C y luego uno vacío:

| Vuelta | Llega | ¿Vacío? | Qué hace |
|---|---|---|---|
| 1 | A | no | guarda A y pide más |
| 2 | B | no | guarda B y pide más |
| 3 | C | no | guarda C y pide más |
| 4 | vacío | sí | caso base, regresa `[]` |

Al regresar se arma `A : B : C : []`, o sea `[A,B,C]`, y `recvAll` los pega con `B.concat`.

### `serve`: el ciclo que no es ciclo

```haskell
serve sock = do
  (conn, _) <- accept sock
  result <- try (handleConnection conn)
  case result of
    Left e -> putStrLn ("Error en la conexion: " ++ show e)
    Right () -> return ()
  close conn
  serve sock
```

Atiende una conexión y se llama a sí misma para la siguiente. Así se hace un ciclo infinito sin variables que cambian. `try` es una red de seguridad: si algo truena, imprime el error y sigue.

**Prueba de escritorio** con tres clics seguidos en la GUI:

| Llamada a `serve` | Petición | Qué pasa | ¿Sigue vivo? |
|---|---|---|---|
| 1 | `negative` con la foto | responde `IMAGE` | sí, se llama otra vez |
| 2 | `sepia` con la foto | `handleRequest` responde `ERROR comando desconocido` | sí, se llama otra vez |
| 3 | `blur` con la foto | responde `IMAGE` | sí, se queda esperando |

### `forceString`: Haskell es flojo

Haskell no calcula nada hasta que lo necesita. Si una respuesta fuera a tronar, no tronaría al llamar a `handleRequest`, sino a mitad del envío, cuando ya no se puede avisar. `forceString` compara cada letra de la respuesta con `'\0'`, y para comparar una letra Haskell tiene que calcularla. Así toda la respuesta se calcula dentro de la red de seguridad.

---

## 10. La demo por consola

Vive en `app/Main.hs`.

```haskell
filters = [ ("negative", negative), ("brightness", brightness 60), ... ]

main = do
  ...
  image <- readPgm "examples/sample.pgm"
  mapM_ (saveFiltered image) filters
```

`mapM_` es como un `map` que en lugar de regresar una lista hace una acción por cada elemento.

**Prueba de escritorio** de las dos primeras vueltas de `mapM_`:

| Vuelta | Par de la lista | `saveFiltered` hace | Imprime |
|---|---|---|---|
| 1 | `("negative", negative)` | escribe `negative image` en `output/negative.pgm` | `Listo: output/negative.pgm` |
| 2 | `("brightness", brightness 60)` | escribe `brightness 60 image` en `output/brightness.pgm` | `Listo: output/brightness.pgm` |

Y así con los 11 pares. Al final imprime los tamaños de la foto y de su versión en blanco y negro.

---

## 11. La interfaz en Python

Vive en `gui/app.py`. Python solo pone la ventana: elige el archivo, manda el texto, recibe la respuesta y la dibuja.

Solo hay un lugar donde Python toca los números: `p2_to_photo`. Tk no sabe dibujar PGM escrito como texto, solo en binario, así que Python reescribe los mismos números como bytes.

**Prueba de escritorio** con la imagen de 2 por 2 `10 20 30 40`:

| Paso | Cómo queda |
|---|---|
| palabras del texto | `["P2","2","2","255","10","20","30","40"]` |
| encabezado nuevo | `"P5\n2 2\n255\n"` |
| píxeles como bytes | los bytes 10, 20, 30 y 40 |

Los números son los mismos; solo cambia la forma de escribirlos, como pasar un texto de letra manuscrita a letra de molde. No es un filtro.

---

## 12. El viaje completo de un clic

Supón que tienes la foto abierta y presionas **Negativo**:

| Paso | Dónde | Qué pasa |
|---|---|---|
| 1 | Python | arma el texto `negative`, un salto de línea y la imagen |
| 2 | Python | se conecta al puerto 5000, manda el texto y avisa que terminó |
| 3 | `Server.hs` | `recvChunks` junta los pedazos y los convierte en texto |
| 4 | `Protocol.hs` | `handleRequest` valida, aplica `negative` y arma `IMAGE` con la imagen nueva |
| 5 | `Server.hs` | manda la respuesta y cierra la conexión |
| 6 | Python | quita la palabra `IMAGE`, pasa la imagen a binario y la dibuja |

Todo tarda alrededor de una décima de segundo, y la GUI te dice el tiempo exacto.

---

## 13. Por qué separar lo puro de lo demás

Piensa en un restaurante: la cocina prepara los platillos y el mesero los lleva. `src/` es la cocina: funciones puras que solo transforman datos. Con la misma entrada siempre dan la misma salida, y en su firma no aparece `IO`. `app/` es el mesero: lee archivos, abre sockets e imprime, con muy poco código.

Lo que ganamos:

- **Probar es fácil.** Todas las pruebas de escritorio de este documento se pueden correr en `ghci` sin levantar el servidor.
- **Todo se reutiliza.** La misma cocina sirve al servidor, a la demo por consola y a las pruebas.
- **No hay sorpresas.** Ninguna función pura cambia algo a escondidas. No usamos `IORef`, `MVar` ni `unsafePerformIO`, y los ciclos son recursión.

---

## 14. Preguntas que te puede hacer el profesor

**¿Dónde se procesa la imagen?**
Solo en Haskell. Python manda texto y dibuja lo que regresa. Lo único que hace con los números es reescribirlos en binario para poder dibujarlos, sin cambiar ninguno.

**¿Por qué dices que es funcional y no imperativo?**
Porque no hay variables que cambien ni ciclos. Todo se hace con funciones que reciben datos y regresan datos nuevos: recursión, `map`, `zipWith3`, `span`, composición y aplicación parcial.

**¿Qué significa `type Filter = Image -> Image`?**
Que un filtro es solo una función. Por eso los puedo guardar en una lista y encadenarlos con `applyChain`.

**¿Cómo funciona `applyChain`? Hazme la prueba de escritorio.**
Con `[brightness 100, threshold 200]` y `[[0,150]]`: primero brightness da `[[100,250]]`, luego threshold da `[[0,255]]`, y con la lista vacía queda `id`. Si inviertes el orden sale `[[100,100]]`, por eso el orden importa.

**¿Dónde usas aplicación parcial?**
En `brightness 30`: todavía no recibe la imagen, pero ya es un filtro que puedo guardar o encadenar. Igual `applyPixel (+1)`.

**¿Por qué el desenfoque hace la imagen más chica?**
Porque cada píxel se promedia con sus 8 vecinos y los del borde no los tienen completos. Solo calculo donde cabe el cuadro de 3 por 3, y se pierde un píxel por lado. Con `mini` sale `[[101,99]]`.

**¿Cómo funciona `runs`? Hazme la prueba de escritorio.**
Con `[0,0,0,255,255,255,255,0,0,0,0,0]`: `span` separa los dos ceros que siguen al primero, racha `(3,0)`; luego cuatro 255, racha `(4,255)`; luego cinco ceros, racha `(5,0)`; y con la lista vacía termina.

**¿Cómo sabes que la compresión no pierde información?**
Porque `roundTrip` descomprime lo comprimido y lo compara con la original, y hay pruebas que lo revisan.

**¿Qué pasa si mando un archivo roto?**
`validatePgm` lo detecta y regresa `Left` con el motivo. El servidor responde `ERROR` y sigue funcionando.

**¿Por qué el protocolo es una función de texto a texto?**
Para que sea pura y se pueda probar sin red. El servidor solo mueve bytes; si cambio los sockets por otra cosa, el protocolo se queda igual.
