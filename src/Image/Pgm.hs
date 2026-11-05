module Image.Pgm(parsePgm, renderPgm) where

import Image (Image, onRows, width, height)
import Data.List (isPrefixOf)

-- Funciones de tipos para el parseo 
parsePgm :: String -> Image 
renderPgm :: Image -> String 

--parserPgm lee un texto y lo parsea a una matriz de tipo Image
parsePgm text = parseImage
    where 
        allLines = lines text
        noComments =  filter(not .isPrefixOf "#") allLines
        wordText = words(unwords noComments)
        ( _ : widthText: _ : _ : rest )  = wordText
        parseImage = (onRows (read widthText :: Int) (map read rest :: [Int]))

--renderPgm recibe una matriz y la escribe para que se renderice
renderPgm image = listRender
    where
        headers = ["P2", unwords ([show(width image), show(height image)]), "255"]
        allRowsText = map (\row -> unwords (map show row)) image
        listRender = unlines(headers ++ allRowsText) 
        



