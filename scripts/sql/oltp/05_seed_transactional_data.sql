-- Inserta datos de prueba con valores realistas para OLTP y DW.

DECLARE
    v_count NUMBER;
    TYPE client_rec IS RECORD (
        clienteid NUMBER,
        nombre VARCHAR2(100),
        apellido VARCHAR2(100),
        email VARCHAR2(150),
        telefono VARCHAR2(30)
    );
    TYPE client_tab IS TABLE OF client_rec INDEX BY PLS_INTEGER;
    clients client_tab := client_tab(
        1 => client_rec(1, 'Sofia', 'Jimenez', 'sofia.jimenez@correo.com', '0981000101'),
        2 => client_rec(2, 'Mateo', 'Torres', 'mateo.torres@correo.com', '0992000202'),
        3 => client_rec(3, 'Valentina', 'Aguilar', 'valentina.aguilar@correo.com', '0983000303'),
        4 => client_rec(4, 'Sebastian', 'Rojas', 'sebastian.rojas@correo.com', '0994000404'),
        5 => client_rec(5, 'Camila', 'Andrade', 'camila.andrade@correo.com', '0985000505'),
        6 => client_rec(6, 'Daniel', 'Cruz', 'daniel.cruz@correo.com', '0996000606'),
        7 => client_rec(7, 'Isabella', 'Vega', 'isabella.vega@correo.com', '0987000707'),
        8 => client_rec(8, 'Alejandro', 'Paredes', 'alejandro.paredes@correo.com', '0998000808'),
        9 => client_rec(9, 'Martina', 'Fernandez', 'martina.fernandez@correo.com', '0989000909'),
        10 => client_rec(10, 'Diego', 'Medina', 'diego.medina@correo.com', '0990001010'),
        11 => client_rec(11, 'Mariana', 'Castro', 'mariana.castro@correo.com', '0981001111'),
        12 => client_rec(12, 'Andres', 'Lozano', 'andres.lozano@correo.com', '0992001212'),
        13 => client_rec(13, 'Paula', 'Benitez', 'paula.benitez@correo.com', '0983001313'),
        14 => client_rec(14, 'Rodrigo', 'Salazar', 'rodrigo.salazar@correo.com', '0994001414'),
        15 => client_rec(15, 'Luisa', 'Pena', 'luisa.pena@correo.com', '0985001515'),
        16 => client_rec(16, 'Nicolas', 'Herrera', 'nicolas.herrera@correo.com', '0996001616'),
        17 => client_rec(17, 'Elena', 'Cortes', 'elena.cortes@correo.com', '0987001717'),
        18 => client_rec(18, 'Ivan', 'Morales', 'ivan.morales@correo.com', '0998001818'),
        19 => client_rec(19, 'Victoria', 'Bravo', 'victoria.bravo@correo.com', '0989001919'),
        20 => client_rec(20, 'David', 'Gil', 'david.gil@correo.com', '0990002020'),
        21 => client_rec(21, 'Natalia', 'Ortiz', 'natalia.ortiz@correo.com', '0981002121'),
        22 => client_rec(22, 'Jorge', 'Cardenas', 'jorge.cardenas@correo.com', '0992002222'),
        23 => client_rec(23, 'Laura', 'Rivera', 'laura.rivera@correo.com', '0983002323'),
        24 => client_rec(24, 'Carlos', 'Vaca', 'carlos.vaca@correo.com', '0994002424'),
        25 => client_rec(25, 'Sara', 'Flores', 'sara.flores@correo.com', '0985002525'),
        26 => client_rec(26, 'Pablo', 'Mendoza', 'pablo.mendoza@correo.com', '0996002626'),
        27 => client_rec(27, 'Andrea', 'Salas', 'andrea.salas@correo.com', '0987002727'),
        28 => client_rec(28, 'Martin', 'Duarte', 'martin.duarte@correo.com', '0998002828'),
        29 => client_rec(29, 'Daniela', 'Reyes', 'daniela.reyes@correo.com', '0989002929'),
        30 => client_rec(30, 'Lucas', 'Andrade', 'lucas.andrade@correo.com', '0990003030')
    );
BEGIN
    SELECT COUNT(*) INTO v_count FROM CLIENTES;
    IF v_count = 0 THEN
        FOR idx IN clients.FIRST..clients.LAST LOOP
            INSERT INTO CLIENTES (CLIENTEID, NOMBRE, APELLIDO, EMAIL, TELEFONO)
            VALUES (
                clients(idx).clienteid,
                clients(idx).nombre,
                clients(idx).apellido,
                clients(idx).email,
                clients(idx).telefono
            );
        END LOOP;
        COMMIT;
    END IF;
END;
/

DECLARE
    v_count NUMBER;
    TYPE product_rec IS RECORD (
        productoid NUMBER,
        descripcion VARCHAR2(255),
        preciounit NUMBER(10, 2),
        categoria VARCHAR2(100)
    );
    TYPE product_tab IS TABLE OF product_rec INDEX BY PLS_INTEGER;
    products product_tab := product_tab(
        1 => product_rec(6001, 'Laptop Ultrabook 13"', 1499.90, 'Electronica'),
        2 => product_rec(6002, 'Monitor 4K 27"', 529.95, 'Electronica'),
        3 => product_rec(6003, 'Smartphone Pro 5G', 1099.50, 'Electronica'),
        4 => product_rec(6004, 'Teclado Mecanico Retroiluminado', 159.90, 'Perifericos'),
        5 => product_rec(6005, 'Mouse Ergonomico con Bluetooth', 89.95, 'Perifericos'),
        6 => product_rec(6006, 'Silla Ergonomica Executive', 399.00, 'Mobiliario'),
        7 => product_rec(6007, 'Escritorio Modular de Madera', 350.00, 'Mobiliario'),
        8 => product_rec(6008, 'Audifonos ANC Wireless', 249.90, 'Electronica'),
        9 => product_rec(6009, 'Impresora Multifuncional A3', 420.00, 'Oficina'),
        10 => product_rec(6010, 'Proyector LED 4K', 620.00, 'Electronica'),
        11 => product_rec(6011, 'Router Wi-Fi 6', 210.00, 'Electronica'),
        12 => product_rec(6012, 'Camara de Seguridad IP', 180.50, 'Electronica'),
        13 => product_rec(6013, 'Lampara Inteligente', 75.00, 'Hogar'),
        14 => product_rec(6014, 'Cafetera Espresso Semi-Auto', 349.99, 'Hogar'),
        15 => product_rec(6015, 'Set de Ollas Acero Inoxidable', 199.00, 'Hogar'),
        16 => product_rec(6016, 'Colchon Ortopedico 90x190', 499.00, 'Hogar'),
        17 => product_rec(6017, 'Bicicleta Urbana 21 Vel', 675.00, 'Deporte'),
        18 => product_rec(6018, 'Maleta Rigida 24"', 130.00, 'Viaje'),
        19 => product_rec(6019, 'Pulsera Fitness', 89.00, 'Salud'),
        20 => product_rec(6020, 'Lampara de Escritorio LED', 65.50, 'Oficina'),
        21 => product_rec(6021, 'Cargador Solar Portatil', 99.99, 'Electronica'),
        22 => product_rec(6022, 'Kit de Herramientas Pro', 145.90, 'Hogar'),
        23 => product_rec(6023, 'Silla Gaming RGB', 450.00, 'Mobiliario'),
        24 => product_rec(6024, 'Mesa de Centro Minimalista', 289.00, 'Mobiliario'),
        25 => product_rec(6025, 'Frigobar Compacto 120L', 520.00, 'Hogar'),
        26 => product_rec(6026, 'Smartwatch Deportivo', 220.00, 'Electronica'),
        27 => product_rec(6027, 'Cortasetos Inalambrico', 310.00, 'Jardin'),
        28 => product_rec(6028, 'Estacion de Carga USB-C', 79.99, 'Oficina'),
        29 => product_rec(6029, 'Set de Lentes Web 4K', 180.00, 'Electronica'),
        30 => product_rec(6030, 'Router Mesh Tri-Band', 340.00, 'Electronica')
    );
BEGIN
    SELECT COUNT(*) INTO v_count FROM PRODUCTOS;
    IF v_count = 0 THEN
        FOR idx IN products.FIRST..products.LAST LOOP
            INSERT INTO PRODUCTOS (PRODUCTOID, DESCRIPCION, PRECIOUNIT, CATEGORIA)
            VALUES (
                products(idx).productoid,
                products(idx).descripcion,
                products(idx).preciounit,
                products(idx).categoria
            );
        END LOOP;
        COMMIT;
    END IF;
END;
/

DECLARE
    v_count NUMBER;
    TYPE order_rec IS RECORD (
        ordenid NUMBER,
        clienteid NUMBER,
        empleadoid NUMBER,
        fechaorden DATE,
        descuento NUMBER(5, 2)
    );
    TYPE order_tab IS TABLE OF order_rec INDEX BY PLS_INTEGER;
    orders order_tab := order_tab(
        1 => order_rec(7001, 1, 501, DATE '2024-01-05', 5),
        2 => order_rec(7002, 2, 502, DATE '2024-01-11', 0),
        3 => order_rec(7003, 3, 503, DATE '2024-01-17', 10),
        4 => order_rec(7004, 4, 501, DATE '2024-01-24', 0),
        5 => order_rec(7005, 5, 502, DATE '2024-02-02', 7.5),
        6 => order_rec(7006, 6, 503, DATE '2024-02-09', 0),
        7 => order_rec(7007, 7, 504, DATE '2024-02-15', 5),
        8 => order_rec(7008, 8, 501, DATE '2024-03-01', 0),
        9 => order_rec(7009, 9, 502, DATE '2024-03-09', 12),
        10 => order_rec(7010, 10, 503, DATE '2024-03-21', 0),
        11 => order_rec(7011, 11, 504, DATE '2024-04-05', 3),
        12 => order_rec(7012, 12, 501, DATE '2024-04-16', 0),
        13 => order_rec(7013, 13, 502, DATE '2024-04-23', 15),
        14 => order_rec(7014, 14, 503, DATE '2024-05-04', 0),
        15 => order_rec(7015, 15, 504, DATE '2024-05-15', 10),
        16 => order_rec(7016, 16, 501, DATE '2024-05-27', 0),
        17 => order_rec(7017, 17, 502, DATE '2024-06-03', 8),
        18 => order_rec(7018, 18, 503, DATE '2024-06-18', 0),
        19 => order_rec(7019, 19, 504, DATE '2024-06-30', 5),
        20 => order_rec(7020, 20, 501, DATE '2024-07-07', 0),
        21 => order_rec(7021, 21, 502, DATE '2024-07-19', 7.5),
        22 => order_rec(7022, 22, 503, DATE '2024-07-25', 0),
        23 => order_rec(7023, 23, 504, DATE '2024-08-08', 10),
        24 => order_rec(7024, 24, 501, DATE '2024-08-19', 0),
        25 => order_rec(7025, 25, 502, DATE '2024-08-27', 12),
        26 => order_rec(7026, 26, 503, DATE '2024-09-03', 0),
        27 => order_rec(7027, 27, 504, DATE '2024-09-18', 5),
        28 => order_rec(7028, 28, 501, DATE '2024-09-26', 0),
        29 => order_rec(7029, 29, 502, DATE '2024-10-05', 0),
        30 => order_rec(7030, 30, 503, DATE '2024-10-16', 7)
    );
BEGIN
    SELECT COUNT(*) INTO v_count FROM ORDENES;
    IF v_count = 0 THEN
        FOR idx IN orders.FIRST..orders.LAST LOOP
            INSERT INTO ORDENES (ORDENID, CLIENTEID, EMPLEADOID, FECHAORDEN, DESCUENTO)
            VALUES (
                orders(idx).ordenid,
                orders(idx).clienteid,
                orders(idx).empleadoid,
                orders(idx).fechaorden,
                orders(idx).descuento
            );
        END LOOP;
        COMMIT;
    END IF;
END;
/

DECLARE
    v_count NUMBER;
    TYPE detail_rec IS RECORD (
        detalleid NUMBER,
        ordenid NUMBER,
        productoid NUMBER,
        cantidad NUMBER
    );
    TYPE detail_tab IS TABLE OF detail_rec INDEX BY PLS_INTEGER;
    detail_data detail_tab := detail_tab(
        1 => detail_rec(9001, 7001, 6001, 1),
        2 => detail_rec(9002, 7001, 6004, 1),
        3 => detail_rec(9003, 7002, 6003, 1),
        4 => detail_rec(9004, 7002, 6005, 2),
        5 => detail_rec(9005, 7003, 6006, 1),
        6 => detail_rec(9006, 7003, 6007, 1),
        7 => detail_rec(9007, 7004, 6008, 1),
        8 => detail_rec(9008, 7004, 6002, 1),
        9 => detail_rec(9009, 7005, 6010, 1),
        10 => detail_rec(9010, 7005, 6009, 1),
        11 => detail_rec(9011, 7006, 6011, 1),
        12 => detail_rec(9012, 7006, 6005, 1),
        13 => detail_rec(9013, 7007, 6012, 1),
        14 => detail_rec(9014, 7007, 6013, 2),
        15 => detail_rec(9015, 7008, 6014, 1),
        16 => detail_rec(9016, 7008, 6022, 1),
        17 => detail_rec(9017, 7009, 6015, 1),
        18 => detail_rec(9018, 7009, 6020, 2),
        19 => detail_rec(9019, 7010, 6016, 1),
        20 => detail_rec(9020, 7010, 6017, 1),
        21 => detail_rec(9021, 7011, 6018, 1),
        22 => detail_rec(9022, 7011, 6001, 1),
        23 => detail_rec(9023, 7012, 6021, 2),
        24 => detail_rec(9024, 7012, 6019, 1),
        25 => detail_rec(9025, 7013, 6023, 1),
        26 => detail_rec(9026, 7013, 6024, 1),
        27 => detail_rec(9027, 7014, 6025, 1),
        28 => detail_rec(9028, 7014, 6026, 1),
        29 => detail_rec(9029, 7015, 6027, 1),
        30 => detail_rec(9030, 7015, 6003, 1),
        31 => detail_rec(9031, 7016, 6002, 1),
        32 => detail_rec(9032, 7016, 6005, 1),
        33 => detail_rec(9033, 7017, 6011, 1),
        34 => detail_rec(9034, 7017, 6013, 1),
        35 => detail_rec(9035, 7018, 6008, 1),
        36 => detail_rec(9036, 7018, 6010, 1),
        37 => detail_rec(9037, 7019, 6014, 1),
        38 => detail_rec(9038, 7019, 6009, 1),
        39 => detail_rec(9039, 7020, 6028, 1),
        40 => detail_rec(9040, 7020, 6029, 1),
        41 => detail_rec(9041, 7021, 6020, 1),
        42 => detail_rec(9042, 7021, 6004, 1),
        43 => detail_rec(9043, 7022, 6022, 1),
        44 => detail_rec(9044, 7022, 6023, 1),
        45 => detail_rec(9045, 7023, 6024, 1),
        46 => detail_rec(9046, 7023, 6025, 1),
        47 => detail_rec(9047, 7024, 6026, 1),
        48 => detail_rec(9048, 7024, 6016, 1),
        49 => detail_rec(9049, 7025, 6007, 1),
        50 => detail_rec(9050, 7025, 6012, 1),
        51 => detail_rec(9051, 7026, 6008, 1),
        52 => detail_rec(9052, 7026, 6001, 1),
        53 => detail_rec(9053, 7027, 6003, 1),
        54 => detail_rec(9054, 7027, 6015, 1),
        55 => detail_rec(9055, 7028, 6021, 1),
        56 => detail_rec(9056, 7028, 6002, 1),
        57 => detail_rec(9057, 7029, 6027, 1),
        58 => detail_rec(9058, 7029, 6028, 1),
        59 => detail_rec(9059, 7030, 6030, 1),
        60 => detail_rec(9060, 7030, 6009, 1)
    );
    TYPE price_map IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
    prices price_map;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DETALLE_ORDENES;
    IF v_count = 0 THEN
        FOR prod IN (SELECT PRODUCTOID, PRECIOUNIT FROM PRODUCTOS) LOOP
            prices(prod.PRODUCTOID) := prod.PRECIOUNIT;
        END LOOP;

        FOR idx IN detail_data.FIRST..detail_data.LAST LOOP
            INSERT INTO DETALLE_ORDENES (DETALLEID, ORDENID, PRODUCTOID, CANTIDAD, PRECIOUNIT)
            VALUES (
                detail_data(idx).detalleid,
                detail_data(idx).ordenid,
                detail_data(idx).productoid,
                detail_data(idx).cantidad,
                prices(detail_data(idx).productoid)
            );
        END LOOP;
        COMMIT;
    END IF;
END;
/
