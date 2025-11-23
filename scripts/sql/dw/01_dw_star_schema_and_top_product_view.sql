-- Esquema estrella para el Data Warehouse.
-- Dimensiones: Tiempo, Categoria, Producto, Ubicacion.
-- Hecho: Fact_Ventas con medidas CantidadVendida y MontoTotal.
-- La dimension ubicacion desagrega provincia y ciudad (con posibles enlaces a cantones/parroquias).

CREATE TABLE DW_DIM_TIEMPO (
    TiempoID  NUMBER PRIMARY KEY,
    Fecha     DATE,
    Anio      NUMBER,
    Mes       NUMBER,
    Trimestre NUMBER,
    DiaSemana VARCHAR2(10)
);

CREATE TABLE DW_DIM_CATEGORIA (
    CategoriaID NUMBER PRIMARY KEY,
    Nombre      VARCHAR2(100) NOT NULL
);

CREATE TABLE DW_DIM_PRODUCTO (
    ProductoID    NUMBER PRIMARY KEY,
    CategoriaID   NUMBER NOT NULL,
    Descripcion   VARCHAR2(100),
    PrecioUnitario NUMBER,
    FOREIGN KEY (CategoriaID) REFERENCES DW_DIM_CATEGORIA(CategoriaID)
);

CREATE TABLE DW_DIM_UBICACION (
    UbicacionID NUMBER PRIMARY KEY,
    ProvinciaID NUMBER,
    CantonID    NUMBER,
    ParroquiaID NUMBER,
    CiudadID    NUMBER,
    Provincia   VARCHAR2(150),
    Canton      VARCHAR2(150),
    Parroquia   VARCHAR2(150),
    Ciudad      VARCHAR2(150)
);

CREATE TABLE DW_FACT_VENTAS (
    FactID         NUMBER PRIMARY KEY,
    ProductoID     NUMBER NOT NULL,
    TiempoID       NUMBER NOT NULL,
    UbicacionID    NUMBER NOT NULL,
    PedidoID       NUMBER,
    CategoriaID    NUMBER NOT NULL,
    CantidadVendida NUMBER,
    MontoTotal     NUMBER,
    FOREIGN KEY (ProductoID)  REFERENCES DW_DIM_PRODUCTO(ProductoID),
    FOREIGN KEY (TiempoID)    REFERENCES DW_DIM_TIEMPO(TiempoID),
    FOREIGN KEY (UbicacionID) REFERENCES DW_DIM_UBICACION(UbicacionID),
    FOREIGN KEY (CategoriaID) REFERENCES DW_DIM_CATEGORIA(CategoriaID)
);

CREATE SEQUENCE SEQ_DW_DIM_TIEMPO     START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DW_DIM_CATEGORIA  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DW_DIM_PRODUCTO   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DW_DIM_UBICACION  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DW_FACT_VENTAS    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

CREATE OR REPLACE VIEW VW_MAS_VENDIDO AS
SELECT
    inner_q.fecha,
    inner_q.anio,
    inner_q.mes,
    inner_q.categoria,
    inner_q.provincia,
    inner_q.ciudad,
    inner_q.producto,
    inner_q.total_vendido
FROM (
    SELECT
        t.Fecha      AS fecha,
        t.Anio       AS anio,
        t.Mes        AS mes,
        c.Nombre     AS categoria,
        u.Provincia  AS provincia,
        u.Ciudad     AS ciudad,
        p.Descripcion AS producto,
        SUM(f.CantidadVendida) AS total_vendido,
        ROW_NUMBER() OVER (
            PARTITION BY t.Fecha, c.Nombre, u.Provincia, u.Ciudad
            ORDER BY SUM(f.CantidadVendida) DESC
        ) AS rn
    FROM DW_FACT_VENTAS f
    JOIN DW_DIM_TIEMPO t    ON f.TiempoID = t.TiempoID
    JOIN DW_DIM_PRODUCTO p  ON f.ProductoID = p.ProductoID
    JOIN DW_DIM_CATEGORIA c ON f.CategoriaID = c.CategoriaID
    JOIN DW_DIM_UBICACION u ON f.UbicacionID = u.UbicacionID
    GROUP BY t.Fecha, t.Anio, t.Mes, c.Nombre, u.Provincia, u.Ciudad, p.Descripcion
) inner_q
WHERE inner_q.rn = 1;
