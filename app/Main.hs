import Image (Image, Filter, applyChain)
import Image.Pgm (parsePgm, renderPgm)
import Image.Pointwise (negative, brightness, threshold, intensity)
import Image.Geometry (mirrorHorizontal, mirrorVertical, rotateRight, rotateLeft)
import Image.Compression (compress, compressedSize, originalSize)
import Image.Convolution (blur)
import System.Directory (createDirectoryIfMissing)

--readPgm recibe una ruta y regresa una Image
readPgm :: FilePath -> IO Image
--writePgm recibe una ruta, una imagen modificada y escribe el archivo
writePgm :: FilePath -> Image -> IO()

readPgm path = do 
    text <- readFile path 
    return (parsePgm text)

writePgm path image = writeFile path (renderPgm image)

-- filters es la lista de pares (nombre, filtro) que el demo guarda en output/
filters :: [(String, Filter)]
filters =
  [ ("negative", negative)
  , ("brightness", brightness 60)
  , ("darker", brightness (-60))
  , ("threshold", threshold 128)
  , ("intensity", intensity 150)
  , ("mirrorHorizontal", mirrorHorizontal)
  , ("mirrorVertical", mirrorVertical)
  , ("rotateRight", rotateRight)
  , ("rotateLeft", rotateLeft)
  , ("blur", blur)
  , ("chain", applyChain [brightness 30, rotateRight, blur, threshold 128])
  ]

-- saveFiltered aplica un filtro y guarda el resultado como output/<nombre>.pgm
saveFiltered :: Image -> (String, Filter) -> IO ()
saveFiltered image (name, f) = do
  writePgm ("output/" ++ name ++ ".pgm") (f image)
  putStrLn ("Listo: output/" ++ name ++ ".pgm")

-- sizeReport arma el texto con el tamano original y comprimido de una imagen
sizeReport :: String -> Image -> String
sizeReport name image =
  name ++ ": original " ++ show (originalSize image)
    ++ " enteros, comprimida " ++ show (compressedSize (compress image)) ++ " enteros"

main :: IO ()
main = do
  createDirectoryIfMissing True "output"
  image <- readPgm "examples/sample.pgm"
  writePgm "output/copy.pgm" image
  putStrLn "Listo: output/copy.pgm"
  mapM_ (saveFiltered image) filters
  putStrLn (sizeReport "Foto" image)
  putStrLn (sizeReport "Foto con threshold 128" (threshold 128 image))
