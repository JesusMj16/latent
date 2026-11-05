module Protocol (handleRequest, validatePgm) where

import Data.Char (isDigit)
import Data.List (isPrefixOf)
import Image (Image, Filter, applyChain, width, height)
import Image.Pgm (parsePgm, renderPgm)
import Image.Pointwise (negative, brightness, threshold, intensity)
import Image.Geometry (mirrorHorizontal, mirrorVertical, rotateRight, rotateLeft)
import Image.Compression (compress, decompress, compressedSize, originalSize)
import Image.Convolution (blur)

-- handleRequest es todo el protocolo: recibe la peticion completa como texto
-- (primera linea = comando, resto = PGM P2) y regresa la respuesta como texto.
-- Es pura: el servidor solo mueve bytes
handleRequest :: String -> String
handleRequest request = case lines request of
    [] -> errorResponse "peticion vacia"
    (commandLine : pgmLines) -> case validatePgm (unlines pgmLines) of
        Left message -> errorResponse message
        Right image -> runCommand (words commandLine) image

-- runCommand decide que hacer con la imagen ya validada
runCommand :: [String] -> Image -> String
runCommand ["compress"] image = statsResponse image
runCommand ws image = case commandFilter ws of
    Nothing -> errorResponse ("comando desconocido: " ++ unwords ws)
    Just f -> imageResponse (f image)

-- commandFilter traduce las palabras del comando a un filtro.
-- Nothing indica comando desconocido o parametro invalido.
-- identity no cambia nada: la GUI lo usa para validar el archivo al abrirlo
commandFilter :: [String] -> Maybe Filter
commandFilter ["identity"] = Just id
commandFilter ["negative"] = Just negative
commandFilter ["brightness", n] = fmap brightness (readInt n)
commandFilter ["threshold", n] = fmap threshold (readInt n)
commandFilter ["intensity", n] = fmap intensity (readInt n)
commandFilter ["mirrorHorizontal"] = Just mirrorHorizontal
commandFilter ["mirrorVertical"] = Just mirrorVertical
commandFilter ["rotateRight"] = Just rotateRight
commandFilter ["rotateLeft"] = Just rotateLeft
commandFilter ["blur"] = Just blur
commandFilter ("chain" : parts) = fmap applyChain (chainFilters (splitOn ',' (concat parts)))
commandFilter _ = Nothing

-- chainFilters convierte cada paso "nombre:parametro" en filtro, por recursion.
-- Si un paso falla, toda la cadena falla (Nothing)
chainFilters :: [String] -> Maybe [Filter]
chainFilters [] = Just []
chainFilters (step : steps) = case (stepFilter step, chainFilters steps) of
    (Just f, Just fs) -> Just (f : fs)
    _ -> Nothing

-- stepFilter interpreta un paso de la cadena; no permite cadenas anidadas
-- ni pasos vacios
stepFilter :: String -> Maybe Filter
stepFilter step
    | name == "chain" || name == "" = Nothing
    | otherwise = commandFilter (splitOn ':' step)
    where
        name = takeWhile (/= ':') step

-- splitOn parte un texto en cada aparicion del separador
splitOn :: Char -> String -> [String]
splitOn sep text = case break (== sep) text of
    (piece, []) -> [piece]
    (piece, _ : rest) -> piece : splitOn sep rest

-- isNatural dice si un texto son solo digitos (y no esta vacio)
isNatural :: String -> Bool
isNatural ds = not (null ds) && all isDigit ds

-- readInt lee un entero que puede ser negativo, sin tronar si no es numero
readInt :: String -> Maybe Int
readInt ('-' : ds) = fmap negate (readInt ds)
readInt ds
    | isNatural ds && length ds <= 9 = Just (read ds)
    | otherwise = Nothing

-- validatePgm revisa el texto antes de llamar a parsePgm, para responder
-- con un error claro en lugar de tronar. Quita comentarios igual que parsePgm
validatePgm :: String -> Either String Image
validatePgm text = validateTokens (words (unwords (filter (not . isPrefixOf "#") (lines text))))
    where
        validateTokens ("P2" : w : h : m : pixels)
            | not (all isNatural [w, h, m]) = Left "encabezado invalido"
            | m /= "255" = Left "solo se admite valor maximo 255"
            | read w < 1 || read h < 1 = Left "ancho y alto deben ser mayores que 0"
            | length pixels /= read w * read h =
                Left ("se esperaban " ++ show (read w * read h :: Int) ++ " pixeles y llegaron " ++ show (length pixels))
            | not (all isPixel pixels) = Left "hay pixeles que no son numeros entre 0 y 255"
            | otherwise = Right (parsePgm text)
        validateTokens (magic : _)
            | magic /= "P2" = Left "solo se admite el formato PGM P2"
        validateTokens _ = Left "PGM incompleto"

-- isPixel dice si un texto es un gris valido (0 a 255)
isPixel :: String -> Bool
isPixel p = isNatural p && length p <= 3 && read p <= (255 :: Int)

-- imageResponse arma la respuesta IMAGE; si el filtro dejo la imagen vacia
-- (por ejemplo blur en una imagen menor a 3x3) responde con error
imageResponse :: Image -> String
imageResponse image
    | width image == 0 || height image == 0 = errorResponse "la imagen resultante quedo vacia"
    | otherwise = "IMAGE\n" ++ renderPgm image

-- statsResponse comprime la imagen y reporta tamanos y si el viaje
-- de ida y vuelta (decompress . compress) regresa la original
statsResponse :: Image -> String
statsResponse image = unlines
    [ "STATS"
    , "originalSize " ++ show original
    , "compressedSize " ++ show compressed
    , "runs " ++ show (length (snd packed))
    , "percent " ++ show (compressed * 100 `div` original)
    , "roundTrip " ++ show (decompress packed == image)
    ]
    where
        packed = compress image
        original = originalSize image
        compressed = compressedSize packed

-- errorResponse arma la respuesta de error
errorResponse :: String -> String
errorResponse message = "ERROR " ++ message ++ "\n"
