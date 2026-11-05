-- Servidor TCP delgado: solo mueve bytes. Toda la logica esta en
-- Protocol.handleRequest, que es una funcion pura String -> String
import Protocol (handleRequest)
import Network.Socket
import Network.Socket.ByteString (recv, sendAll)
import qualified Data.ByteString.Char8 as B
import Control.Exception (SomeException, try, evaluate)
import System.IO (hSetBuffering, stdout, BufferMode (LineBuffering))

-- main abre el puerto 5000 en 127.0.0.1 y atiende conexiones para siempre
main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  sock <- socket AF_INET Stream defaultProtocol
  setSocketOption sock ReuseAddr 1
  bind sock (SockAddrInet 5000 (tupleToHostAddress (127, 0, 0, 1)))
  listen sock 5
  putStrLn "Servidor Haskell escuchando en 127.0.0.1:5000"
  serve sock

-- serve atiende una conexion y se llama a si misma (recursion en lugar de ciclo).
-- Si la conexion falla, imprime el error y sigue vivo
serve :: Socket -> IO ()
serve sock = do
  (conn, _) <- accept sock
  result <- try (handleConnection conn) :: IO (Either SomeException ())
  case result of
    Left e -> putStrLn ("Error en la conexion: " ++ show e)
    Right () -> return ()
  close conn
  serve sock

-- handleConnection lee la peticion completa, la pasa a handleRequest
-- y manda la respuesta. Si handleRequest truena, responde ERROR
handleConnection :: Socket -> IO ()
handleConnection conn = do
  bytes <- recvAll conn
  let request = B.unpack bytes
  putStrLn ("Peticion: " ++ takeWhile (/= '\n') request ++ " (" ++ show (B.length bytes) ++ " bytes)")
  answer <- try (evaluate (forceString (handleRequest request))) :: IO (Either SomeException String)
  case answer of
    Right response -> sendAll conn (B.pack response)
    Left e -> sendAll conn (B.pack ("ERROR fallo interno: " ++ show e ++ "\n"))

-- forceString obliga a calcular toda la respuesta (Haskell es perezoso):
-- comparar cada caracter obliga a calcularlo. Asi un error se detecta
-- aqui y no a mitad del envio
forceString :: String -> String
forceString s = length (filter (== '\0') s) `seq` s

-- recvAll lee hasta que el cliente cierra su lado de escritura (EOF).
-- recvChunks junta los pedazos en una lista por recursion
recvAll :: Socket -> IO B.ByteString
recvAll conn = fmap B.concat (recvChunks conn)

recvChunks :: Socket -> IO [B.ByteString]
recvChunks conn = do
  chunk <- recv conn 4096
  if B.null chunk
    then return []
    else fmap (chunk :) (recvChunks conn)
