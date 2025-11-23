-- Referencia de esquema dimensional inicial para el sistema de pedidos (zona OLTP).
-- Las tablas Dim_Producto, Dim_Tiempo y Dim_Pedidos se cargan desde PRODUCTOS y ORDENES.
-- No incluye ubicacion; se conserva como referencia del modelo previo a la ampliacion geografica.

CREATE TABLE Dim_Producto (
    ProductoID    NUMBER       PRIMARY KEY,
    Descripcion   VARCHAR2(50),
    PrecioUnitario NUMBER,
    Categoria     VARCHAR2(50)
);

CREATE TABLE Dim_Tiempo (
    TiempoID  NUMBER      PRIMARY KEY,
    Fecha     DATE,
    Anio      NUMBER,
    Mes       NUMBER,
    Trimestre NUMBER,
    DiaSemana VARCHAR2(10)
);

CREATE TABLE Dim_Pedidos (
    PedidoID   NUMBER PRIMARY KEY,
    ClienteID  NUMBER,
    EmpleadoID NUMBER,
    FechaPedido DATE,
    Descuento  NUMBER
);

CREATE TABLE Fact_Ventas (
    VentaID        NUMBER PRIMARY KEY,
    ProductoID     NUMBER,
    TiempoID       NUMBER,
    PedidoID       NUMBER,
    CantidadVendida NUMBER,
    FOREIGN KEY (ProductoID) REFERENCES Dim_Producto(ProductoID),
    FOREIGN KEY (TiempoID) REFERENCES Dim_Tiempo(TiempoID),
    FOREIGN KEY (PedidoID) REFERENCES Dim_Pedidos(PedidoID)
);

-- Carga de dimensiones desde tablas transaccionales.
INSERT INTO Dim_Producto (ProductoID, Descripcion, PrecioUnitario, Categoria)
SELECT PRODUCTOID, DESCRIPCION, PRECIOUNIT, CATEGORIA
FROM PRODUCTOS;

INSERT INTO Dim_Tiempo (TiempoID, Fecha, Anio, Mes, Trimestre, DiaSemana)
SELECT DISTINCT
    ROW_NUMBER() OVER (ORDER BY FECHAORDEN) AS TiempoID,
    FECHAORDEN,
    EXTRACT(YEAR FROM FECHAORDEN),
    EXTRACT(MONTH FROM FECHAORDEN),
    CEIL(EXTRACT(MONTH FROM FECHAORDEN) / 3),
    TO_CHAR(FECHAORDEN, 'Day')
FROM ORDENES;

INSERT INTO Dim_Pedidos (PedidoID, ClienteID, EmpleadoID, FechaPedido, Descuento)
SELECT ORDENID, CLIENTEID, EMPLEADOID, FECHAORDEN, DESCUENTO
FROM ORDENES;

INSERT INTO Fact_Ventas (VentaID, ProductoID, TiempoID, PedidoID, CantidadVendida)
SELECT
    ROW_NUMBER() OVER (ORDER BY d.DETALLEID),
    d.PRODUCTOID,
    t.TiempoID,
    o.ORDENID,
    d.CANTIDAD
FROM DETALLE_ORDENES d
JOIN ORDENES o ON d.ORDENID = o.ORDENID
JOIN Dim_Tiempo t ON o.FECHAORDEN = t.Fecha;

-- Ejemplo de consulta: producto mas vendido del mes 1.
SELECT p.Descripcion AS Producto,
       SUM(f.CantidadVendida) AS Total_Vendido
FROM Fact_Ventas f
JOIN Dim_Producto p ON f.ProductoID = p.ProductoID
JOIN Dim_Tiempo t ON f.TiempoID = t.TiempoID
WHERE t.Mes = 1
GROUP BY p.Descripcion
ORDER BY Total_Vendido DESC;
