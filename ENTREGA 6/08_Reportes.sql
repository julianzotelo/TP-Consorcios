-- REPORTE 1

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



-- REPORTE 2 

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


-- REPORTE 3

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



-- REPORTE 4

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



-- REPORTE 5

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



-- REPORTE 6

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

