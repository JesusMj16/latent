module Image.Compression (Compressed, compress, decompress, compressedSize, originalSize) where

import Image (Image, onRows, width, height)

-- Imagen comprimida: el ancho (para volver a partir en filas) y la lista
-- de rachas (cantidad, valor). Ejemplo: (3,0) significa "tres ceros seguidos"
type Compressed = (Int, [(Int, Int)])

-- runs agrupa valores iguales consecutivos por recursion.
-- span separa los iguales al primero (same) del resto (rest)
runs :: [Int] -> [(Int, Int)]
runs [] = []
runs (p:ps) = (1 + length same, p) : runs rest
    where
        (same, rest) = span (== p) ps

-- compress aplana la imagen con concat y la codifica con RLE
compress :: Image -> Compressed
compress image = (width image, runs (concat image))

-- decompress expande cada racha con replicate y vuelve a partir en filas
decompress :: Compressed -> Image
decompress (w, rs) = onRows w (concatMap (\(n, v) -> replicate n v) rs)

-- originalSize es el numero de pixeles (enteros) de la imagen sin comprimir
originalSize :: Image -> Int
originalSize image = width image * height image

-- compressedSize cuenta los enteros guardados en las rachas: 2 por racha
-- (cantidad y valor). No contamos el ancho porque tampoco contamos el
-- encabezado de la imagen original
compressedSize :: Compressed -> Int
compressedSize (_, rs) = 2 * length rs
