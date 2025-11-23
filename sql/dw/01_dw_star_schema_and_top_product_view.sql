-- 01_dw_star_schema_and_top_product_view.sql
-- Esquema estrella (OLAP) y vista del producto más vendido.
-- Incluye jerarquía geográfica Provincia -> Cantón -> Parroquia/Ciudad.

-------------------------------------------------------------------------------
-- DIMENSIÓN CATEGORÍA
-------------------------------------------------------------------------------
CREATE TABLE Dim_Categoria (
  CategoriaID   NUMBER(10)   PRIMARY KEY,
  Nombre        VARCHAR2(200) NOT NULL
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

-- Añadir CATEGORIAID a Dim_Producto si aún no existe
DECLARE
  v_cols NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cols
  FROM USER_TAB_COLS
  WHERE TABLE_NAME = 'DIM_PRODUCTO' AND COLUMN_NAME = 'CATEGORIAID';

  IF v_cols = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE Dim_Producto ADD (CategoriaID NUMBER(10))';
  END IF;
END;
/

-------------------------------------------------------------------------------
-- DIMENSIÓN UBICACIÓN (Provincia -> Cantón -> Parroquia/Ciudad)
-------------------------------------------------------------------------------
CREATE TABLE Dim_Ubicacion (
  UbicacionID   NUMBER(10)   PRIMARY KEY,
  Provincia     VARCHAR2(200) NOT NULL,
  Canton        VARCHAR2(200),
  Parroquia     VARCHAR2(200),
  Ciudad        VARCHAR2(200),
  ProvinciaID   NUMBER(10),
  CantonID      NUMBER(10),
  ParroquiaID   NUMBER(10),
  CiudadID      NUMBER(10)
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

-------------------------------------------------------------------------------
-- TABLA DE HECHOS (Fact_Ventas) CON MÉTRICAS Y CLAVES A TODAS LAS DIMENSIONES
-------------------------------------------------------------------------------
-- Si la tabla original existe sin columnas de ubicación/categoría, se amplía.
DECLARE
  v_cols NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cols FROM USER_TABLES WHERE TABLE_NAME = 'FACT_VENTAS';
  IF v_cols = 0 THEN
    EXECUTE IMMEDIATE q'{
      CREATE TABLE Fact_Ventas (
        VentaID         NUMBER(20)   PRIMARY KEY,
        ProductoID      NUMBER(10)   NOT NULL,
        TiempoID        NUMBER(10)   NOT NULL,
        PedidoID        NUMBER(10)   NOT NULL,
        UbicacionID     NUMBER(10),
        CategoriaID     NUMBER(10),
        CantidadVendida NUMBER,
        MontoTotal      NUMBER(18,2),
        CONSTRAINT FK_FACT_PROD FOREIGN KEY (ProductoID) REFERENCES Dim_Producto(ProductoID),
        CONSTRAINT FK_FACT_TIEMPO FOREIGN KEY (TiempoID) REFERENCES Dim_Tiempo(TiempoID),
        CONSTRAINT FK_FACT_PEDIDO FOREIGN KEY (PedidoID) REFERENCES Dim_Pedidos(PedidoID),
        CONSTRAINT FK_FACT_UBIC FOREIGN KEY (UbicacionID) REFERENCES Dim_Ubicacion(UbicacionID),
        CONSTRAINT FK_FACT_CAT FOREIGN KEY (CategoriaID) REFERENCES Dim_Categoria(CategoriaID)
      )
    }';
  ELSE
    -- Garantizar columnas nuevas
    SELECT COUNT(*) INTO v_cols FROM USER_TAB_COLS WHERE TABLE_NAME = 'FACT_VENTAS' AND COLUMN_NAME = 'UBICACIONID';
    IF v_cols = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE Fact_Ventas ADD (UbicacionID NUMBER(10))';
    END IF;
    SELECT COUNT(*) INTO v_cols FROM USER_TAB_COLS WHERE TABLE_NAME = 'FACT_VENTAS' AND COLUMN_NAME = 'CATEGORIAID';
    IF v_cols = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE Fact_Ventas ADD (CategoriaID NUMBER(10))';
    END IF;
    SELECT COUNT(*) INTO v_cols FROM USER_TAB_COLS WHERE TABLE_NAME = 'FACT_VENTAS' AND COLUMN_NAME = 'MONTOTOTAL';
    IF v_cols = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE Fact_Ventas ADD (MontoTotal NUMBER(18,2))';
    END IF;
  END IF;
END;
/

CREATE SEQUENCE SEQ_FACT_VENTAS START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE OR REPLACE TRIGGER TRG_FACT_VENTAS_BI
BEFORE INSERT ON Fact_Ventas
FOR EACH ROW
BEGIN
  IF :NEW.VentaID IS NULL THEN
    :NEW.VentaID := SEQ_FACT_VENTAS.NEXTVAL;
  END IF;
END;
/

-------------------------------------------------------------------------------
-- VISTA: PRODUCTO MÁS VENDIDO POR TIEMPO, CATEGORÍA Y UBICACIÓN
-------------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_MAS_VENDIDO AS
SELECT *
FROM (
  SELECT
    t.Fecha,
    t.Año,
    t.Trimestre,
    t.Mes,
    tc.Nombre           AS Categoria,
    u.Provincia,
    u.Canton,
    u.Parroquia,
    u.Ciudad,
    p.Descripcion       AS Producto,
    SUM(f.CantidadVendida) AS Cantidad_Total,
    SUM(f.MontoTotal)      AS Monto_Total,
    ROW_NUMBER() OVER (
      PARTITION BY t.Año, t.Trimestre, t.Mes, tc.Nombre, u.Provincia, u.Canton, u.Parroquia
      ORDER BY SUM(f.CantidadVendida) DESC, SUM(f.MontoTotal) DESC
    ) AS RN
  FROM Fact_Ventas f
  JOIN Dim_Tiempo t ON f.TiempoID = t.TiempoID
  JOIN Dim_Producto p ON f.ProductoID = p.ProductoID
  LEFT JOIN Dim_Categoria tc ON f.CategoriaID = tc.CategoriaID
  LEFT JOIN Dim_Ubicacion u ON f.UbicacionID = u.UbicacionID
  GROUP BY t.Fecha, t.Año, t.Trimestre, t.Mes, tc.Nombre, u.Provincia, u.Canton, u.Parroquia, u.Ciudad, p.Descripcion
)
WHERE RN = 1;

-- Consulta de ejemplo:
-- SELECT * FROM VW_MAS_VENDIDO WHERE Año = 2025 AND Categoria = 'Lácteos' AND Provincia = 'Pichincha';
