CREATE TABLE Dim_Producto (
  ProductoID INT PRIMARY KEY,
  Descripcion VARCHAR2(50),
  PrecioUnitario NUMBER
);

CREATE TABLE Dim_Tiempo (
  TiempoID INT PRIMARY KEY,
  Fecha DATE,
  Año INT,
  Mes INT,
  Trimestre INT,
  DiaSemana VARCHAR2(10)
);

CREATE TABLE Dim_Pedidos (
  PedidoID INT PRIMARY KEY,
  ClienteID INT,
  EmpleadoID INT,
  FechaPedido DATE,
  Descuento INT
);

CREATE TABLE Fact_Ventas (
  VentaID INT PRIMARY KEY,
  ProductoID INT,
  TiempoID INT,
  PedidoID INT,
  CantidadVendida INT,
  FOREIGN KEY (ProductoID) REFERENCES Dim_Producto(ProductoID),
  FOREIGN KEY (TiempoID) REFERENCES Dim_Tiempo(TiempoID),
  FOREIGN KEY (PedidoID) REFERENCES Dim_Pedidos(PedidoID)
);




INSERT INTO Dim_Producto (ProductoID, Descripcion, PrecioUnitario)
SELECT PRODUCTOID, DESCRIPCION, PRECIOUNIT
FROM PRODUCTOS;

INSERT INTO Dim_Tiempo (TiempoID, Fecha, Año, Mes, Trimestre, DiaSemana)
SELECT DISTINCT
  ROW_NUMBER() OVER (ORDER BY FECHAORDEN) AS TiempoID,
  FECHAORDEN,
  EXTRACT(YEAR FROM FECHAORDEN),
  EXTRACT(MONTH FROM FECHAORDEN),
  CEIL(EXTRACT(MONTH FROM FECHAORDEN)/3),
  TO_CHAR(FECHAORDEN,'Day')
FROM ORDENES;

INSERT INTO Dim_Pedidos (PedidoID, ClienteID, EmpleadoID, FechaPedido, Descuento)
SELECT ORDENID, CLIENTEID, EMPLEADOID, FECHAORDEN, DESCUENTO
FROM ORDENES;

INSERT INTO Fact_Ventas (VentaID, ProductoID, TiempoID, PedidoID, CantidadVendida)
SELECT
  ROW_NUMBER() OVER (ORDER BY DETALLEID),
  d.PRODUCTOID,
  t.TiempoID,
  o.ORDENID,
  d.CANTIDAD
FROM DETALLE_ORDENES d
JOIN ORDENES o ON d.ORDENID = o.ORDENID
JOIN Dim_Tiempo t ON o.FECHAORDEN = t.Fecha;






SELECT
  p.Descripcion AS Producto,
  SUM(f.CantidadVendida) AS Total_Vendido
FROM Fact_Ventas f
JOIN Dim_Producto p ON f.ProductoID = p.ProductoID
JOIN Dim_Tiempo t ON f.TiempoID = t.TiempoID
WHERE t.Mes = 1
GROUP BY p.Descripcion
ORDER BY Total_Vendido DESC;

