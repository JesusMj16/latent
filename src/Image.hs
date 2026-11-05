module Image (Image, Filter, onRows, width, height, clamp, applyPixel, applyChain) where

-- Sinonimo de tipos Image y Filter
type Image =  [[Int]]

type Filter =  Image -> Image

--Toma una fila y la divide en n partes hasta llegar al caso base
onRows :: Int-> [Int] -> [[Int]]
onRows _ [] = []
onRows n lista = take n lista : onRows n (drop n lista)

--Recibe una Imagen y regresa su width
width :: Image -> Int 
width [] = 0
width (fila:_) = length fila

--Recibe una Imagen y regresa la altura
height :: Image -> Int
height [] = 0
height filas = length filas

-- clamp deja un valor dentro del rango valido de gris (0 a 255),
-- para que ningun filtro produzca pixeles imposibles
clamp :: Int -> Int
clamp p = max 0 (min 255 p)

-- applyPixel convierte una funcion de un pixel en un filtro de imagen:
-- map recorre las filas y el map interior recorre cada pixel de la fila
applyPixel :: (Int -> Int) -> Filter
applyPixel f = map (map f)

-- applyChain aplica una lista de filtros de izquierda a derecha.
-- Caso base: sin filtros la imagen no cambia (id).
-- Caso recursivo: primero f y luego el resto de la cadena
applyChain :: [Filter] -> Filter
applyChain [] = id
applyChain (f:fs) = applyChain fs . f
