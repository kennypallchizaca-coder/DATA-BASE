-- Carga dimensional y de hechos desde el esquema transaccional hacia el DW.
-- Supone que los objetos de DW ya fueron creados (ver dw/01_dw_star_schema_and_top_product_view.sql).
-- Incluye fila "DESCONOCIDA" para casos sin ciudad asignada.

-- Fila para ubicacion desconocida.
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DW_DIM_UBICACION WHERE UbicacionID = 0;
    IF v_count = 0 THEN
        INSERT INTO DW_DIM_UBICACION (UbicacionID, Provincia, Ciudad)
        VALUES (0, 'DESCONOCIDA', 'DESCONOCIDA');
    END IF;
    COMMIT;
END;
/

-- Dimension Tiempo.
MERGE INTO DW_DIM_TIEMPO d
USING (
    SELECT DISTINCT
        FECHAORDEN AS Fecha,
        EXTRACT(YEAR FROM FECHAORDEN) AS Anio,
        EXTRACT(MONTH FROM FECHAORDEN) AS Mes,
        CEIL(EXTRACT(MONTH FROM FECHAORDEN) / 3) AS Trimestre,
        TO_CHAR(FECHAORDEN, 'Day') AS DiaSemana
    FROM ORDENES
) s
ON (d.Fecha = s.Fecha)
WHEN NOT MATCHED THEN
    INSERT (TiempoID, Fecha, Anio, Mes, Trimestre, DiaSemana)
    VALUES (SEQ_DW_DIM_TIEMPO.NEXTVAL, s.Fecha, s.Anio, s.Mes, s.Trimestre, s.DiaSemana);

COMMIT;

-- Dimension Categoria (derivada de PRODUCTOS.CATEGORIA).
MERGE INTO DW_DIM_CATEGORIA c
USING (
    SELECT DISTINCT NVL(TRIM(CATEGORIA), 'SIN CATEGORIA') AS Nombre
    FROM PRODUCTOS
) s
ON (UPPER(c.Nombre) = UPPER(s.Nombre))
WHEN NOT MATCHED THEN
    INSERT (CategoriaID, Nombre)
    VALUES (SEQ_DW_DIM_CATEGORIA.NEXTVAL, s.Nombre);

COMMIT;

-- Dimension Producto (usa el mismo ProductoID del OLTP).
MERGE INTO DW_DIM_PRODUCTO dp
USING (
    SELECT p.PRODUCTOID,
           p.DESCRIPCION,
           p.PRECIOUNIT,
           NVL(TRIM(p.CATEGORIA), 'SIN CATEGORIA') AS CATEGORIA
    FROM PRODUCTOS p
) s
ON (dp.ProductoID = s.PRODUCTOID)
WHEN NOT MATCHED THEN
    INSERT (ProductoID, CategoriaID, Descripcion, PrecioUnitario)
    VALUES (
        s.PRODUCTOID,
        (SELECT CategoriaID FROM DW_DIM_CATEGORIA WHERE UPPER(Nombre) = UPPER(s.CATEGORIA)),
        s.DESCRIPCION,
        s.PRECIOUNIT
    )
WHEN MATCHED THEN UPDATE
    SET dp.Descripcion   = s.DESCRIPCION,
        dp.PrecioUnitario = s.PRECIOUNIT,
        dp.CategoriaID   = (SELECT CategoriaID FROM DW_DIM_CATEGORIA WHERE UPPER(Nombre) = UPPER(s.CATEGORIA));

COMMIT;

-- Dimension Ubicacion (provincia + ciudad, con enlaces a jerarquia si existe).
MERGE INTO DW_DIM_UBICACION u
USING (
    SELECT DISTINCT
        c.CIUDADID,
        c.NOMBRE AS Ciudad,
        TRIM(c.PROVINCIA) AS Provincia,
        p.PROVINCIAID,
        NULL AS CANTONID,
        NULL AS PARROQUIAID
    FROM CIUDAD c
    LEFT JOIN PROVINCIAS p ON UPPER(p.NOMBRE) = UPPER(TRIM(c.PROVINCIA))
) s
ON (u.CiudadID = s.CIUDADID)
WHEN NOT MATCHED THEN
    INSERT (UbicacionID, ProvinciaID, CantonID, ParroquiaID, CiudadID, Provincia, Canton, Parroquia, Ciudad)
    VALUES (
        SEQ_DW_DIM_UBICACION.NEXTVAL,
        s.PROVINCIAID,
        s.CANTONID,
        s.PARROQUIAID,
        s.CIUDADID,
        s.Provincia,
        NULL,
        NULL,
        s.Ciudad
    )
WHEN MATCHED THEN UPDATE
    SET u.ProvinciaID = s.PROVINCIAID,
        u.CantonID    = s.CANTONID,
        u.ParroquiaID = s.PARROQUIAID,
        u.Provincia   = s.Provincia,
        u.Ciudad      = s.Ciudad;

COMMIT;

-- Hecho de ventas: agrega ubicacion y categoria al hecho de pedidos.
MERGE INTO DW_FACT_VENTAS f
USING (
    SELECT
        d.PRODUCTOID,
        o.ORDENID AS PedidoID,
        t.TiempoID,
        NVL(u.UbicacionID, 0) AS UbicacionID,
        (SELECT CategoriaID FROM DW_DIM_CATEGORIA WHERE UPPER(Nombre) = UPPER(NVL(p.CATEGORIA, 'SIN CATEGORIA'))) AS CategoriaID,
        SUM(d.CANTIDAD) AS CantidadVendida,
        SUM(d.CANTIDAD * d.PRECIOUNIT * (1 - NVL(o.DESCUENTO, 0) / 100)) AS MontoTotal
    FROM DETALLE_ORDENES d
    JOIN ORDENES o ON d.ORDENID = o.ORDENID
    JOIN PRODUCTOS p ON p.PRODUCTOID = d.PRODUCTOID
    JOIN DW_DIM_TIEMPO t ON t.Fecha = o.FECHAORDEN
    LEFT JOIN CLIENTES cli ON cli.CLIENTEID = o.CLIENTEID
    LEFT JOIN CIUDAD c ON c.CIUDADID = cli.CIUDADID
    LEFT JOIN DW_DIM_UBICACION u ON u.CiudadID = c.CIUDADID
    GROUP BY d.PRODUCTOID, o.ORDENID, t.TiempoID, NVL(u.UbicacionID, 0), NVL(p.CATEGORIA, 'SIN CATEGORIA')
) s
ON (
    f.ProductoID  = s.PRODUCTOID
    AND f.PedidoID   = s.PedidoID
    AND f.TiempoID   = s.TiempoID
    AND f.UbicacionID = s.UbicacionID
)
WHEN NOT MATCHED THEN
    INSERT (FactID, ProductoID, TiempoID, UbicacionID, PedidoID, CategoriaID, CantidadVendida, MontoTotal)
    VALUES (SEQ_DW_FACT_VENTAS.NEXTVAL, s.PRODUCTOID, s.TiempoID, s.UbicacionID, s.PedidoID, s.CategoriaID, s.CantidadVendida, s.MontoTotal)
WHEN MATCHED THEN UPDATE
    SET f.CantidadVendida = s.CantidadVendida,
        f.MontoTotal      = s.MontoTotal,
        f.CategoriaID     = s.CategoriaID;

COMMIT;
