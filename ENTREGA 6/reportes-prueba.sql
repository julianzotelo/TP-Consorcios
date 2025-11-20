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
