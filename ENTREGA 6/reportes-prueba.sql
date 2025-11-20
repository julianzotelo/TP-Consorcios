/* REPORTE 1 */
WITH PagosSemanal AS (
    SELECT 
        DATEPART(YEAR, p.fecha) AS anio,
        DATEPART(WEEK, p.fecha) AS semana,
        SUM(CASE WHEN tp.nombre = 'ORDINARIO' THEN p.importe ELSE 0 END) AS recaudacion_ordinaria,
        SUM(CASE WHEN tp.nombre = 'EXTRAORDINARIO' THEN p.importe ELSE 0 END) AS recaudacion_extraordinaria,
        SUM(p.importe) AS total_semana
    FROM Pagos_importados p
    INNER JOIN TipoPago tp ON p.ID_tipo_pago = tp.ID_tipo_pago
    GROUP BY DATEPART(YEAR, p.fecha), DATEPART(WEEK, p.fecha)
)
SELECT anio, semana,
       recaudacion_ordinaria,
       recaudacion_extraordinaria,
       total_semana,
       AVG(total_semana) OVER () AS promedio_periodo,
       SUM(total_semana) OVER (ORDER BY anio, semana) AS acumulado_progresivo
FROM PagosSemanal
ORDER BY anio, semana;



/* REPORTE 2 */
-- Paso 1: obtener recaudación por mes y departamento
WITH Recaudacion AS (
    SELECT 
        u.departamento,
        FORMAT(p.fecha, 'yyyy-MM') AS periodo,
        SUM(p.importe) AS total_recaudacion
    FROM Pagos_importados p
    INNER JOIN Unidad_funcional u 
        ON p.ID_unidad_funcional = u.ID_unidad_funcional
       AND p.ID_consorcio = u.ID_consorcio
    GROUP BY u.departamento, FORMAT(p.fecha, 'yyyy-MM')
)
-- Paso 2: pivotear para tabla cruzada
SELECT *
FROM Recaudacion
PIVOT (
    SUM(total_recaudacion)
    FOR periodo IN ([2025-01],[2025-02],[2025-03],[2025-04],[2025-05],[2025-06],
                    [2025-07],[2025-08],[2025-09],[2025-10],[2025-11],[2025-12])
) AS PivotTable
ORDER BY departamento;


/* REPORTE 3 */
-- Paso 1: obtener recaudación por periodo y tipo de pago
WITH Recaudacion AS (
    SELECT 
        FORMAT(p.fecha, 'yyyy-MM') AS periodo,
        tp.nombre AS tipo_pago,
        SUM(p.importe) AS total_recaudacion
    FROM Pagos_importados p
    INNER JOIN TipoPago tp ON p.ID_tipo_pago = tp.ID_tipo_pago
    GROUP BY FORMAT(p.fecha, 'yyyy-MM'), tp.nombre
)
-- Paso 2: pivotear para cuadro cruzado
SELECT *
FROM Recaudacion
PIVOT (
    SUM(total_recaudacion)
    FOR tipo_pago IN ([ORDINARIO],[EXTRAORDINARIO])
) AS PivotTable
ORDER BY periodo;



/* REPORTE 4 */
-- TOP 5 MESES DE MAYORES GASTOS
SELECT TOP 5 
    FORMAT(g.fecha, 'yyyy-MM') AS periodo,
    SUM(g.monto_total) AS total_gastos
FROM Gastos g
GROUP BY FORMAT(g.fecha, 'yyyy-MM')
ORDER BY total_gastos DESC;


-- TOP 5 MESES DE MAYORES INGRESOS
SELECT TOP 5 
    FORMAT(p.fecha, 'yyyy-MM') AS periodo,
    SUM(p.importe) AS total_ingresos
FROM Pagos_importados p
GROUP BY FORMAT(p.fecha, 'yyyy-MM')
ORDER BY total_ingresos DESC;

/* REPORTE 5 – Top 3 propietarios con mayor morosidad */

WITH DeudaUF AS (
    SELECT 
        ecp.ID_unidad_funcional,
        ecp.ID_consorcio,
        SUM(ecp.total_pagar) AS deuda_uf
    FROM Estado_cuenta_prorrateo ecp
    GROUP BY ecp.ID_unidad_funcional, ecp.ID_consorcio
),

Propietarios AS (
    SELECT
        ufp.ID_unidad_funcional,
        ufp.ID_consorcio,
        ufp.ID_PropietarioInquilino
    FROM UnidadFuncionalPersona ufp
    WHERE ufp.rol = 'PROPIETARIO'
),

MorosidadProp AS (
    SELECT
        p.ID_PropietarioInquilino,
        SUM(d.deuda_uf) AS deuda_total
    FROM DeudaUF d
    INNER JOIN Propietarios p
        ON d.ID_unidad_funcional = p.ID_unidad_funcional
       AND d.ID_consorcio = p.ID_consorcio
    GROUP BY p.ID_PropietarioInquilino
)

SELECT TOP 3
    pi.ID_PropietarioInquilino,
    pi.nombre,
    pi.apellido,
    pi.dni,
    pi.email,
    pi.telefono,
    mp.deuda_total
FROM MorosidadProp mp
INNER JOIN PropietarioInquilino pi
    ON mp.ID_PropietarioInquilino = pi.ID_PropietarioInquilino
ORDER BY mp.deuda_total DESC;

--REPORTE 6--

SELECT
    PI.ID_unidad_funcional,
    PI.ID_consorcio,
    UF.departamento,
    UF.piso,
    PI.fecha AS FechaPago,
    DATEDIFF(
        DAY,
        PI.fecha,
        LEAD(PI.fecha) OVER (PARTITION BY PI.ID_unidad_funcional, PI.ID_consorcio ORDER BY PI.fecha)
    ) AS DiasEntrePagos
FROM
    Pagos_importados PI
    INNER JOIN TipoPago TP ON PI.ID_tipo_pago = TP.ID_tipo_pago
    INNER JOIN Unidad_funcional UF ON 
        PI.ID_unidad_funcional = UF.ID_unidad_funcional AND 
        PI.ID_consorcio = UF.ID_consorcio
WHERE
    TP.nombre = 'ORDINARIO'
ORDER BY
    PI.ID_unidad_funcional,
    PI.ID_consorcio,
    PI.fecha
FOR XML PATH('Pago'), ROOT('PagosImportados');











--DATOS--
IF NOT EXISTS (SELECT 1 FROM TipoPago WHERE nombre = 'ORDINARIO')
INSERT INTO TipoPago (nombre, descripcion)
VALUES ('ORDINARIO', 'Pago mensual ordinario');

IF NOT EXISTS (SELECT 1 FROM TipoPago WHERE nombre = 'EXTRAORDINARIO')
INSERT INTO TipoPago (nombre, descripcion)
VALUES ('EXTRAORDINARIO', 'Pago extraordinario del consorcio');

INSERT INTO Pagos_importados (fecha, cuenta_origen, importe, asociado, ID_unidad_funcional, ID_consorcio, ID_tipo_pago)
VALUES
-- 1. Enero
('2025-01-05', '1111111111111111111111', 32000.50, 0, 1, 1, 1),
('2025-01-15', '1111111111111111111111', 18000.00, 0, 1, 2, 2),
('2025-01-25', '1111111111111111111111', 21000.75, 0, 1, 3, 1),

-- 2. Febrero
('2025-02-03', '2222222222222222222222', 41000.00, 0, 1, 4, 1),
('2025-02-14', '2222222222222222222222', 14000.25, 0, 1, 5, 1),
('2025-02-27', '2222222222222222222222', 15000.00, 0, 2, 1, 2),

-- 3. Marzo
('2025-03-05', '3333333333333333333333', 29500.90, 0, 2, 2, 1),
('2025-03-15', '3333333333333333333333', 18000.00, 0, 2, 3, 2),
('2025-03-28', '3333333333333333333333', 22000.50, 0, 2, 4, 1),

-- 4. Abril
('2025-04-06', '4444444444444444444444', 31500.00, 0, 2, 5, 1),
('2025-04-14', '4444444444444444444444', 15000.00, 0, 3, 1, 2),
('2025-04-26', '4444444444444444444444', 27000.75, 0, 3, 2, 1),

-- 5. Mayo
('2025-05-04', '5555555555555555555555', 35000.00, 0, 3, 3, 1),
('2025-05-13', '5555555555555555555555', 19000.00, 0, 3, 4, 1),
('2025-05-24', '5555555555555555555555', 16000.00, 0, 3, 5, 2),

-- 6. Junio
('2025-06-02', '6666666666666666666666', 37500.25, 0, 4, 1, 1),
('2025-06-11', '6666666666666666666666', 14000.00, 0, 4, 2, 2),
('2025-06-22', '6666666666666666666666', 16500.00, 0, 4, 3, 1),

-- 7. Julio
('2025-07-05', '7777777777777777777777', 42000.00, 0, 4, 4, 1),
('2025-07-17', '7777777777777777777777', 15000.00, 0, 4, 5, 2),
('2025-07-28', '7777777777777777777777', 23000.00, 0, 5, 1, 1),

-- 8. Agosto
('2025-08-08', '8888888888888888888888', 28000.00, 0, 5, 2, 2),
('2025-08-16', '8888888888888888888888', 31000.00, 0, 5, 3, 1),
('2025-08-27', '8888888888888888888888', 19000.00, 0, 5, 4, 2),

-- 9. Septiembre
('2025-09-03', '9999999999999999999999', 35000.00, 0, 5, 5, 1),
('2025-09-14', '9999999999999999999999', 17500.00, 0, 6, 1, 2),
('2025-09-26', '9999999999999999999999', 16000.00, 0, 6, 2, 1),

-- 10. Octubre
('2025-10-05', '1010101010101010101010', 33000.00, 0, 6, 3, 1),
('2025-10-15', '1010101010101010101010', 14500.00, 0, 6, 4, 2),
('2025-10-28', '1010101010101010101010', 28000.00, 0, 6, 5, 1),

-- 11. Noviembre
('2025-11-03', '1212121212121212121212', 36000.00, 0, 7, 1, 1),
('2025-11-12', '1212121212121212121212', 15500.00, 0, 7, 2, 2),
('2025-11-25', '1212121212121212121212', 20500.00, 0, 7, 3, 1),

-- 12. Diciembre
('2025-12-04', '1313131313131313131313', 39000.75, 0, 7, 4, 1),
('2025-12-15', '1313131313131313131313', 18000.00, 0, 7, 5, 2),
('2025-12-27', '1313131313131313131313', 25000.00, 0, 8, 1, 1);




INSERT INTO Gastos (ID_consorcio, ID_tipo_gasto, ID_categoria, monto_total, concepto, mes, fecha)
VALUES
-- ENERO 2025
(1, 1, 5, 35000, 'Servicio eléctrico', 'Enero', '2025-01-05'),
(2, 1, 3, 18000, 'Limpieza mensual', 'Enero', '2025-01-12'),
(3, 2, 6, 22000, 'Reparación de bomba de agua', 'Enero', '2025-01-20'),

-- FEBRERO 2025
(4, 1, 2, 27000, 'Honorarios administración', 'Febrero', '2025-02-04'),
(5, 1, 5, 19500, 'Gas natural', 'Febrero', '2025-02-15'),
(1, 2, 4, 31000, 'Pago de seguro', 'Febrero', '2025-02-26'),

-- MARZO 2025
(2, 1, 3, 24000, 'Limpieza mensual', 'Marzo', '2025-03-06'),
(3, 2, 6, 17500, 'Mantenimiento ascensor', 'Marzo', '2025-03-14'),
(4, 1, 5, 33000, 'Servicio eléctrico', 'Marzo', '2025-03-25'),

-- ABRIL 2025
(5, 1, 1, 8500, 'Gastos bancarios', 'Abril', '2025-04-03'),
(1, 2, 6, 26000, 'Reparación plomería', 'Abril', '2025-04-17'),
(2, 1, 5, 28000, 'Agua corriente', 'Abril', '2025-04-27'),

-- MAYO 2025
(3, 1, 2, 27000, 'Honorarios administración', 'Mayo', '2025-05-04'),
(4, 1, 3, 21000, 'Limpieza mensual', 'Mayo', '2025-05-15'),
(5, 2, 6, 35000, 'Mantenimiento general', 'Mayo', '2025-05-30'),

-- JUNIO 2025
(1, 1, 5, 32000, 'Servicio eléctrico', 'Junio', '2025-06-06'),
(2, 2, 4, 30000, 'Póliza seguro incendio', 'Junio', '2025-06-13'),
(3, 1, 1, 9000, 'Gastos bancarios', 'Junio', '2025-06-23'),

-- JULIO 2025
(4, 1, 3, 19500, 'Limpieza mensual', 'Julio', '2025-07-07'),
(5, 1, 5, 24000, 'Agua corriente', 'Julio', '2025-07-18'),
(1, 2, 6, 31000, 'Arreglo portón cochera', 'Julio', '2025-07-29'),

-- AGOSTO 2025
(2, 1, 2, 27000, 'Honorarios administración', 'Agosto', '2025-08-05'),
(3, 2, 6, 33000, 'Reparación de ascensor', 'Agosto', '2025-08-17'),
(4, 1, 5, 22000, 'Gas natural', 'Agosto', '2025-08-28'),

-- SEPTIEMBRE 2025
(5, 1, 3, 21000, 'Limpieza mensual', 'Septiembre', '2025-09-03'),
(1, 1, 5, 29000, 'Servicio eléctrico', 'Septiembre', '2025-09-15'),
(2, 2, 6, 36000, 'Mantenimiento general', 'Septiembre', '2025-09-27'),

-- OCTUBRE 2025
(3, 1, 2, 27500, 'Honorarios administración', 'Octubre', '2025-10-06'),
(4, 2, 4, 34000, 'Póliza contra incendios', 'Octubre', '2025-10-17'),
(5, 1, 5, 26000, 'Agua corriente', 'Octubre', '2025-10-29'),

-- NOVIEMBRE 2025
(1, 1, 3, 20000, 'Limpieza mensual', 'Noviembre', '2025-11-04'),
(2, 1, 5, 31000, 'Servicio eléctrico', 'Noviembre', '2025-11-12'),
(3, 2, 6, 35000, 'Reparaciones varias', 'Noviembre', '2025-11-24'),

-- DICIEMBRE 2025
(4, 1, 2, 28000, 'Honorarios administración', 'Diciembre', '2025-12-05'),
(5, 1, 3, 21500, 'Limpieza mensual', 'Diciembre', '2025-12-14'),
(1, 2, 4, 38000, 'Renovación seguro anual', 'Diciembre', '2025-12-23');


INSERT INTO Pagos_importados (fecha, cuenta_origen, importe, asociado, ID_unidad_funcional, ID_consorcio, ID_tipo_pago)
VALUES
-- ENERO 2025
('2025-01-10', '1111111111111111111111', 15000, 0, 1, 1, 1), -- A
('2025-01-11', '1111111111111111111112', 17000, 0, 1, 2, 1), -- B
('2025-01-12', '1111111111111111111113', 19000, 0, 1, 3, 2), -- C
('2025-01-13', '1111111111111111111114', 21000, 0, 1, 4, 1), -- D
('2025-01-14', '1111111111111111111115', 23000, 0, 1, 5, 2), -- E

-- FEBRERO 2025
('2025-02-10', '2222222222222222222221', 16000, 0, 1, 1, 1),
('2025-02-11', '2222222222222222222222', 17500, 0, 1, 2, 2),
('2025-02-12', '2222222222222222222223', 18500, 0, 1, 3, 1),
('2025-02-13', '2222222222222222222224', 20500, 0, 1, 4, 2),
('2025-02-14', '2222222222222222222225', 22500, 0, 1, 5, 1),

-- MARZO 2025
('2025-03-10', '3333333333333333333331', 15500, 0, 1, 1, 2),
('2025-03-11', '3333333333333333333332', 16500, 0, 1, 2, 1),
('2025-03-12', '3333333333333333333333', 17500, 0, 1, 3, 2),
('2025-03-13', '3333333333333333333334', 18500, 0, 1, 4, 1),
('2025-03-14', '3333333333333333333335', 19500, 0, 1, 5, 2),

-- ABRIL 2025
('2025-04-10', '4444444444444444444441', 20000, 0, 1, 1, 1),
('2025-04-11', '4444444444444444444442', 21000, 0, 1, 2, 1),
('2025-04-12', '4444444444444444444443', 22000, 0, 1, 3, 2),
('2025-04-13', '4444444444444444444444', 23000, 0, 1, 4, 1),
('2025-04-14', '4444444444444444444445', 24000, 0, 1, 5, 2),

-- MAYO 2025
('2025-05-10', '5555555555555555555551', 21000, 0, 1, 1, 2),
('2025-05-11', '5555555555555555555552', 22500, 0, 1, 2, 1),
('2025-05-12', '5555555555555555555553', 23500, 0, 1, 3, 2),
('2025-05-13', '5555555555555555555554', 24500, 0, 1, 4, 1),
('2025-05-14', '5555555555555555555555', 25500, 0, 1, 5, 2),

-- JUNIO 2025
('2025-06-10', '6666666666666666666661', 26000, 0, 1, 1, 1),
('2025-06-11', '6666666666666666666662', 27500, 0, 1, 2, 2),
('2025-06-12', '6666666666666666666663', 29000, 0, 1, 3, 1),
('2025-06-13', '6666666666666666666664', 30500, 0, 1, 4, 2),
('2025-06-14', '6666666666666666666665', 32000, 0, 1, 5, 1),

-- JULIO 2025
('2025-07-10', '7777777777777777777771', 27000, 0, 1, 1, 2),
('2025-07-11', '7777777777777777777772', 28500, 0, 1, 2, 1),
('2025-07-12', '7777777777777777777773', 30000, 0, 1, 3, 2),
('2025-07-13', '7777777777777777777774', 31500, 0, 1, 4, 1),
('2025-07-14', '7777777777777777777775', 33000, 0, 1, 5, 2),

-- AGOSTO 2025
('2025-08-10', '8888888888888888888881', 28000, 0, 1, 1, 1),
('2025-08-11', '8888888888888888888882', 29000, 0, 1, 2, 2),
('2025-08-12', '8888888888888888888883', 30000, 0, 1, 3, 1),
('2025-08-13', '8888888888888888888884', 31000, 0, 1, 4, 2),
('2025-08-14', '8888888888888888888885', 32000, 0, 1, 5, 1),

-- SEPTIEMBRE 2025
('2025-09-10', '9999999999999999999991', 28500, 0, 1, 1, 2),
('2025-09-11', '9999999999999999999992', 29500, 0, 1, 2, 1),
('2025-09-12', '9999999999999999999993', 30500, 0, 1, 3, 2),
('2025-09-13', '9999999999999999999994', 31500, 0, 1, 4, 1),
('2025-09-14', '9999999999999999999995', 32500, 0, 1, 5, 2),

-- OCTUBRE 2025
('2025-10-10', '1010101010101010101011', 30000, 0, 1, 1, 1),
('2025-10-11', '1010101010101010101012', 31000, 0, 1, 2, 2),
('2025-10-12', '1010101010101010101013', 32000, 0, 1, 3, 1),
('2025-10-13', '1010101010101010101014', 33000, 0, 1, 4, 2),
('2025-10-14', '1010101010101010101015', 34000, 0, 1, 5, 1),

-- NOVIEMBRE 2025
('2025-11-10', '1212121212121212121211', 31000, 0, 1, 1, 2),
('2025-11-11', '1212121212121212121212', 32000, 0, 1, 2, 1),
('2025-11-12', '1212121212121212121213', 33000, 0, 1, 3, 2),
('2025-11-13', '1212121212121212121214', 34000, 0, 1, 4, 1),
('2025-11-14', '1212121212121212121215', 35000, 0, 1, 5, 2),

-- DICIEMBRE 2025
('2025-12-10', '1313131313131313131311', 32000, 0, 1, 1, 1),
('2025-12-11', '1313131313131313131312', 33000, 0, 1, 2, 2),
('2025-12-12', '1313131313131313131313', 34000, 0, 1, 3, 1),
('2025-12-13', '1313131313131313131314', 35000, 0, 1, 4, 2),
('2025-12-14', '1313131313131313131315', 36000, 0, 1, 5, 1);

SELECT ID_unidad_funcional, ID_consorcio, departamento
FROM Unidad_funcional
ORDER BY ID_unidad_funcional, ID_consorcio;



INSERT INTO Pagos_importados (fecha, cuenta_origen, importe, asociado, ID_unidad_funcional, ID_consorcio, ID_tipo_pago)
VALUES
-- Departamento B: 1 pago por mes (ene-dic 2025)
('2025-01-18','2000000000000000000001', 12500.00, 0, 2, 1, 1),
('2025-02-15','2000000000000000000002', 13500.00, 0, 2, 2, 2),
('2025-03-12','2000000000000000000003', 14000.00, 0, 2, 3, 1),
('2025-04-10','2000000000000000000004', 15000.00, 0, 2, 4, 1),
('2025-05-11','2000000000000000000005', 16000.00, 0, 2, 5, 2),
('2025-06-09','2000000000000000000006', 15500.00, 0, 6, 3, 1),
('2025-07-14','2000000000000000000007', 14800.00, 0, 7, 1, 1),
('2025-08-13','2000000000000000000008', 15250.00, 0, 7, 2, 2),
('2025-09-16','2000000000000000000009', 15800.00, 0, 10, 3, 1),
('2025-10-20','2000000000000000000010', 16200.00, 0, 12, 1, 2),
('2025-11-19','2000000000000000000011', 17000.00, 0, 14, 3, 1),
('2025-12-08','2000000000000000000012', 17500.00, 0, 17, 1, 2),

-- Departamento C: 1 pago por mes (ene-dic 2025)
('2025-01-21','3000000000000000000001', 9800.00, 0, 3, 1, 1),
('2025-02-18','3000000000000000000002', 10200.00, 0, 3, 2, 2),
('2025-03-11','3000000000000000000003', 10750.00, 0, 3, 3, 1),
('2025-04-09','3000000000000000000004', 11100.00, 0, 3, 4, 2),
('2025-05-07','3000000000000000000005', 11500.00, 0, 3, 5, 1),
('2025-06-16','3000000000000000000006', 12000.00, 0, 8, 1, 1),
('2025-07-12','3000000000000000000007', 12500.00, 0, 8, 2, 2),
('2025-08-14','3000000000000000000008', 13000.00, 0, 8, 4, 1),
('2025-09-10','3000000000000000000009', 13500.00, 0, 11, 3, 2),
('2025-10-18','3000000000000000000010', 14000.00, 0, 13, 1, 1),
('2025-11-15','3000000000000000000011', 14500.00, 0, 15, 3, 2),
('2025-12-22','3000000000000000000012', 15000.00, 0, 18, 1, 1),

-- Departamento D: 1 pago por mes (ene-dic 2025)
('2025-01-23','4000000000000000000001', 21000.00, 0, 4, 1, 1),
('2025-02-19','4000000000000000000002', 21500.00, 0, 4, 2, 2),
('2025-03-17','4000000000000000000003', 22000.00, 0, 4, 3, 1),
('2025-04-21','4000000000000000000004', 22500.00, 0, 4, 4, 2),
('2025-05-20','4000000000000000000005', 23000.00, 0, 4, 5, 1),
('2025-06-18','4000000000000000000006', 23500.00, 0, 9, 1, 2),
('2025-07-16','4000000000000000000007', 24000.00, 0, 9, 4, 1),
('2025-08-19','4000000000000000000008', 24500.00, 0, 14, 1, 2),
('2025-09-22','4000000000000000000009', 25000.00, 0, 16, 3, 1),
('2025-10-24','4000000000000000000010', 25500.00, 0, 19, 1, 2),
('2025-11-21','4000000000000000000011', 26000.00, 0, 24, 1, 1),
('2025-12-26','4000000000000000000012', 26500.00, 0, 28, 5, 2),

-- Departamento E: 1 pago por mes (ene-dic 2025)
('2025-01-25','5000000000000000000001', 18000.00, 0, 5, 1, 1),
('2025-02-22','5000000000000000000002', 18500.00, 0, 5, 2, 2),
('2025-03-20','5000000000000000000003', 19000.00, 0, 5, 3, 1),
('2025-04-24','5000000000000000000004', 19500.00, 0, 5, 4, 2),
('2025-05-26','5000000000000000000005', 20000.00, 0, 5, 5, 1),
('2025-06-21','5000000000000000000006', 20500.00, 0, 10, 1, 2),
('2025-07-22','5000000000000000000007', 21000.00, 0, 10, 2, 1),
('2025-08-26','5000000000000000000008', 21500.00, 0, 10, 4, 2),
('2025-09-23','5000000000000000000009', 22000.00, 0, 15, 1, 1),
('2025-10-27','5000000000000000000010', 22500.00, 0, 20, 1, 2),
('2025-11-25','5000000000000000000011', 23000.00, 0, 25, 1, 1),
('2025-12-29','5000000000000000000012', 23500.00, 0, 30, 1, 2);


/* --- PAGOS FALTANTES PARA MARZO 2025 (Depto E) --- */
INSERT INTO Pagos_importados (fecha, cuenta_origen, importe, asociado, ID_unidad_funcional, ID_consorcio, ID_tipo_pago)
VALUES
('2025-03-08', '2850590940090412345678', 18500, 1, 5, 1, 1),  -- E, marzo
('2025-03-21', '0170201234567890123456', 21000, 0, 10, 1, 2); -- E, marzo

/* --- PAGOS FALTANTES PARA MAYO 2025 (Depto E) --- */
INSERT INTO Pagos_importados (fecha, cuenta_origen, importe, asociado, ID_unidad_funcional, ID_consorcio, ID_tipo_pago)
VALUES
('2025-05-05', '0720001790012345678901', 17250, 1, 5, 1, 1),  -- E, mayo
('2025-05-19', '0720487788001122334455', 22300, 0, 10, 1, 2); -- E, mayo





