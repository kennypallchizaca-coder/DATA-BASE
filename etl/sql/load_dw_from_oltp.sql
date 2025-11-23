-- load_dw_from_oltp.sql
-- Flujo ETL (Extract, Transform, Load) para poblar el Data Warehouse.
-- Pasos: extraer pedidos/detalles/clientes, cruzar ubicación con censo,
-- hidratar dimensiones y cargar Fact_Ventas.

PROMPT Iniciando ETL DW...

-------------------------------------------------------------------------------
-- 1) Preparar dimensiones base desde el OLTP
-------------------------------------------------------------------------------
PROMPT Refrescando Dim_Tiempo desde ORDENES.FECHAORDEN;
DELETE FROM Dim_Tiempo;
INSERT INTO Dim_Tiempo (TiempoID, Fecha, Año, Mes, Trimestre, DiaSemana)
SELECT
  ROW_NUMBER() OVER (ORDER BY fecha) AS TiempoID,
  fecha,
  EXTRACT(YEAR FROM fecha) AS Año,
  EXTRACT(MONTH FROM fecha) AS Mes,
  CEIL(EXTRACT(MONTH FROM fecha) / 3) AS Trimestre,
  TO_CHAR(fecha, 'Day', 'NLS_DATE_LANGUAGE=SPANISH') AS DiaSemana
FROM (
  SELECT DISTINCT FECHAORDEN AS fecha FROM ORDENES
);
COMMIT;

PROMPT Refrescando Dim_Producto y Dim_Categoria desde PRODUCTOS;
MERGE INTO Dim_Categoria c
USING (
  SELECT DISTINCT CATEGORIA FROM PRODUCTOS WHERE CATEGORIA IS NOT NULL
) src
ON (c.Nombre = src.CATEGORIA)
WHEN NOT MATCHED THEN
  INSERT (CategoriaID, Nombre) VALUES (SEQ_CATEGORIA.NEXTVAL, src.CATEGORIA);

MERGE INTO Dim_Producto d
USING (
  SELECT PRODUCTOID, DESCRIPCION, PRECIOUNIT, CATEGORIA FROM PRODUCTOS
) src
ON (d.ProductoID = src.PRODUCTOID)
WHEN MATCHED THEN
  UPDATE SET d.Descripcion = src.DESCRIPCION,
             d.PrecioUnitario = src.PRECIOUNIT
WHEN NOT MATCHED THEN
  INSERT (ProductoID, Descripcion, PrecioUnitario)
  VALUES (src.PRODUCTOID, src.DESCRIPCION, src.PRECIOUNIT);

-- Mapear producto -> categoría
UPDATE Dim_Producto dp
SET CategoriaID = (
  SELECT c.CategoriaID FROM Dim_Categoria c WHERE c.Nombre = (
    SELECT p.CATEGORIA FROM PRODUCTOS p WHERE p.PRODUCTOID = dp.ProductoID
  )
)
WHERE EXISTS (
  SELECT 1 FROM PRODUCTOS p WHERE p.PRODUCTOID = dp.ProductoID AND p.CATEGORIA IS NOT NULL
);
COMMIT;

-------------------------------------------------------------------------------
-- 2) Construir la dimensión geográfica cruzando CIUDAD con el censo
-------------------------------------------------------------------------------
PROMPT Refrescando Dim_Ubicacion a partir de PROVINCIAS/CANTONES/PARROQUIAS y CIUDAD;
DELETE FROM Dim_Ubicacion;

-- Inserta ubicaciones exactas por parroquia (parroquia = ciudad en muchos cantones)
INSERT INTO Dim_Ubicacion (
  UbicacionID, Provincia, Canton, Parroquia, Ciudad,
  ProvinciaID, CantonID, ParroquiaID, CiudadID
)
SELECT
  SEQ_UBICACION.NEXTVAL,
  p.NOMBRE AS Provincia,
  ca.NOMBRE AS Canton,
  pa.NOMBRE AS Parroquia,
  NVL(ci.NOMBRE, pa.NOMBRE) AS Ciudad,
  p.PROVINCIAID,
  ca.CANTONID,
  pa.PARROQUIAID,
  ci.CIUDADID
FROM PARROQUIAS pa
JOIN CANTONES ca ON pa.CANTONID = ca.CANTONID
JOIN PROVINCIAS p ON ca.PROVINCIAID = p.PROVINCIAID
LEFT JOIN CIUDAD ci ON UPPER(ci.NOMBRE) = UPPER(pa.NOMBRE);

-- Inserta ciudades que no hicieron match con parroquia (fuente carta-natal.es)
INSERT INTO Dim_Ubicacion (
  UbicacionID, Provincia, Canton, Parroquia, Ciudad,
  ProvinciaID, CantonID, ParroquiaID, CiudadID
)
SELECT
  SEQ_UBICACION.NEXTVAL,
  NVL(ci.PROVINCIA, 'SIN PROVINCIA'),
  NULL,
  NULL,
  ci.NOMBRE,
  NULL,
  NULL,
  NULL,
  ci.CIUDADID
FROM CIUDAD ci
WHERE NOT EXISTS (
  SELECT 1 FROM Dim_Ubicacion u WHERE u.CiudadID = ci.CIUDADID
);
COMMIT;

-------------------------------------------------------------------------------
-- 3) Cargar la tabla de hechos con medidas Cantidad/Monto
-------------------------------------------------------------------------------
PROMPT Recalculando Fact_Ventas (se vacía para evitar duplicados);
DELETE FROM Fact_Ventas;

INSERT INTO Fact_Ventas (
  VentaID, ProductoID, TiempoID, PedidoID, UbicacionID, CategoriaID,
  CantidadVendida, MontoTotal
)
SELECT
  SEQ_FACT_VENTAS.NEXTVAL,
  d.PRODUCTOID,
  t.TiempoID,
  o.ORDENID,
  u.UbicacionID,
  dp.CategoriaID,
  d.CANTIDAD,
  d.CANTIDAD * NVL(dp.PrecioUnitario, 0) AS MontoTotal
FROM DETALLE_ORDENES d
JOIN ORDENES o ON d.ORDENID = o.ORDENID
JOIN Dim_Tiempo t ON t.Fecha = o.FECHAORDEN
JOIN Dim_Producto dp ON dp.ProductoID = d.PRODUCTOID
LEFT JOIN CLIENTES cl ON o.CLIENTEID = cl.CLIENTEID
LEFT JOIN Dim_Ubicacion u ON u.CiudadID = cl.CIUDADID
;
COMMIT;

PROMPT ETL DW finalizado. Consulta VW_MAS_VENDIDO para el top de productos.
