# Cómo funciona latent, explicado fácil

Este documento cuenta el proyecto de principio a fin, como si se lo explicaras a un amigo. Cada idea empieza con algo cotidiano y luego baja al código. Si entiendes este documento, puedes explicar cualquier línea del proyecto.

Las funciones que llevan la marca **Escrita por Jesús** son las que escribí yo antes de usar la IA. Todo lo demás se construyó alrededor de ellas, con mi mismo estilo.

---

## 1. La idea en una frase

Una imagen en escala de grises es una hoja cuadriculada donde cada cuadrito tiene un número del 0 al 255. El 0 es negro, el 255 es blanco y lo de en medio son grises.

Todo el proyecto hace tres cosas con esa hoja:

1. **Leerla** desde un archivo de texto.
2. **Cambiarle los números** siguiendo una regla. A eso le llamamos filtro.
3. **Guardarla** o **comprimirla** para que ocupe menos.

Eso es todo. Lo demás son detalles de cómo hacerlo bien.

---

## 2. La imagen es una tabla de números

Durante todo el documento vamos a usar esta imagen chiquita de 4 columnas y 3 filas. Le decimos `mini`:

```
  0   50  100  150
200  250  255    0
 10   20   30   40
```

En Haskell la guardamos como una lista de filas, y cada fila es una lista de números:

```haskell
mini = [[0,50,100,150],[200,250,255,0],[10,20,30,40]]
```

Por eso definimos dos nombres que usamos en todo el proyecto:

```haskell
type Image  = [[Int]]
type Filter = Image -> Image
```

`Image` es solo otra forma de decir "lista de listas de enteros". `Filter` es cualquier función que recibe una imagen y entrega otra. Piensa en un filtro como una máquina: entra una imagen por un lado y sale otra por el otro. Esta idea es la más importante del proyecto, porque si un filtro es solo una función, podemos guardar filtros en listas, pasarlos como datos y encadenarlos.

### `width` y `height`

**Escritas por Jesús.**

```haskell
width [] = 0
width (fila:_) = length fila

height [] = 0
height filas = length filas
```

El ancho es cuántos números tiene la primera fila. El alto es cuántas filas hay. Si la imagen está vacía, las dos regresan 0. El patrón `(fila:_)` significa "dame la primera fila y no me importa el resto".

---

## 3. Leer y escribir el archivo

Un archivo PGM P2 es texto normal. Así se ve `mini` guardada:

```
P2
4 3
255
0 50 100 150
200 250 255 0
10 20 30 40
```

La primera línea dice el formato. La segunda dice ancho y alto. La tercera dice cuál es el blanco más blanco. Después vienen los píxeles. GIMP además agrega una línea de comentario que empieza con `#`, y pone un número por línea, pero eso no nos importa, como vas a ver.

### `onRows`

**Escrita por Jesús.**

```haskell
onRows _ [] = []
onRows n lista = take n lista : onRows n (drop n lista)
```

Imagina que tienes una tira larga de números y unas tijeras. `onRows` corta los primeros `n`, los pone como una fila, y repite con lo que sobró. Cuando ya no queda tira, se detiene.

Así trabaja con `onRows 4 [0,50,100,150,200,250,255,0,10,20,30,40]`:

1. Corta `[0,50,100,150]` y sigue con lo demás.
2. Corta `[200,250,255,0]` y sigue.
3. Corta `[10,20,30,40]` y sigue con una lista vacía.
4. La lista vacía es el caso base: ya terminó.

Resultado: `[[0,50,100,150],[200,250,255,0],[10,20,30,40]]`, que es justo `mini`.

### `parsePgm`

**Escrita por Jesús.**

Convierte el texto del archivo en una imagen. Lo hace en cinco pasos sencillos:

1. `lines` parte el texto en renglones.
2. `filter (not . isPrefixOf "#")` tira los renglones que empiezan con `#`, o sea los comentarios.
3. `words (unwords ...)` junta todo y lo vuelve a separar por palabras. Gracias a esto da igual si GIMP puso un número por línea o varios: al final todo queda en una sola lista de palabras.
4. El patrón `( _ : widthText : _ : _ : rest )` funciona como un molde. Ignora `P2`, se queda con el ancho, ignora el alto y el 255, y deja todos los píxeles en `rest`.
5. `map read rest` convierte las palabras en números y `onRows` los corta en filas.

Con el texto de `mini` las palabras quedan así: `["P2","4","3","255","0","50",...]`. El molde toma `"4"` como ancho, y `onRows 4` arma la tabla.

`parsePgm` confía en que el texto viene bien escrito. Quien lo revisa antes es `validatePgm`, que veremos en el protocolo.

### `renderPgm`

**Escrita por Jesús.**

Hace el camino de regreso. Escribe el encabezado `P2`, el ancho y alto, y `255`. Luego convierte cada fila en un renglón de números separados por espacio y une todo con saltos de línea. Si lees con `parsePgm` lo que escribió `renderPgm`, recuperas la misma imagen.

### `readPgm` y `writePgm`

**Escritas por Jesús.** Viven en `app/Main.hs`.

`readPgm` lee un archivo del disco y se lo pasa a `parsePgm`. `writePgm` usa `renderPgm` y escribe el resultado en el disco. Son las únicas que tocan archivos, y por eso viven en `app/` y no en `src/`.

---

## 4. Tres herramientas que usan todos los filtros

Viven en `src/Image.hs`.

### `clamp`: el tope

```haskell
clamp p = max 0 (min 255 p)
```

Si aclaras un píxel que ya valía 250 y le sumas 40, te da 290, y ese gris no existe. `clamp` es como el tope de una puerta: si te pasas de 255 te deja en 255, y si bajas de 0 te deja en 0.

### `applyPixel`: el sello

```haskell
applyPixel f = map (map f)
```

Imagina que tienes un sello y quieres estampar cada cuadrito de la hoja. El `map` de afuera recorre las filas y el `map` de adentro recorre cada píxel de la fila. A cada uno le aplica `f`.

Lo interesante es lo que regresa. Le das una regla para un píxel y te devuelve un filtro completo. Por ejemplo, `applyPixel (+1)` ya es un filtro que suma 1 a toda la imagen, aunque todavía no le hayas dado ninguna imagen. A eso se le llama aplicación parcial: le das a una función solo una parte de lo que necesita y te regresa otra función lista para recibir el resto.

### `applyChain`: la línea de producción

```haskell
applyChain [] = id
applyChain (f:fs) = applyChain fs . f
```

Piensa en una línea de producción con varias estaciones. La imagen pasa por la primera, luego por la segunda, y así. `applyChain` recibe la lista de estaciones y arma la línea completa.

- Si la lista está vacía, la imagen no cambia. `id` es la función que regresa lo mismo que recibe.
- Si hay estaciones, aplica la primera, `f`, y luego el resto de la cadena.

El punto `.` es la composición: `g . f` quiere decir "primero `f` y luego `g`". Por eso `applyChain [f, g, h]` termina siendo `h . g . f`, y la imagen pasa por las estaciones en el orden en que las escribiste, de izquierda a derecha.

---

## 5. Filtros que cambian cada píxel

Viven en `src/Image/Pointwise.hs`. Todos son el mismo sello, `applyPixel`, con una regla distinta.

```haskell
negative     = applyPixel (\p -> 255 - p)
brightness n = applyPixel (clamp . (+ n))
threshold t  = applyPixel (\p -> if p >= t then 255 else 0)
intensity percent = applyPixel (\p -> clamp (p * percent `div` 100))
```

- **negative** voltea los tonos, como el negativo de una foto. Lo negro se vuelve blanco y al revés.
- **brightness** suma un número a cada píxel y luego pone el tope. `clamp . (+ n)` se lee "primero suma n, luego aplica clamp". Si el número es negativo, oscurece.
- **threshold** decide entre blanco y negro. Si el píxel llega al umbral, se vuelve blanco; si no, negro. Es como preguntarle a cada cuadrito "¿eres claro o eres oscuro?".
- **intensity** multiplica por un porcentaje. Con 150 aclara, con 50 oscurece.

Fíjate en la firma de `brightness`: `Int -> Filter`. Quiere decir "dame un número y te regreso un filtro". `brightness 30` todavía no tiene imagen. Es una receta a medio llenar que está lista para usarse, y por eso la podemos meter en una cadena.

---

## 6. Filtros que mueven los píxeles

Viven en `src/Image/Geometry.hs`. Aquí los números no cambian de valor, solo de lugar.

```haskell
mirrorHorizontal = map reverse
mirrorVertical   = reverse
```

Un espejo horizontal voltea cada fila, como verte en un espejo. Un espejo vertical voltea el orden de las filas, como un reflejo en el agua. Cada uno es una sola línea porque `reverse` ya sabe voltear una lista.

### Girar la imagen

Para girar necesitamos una función auxiliar, `columns`, que lee la tabla por columnas en lugar de por filas:

```haskell
columns [] = []
columns ([]:_) = []
columns rows = concatMap (take 1) rows : columns (map (drop 1) rows)
```

Toma el primer número de cada fila y con eso forma una fila nueva. Luego le quita ese primer número a cada fila y repite. Cuando las filas se quedan vacías, termina. `take 1` y `drop 1` nunca truenan, aunque la lista esté vacía, por eso las usamos.

Con eso, girar es fácil:

```haskell
rotateRight = map reverse . columns
rotateLeft  = reverse . columns
```

Así gira `mini` a la derecha:

1. `columns mini` lee las columnas: `[0,200,10]`, `[50,250,20]`, `[100,255,30]` y `[150,0,40]`.
2. `map reverse` voltea cada una: `[10,200,0]`, `[20,250,50]`, `[30,255,100]` y `[40,0,150]`.

Si tomas una hoja de papel y la giras a la derecha, la columna de la izquierda queda arriba, leída de abajo hacia arriba. Eso es exactamente lo que salió. La imagen tenía 4 de ancho y 3 de alto, y ahora tiene 3 de ancho y 4 de alto.

---

## 7. El desenfoque

Vive en `src/Image/Convolution.hs`.

La idea es que cada píxel se vuelva el promedio de su vecindario: él y los 8 cuadritos que lo rodean, un cuadro de 3 por 3. Así los cambios bruscos se suavizan, como cuando ves algo sin lentes.

```haskell
sums3 row = zipWith3 (\a b c -> a + b + c) row (drop 1 row) (drop 2 row)

blurRows top mid bottom = zipWith3 (\a b c -> (a + b + c) `div` 9) (sums3 top) (sums3 mid) (sums3 bottom)

blur image = zipWith3 blurRows image (drop 1 image) (drop 2 image)
```

El truco está en `zipWith3`. Si pones una fila, la misma fila recorrida un lugar y la misma recorrida dos lugares, una debajo de otra, cada columna queda formada por tres vecinos seguidos. `zipWith3` los suma de tres en tres. Y como se detiene cuando se acaba la lista más corta, solo salen las ventanas completas.

`blur` hace el mismo truco pero con filas: junta cada fila con la de abajo y la siguiente, y `blurRows` suma las tres ventanas y divide entre 9.

**¿Por qué la imagen se encoge?** Los píxeles del borde no tienen vecinos completos. Al de la esquina le faltan cinco. En lugar de inventar vecinos, solo calculamos donde cabe la ventana completa. Por eso la imagen pierde un píxel en cada lado: 2 de ancho y 2 de alto.

Así queda `mini`:

1. Solo cabe un grupo de tres filas, porque `mini` tiene exactamente tres.
2. Fila de arriba: `0+50+100 = 150` y `50+100+150 = 300`.
3. Fila de en medio: `200+250+255 = 705` y `250+255+0 = 505`.
4. Fila de abajo: `10+20+30 = 60` y `20+30+40 = 90`.
5. Primera ventana: `150+705+60 = 915`, y `915 div 9 = 101`.
6. Segunda ventana: `300+505+90 = 895`, y `895 div 9 = 99`.

Resultado: `[[101,99]]`. Una imagen de 4 por 3 se convirtió en una de 2 por 1.

---

## 8. La compresión RLE

Vive en `src/Image/Compression.hs`.

Imagina que le dictas a alguien esta fila por teléfono: "cero, cero, cero, doscientos cincuenta y cinco, doscientos cincuenta y cinco, doscientos cincuenta y cinco, doscientos cincuenta y cinco". Te cansas. Es más fácil decir "tres ceros, cuatro doscientos cincuenta y cinco". Eso es RLE: en lugar de repetir, dices cuántas veces se repite. A cada grupo de valores iguales seguidos le llamamos racha.

```haskell
type Compressed = (Int, [(Int, Int)])
```

Una imagen comprimida guarda dos cosas: el ancho, para poder volver a cortar en filas, y una lista de rachas. Cada racha es un par: cuántas veces y qué valor. `(3,0)` quiere decir "tres ceros".

### Comprimir

```haskell
runs [] = []
runs (p:ps) = (1 + length same, p) : runs rest
    where
        (same, rest) = span (== p) ps

compress image = (width image, runs (concat image))
```

`concat` aplana la tabla en una sola tira. Luego `runs` toma el primer número, `p`, y con `span` separa los que son iguales a él de los que no. `span` es como ir caminando por la tira y detenerse en el primer número distinto. La racha mide `1 + length same`, porque hay que contar a `p` también. Después repite con lo que sobró.

Así queda `compress (threshold 128 mini)`:

1. Después del umbral la imagen es `[[0,0,0,255],[255,255,255,0],[0,0,0,0]]`.
2. Aplanada: `0,0,0,255,255,255,255,0,0,0,0,0`.
3. Empieza con 0 y hay dos ceros más. Racha `(3,0)`.
4. Sigue un 255 y hay tres más. Racha `(4,255)`.
5. Sigue un 0 y hay cuatro más. Racha `(5,0)`.
6. Ya no queda nada.

Resultado: `(4,[(3,0),(4,255),(5,0)])`. Doce números se volvieron seis.

### Descomprimir

```haskell
decompress (w, rs) = onRows w (concatMap (\(n, v) -> replicate n v) rs)
```

`replicate 3 0` da `[0,0,0]`. Así cada racha se vuelve a expandir, todo se pega en una tira y `onRows`, la función que ya habías escrito, la corta en filas otra vez. Es bonito ver que una función que hiciste para leer archivos también sirve para descomprimir.

### ¿Cuánto ocupa?

```haskell
originalSize image = width image * height image
compressedSize (_, rs) = 2 * length rs
```

La imagen original ocupa un número por píxel. La comprimida ocupa dos números por racha: cuántas veces y qué valor. No contamos el ancho, igual que no contamos el encabezado de la original, para que la comparación sea justa.

### ¿Cuándo conviene?

RLE gana cuando hay muchos píxeles iguales seguidos, como en una imagen en blanco y negro. Pierde cuando todo cambia todo el tiempo. `mini` no tiene ningún par de vecinos iguales, así que salen 12 rachas de un solo píxel y la versión comprimida ocupa 24 números, el doble. En cambio la foto de ejemplo baja a 35 por ciento de su tamaño, y después de `threshold 128` baja a menos del 3 por ciento.

---

## 9. El protocolo: la ventanilla

Vive en `src/Protocol.hs`.

Imagina una ventanilla de trámites. Te pasan una hoja que arriba dice qué quieren, por ejemplo `negative`, y abajo trae la imagen. La persona de la ventanilla revisa que la imagen esté bien escrita, hace el trámite y te regresa otra hoja con el resultado. Si algo está mal, te regresa una hoja que dice qué falló. Nunca se desmaya.

Esa ventanilla es una sola función:

```haskell
handleRequest :: String -> String
```

Recibe texto y regresa texto. No abre archivos, no usa la red, no imprime nada. Por eso es pura, y por eso la podemos probar sin servidor.

### Qué pasa adentro

1. **Separar la hoja.** `lines` parte la petición. El primer renglón es el comando y el resto es la imagen.
2. **Revisar la imagen.** `validatePgm` comprueba que todo esté en orden. Regresa un `Either`: o `Left` con un mensaje de error, o `Right` con la imagen ya lista. Piensa en `Either` como una caja con dos compartimentos: en uno viene la mala noticia y en el otro la buena, pero nunca las dos.
3. **Entender el comando.** `commandFilter` busca qué filtro corresponde. Regresa un `Maybe`: `Just` con el filtro si lo encontró, o `Nothing` si el comando no existe. `Maybe` es una caja que puede venir llena o vacía.
4. **Responder.** Si todo salió bien, regresa `IMAGE` y la imagen nueva. Si el comando era `compress`, regresa `STATS` con los tamaños. Si algo falló, regresa `ERROR` y el motivo.

### Qué revisa `validatePgm`

Revisa el archivo como un inspector con una lista, en orden. Cada renglón de la lista es una guarda:

- que empiece con `P2`;
- que el ancho, el alto y el máximo sean números;
- que el máximo sea 255;
- que el ancho y el alto sean mayores que cero;
- que haya exactamente ancho por alto píxeles;
- que cada píxel sea un número entre 0 y 255.

Si todo pasa, ahora sí llama a `parsePgm` con la seguridad de que no va a tronar.

### Cómo entiende los comandos

`commandFilter` usa pattern matching sobre las palabras del comando:

```haskell
commandFilter ["negative"] = Just negative
commandFilter ["brightness", n] = fmap brightness (readInt n)
...
commandFilter _ = Nothing
```

El último renglón atrapa todo lo que no reconoció. `readInt` intenta leer el número sin tronar. `fmap brightness` quiere decir "si lograste leer el número, conviértelo en filtro; si no, sigue vacío".

Para una cadena como `chain brightness:30,rotateRight,threshold:128`, `splitOn` corta el texto en cada coma, y luego cada paso en cada dos puntos. `chainFilters` convierte cada paso en filtro, uno por uno, de forma recursiva. Si un solo paso está mal, toda la cadena se rechaza. Al final `applyChain` arma la línea de producción.

### Las estadísticas

Para `compress`, la respuesta incluye el tamaño original, el comprimido, cuántas rachas hubo, el porcentaje y `roundTrip`. Ese último es la prueba de honestidad: descomprime lo que comprimió y revisa que salga idéntico a la original.

---

## 10. El servidor: el mensajero

Vive en `app/Server.hs`.

El servidor es un mensajero que no abre los paquetes. Recibe bytes, se los pasa a la ventanilla, y entrega la respuesta. No sabe nada de imágenes.

- **`main`** abre el puerto 5000 en la propia computadora y espera.
- **`serve`** atiende una conexión y luego se llama a sí misma para atender la siguiente. Así se hace un ciclo infinito en Haskell: con recursión, sin variables que cambian.
- **`recvChunks`** lee la petición a pedazos hasta que Python avisa que ya terminó de mandar. Cada vez que llega un pedazo, lo guarda y pide el siguiente. Cuando llega uno vacío, se detiene.
- **`handleConnection`** convierte los bytes en texto, imprime una línea en la terminal para que se vea que Haskell está trabajando, llama a `handleRequest` y manda la respuesta.
- **`try`** es una red de seguridad. Si algo truena en una conexión, el servidor imprime el error y sigue vivo para la siguiente.

### Un detalle curioso: Haskell es flojo

Haskell no calcula nada hasta que de verdad lo necesita. Eso tiene una consecuencia rara: si `handleRequest` fuera a tronar, no tronaría al llamarla, sino a la mitad del envío, cuando ya no podemos avisar del error. `forceString` obliga a Haskell a calcular toda la respuesta de una vez, dentro de la red de seguridad, para que cualquier problema se atrape a tiempo.

---

## 11. La interfaz en Python

Vive en `gui/app.py`.

Python solo pone la ventana. Elige el archivo, manda el texto, recibe la respuesta y la dibuja. No suma, no promedia, no compara píxeles.

Hay un solo lugar donde Python toca los números de la imagen: `p2_to_photo`. Tk, la biblioteca de ventanas, no sabe dibujar PGM escrito como texto, solo en binario. Entonces Python reescribe los mismos números como bytes. Es como pasar un texto de letra manuscrita a letra de molde: dice exactamente lo mismo, solo cambia la forma. No es un filtro, y el código lo dice en un comentario.

El porcentaje y la barra de la tarjeta de compresión también vienen de Haskell. Python solo los pinta.

---

## 12. Por qué separar lo puro de lo demás

Piensa en un restaurante. La cocina prepara los platillos y el mesero los lleva a la mesa. La cocina no sale a atender clientes y el mesero no cocina.

En el proyecto, `src/` es la cocina: funciones puras que solo transforman datos. Con la misma entrada siempre dan la misma salida y no tocan el mundo exterior. En Haskell eso se nota en el tipo: si la firma no dice `IO`, la función es pura. `app/` es el mesero: lee archivos, abre sockets e imprime en pantalla, pero lo hace con muy poco código y deja todo el trabajo a la cocina.

¿Qué ganamos?

- **Probar es fácil.** Para revisar un filtro basta comparar dos listas. No hace falta levantar el servidor.
- **Todo se reutiliza.** La misma cocina sirve al servidor, a la demo por consola y a las pruebas.
- **No hay sorpresas.** Ninguna función pura puede cambiar algo a escondidas.

El proyecto no usa variables que cambian de valor, como `IORef` o `MVar`, ni trucos para esconder efectos, como `unsafePerformIO`. Los ciclos son recursión.

---

## 13. El viaje completo de un clic

Supón que tienes abierta la foto y presionas **Negativo**.

1. Python arma un texto: `negative`, un salto de línea, y la imagen completa.
2. Abre una conexión al puerto 5000, manda el texto y avisa que ya terminó de mandar.
3. `Server.hs` junta los pedazos con `recvChunks` y los convierte en texto.
4. `handleRequest` revisa la imagen, encuentra el filtro `negative`, lo aplica y arma la respuesta `IMAGE` con la imagen nueva.
5. El servidor manda la respuesta y cierra la conexión.
6. Python quita la palabra `IMAGE`, pasa la imagen a binario solo para poder dibujarla, y la muestra a la derecha.

Todo eso tarda alrededor de una décima de segundo, y la GUI te dice el tiempo exacto.

---

## 14. Preguntas que te puede hacer el profesor

**¿Dónde se procesa la imagen?**
Solo en Haskell. Python manda texto y dibuja lo que regresa. Lo único que hace con los números es reescribirlos en binario para que la ventana los pueda dibujar, sin cambiar ninguno.

**¿Por qué dices que es funcional y no imperativo?**
Porque no hay variables que cambien ni ciclos. Todo se hace con funciones que reciben datos y regresan datos nuevos: recursión, `map`, `zipWith3`, `span`, composición y aplicación parcial. Toda la carpeta `src/` es pura.

**¿Qué significa `type Filter = Image -> Image`?**
Que un filtro es solo una función. Gracias a eso los filtros se pueden guardar en una lista y encadenar con `applyChain`.

**¿Cómo funciona `applyChain`?**
Si la lista está vacía regresa `id`, que no cambia nada. Si no, aplica el primer filtro y después el resto de la cadena. Por eso el orden es de izquierda a derecha.

**¿Dónde usas aplicación parcial?**
En `brightness 30`, por ejemplo. Todavía no recibe la imagen, pero ya es un filtro completo que se puede guardar o encadenar. Lo mismo pasa con `applyPixel (+1)`.

**¿Por qué el desenfoque hace la imagen más chica?**
Porque cada píxel se promedia con sus 8 vecinos, y los del borde no tienen vecinos completos. Solo calculo donde cabe el cuadro de 3 por 3 entero, así que se pierde un píxel por lado.

**¿Cuándo conviene RLE?**
Cuando hay muchos píxeles iguales seguidos. La foto baja a 35 por ciento y en blanco y negro a menos del 3 por ciento. En una imagen llena de detalle puede ocupar más que la original.

**¿Cómo sabes que la compresión no pierde información?**
Porque `roundTrip` descomprime lo comprimido y lo compara con la original, y además hay pruebas que lo revisan.

**¿Qué pasa si mando un archivo roto?**
`validatePgm` lo detecta y regresa un mensaje de error. El servidor responde `ERROR` con el motivo y sigue funcionando.

**¿Por qué el protocolo es una función de texto a texto?**
Para que sea pura y se pueda probar sin red. El servidor solo mueve bytes. Si mañana cambio los sockets por otra forma de comunicación, el protocolo se queda igual.
