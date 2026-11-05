module Image.Convolution (blur) where

import Image (Image, Filter)

-- sums3 suma cada ventana de 3 vecinos de una fila, alineando la fila
-- con ella misma recorrida 1 y 2 lugares (drop 1, drop 2)
sums3 :: [Int] -> [Int]
sums3 row = zipWith3 (\a b c -> a + b + c) row (drop 1 row) (drop 2 row)

-- blurRows combina tres filas seguidas: suma sus ventanas y divide entre 9
blurRows :: [Int] -> [Int] -> [Int] -> [Int]
blurRows top mid bottom = zipWith3 (\a b c -> (a + b + c) `div` 9) (sums3 top) (sums3 mid) (sums3 bottom)

-- blur es el promedio 3x3. Solo calcula donde cabe la ventana completa,
-- por eso la imagen pierde 1 pixel en cada borde (2 de ancho y 2 de alto)
blur :: Filter
blur image = zipWith3 blurRows image (drop 1 image) (drop 2 image)
