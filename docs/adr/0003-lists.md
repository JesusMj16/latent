# ADR 0003: Imagen como lista de listas

**Estado:** aceptado

**Contexto.** Hay que representar la matriz de píxeles.

**Decisión.** `type Image = [[Int]]`: una lista de filas, cada fila una lista
de grises. `type Filter = Image -> Image`.

**Consecuencias.** Los filtros se escriben con `map`, `reverse`, `zipWith3`,
recursión y composición, que son las herramientas vistas en clase. Un filtro
es solo una función, así que una cadena de filtros es composición. El costo es
el rendimiento: acceder a un elemento es O(n). Para las imágenes del demo
(160x200) es suficiente; arreglos o `Data.Vector` quedan como trabajo futuro.
