module Image.Pointwise (negative, brightness, threshold, intensity) where

import Image (Filter, clamp, applyPixel)

-- negative invierte cada gris: lo negro pasa a blanco y al reves
negative :: Filter
negative = applyPixel (\p -> 255 - p)

-- brightness suma n a cada pixel y luego aplica clamp (composicion con .);
-- n puede ser negativo para oscurecer
brightness :: Int -> Filter
brightness n = applyPixel (clamp . (+ n))

-- threshold convierte a blanco y negro: p >= t da 255, si no 0
threshold :: Int -> Filter
threshold t = applyPixel (\p -> if p >= t then 255 else 0)

-- intensity escala cada pixel por un porcentaje (100 = igual) y aplica clamp
intensity :: Int -> Filter
intensity percent = applyPixel (\p -> clamp (p * percent `div` 100))
