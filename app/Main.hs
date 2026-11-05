import Image (Image)
import Image.Pgm (parsePgm, renderPgm)
import System.Directory (createDirectoryIfMissing)

--readPgm recibe una ruta y regresa una Image
readPgm :: FilePath -> IO Image
--writePgm recibe una ruta, una imagen modificada y escribe el archivo
writePgm :: FilePath -> Image -> IO()

readPgm path = do 
    text <- readFile path 
    return (parsePgm text)

writePgm path image = writeFile path (renderPgm image)

main :: IO ()
main = do
  createDirectoryIfMissing True "output"
  image <- readPgm "examples/sample.pgm"
  writePgm "output/copy.pgm" image
  putStrLn "Listo: output/copy.pgm"