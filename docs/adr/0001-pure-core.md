# ADR 0001: Núcleo puro y IO solo en app/

**Estado:** aceptado

**Contexto.** La materia pide código funcional de verdad. Además, el proyecto
tiene dos formas de uso (GUI por sockets y demo por consola) que deben dar el
mismo resultado.

**Decisión.** Todo lo que está en `src/` son funciones puras: ninguna firma usa
`IO` y ningún módulo importa `System.IO`. El protocolo completo es
`handleRequest :: String -> String`. El IO (leer archivos, sockets, imprimir)
vive solo en `app/Server.hs` y `app/Main.hs`, que son delgados.

**Consecuencias.** Las funciones se prueban comparando valores, sin servidor.
El servidor y la consola reutilizan el mismo núcleo. Si el servidor cambiara
(por ejemplo a stdin/stdout), el núcleo no cambia.
