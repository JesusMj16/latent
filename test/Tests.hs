import Image (Image, onRows, width, height, clamp, applyPixel, applyChain)
import Image.Pgm (parsePgm, renderPgm)
import Image.Pointwise (negative, brightness, threshold, intensity)
import Image.Geometry (mirrorHorizontal, mirrorVertical, rotateRight, rotateLeft)
import Image.Compression (compress, decompress, compressedSize, originalSize)
import Image.Convolution (blur)
import Protocol (handleRequest)
import Data.List (isPrefixOf)

check :: (Eq a, Show a) => String -> a -> a -> IO Bool

--Funcion para revision de valor esperado y resultado.
--Si falla imprime lo esperado y lo obtenido; regresa True si paso
check nombre esperado obtenido =
  if esperado == obtenido
    then do
      putStrLn ("OK: " ++ nombre)
      return True
    else do
      putStrLn("FALLA " ++ nombre)
      putStrLn("  esperado: " ++ show esperado)
      putStrLn("  obtenido: " ++ show obtenido)
      return False

--Datos de prueba
mini :: Image
mini = [[0,50,100,150],[200,250,255,0],[10,20,30,40]]

miniText :: String
miniText = "P2\n4 3\n255\n0 50 100 150\n200 250 255 0\n10 20 30 40\n"

--Test
main :: IO ()
main = do
    resultados <- sequence
      [ check "onRows parte en filas" [[1,2,3],[4,5,6],[7]] (onRows 3 [1..7])
      , check "onRows con lista vacia" [] (onRows 4 ([]::[Int]))
      , check "width regresa el ancho" 4 (width mini)
      , check "width regresa 0 con lista vacia" 0 (width [])
      , check "height regresa el alto" 3 (height mini)
      , check "height regresa 0 si l = []" 0 (height [])
      , check "parsePgm lee mini" mini (parsePgm miniText)
      , check "renderPgm escribe mini" miniText (renderPgm mini)
      -- Image
      , check "clamp deja valores entre 0 y 255" [0,128,255] (map clamp [-20,128,300])
      , check "applyPixel aplica a cada pixel" [[1,51,101,151],[201,251,256,1],[11,21,31,41]] (applyPixel (+1) mini)
      , check "applyChain [] es id" mini (applyChain [] mini)
      , check "applyChain va de izquierda a derecha" [[0,0],[0,0]] (applyChain [brightness 100, threshold 200] [[0,50],[60,99]])
      -- Pointwise
      , check "negative invierte" [[255,205,155,105],[55,5,0,255],[245,235,225,215]] (negative mini)
      , check "brightness 10" [[10,60,110,160],[210,255,255,10],[20,30,40,50]] (brightness 10 mini)
      , check "brightness negativo" [[0,0,50,100],[150,200,205,0],[0,0,0,0]] (brightness (-50) mini)
      , check "threshold 128" [[0,0,0,255],[255,255,255,0],[0,0,0,0]] (threshold 128 mini)
      , check "intensity 50" [[0,25,50,75],[100,125,127,0],[5,10,15,20]] (intensity 50 mini)
      -- Geometry
      , check "mirrorHorizontal" [[150,100,50,0],[0,255,250,200],[40,30,20,10]] (mirrorHorizontal mini)
      , check "mirrorVertical" [[10,20,30,40],[200,250,255,0],[0,50,100,150]] (mirrorVertical mini)
      , check "rotateRight" [[10,200,0],[20,250,50],[30,255,100],[40,0,150]] (rotateRight mini)
      , check "rotateLeft deshace rotateRight" mini (rotateLeft (rotateRight mini))
      -- Compression
      , check "compress threshold 128" (4,[(3,0),(4,255),(5,0)]) (compress (threshold 128 mini))
      , check "decompress . compress == id" mini (decompress (compress mini))
      , check "decompress . compress con threshold" (threshold 128 mini) (decompress (compress (threshold 128 mini)))
      , check "originalSize" 12 (originalSize mini)
      , check "compressedSize 2 por racha" 6 (compressedSize (compress (threshold 128 mini)))
      -- Convolution
      , check "blur promedio 3x3" [[101,99]] (blur mini)
      -- Protocol
      , check "handleRequest negative" ("IMAGE\n" ++ renderPgm (negative mini)) (handleRequest ("negative\n" ++ miniText))
      , check "handleRequest chain" ("IMAGE\n" ++ renderPgm (threshold 128 (rotateRight (brightness 30 mini))))
                                   (handleRequest ("chain brightness:30,rotateRight,threshold:128\n" ++ miniText))
      , check "handleRequest compress" "STATS\noriginalSize 12\ncompressedSize 24\nruns 12\npercent 200\nroundTrip True\n"
                                     (handleRequest ("compress\n" ++ miniText))
      , check "handleRequest comando desconocido" True (isPrefixOf "ERROR" (handleRequest ("sepia\n" ++ miniText)))
      , check "handleRequest PGM roto" True (isPrefixOf "ERROR" (handleRequest "negative\nP2\n4 3\n255\n1 2 3\n"))
      , check "handleRequest no P2" True (isPrefixOf "ERROR" (handleRequest "negative\nP5\n4 3\n255\n"))
      , check "handleRequest parametro invalido" True (isPrefixOf "ERROR" (handleRequest ("brightness abc\n" ++ miniText)))
      , check "handleRequest blur en imagen chica" True (isPrefixOf "ERROR" (handleRequest "blur\nP2\n2 2\n255\n1 2 3 4\n"))
      ]
    let pasaron = length (filter id resultados)
    putStrLn ("Pasaron " ++ show pasaron ++ " de " ++ show (length resultados))
