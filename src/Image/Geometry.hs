module Image.Geometry (mirrorHorizontal, mirrorVertical, rotateRight, rotateLeft) where

import Image (Image, Filter)

-- columns convierte las columnas en filas (transpuesta), por recursion:
-- toma el primer elemento de cada fila (concatMap (take 1)) y sigue con
-- el resto de cada fila (map (drop 1)). take y drop nunca truenan
columns :: Image -> Image
columns [] = []
columns ([]:_) = []
columns rows = concatMap (take 1) rows : columns (map (drop 1) rows)

-- mirrorHorizontal invierte cada fila: izquierda pasa a derecha
mirrorHorizontal :: Filter
mirrorHorizontal = map reverse

-- mirrorVertical invierte el orden de las filas: arriba pasa a abajo
mirrorVertical :: Filter
mirrorVertical = reverse

-- rotateRight gira 90 grados a la derecha: transpuesta y luego cada fila al reves
rotateRight :: Filter
rotateRight = map reverse . columns

-- rotateLeft gira 90 grados a la izquierda: transpuesta y luego filas al reves
rotateLeft :: Filter
rotateLeft = reverse . columns
