CREATE TABLE Dim_Producto (
  ProductoID NUMBER PRIMARY KEY,
  Descripcion VARCHAR2(50),
  PrecioUnitario NUMBER(10,2)
);

CREATE TABLE Dim_Tiempo (
  TiempoID NUMBER PRIMARY KEY,
  Fecha DATE,
  Anio NUMBER(4),
  Mes NUMBER(2),
  Trimestre NUMBER(1),
  DiaSemana VARCHAR2(10)
);

CREATE TABLE Dim_Pedidos (
  PedidoID NUMBER PRIMARY KEY,
  ClienteID NUMBER,
  EmpleadoID NUMBER,
  FechaPedido DATE,
  Descuento NUMBER(5,2)
);

CREATE TABLE Fact_Ventas (
  VentaID NUMBER PRIMARY KEY,
  ProductoID NUMBER,
  TiempoID NUMBER,
  PedidoID NUMBER,
  CantidadVendida NUMBER,
  FOREIGN KEY (ProductoID) REFERENCES Dim_Producto(ProductoID),
  FOREIGN KEY (TiempoID) REFERENCES Dim_Tiempo(TiempoID),
  FOREIGN KEY (PedidoID) REFERENCES Dim_Pedidos(PedidoID)
);
