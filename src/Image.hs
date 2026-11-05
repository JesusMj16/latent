module Image (Image, Filter, onRows, width, height) where

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