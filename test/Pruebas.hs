import Image (Image, onRows, width, height)

check :: (Eq a, Show a) => String -> a -> a -> IO ()

--Funcion para revision de valor esperado y resultado
check nombre esperado obtenido =
  if esperado == obtenido
    then putStrLn ("OK: " ++ nombre)
    else do
      putStrLn("FALLA " ++ nombre)

--Datos de prueba
mini :: Image
mini = [[0,50,100,150],[200,250,255,0],[10,20,30,40]]

miniText :: String
miniText = "P2\n4 3\n255\n0 50 100 150\n200 250 255 0\n10 20 30 40\n"

--Test
main :: IO ()
main = do 
    check "onRows parte en filas" [[1,2,3],[4,5,6],[7]] (onRows 3 [1..7])
    check "onRows con lista vacia" [] (onRows 4 ([]::[Int]))
    check "width regresa el ancho" 4 (width mini)
    check "width regresa 0 con lista vacia" 0 (width [])
    check "height regresa el alto" 3 (height mini)
    check "height regresa 0 si l = []" 0 (height [])
