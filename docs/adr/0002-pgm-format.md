# ADR 0002: Formato PGM P2

**Estado:** aceptado

**Contexto.** Necesitamos un formato de imagen que se pueda leer sin
bibliotecas externas.

**Decisión.** Usamos PGM P2: un encabezado (`P2`, ancho, alto, valor máximo)
seguido de los grises como números en texto. Se lee con `lines`, `words` y
`read`. Se ignoran las líneas de comentario que empiezan con `#` (como
`# Created by GIMP`). Solo se acepta valor máximo 255.

**Consecuencias.** Es fácil de leer, de depurar a mano y de exportar desde GIMP.
Los archivos son más grandes que en binario (P5) y solo hay escala de grises.
P5 y PPM a color quedan como trabajo futuro.
