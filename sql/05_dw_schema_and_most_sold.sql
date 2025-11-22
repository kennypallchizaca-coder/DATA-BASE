-- 05_dw_schema_and_most_sold.sql
-- Creación de dimensiones y consultas para obtener el producto más vendido
-- Dimensión Categoría

CREATE TABLE Dim_Categoria (
  CategoriaID NUMBER(10) PRIMARY KEY,
  Nombre VARCHAR2(200)
);

CREATE SEQUENCE SEQ_CATEGORIA START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE OR REPLACE TRIGGER TRG_CATEGORIA_BI
BEFORE INSERT ON Dim_Categoria
FOR EACH ROW
BEGIN
  IF :NEW.CategoriaID IS NULL THEN
    :NEW.CategoriaID := SEQ_CATEGORIA.NEXTVAL;
  END IF;
END;
/
-- Añadir columna CategoriaID a Dim_Producto (si aplica)
ALTER TABLE Dim_Producto ADD (CategoriaID NUMBER(10));

-- Población de Dim_Categoria desde la tabla transaccional PRODUCTOS (si existe campo CATEGORIA)
INSERT INTO Dim_Categoria (Nombre)
SELECT DISTINCT CATEGORIA FROM PRODUCTOS WHERE CATEGORIA IS NOT NULL;
COMMIT;

-- Mapear categorías a Dim_Producto
MERGE INTO Dim_Producto d
USING (
  SELECT p.PRODUCTOID, c.CategoriaID
  FROM PRODUCTOS p
  LEFT JOIN Dim_Categoria c ON p.CATEGORIA = c.NOMBRE
) src
ON (d.ProductoID = src.PRODUCTOID)
WHEN MATCHED THEN UPDATE SET d.CategoriaID = src.CategoriaID;

COMMIT;

-- Dimensión Ubicación (desagregada en Provincia y Ciudad)
CREATE TABLE Dim_Ubicacion (
  UbicacionID NUMBER(10) PRIMARY KEY,
  Provincia VARCHAR2(200),
  Ciudad VARCHAR2(200),
  CiudadID NUMBER(10)
);

CREATE SEQUENCE SEQ_UBICACION START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE OR REPLACE TRIGGER TRG_UBICACION_BI
BEFORE INSERT ON Dim_Ubicacion
FOR EACH ROW
BEGIN
  IF :NEW.UbicacionID IS NULL THEN
    :NEW.UbicacionID := SEQ_UBICACION.NEXTVAL;
  END IF;
END;
/
-- Poblar Dim_Ubicacion con combinaciones únicas (ejemplo a partir de CLIENTES join CIUDAD)
INSERT INTO Dim_Ubicacion (Provincia, Ciudad, CiudadID)
SELECT DISTINCT c.PROVINCIA, c.NOMBRE, c.CIUDADID
FROM CIUDAD c
WHERE c.NOMBRE IS NOT NULL;
COMMIT;

-- Tabla de hechos agregada por producto / tiempo / categoría / ubicación
CREATE TABLE Fact_Ventas_Agg (
  FactID NUMBER(20) PRIMARY KEY,
  TiempoID NUMBER(10),
  CategoriaID NUMBER(10),
  UbicacionID NUMBER(10),
  ProductoID NUMBER(10),
  Total_Vendido NUMBER,
  CONSTRAINT FK_FT_TIEMPO FOREIGN KEY (TiempoID) REFERENCES Dim_Tiempo(TiempoID),
  CONSTRAINT FK_FT_CATEGORIA FOREIGN KEY (CategoriaID) REFERENCES Dim_Categoria(CategoriaID),
  CONSTRAINT FK_FT_UBICACION FOREIGN KEY (UbicacionID) REFERENCES Dim_Ubicacion(UbicacionID),
  CONSTRAINT FK_FT_PRODUCTO FOREIGN KEY (ProductoID) REFERENCES Dim_Producto(ProductoID)
);

CREATE SEQUENCE SEQ_FACT_AGG START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE OR REPLACE TRIGGER TRG_FACT_AGG_BI
BEFORE INSERT ON Fact_Ventas_Agg
FOR EACH ROW
BEGIN
  IF :NEW.FactID IS NULL THEN
    :NEW.FactID := SEQ_FACT_AGG.NEXTVAL;
  END IF;
END;
/
-- Poblar tabla agregada desde Fact_Ventas, uniendo dimensiones
INSERT INTO Fact_Ventas_Agg (TiempoID, CategoriaID, UbicacionID, ProductoID, Total_Vendido)
SELECT
  f.TiempoID,
  p.CategoriaID,
  u.UbicacionID,
  f.ProductoID,
  SUM(f.CantidadVendida) AS Total_Vendido
FROM Fact_Ventas f
LEFT JOIN Dim_Producto p ON f.ProductoID = p.ProductoID
LEFT JOIN Dim_Pedidos ped ON f.PedidoID = ped.PedidoID
LEFT JOIN CLIENTES cl ON ped.ClienteID = cl.ClienteID
LEFT JOIN CIUDAD ci ON cl.CIUDADID = ci.CIUDADID
LEFT JOIN Dim_Ubicacion u ON u.CiudadID = ci.CIUDADID
GROUP BY f.TiempoID, p.CategoriaID, u.UbicacionID, f.ProductoID;

COMMIT;

-- Vista para producto más vendido por tiempo, categoría y provincia/ciudad
CREATE OR REPLACE VIEW VW_MAS_VENDIDO AS
SELECT * FROM (
  SELECT
    t.Fecha AS FECHA,
    tc.Nombre AS CATEGORIA,
    u.Provincia,
    u.Ciudad,
    p.Descripcion AS PRODUCTO,
    f.Total_Vendido,
    ROW_NUMBER() OVER (PARTITION BY t.Fecha, tc.Nombre, u.Provincia, u.Ciudad ORDER BY f.Total_Vendido DESC) AS RN
  FROM Fact_Ventas_Agg f
  LEFT JOIN Dim_Tiempo t ON f.TiempoID = t.TiempoID
  LEFT JOIN Dim_Categoria tc ON f.CategoriaID = tc.CategoriaID
  LEFT JOIN Dim_Ubicacion u ON f.UbicacionID = u.UbicacionID
  LEFT JOIN Dim_Producto p ON f.ProductoID = p.ProductoID
)
WHERE RN = 1;

-- Consulta ejemplo:
-- SELECT FECHA, CATEGORIA, PROVINCIA, CIUDAD, PRODUCTO, TOTAL_VENDIDO FROM VW_MAS_VENDIDO WHERE FECHA BETWEEN TO_DATE('2025-01-01','YYYY-MM-DD') AND TO_DATE('2025-12-31','YYYY-MM-DD');
