/*  Generacion de expensas completa
13-11-2025
Comisi�n 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Mart�n    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/
use Com3641G01
USE Com3641G01;
GO

CREATE OR ALTER PROCEDURE SP_Generar_Expensas_Completo
(
    @ID_consorcio INT,
    @periodo CHAR(20)  -- formato esperado: 'marzo-2025' (mesNombre-anio)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        --BEGIN TRAN;

        ------------------------------------------------------------------
        -- TABLA UNIFICADA: Seccion | Clave | Valor | Orden
        ------------------------------------------------------------------
        IF OBJECT_ID('tempdb..#ResultadoFinal') IS NOT NULL DROP TABLE #ResultadoFinal;
        CREATE TABLE #ResultadoFinal (
        Seccion VARCHAR(100),
        Clave VARCHAR(200),
        Valor NVARCHAR(1000),
        Orden INT
        );


        -------------------------------
        -- 0) Calculos y variables base
        -------------------------------
        DECLARE @anio INT = TRY_CAST(SUBSTRING(@periodo, CHARINDEX('-', @periodo) + 1, 4) AS INT);
        DECLARE @mesNombre VARCHAR(20) =LEFT(@periodo, CHARINDEX('-', @periodo) - 1);
        DECLARE @ID_estado_financiero int;
     
        DECLARE @mes INT =
            CASE @mesNombre
                WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
                WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
                WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
                WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
                ELSE NULL
            END;
          
        DECLARE @FechaDesde DATE = DATEFROMPARTS(@anio, @mes, 1);
        DECLARE @FechaHasta DATE = EOMONTH(@FechaDesde);
    
        DECLARE @vencimiento DATE = dbo.fn_CalcularVencimiento(@mesNombre); 
        DECLARE @segundo_vto DATE = DATEADD(DAY, 15, @vencimiento); -- SUPOSICI�N: 15 d�as para 2do vencimiento

        -------------------------------
        -- 1) ENCABEZADO (�tem 1 del enunciado)
        --  Trae datos de la administraci�n y del consorcio.
        --  En lugar de SELECT, insertamos clave-valor en #ResultadoFinal
        -------------------------------
        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'ENCABEZADO', 'ID_consorcio', CAST(c.ID_consorcio AS NVARCHAR(100)), 1
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'ENCABEZADO', 'consorcio', c.consorcio, 1
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'ENCABEZADO', 'administrador', c.nombre, 1
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'ENCABEZADO', 'direccion', c.direccion, 1
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'ENCABEZADO', 'cant_unidades', CAST(c.cant_unidades AS NVARCHAR(100)), 1
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'ENCABEZADO', 'm2_totales', CAST(c.m2_totales AS NVARCHAR(100)), 1
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        -------------------------------
        -- FORMA DE PAGO Y VENCIMIENTO (�tem 2)
        -------------------------------
        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'PAGO_Y_VENCIMIENTO','CuentaBancaria', ISNULL(CBU_CVU,''), 2
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'PAGO_Y_VENCIMIENTO','FechaVencimiento', CONVERT(NVARCHAR(50), @vencimiento, 23), 2
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'PAGO_Y_VENCIMIENTO','FechaSegundoVto', CONVERT(NVARCHAR(50), @segundo_vto, 23), 2
        FROM Consorcios c WHERE c.ID_consorcio = @ID_consorcio;

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        VALUES ('PAGO_Y_VENCIMIENTO','Periodo', @periodo, 2);

        -------------------------------
        -- m2 por UF y CONS_TOTAL (se mantiene igual, no produce output)
        -------------------------------
        ;WITH CocheASum AS (
            SELECT 
                ID_unidad_funcional, 
                ID_consorcio, 
                SUM(m2) AS m2_sum
            FROM Cochera
            GROUP BY ID_unidad_funcional, ID_consorcio
        ), 
        BauleraSum AS (
            SELECT 
                ID_unidad_funcional, 
                ID_consorcio, 
                SUM(m2) AS m2_sum
            FROM Baulera
            GROUP BY ID_unidad_funcional, ID_consorcio
        ), 
        UF_M2 AS (
            SELECT
                uf.ID_unidad_funcional,
                uf.ID_consorcio,
                uf.departamento,
                uf.piso,
                uf.coeficiente,
                uf.m2 AS m2_uf,
                ISNULL(c.m2_sum,0) AS m2_cochera,
                ISNULL(b.m2_sum,0) AS m2_baulera,
                (uf.m2 + ISNULL(c.m2_sum,0) + ISNULL(b.m2_sum,0)) AS m2_total_uf
            FROM Unidad_funcional uf
            LEFT JOIN CocheASum c
                ON c.ID_unidad_funcional = uf.ID_unidad_funcional 
                AND c.ID_consorcio = uf.ID_consorcio
            LEFT JOIN BauleraSum b
                ON b.ID_unidad_funcional = uf.ID_unidad_funcional 
                AND b.ID_consorcio = uf.ID_consorcio
            WHERE uf.ID_consorcio = @ID_consorcio
        ), 
        CONS_TOTAL AS (
            SELECT SUM(UF_M2.m2_total_uf) AS m2_total_consorcio FROM UF_M2
        )
        -- Nota: la CTE la usamos m�s abajo para crear #UF_M2_CT

        -------------------------------
        -- LISTADO DE GASTOS ORDINARIOS (�tem 4)
        -------------------------------
        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_ORDINARIOS', 'ID_gastos', CAST(g.ID_gastos AS NVARCHAR(100)), 3
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 1
          AND LOWER(CONCAT(g.mes, '-', YEAR(g.fecha))) = LOWER(@periodo);

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_ORDINARIOS', 'concepto', ISNULL(g.concepto,''), 3
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 1
          AND LOWER(CONCAT(g.mes, '-', YEAR(g.fecha))) = LOWER(@periodo);

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_ORDINARIOS', 'mes', LOWER(g.mes), 3
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 1
          AND LOWER(CONCAT(g.mes, '-', YEAR(g.fecha))) = LOWER(@periodo);

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_ORDINARIOS', 'monto_total', CAST(g.monto_total AS NVARCHAR(100)), 3
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 1
          AND LOWER(CONCAT(g.mes, '-', YEAR(g.fecha))) = LOWER(@periodo);

        -- Total gastos ordinarios del per�odo (para prorrateo)
        DECLARE @Total_Ordinarios DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(dg.importe)
                FROM Gastos g
                INNER JOIN Detalle_Gasto dg ON dg.ID_gasto = g.ID_gastos
                WHERE g.ID_consorcio = @ID_consorcio
                  AND g.ID_tipo_gasto = 1
                  AND LOWER(CONCAT(YEAR(g.fecha), '-', g.mes)) = LOWER(@periodo)
            ), 0);

        -------------------------------
        -- LISTADO DE GASTOS EXTRAORDINARIOS (�tem 5)
        -------------------------------
        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_EXTRAORDINARIOS', 'ID_gastos', CAST(g.ID_gastos AS NVARCHAR(100)), 4
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 2
          AND LOWER(CONCAT(LTRIM(RTRIM(g.mes)), '-',YEAR(g.fecha))) = LOWER(@periodo);

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_EXTRAORDINARIOS', 'concepto', ISNULL(g.concepto,''), 4
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 2
          AND LOWER(CONCAT(LTRIM(RTRIM(g.mes)), '-',YEAR(g.fecha))) = LOWER(@periodo);

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_EXTRAORDINARIOS', 'mes', LOWER(g.mes), 4
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 2
          AND LOWER(CONCAT(LTRIM(RTRIM(g.mes)), '-',YEAR(g.fecha))) = LOWER(@periodo);

        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'GASTOS_EXTRAORDINARIOS', 'monto_total', CAST(g.monto_total AS NVARCHAR(100)), 4
        FROM Gastos g
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 2
          AND LOWER(CONCAT(LTRIM(RTRIM(g.mes)), '-',YEAR(g.fecha))) = LOWER(@periodo);

        -- Total gastos extraordinarios del per�odo (para prorrateo)
        DECLARE @Total_Extraordinarios DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(dg.importe)
                FROM Gastos g
                INNER JOIN Detalle_Gasto dg ON dg.ID_gasto = g.ID_gastos
                WHERE g.ID_consorcio = @ID_consorcio
                  AND g.ID_tipo_gasto = 2
                  AND LOWER(CONCAT(LTRIM(RTRIM(g.mes)), '-',YEAR(g.fecha))) = LOWER(@periodo)
            ), 0);
        
        -------------------------------
        -- GENERAR EXPENSAS POR UF (prorrateo por m2) y Detalles_expensas
        -------------------------------
        IF OBJECT_ID('tempdb..#ExpensasInsertadas') IS NOT NULL DROP TABLE #ExpensasInsertadas;
        CREATE TABLE #ExpensasInsertadas (
            ID_unidad_funcional INT,
            ID_consorcio INT,
            ID_expensas INT,
            MontoOrdinario DECIMAL(18,2),
            MontoExtraordinario DECIMAL(18,2),
            MontoTotal DECIMAL(18,2)
        );

        -- ===========================================
        -- Crear tabla temporal con los m2 por UF
        -- ===========================================
        IF OBJECT_ID('tempdb..#UF_M2_CT') IS NOT NULL
            DROP TABLE #UF_M2_CT;

        SELECT
            uf.ID_unidad_funcional,
            uf.ID_consorcio,
            uf.departamento,
            uf.piso,
            uf.coeficiente,
            uf.m2 AS m2_uf,
            ISNULL(c.m2_sum,0) AS m2_cochera,
            ISNULL(b.m2_sum,0) AS m2_baulera,
            (uf.m2 + ISNULL(c.m2_sum,0) + ISNULL(b.m2_sum,0)) AS m2_total_uf,
            ct.m2_total_consorcio
        INTO #UF_M2_CT
        FROM Unidad_funcional uf
        LEFT JOIN (
            SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
            FROM Cochera
            GROUP BY ID_unidad_funcional, ID_consorcio
        ) c ON c.ID_unidad_funcional = uf.ID_unidad_funcional 
           AND c.ID_consorcio = uf.ID_consorcio
        LEFT JOIN (
            SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
            FROM Baulera
            GROUP BY ID_unidad_funcional, ID_consorcio
        ) b ON b.ID_unidad_funcional = uf.ID_unidad_funcional 
           AND b.ID_consorcio = uf.ID_consorcio
        CROSS JOIN (
            SELECT SUM(uf2.m2 + ISNULL(c2.m2_sum,0) + ISNULL(b2.m2_sum,0)) AS m2_total_consorcio
            FROM Unidad_funcional uf2
            LEFT JOIN (
                SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
                FROM Cochera
                GROUP BY ID_unidad_funcional, ID_consorcio
            ) c2 ON c2.ID_unidad_funcional = uf2.ID_unidad_funcional 
               AND c2.ID_consorcio = uf2.ID_consorcio
            LEFT JOIN (
                SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
                FROM Baulera
                GROUP BY ID_unidad_funcional, ID_consorcio
            ) b2 ON b2.ID_unidad_funcional = uf2.ID_unidad_funcional 
               AND b2.ID_consorcio = uf2.ID_consorcio
            WHERE uf2.ID_consorcio = @ID_consorcio
        ) ct
        WHERE uf.ID_consorcio = @ID_consorcio;


        -- Inserto en Expensas y guardo mapping en #ExpensasInsertadas
        INSERT INTO Expensas (ID_unidad_funcional, ID_consorcio, periodo, monto_total, estado, fecha_vencimiento)
        OUTPUT inserted.ID_expensas, inserted.ID_unidad_funcional, inserted.ID_consorcio, inserted.monto_total 
        INTO #ExpensasInsertadas (ID_expensas, ID_unidad_funcional, ID_consorcio, MontoTotal)
        SELECT
            u.ID_unidad_funcional,
            u.ID_consorcio,
            LOWER(@periodo) AS periodo,
            ROUND(
                COALESCE(@Total_Ordinarios,0) * CASE WHEN u.m2_total_consorcio = 0 THEN 0 ELSE (u.m2_total_uf / u.m2_total_consorcio) END
                +
                COALESCE(@Total_Extraordinarios,0) * CASE WHEN u.m2_total_consorcio = 0 THEN 0 ELSE (u.m2_total_uf / u.m2_total_consorcio) END
            ,2) AS monto_total,
            'GENERADA' AS estado,
            @vencimiento AS fecha_vencimiento
        FROM #UF_M2_CT u;

        -- Guardamos info de las expensas insertadas en el resultado final
        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        SELECT 'EXPENSAS', CONCAT('ID_expensas_', CAST(ID_expensas AS NVARCHAR(50))), CAST(MontoTotal AS NVARCHAR(100)), 5
        FROM #ExpensasInsertadas;

        -------------------------------
        -- Corregir columnas en #ExpensasInsertadas (si corresponde)
        -------------------------------
        IF EXISTS (SELECT 1 FROM tempdb..sysobjects WHERE name LIKE '#ExpensasInsertadas%')
        BEGIN
            UPDATE ei
            SET
                ei.MontoOrdinario = ROUND(
                    CASE WHEN u.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Ordinarios * (u.m2_total_uf / u.m2_total_consorcio)) END
                ,2),
                ei.MontoExtraordinario = ROUND(
                    CASE WHEN u.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Extraordinarios * (u.m2_total_uf / u.m2_total_consorcio)) END
                ,2),
                ei.MontoTotal = ROUND(
                    COALESCE(ROUND(CASE WHEN u.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Ordinarios * (u.m2_total_uf / u.m2_total_consorcio)) END,2),0)
                    +
                    COALESCE(ROUND(CASE WHEN u.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Extraordinarios * (u.m2_total_uf / u.m2_total_consorcio)) END,2),0)
                ,2)
            FROM #ExpensasInsertadas ei
            JOIN #UF_M2_CT u
                ON u.ID_unidad_funcional = ei.ID_unidad_funcional
                AND u.ID_consorcio = ei.ID_consorcio;
        END

        -------------------------------
        -- INSERTAR Detalle_expensas prorrateado
        -------------------------------
        IF OBJECT_ID('tempdb..#DetalleGastosPeriodo') IS NOT NULL DROP TABLE #DetalleGastosPeriodo;
        CREATE TABLE #DetalleGastosPeriodo (
            ID_detalle_gasto INT,
            ID_gasto INT,
            ID_tipo_gasto INT,
            ID_categoria INT,
            empresa_persona VARCHAR(200),
            descripcion VARCHAR(500),
            importe DECIMAL(18,2),
            nro_factura VARCHAR(100),
            pago_total BIT,
            cuota_actual INT,
            cuota_total INT
        );
    
        INSERT INTO #DetalleGastosPeriodo (ID_detalle_gasto, ID_gasto, ID_tipo_gasto, ID_categoria, empresa_persona, descripcion, importe, nro_factura, pago_total, cuota_actual, cuota_total)
        SELECT
            dg.ID_detalle_gasto,
            dg.ID_gasto,
            g.ID_tipo_gasto,
            g.ID_categoria,
            dg.empresa_persona,
            dg.descripcion,
            dg.importe,
            dg.nro_factura,
            dg.pago_total,
            dg.cuota_actual,
            dg.cuota_total
        FROM Detalle_Gasto dg
        INNER JOIN Gastos g ON g.ID_gastos = dg.ID_gasto
        WHERE g.ID_consorcio = @ID_consorcio
          AND LOWER(CONCAT(YEAR(g.fecha), '-', g.mes)) = LOWER(@periodo);
       
        -- Insert prorrateos por UF (mantengo la l�gica original)
        INSERT INTO Detalles_expensas (ID_expensas, ID_detalle_gasto, concepto, monto, descripcion)
        SELECT
            ei.ID_expensas,
            dgp.ID_detalle_gasto,
            CASE WHEN dgp.ID_tipo_gasto = 1 THEN ISNULL((SELECT nombre FROM CategoriaGastoOrdinario c WHERE c.ID_categoria = dgp.ID_categoria), 'ORDINARIO')
                 ELSE 'EXTRAORDINARIO' END AS concepto,
            ROUND( (dgp.importe * (u.m2_total_uf / NULLIF(ct.m2_total_consorcio,0)) ), 2 ) AS monto,
            dgp.descripcion
        FROM #DetalleGastosPeriodo dgp
        CROSS JOIN (
            SELECT SUM(u2.m2 + ISNULL(c2.m2_sum,0) + ISNULL(b2.m2_sum,0)) AS m2_total_consorcio
            FROM Unidad_funcional u2
            LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Cochera GROUP BY ID_unidad_funcional, ID_consorcio) c2
                ON c2.ID_unidad_funcional = u2.ID_unidad_funcional AND c2.ID_consorcio = u2.ID_consorcio
            LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Baulera GROUP BY ID_unidad_funcional, ID_consorcio) b2
                ON b2.ID_unidad_funcional = u2.ID_unidad_funcional AND b2.ID_consorcio = u2.ID_consorcio
            WHERE u2.ID_consorcio = @ID_consorcio
        ) ct
        INNER JOIN (
            SELECT uf.ID_unidad_funcional, uf.ID_consorcio, (uf.m2 + ISNULL(c.m2_sum,0) + ISNULL(b.m2_sum,0)) AS m2_total_uf
            FROM Unidad_funcional uf
            LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Cochera GROUP BY ID_unidad_funcional, ID_consorcio) c
                ON c.ID_unidad_funcional = uf.ID_unidad_funcional AND c.ID_consorcio = uf.ID_consorcio
            LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Baulera GROUP BY ID_unidad_funcional, ID_consorcio) b
                ON b.ID_unidad_funcional = uf.ID_unidad_funcional AND b.ID_consorcio = uf.ID_consorcio
            WHERE uf.ID_consorcio = @ID_consorcio
        ) u ON 1=1
        JOIN #ExpensasInsertadas ei ON ei.ID_unidad_funcional = u.ID_unidad_funcional AND ei.ID_consorcio = u.ID_consorcio
        ;

        -------------------------------
        --  COMPOSICI�N DEL ESTADO FINANCIERO (�tem 6)
        -------------------------------
        DECLARE @periodo_prev VARCHAR(20);
        ;WITH PeriodoPrev AS (
            SELECT CASE WHEN @mes = 1 THEN 12 ELSE @mes - 1 END AS mes_prev,
                   CASE WHEN @mes = 1 THEN @anio - 1 ELSE @anio END AS anio_prev
        )
        SELECT @periodo_prev =
            CASE p.mes_prev
                WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo' WHEN 6 THEN 'junio'
                WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto' WHEN 9 THEN 'septiembre'
                WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
            END + '-' + CAST(p.anio_prev AS VARCHAR(4))
        FROM PeriodoPrev p;

        DECLARE @SaldoAnterior DECIMAL(18,2) =
            ISNULL((
                SELECT TOP 1 saldo_cierre FROM Estado_financiero ef
                WHERE ef.ID_consorcio = @ID_consorcio AND ef.periodo = LOWER(@periodo_prev)
            ), 0);

        DECLARE @IngresosEnTermino DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(importe) FROM Pagos_importados p
                WHERE p.ID_consorcio = @ID_consorcio
                  AND p.fecha BETWEEN @FechaDesde AND @vencimiento
            ), 0);

        DECLARE @IngresosAdeudadas DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(importe) FROM Pagos_importados p
                WHERE p.ID_consorcio = @ID_consorcio
                  AND p.fecha BETWEEN DATEADD(DAY,1,@vencimiento) AND @segundo_vto
            ), 0);

        DECLARE @IngresosAdelantados DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(importe) FROM Pagos_importados p
                WHERE p.ID_consorcio = @ID_consorcio
                  AND p.fecha > @FechaHasta
            ), 0);

        DECLARE @EgresosMes DECIMAL(18,2) = COALESCE(@Total_Ordinarios,0) + COALESCE(@Total_Extraordinarios,0);

        DECLARE @IngresosTotales DECIMAL(18,2) = @IngresosEnTermino + @IngresosAdeudadas + @IngresosAdelantados;

        DECLARE @SaldoCierre DECIMAL(18,2) = ROUND((@SaldoAnterior + @IngresosTotales - @EgresosMes), 2);
       
        -- Insertar o actualizar Estado_financiero para el per�odo
        IF EXISTS (SELECT 1 FROM Estado_financiero ef WHERE ef.ID_consorcio = @ID_consorcio AND ef.periodo = LOWER(@periodo))
        BEGIN
            UPDATE Estado_financiero
            SET saldo_anterior = @SaldoAnterior,
                saldo_cierre = @SaldoCierre
            WHERE ID_consorcio = @ID_consorcio AND periodo = LOWER(@periodo);
        END
        ELSE
        BEGIN
            INSERT INTO Estado_financiero (ID_consorcio, periodo, saldo_anterior, saldo_cierre)
            VALUES (@ID_consorcio, LOWER(@periodo), @SaldoAnterior, @SaldoCierre);
        END

        -- obtengo el ID_estado_financiero correspondiente al per�odo actual
        SELECT @ID_estado_financiero = ID_estado_financiero
        FROM Estado_financiero
        WHERE ID_consorcio = @ID_consorcio
          AND periodo = LOWER(@periodo);

        -- Insertar detalles del estado financiero
        INSERT INTO Detalle_EstadoFinanciero
        (ID_estado_financiero, ID_tipo_detalle, monto, descripcion)
        VALUES
            (
                @ID_estado_financiero,
                (SELECT ID_tipo_detalle FROM TipoDetalleFinanciero WHERE nombre = 'Saldo anterior'),
                @SaldoAnterior,
                'Saldo anterior'
            ),
            (
                @ID_estado_financiero,
                (SELECT ID_tipo_detalle FROM TipoDetalleFinanciero WHERE nombre = 'Expensas en término'),
                @IngresosEnTermino,
                'Ingresos por pago en término'
            ),
            (
                @ID_estado_financiero,
                (SELECT ID_tipo_detalle FROM TipoDetalleFinanciero WHERE nombre = 'Expensas adeudadas'),
                @IngresosAdeudadas,
                'Ingresos por pagos adeudados'
            ),
            (
                @ID_estado_financiero,
                (SELECT ID_tipo_detalle FROM TipoDetalleFinanciero WHERE nombre = 'Expensas adelantadas'),
                @IngresosAdelantados,
                'Ingresos por expensas adelantadas'
            ),
            (
                @ID_estado_financiero,
                (SELECT ID_tipo_detalle FROM TipoDetalleFinanciero WHERE nombre = 'Gastos del mes'),
                @EgresosMes,
                'Egresos por gastos del mes'
            ),
            (
                @ID_estado_financiero,
                (SELECT ID_tipo_detalle FROM TipoDetalleFinanciero WHERE nombre = 'Saldo al cierre'),
                @SaldoCierre,
                'Saldo al cierre'
            );

        -------------------------------
        -- ACTUALIZAR Estado_cuenta_prorrateo (tabla por UF)
        -------------------------------
        IF OBJECT_ID('tempdb..#PagosPorUF') IS NOT NULL DROP TABLE #PagosPorUF;
        CREATE TABLE #PagosPorUF (
            ID_unidad_funcional INT,
            pagos_recibidos DECIMAL(18,2)
        );

        INSERT INTO #PagosPorUF (ID_unidad_funcional, pagos_recibidos)
        SELECT
            p.ID_unidad_funcional,
            SUM(p.importe)
        FROM Pagos_importados p
        WHERE p.ID_consorcio = @ID_consorcio
          AND p.ID_unidad_funcional IS NOT NULL
          AND p.fecha BETWEEN @FechaDesde AND @FechaHasta
        GROUP BY p.ID_unidad_funcional;

        IF OBJECT_ID('tempdb..#InteresPorUF') IS NOT NULL DROP TABLE #InteresPorUF;
        CREATE TABLE #InteresPorUF (
            ID_unidad_funcional INT,
            interes_mora DECIMAL(18,2)
        );

        INSERT INTO #InteresPorUF (ID_unidad_funcional, interes_mora)
        SELECT
            ei.ID_unidad_funcional,
            ISNULL(SUM(m.importe), 0)
        FROM #ExpensasInsertadas ei
        LEFT JOIN Mora m ON m.ID_expensas = ei.ID_expensas
        GROUP BY ei.ID_unidad_funcional;

        IF OBJECT_ID('tempdb..#EstadoUF') IS NOT NULL DROP TABLE #EstadoUF;
        CREATE TABLE #EstadoUF (
            ID_unidad_funcional INT,
            ID_consorcio INT,
            periodo CHAR(20),
            saldo_anterior DECIMAL(18,2),
            pagos_recibidos DECIMAL(18,2),
            interes_mora DECIMAL(18,2),
            expensas_ordinarias DECIMAL(18,2),
            expensas_extraordinarias DECIMAL(18,2),
            total_pagar DECIMAL(18,2)
        );

        INSERT INTO #EstadoUF (ID_unidad_funcional, ID_consorcio, periodo, saldo_anterior, pagos_recibidos, interes_mora, expensas_ordinarias, expensas_extraordinarias, total_pagar)
        SELECT
            ei.ID_unidad_funcional,
            ei.ID_consorcio,
            LOWER(@periodo),
            ISNULL(prev.saldo_anterior,0) AS saldo_anterior,
            ISNULL(pf.pagos_recibidos,0) AS pagos_recibidos,
            ISNULL(ip.interes_mora,0) AS interes_mora,
            ISNULL(ei.MontoOrdinario,0) AS expensas_ordinarias,
            ISNULL(ei.MontoExtraordinario,0) AS expensas_extraordinarias,
            ROUND(
                (ISNULL(prev.saldo_anterior,0) - ISNULL(pf.pagos_recibidos,0))
                + ISNULL(ip.interes_mora,0)
                + ISNULL(ei.MontoOrdinario,0)
                + ISNULL(ei.MontoExtraordinario,0)
            ,2) AS total_pagar
        FROM #ExpensasInsertadas ei
        LEFT JOIN (
            SELECT ID_unidad_funcional, saldo_anterior FROM Estado_cuenta_prorrateo ec
            WHERE ec.ID_consorcio = @ID_consorcio AND ec.periodo = LOWER(@periodo_prev)
        ) prev ON prev.ID_unidad_funcional = ei.ID_unidad_funcional
        LEFT JOIN #PagosPorUF pf ON pf.ID_unidad_funcional = ei.ID_unidad_funcional
        LEFT JOIN #InteresPorUF ip ON ip.ID_unidad_funcional = ei.ID_unidad_funcional
        ;

        -- Upsert en Estado_cuenta_prorrateo
        UPDATE ec
        SET
            ec.saldo_anterior = ef.saldo_anterior,
            ec.pagos_recibidos = ef.pagos_recibidos,
            ec.interes_mora = ef.interes_mora,
            ec.expensas_ordinarias = ef.expensas_ordinarias,
            ec.expensas_extraordinarias = ef.expensas_extraordinarias,
            ec.total_pagar = ef.total_pagar
        FROM Estado_cuenta_prorrateo ec
        INNER JOIN #EstadoUF ef
            ON ec.ID_unidad_funcional = ef.ID_unidad_funcional
           AND ec.ID_consorcio = ef.ID_consorcio
           AND ec.periodo = ef.periodo;

        INSERT INTO Estado_cuenta_prorrateo (ID_unidad_funcional, ID_consorcio, periodo, saldo_anterior, pagos_recibidos, interes_mora, expensas_ordinarias, expensas_extraordinarias, total_pagar)
        SELECT ef.ID_unidad_funcional, ef.ID_consorcio, ef.periodo, ef.saldo_anterior, ef.pagos_recibidos, ef.interes_mora, ef.expensas_ordinarias, ef.expensas_extraordinarias, ef.total_pagar
        FROM #EstadoUF ef
        LEFT JOIN Estado_cuenta_prorrateo ec
            ON ec.ID_unidad_funcional = ef.ID_unidad_funcional
           AND ec.ID_consorcio = ef.ID_consorcio
           AND ec.periodo = ef.periodo
        WHERE ec.ID_estado_de_cuenta IS NULL;

        -------------------------------
        -- SALIDA FINAL: Composici�n del estado financiero
        -- Insertamos los valores calculados en la tabla unificada
        -------------------------------
        INSERT INTO #ResultadoFinal (Seccion, Clave, Valor, Orden)
        VALUES
            ('ESTADO_FINANCIERO','SaldoAnterior', CAST(@SaldoAnterior AS NVARCHAR(100)), 6),
            ('ESTADO_FINANCIERO','IngresosEnTermino', CAST(@IngresosEnTermino AS NVARCHAR(100)), 6),
            ('ESTADO_FINANCIERO','IngresosAdeudadas', CAST(@IngresosAdeudadas AS NVARCHAR(100)), 6),
            ('ESTADO_FINANCIERO','IngresosAdelantados', CAST(@IngresosAdelantados AS NVARCHAR(100)), 6),
            ('ESTADO_FINANCIERO','EgresosDelMes', CAST(@EgresosMes AS NVARCHAR(100)), 6),
            ('ESTADO_FINANCIERO','SaldoCierre', CAST(@SaldoCierre AS NVARCHAR(100)), 6),
            ('ESTADO_FINANCIERO','Periodo', @periodo, 6);

        -- Al final devolvemos SOLO la tabla unificada (�nico result set)
        SELECT Seccion, Clave, Valor, Orden
        FROM #ResultadoFinal
        ORDER BY Orden, Seccion, Clave;

        --COMMIT;
    END TRY
    BEGIN CATCH
       -- IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en SP_GenerarCSV1_Expensas_Completo: %s',16,1,@ErrMsg);
        RETURN;
    END CATCH
END;
GO
