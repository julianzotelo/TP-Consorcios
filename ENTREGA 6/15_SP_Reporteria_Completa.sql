/*  GENERACION DE REPORTES - ENTREGA 6
13-11-2025
Comisión 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Martín    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/

------------------------------------------------------
/* SP REPORTE 1 - Recaudación semanal
Se desea analizar el flujo de caja en forma semanal. Debe presentar la recaudación por
pagos ordinarios y extraordinarios de cada semana, el promedio en el periodo, y el
acumulado progresivo.*/
------------------------------------------------------
use Com3641G01
go
CREATE OR ALTER PROCEDURE SP_Reporte_1_RecaudacionSemanal
(
    @FechaDesde DATE,
    @FechaHasta DATE,
    @ID_Consorcio INT
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH CTE_Pagos AS (
        SELECT 
            p.ID_unidad_funcional,
            uf.ID_consorcio,
            p.fecha,
            p.importe,
            g.ID_tipo_gasto,
            DATEPART(WEEK, p.fecha) AS Semana,
            DATEPART(YEAR, p.fecha) AS Anio
        FROM Pagos_importados p 
        INNER JOIN Expensas e ON e.ID_unidad_funcional = p.ID_unidad_funcional and e.ID_consorcio = p.ID_consorcio
        INNER JOIN Unidad_funcional uf ON uf.ID_unidad_funcional = p.ID_unidad_funcional
        INNER JOIN Gastos g ON g.ID_consorcio = p.ID_consorcio 
        WHERE p.fecha BETWEEN @FechaDesde AND @FechaHasta
          AND uf.ID_consorcio = @ID_Consorcio
    ),
    Semanal AS (
        SELECT 
            Anio,
            Semana,
            SUM(CASE WHEN ID_tipo_gasto = 1 THEN importe END) AS TotalOrdinario,
            SUM(CASE WHEN ID_tipo_gasto = 2 THEN importe END) AS TotalExtraordinario,
            SUM(importe) AS TotalSemana
        FROM CTE_Pagos
        GROUP BY Anio, Semana
    ),
    Acumulado AS (
        SELECT *,
            SUM(TotalSemana) OVER (ORDER BY Anio, Semana) AS Acumulado
        FROM Semanal
    )
    
    -- SALIDA OBLIGATORIA EN XML
    SELECT 
        Anio,
        Semana,
        TotalOrdinario,
        TotalExtraordinario,
        TotalSemana,
        Acumulado,
        AVG(TotalSemana) OVER() AS PromedioPeriodo
    FROM Acumulado
    ORDER BY Anio, Semana
    FOR XML AUTO, ROOT('FlujoSemanal'), ELEMENTS;
END
GO

--EXEC SP_Reporte_1_RecaudacionSemanal
--     @FechaDesde = '2025-04-01',
--     @FechaHasta = '2025-04-30',
--     @ID_Consorcio = 1;


------------------------------------------------------
-- SP REPORTE 2 - Recaudación por mes y departamento
/*
Presente el total de recaudación por mes y departamento en formato de tabla cruzada. 
*/
------------------------------------------------------
CREATE OR ALTER PROCEDURE SP_Reporte_2_RecaudacionDepartamentoMensual
(
    @FechaInicio DATE,
    @FechaFin DATE,
    @ID_Consorcio INT
)
AS
BEGIN
    SET NOCOUNT ON;

    WITH Recaudacion AS (
        SELECT 
            u.departamento,
            FORMAT(p.fecha, 'yyyy-MM') AS periodo,
            SUM(p.importe) AS total_recaudacion
        FROM Pagos_importados p
        INNER JOIN Unidad_funcional u 
            ON p.ID_unidad_funcional = u.ID_unidad_funcional
           AND p.ID_consorcio = u.ID_consorcio
        WHERE p.fecha BETWEEN @FechaInicio AND @FechaFin
          AND p.ID_consorcio = @ID_Consorcio
        GROUP BY u.departamento, FORMAT(p.fecha, 'yyyy-MM')
    )
    SELECT *
    FROM Recaudacion
    PIVOT (
        SUM(total_recaudacion)
        FOR periodo IN ([2025-01],[2025-02],[2025-03],[2025-04],[2025-05],[2025-06],
                        [2025-07],[2025-08],[2025-09],[2025-10],[2025-11],[2025-12])
    ) AS PivotTable
    ORDER BY departamento;
END;
GO

--EXEC SP_Reporte_2_RecaudacionDepartamentoMensual
--     @FechaInicio = '2025-01-01',
--     @FechaFin    = '2025-12-31',
--     @ID_Consorcio = 1;


--------------------------------------------------------
---- SP REPORTE 3 - Recaudación mensual por tipo de pago
/*Presente un cuadro cruzado con la recaudación total desagregada según su procedencia
(ordinario, extraordinario, etc.) según el periodo.*/
--------------------------------------------------------
CREATE OR ALTER PROCEDURE SP_Reporte_3_RecaudacionMensualPorTipo
(
    @PeriodoDesde VARCHAR(10),
    @PeriodoHasta VARCHAR(10),
    @ID_Consorcio INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.periodo,
        SUM(CASE WHEN g.ID_tipo_gasto = 1 THEN p.importe END) AS Ordinario,
        SUM(CASE WHEN g.ID_tipo_gasto = 2 THEN p.importe END) AS Extraordinario,
        SUM(p.importe) AS Total
    FROM Pagos_importados p
        INNER JOIN Expensas e ON e.ID_unidad_funcional = p.ID_unidad_funcional and e.ID_consorcio = p.ID_consorcio
        INNER JOIN Unidad_funcional uf ON uf.ID_unidad_funcional = p.ID_unidad_funcional
        INNER JOIN Gastos g ON g.ID_consorcio = p.ID_consorcio 
        WHERE p.fecha BETWEEN @PeriodoDesde AND @PeriodoHasta
          AND uf.ID_consorcio = @ID_Consorcio
    GROUP BY e.periodo
    ORDER BY e.periodo
    FOR XML AUTO, ELEMENTS;
END
GO
--EXEC SP_Reporte_3_RecaudacionMensualPorTipo '2025-01-01','2025-12-31',1;



--------------------------------------------------------
---- SP REPORTE 4 - Top 5 ingresos y gastos por mes
--Obtenga los 5 (cinco) meses de mayores gastos y los 5 (cinco) de mayores ingresos. 
--------------------------------------------------------

CREATE OR ALTER PROCEDURE SP_Reporte_4_TopMesesIngresosYGastos
(
    @FechaInicio DATE,
    @FechaFin DATE,
    @ID_Consorcio INT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- TOP 5 GASTOS
    SELECT TOP 5 
        FORMAT(g.fecha, 'yyyy-MM') AS periodo,
        SUM(g.monto_total) AS total_gastos
    FROM Gastos g
    WHERE g.fecha BETWEEN @FechaInicio AND @FechaFin
    GROUP BY FORMAT(g.fecha, 'yyyy-MM')
    ORDER BY total_gastos DESC;

    -- TOP 5 INGRESOS
    SELECT TOP 5 
        FORMAT(p.fecha, 'yyyy-MM') AS periodo,
        SUM(p.importe) AS total_ingresos
    FROM Pagos_importados p
    WHERE p.fecha BETWEEN @FechaInicio AND @FechaFin
      AND p.ID_consorcio = @ID_Consorcio
    GROUP BY FORMAT(p.fecha, 'yyyy-MM')
    ORDER BY total_ingresos DESC;
END;
GO

--EXEC SP_Reporte_4_TopMesesIngresosYGastos  '2025-01-01','2025-12-31',1;
--------------------------------------------------------
---- SP REPORTE 5 - Top 3 propietarios más morosos
/*Obtenga los 3 (tres) propietarios con mayor morosidad. Presente información de contacto y
DNI de los propietarios para que la administración los pueda contactar o remitir el trámite al
estudio jurídico.*/
--------------------------------------------------------
CREATE OR ALTER PROCEDURE SP_Reporte_5_TopPropietariosMorosos
(
    @FechaInicio DATE,
    @FechaFin DATE,
    @ID_Consorcio INT
)
AS
BEGIN
    SET NOCOUNT ON;

    WITH DeudaUF AS (
        SELECT 
            ecp.ID_unidad_funcional,
            ecp.ID_consorcio,
            SUM(ecp.total_pagar) AS deuda_uf
        FROM Estado_cuenta_prorrateo ecp
        WHERE ecp.periodo BETWEEN FORMAT(@FechaInicio,'yyyy-MM') 
                              AND FORMAT(@FechaFin,'yyyy-MM')
          AND ecp.ID_consorcio = @ID_Consorcio
        GROUP BY ecp.ID_unidad_funcional, ecp.ID_consorcio
    ),

    Propietarios AS (
        SELECT
            ufp.ID_unidad_funcional,
            ufp.ID_consorcio,
            ufp.ID_PropietarioInquilino
        FROM UnidadFuncionalPersona ufp
        WHERE ufp.rol = 'PROPIETARIO'
          AND ufp.ID_consorcio = @ID_Consorcio
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
END;
GO

--EXEC SP_Reporte_5_TopPropietariosMorosos   '2025-01-01','2025-12-31',1;
--------------------------------------------------------
---- SP REPORTE 6 - Días entre pagos (XML)
--------------------------------------------------------
CREATE OR ALTER PROCEDURE SP_Reporte_6_DiasEntrePagos
(
    @ID_Consorcio INT,
    @FechaDesde DATE,
    @FechaHasta DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH PagosOrdenados AS (
        SELECT 
            uf.ID_unidad_funcional,
            p.fecha,
            LAG(p.fecha) OVER (PARTITION BY uf.ID_unidad_funcional ORDER BY p.fecha) AS FechaAnterior
        FROM Pagos_importados p
        INNER JOIN Unidad_funcional uf ON uf.ID_unidad_funcional = p.ID_unidad_funcional
        WHERE uf.ID_consorcio = @ID_Consorcio
          AND p.fecha BETWEEN @FechaDesde AND @FechaHasta
    )
    SELECT 
        ID_unidad_funcional,
        FechaAnterior,
        fecha AS FechaActual,
        DATEDIFF(DAY, FechaAnterior, fecha) AS DiasDiferencia
    FROM PagosOrdenados
    WHERE FechaAnterior IS NOT NULL
    ORDER BY ID_unidad_funcional, FechaActual;
END
GO

--EXEC SP_Reporte_6_DiasEntrePagos
--     @ID_Consorcio = 1,
--     @FechaDesde = '2025-01-01',
--     @FechaHasta = '2025-12-31';
