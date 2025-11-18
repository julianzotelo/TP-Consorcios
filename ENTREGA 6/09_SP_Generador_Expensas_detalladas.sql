/*  SP que prepara todo para mi primer archivo csv que pide el TP
13-11-2025
Comisi�n 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Mart�n    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/
USE Com3641G01;
GO

-- SP maestro que genera el contenido del "CSV1" (�tems 1 a 6)
-- y persiste/actualiza las tablas necesarias (Expensas, Detalles_expensas,
-- Estado_financiero, Detalle_EstadoFinanciero, Estado_cuenta_prorrateo).
-- Prorrateo por m2 (opci�n 2).
CREATE OR ALTER PROCEDURE SP_Generar_Expensas_Completo
(
    @ID_consorcio INT,
    @periodo CHAR(20)  -- formato esperado: 'marzo-2025' (mesNombre-anio)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
      - 'vencimiento' del per�odo se calcula con fn_CalcularVencimiento(@periodo).
      - 'segundo_vto' = vencimiento + 15 d�as (este valor puede parametrizarse luego).
      - Los registros de Gastos se filtran con: CONCAT(YEAR(g.fecha), '-', LOWER(g.mes)) = LOWER(@periodo)
      - Prorrateo: cada UF aporta seg�n (m2_uf_total / m2_total_consorcio).
      - Para cocheras/bauleras incluimos su m2 al m2_total_uf (como definiste antes).
    */

    BEGIN TRY
        BEGIN TRAN;

        -------------------------------
        -- 0) Calculos y variables base
        -------------------------------
        print 1
        DECLARE @anio INT = TRY_CAST(RIGHT(@periodo,4) AS INT);
        DECLARE @mesNombre VARCHAR(20) = LEFT(@periodo, CHARINDEX('-', @periodo + '-') - 1);
        print @mesNombre

        DECLARE @mes INT =
            CASE LOWER(LTRIM(RTRIM(@mesNombre)))
                WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
                WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
                WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
                WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
                ELSE NULL
            END;

        IF @anio IS NULL OR @mes IS NULL
        BEGIN
            RAISERROR('Periodo inv�lido. Usar formato ''mes-YYYY'' (ej: marzo-2025).', 16, 1);
            ROLLBACK;
            RETURN;
        END
        print 2
        DECLARE @FechaDesde DATE = DATEFROMPARTS(@anio, @mes, 1);
        DECLARE @FechaHasta DATE = EOMONTH(@FechaDesde);
        select @mesNombre
        DECLARE @vencimiento DATE = dbo.fn_CalcularVencimiento(@mesNombre); 
        DECLARE @segundo_vto DATE = DATEADD(DAY, 15, @vencimiento); -- SUPOSICI�N: 15 d�as para 2do vencimiento

        SELECT
            'ENCABEZADO' AS Seccion,
            c.ID_consorcio,
            c.consorcio,
            c.nombre AS administrador,
            c.direccion,
            c.cant_unidades,
            c.m2_totales
        FROM Consorcios c
        WHERE c.ID_consorcio = @ID_consorcio;

        -------------------------------
        --FORMA DE PAGO Y VENCIMIENTO (�tem 2)
        --   Para cada consorcio/periodo devolvemos forma de pago (CBU) y fecha de vencimiento.
        -------------------------------
        print 3
        SELECT
            'PAGO_Y_VENCIMIENTO' AS Seccion,
            c.CBU_CVU AS CuentaBancaria,
            @vencimiento AS FechaVencimiento,
            @segundo_vto AS FechaSegundoVto,
            @periodo AS Periodo
        FROM Consorcios c
        WHERE c.ID_consorcio = @ID_consorcio;


        -------------------------------
        -- m2 por UF (incluyendo cochera y baulera)
        -------------------------------
        ;WITH CocheASum AS (
            SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
            FROM Cochera
            GROUP BY ID_unidad_funcional, ID_consorcio
        ), BauleraSum AS (
            SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
            FROM Baulera
            GROUP BY ID_unidad_funcional, ID_consorcio
        ), UF_M2 AS (
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
                ON c.ID_unidad_funcional = uf.ID_unidad_funcional AND c.ID_consorcio = uf.ID_consorcio
            LEFT JOIN BauleraSum b
                ON b.ID_unidad_funcional = uf.ID_unidad_funcional AND b.ID_consorcio = uf.ID_consorcio
            WHERE uf.ID_consorcio = @ID_consorcio
        ), CONS_TOTAL AS (
            SELECT SUM(m2_total_uf) AS m2_total_consorcio FROM UF_M2
        )

        -------------------------------
        -- LISTADO DE GASTOS ORDINARIOS (�tem 4)
        --     Recupero los gastos ordinarios del periodo (ID_tipo_gasto = 1).
        --    suma el total de ordinarios para prorrateo.
        -------------------------------
       
        SELECT
            'GASTOS_ORDINARIOS' AS Seccion,
            g.ID_gastos,
            g.concepto,
            LOWER(g.mes) AS mes,
            dg.empresa_persona,
            dg.descripcion,
            dg.importe,
            dg.nro_factura,
            dg.pago_total,
            dg.cuota_actual,
            dg.cuota_total
        FROM Gastos g
        INNER JOIN Detalle_Gasto dg ON dg.ID_gasto = g.ID_gastos
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 1
          AND LOWER(CONCAT(YEAR(g.fecha), '-', g.mes)) = LOWER(@periodo);

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
        --LISTADO DE GASTOS EXTRAORDINARIOS (�tem 5)
        --    Recupero los gastos extraordinarios del periodo (ID_tipo_gasto = 2).
        -------------------------------
        print 4 
        SELECT
            'GASTOS_EXTRAORDINARIOS' AS Seccion,
            g.ID_gastos,
            g.concepto,
            LOWER(g.mes) AS mes,
            dg.empresa_persona,
            dg.descripcion,
            dg.importe,
            dg.nro_factura,
            dg.pago_total,
            dg.cuota_actual,
            dg.cuota_total
        FROM Gastos g
        INNER JOIN Detalle_Gasto dg ON dg.ID_gasto = g.ID_gastos
        WHERE g.ID_consorcio = @ID_consorcio
          AND g.ID_tipo_gasto = 2
          AND LOWER(CONCAT(YEAR(g.fecha), '-', g.mes)) = LOWER(@periodo);

        -- Total gastos extraordinarios del per�odo (para prorrateo)
        DECLARE @Total_Extraordinarios DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(dg.importe)
                FROM Gastos g
                INNER JOIN Detalle_Gasto dg ON dg.ID_gasto = g.ID_gastos
                WHERE g.ID_consorcio = @ID_consorcio
                  AND g.ID_tipo_gasto = 2
                  AND LOWER(CONCAT(YEAR(g.fecha), '-', g.mes)) = LOWER(@periodo)
            ), 0);

        -------------------------------
        --  GENERAR EXPENSAS POR UF (prorrateo por m2) y Detalles_expensas
        --   Inserta una Expensa por cada UF con monto_total = ord + extra
        --   Inserta un Detalle_expensas por cada Detalle_Gasto prorrateado (y subtotales por categor�a)
        --   Esto cumple los �tems 3,4,5 parcialmente (detalle por UF).
        -------------------------------

        -- tabla temporal para mapear UF Expensa insertada
        IF OBJECT_ID('tempdb..#ExpensasInsertadas') IS NOT NULL DROP TABLE #ExpensasInsertadas;
        CREATE TABLE #ExpensasInsertadas (
            ID_unidad_funcional INT,
            ID_consorcio INT,
            ID_expensas INT,
            MontoOrdinario DECIMAL(18,2),
            MontoExtraordinario DECIMAL(18,2),
            MontoTotal DECIMAL(18,2)
        );

       ;WITH UF_M2_CT AS (
    -- 1) Calcular los m2 completos por UF
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
    WHERE uf.ID_consorcio = @ID_consorcio
)

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
       FROM UF_M2_CT u;


        -- Corregir columnas en #ExpensasInsertadas: (inserci�n anterior con OUTPUT devolvi� orden distinto)
        -- El OUTPUT puso ID_expensas, ID_unidad_funcional, ID_consorcio, monto_total en ese orden.
        -- Reorganizamos la tabla para que quede consistente:
        IF EXISTS (SELECT 1 FROM tempdb..sysobjects WHERE name LIKE '#ExpensasInsertadas%')
        BEGIN
            -- Aseguramos que las columnas est�n con los nombres correctos (ya creadas as�).
            -- Ahora actualizaremos los montos separados (ordinario/extra) en la tabla temporal.
            UPDATE ei
            SET
                ei.MontoOrdinario = ROUND(
                    CASE WHEN ct.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Ordinarios * (u.m2_total_uf / ct.m2_total_consorcio)) END
                ,2),
                ei.MontoExtraordinario = ROUND(
                    CASE WHEN ct.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Extraordinarios * (u.m2_total_uf / ct.m2_total_consorcio)) END
                ,2),
                ei.MontoTotal = ROUND(
                    COALESCE(ROUND(CASE WHEN ct.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Ordinarios * (u.m2_total_uf / ct.m2_total_consorcio)) END,2),0)
                    +
                    COALESCE(ROUND(CASE WHEN ct.m2_total_consorcio = 0 THEN 0 ELSE (@Total_Extraordinarios * (u.m2_total_uf / ct.m2_total_consorcio)) END,2),0)
                ,2)
            FROM #ExpensasInsertadas ei
            JOIN (
                SELECT u.ID_unidad_funcional, u.ID_consorcio, u.m2_total_uf,
                       (SELECT ISNULL(SUM(uf2.m2 + ISNULL(c2.m2_sum,0) + ISNULL(b2.m2_sum,0)),0)
                        FROM Unidad_funcional uf2
                        LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Cochera GROUP BY ID_unidad_funcional, ID_consorcio) c2
                            ON c2.ID_unidad_funcional = uf2.ID_unidad_funcional AND c2.ID_consorcio = uf2.ID_consorcio
                        LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Baulera GROUP BY ID_unidad_funcional, ID_consorcio) b2
                            ON b2.ID_unidad_funcional = uf2.ID_unidad_funcional AND b2.ID_consorcio = uf2.ID_consorcio
                        WHERE uf2.ID_consorcio = @ID_consorcio
                       ) AS m2_total_consorcio
                FROM Unidad_funcional u
                LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Cochera GROUP BY ID_unidad_funcional, ID_consorcio) c
                    ON c.ID_unidad_funcional = u.ID_unidad_funcional AND c.ID_consorcio = u.ID_consorcio
                LEFT JOIN (SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum FROM Baulera GROUP BY ID_unidad_funcional, ID_consorcio) b
                    ON b.ID_unidad_funcional = u.ID_unidad_funcional AND b.ID_consorcio = u.ID_consorcio
                WHERE u.ID_consorcio = @ID_consorcio
            ) u ON u.ID_unidad_funcional = ei.ID_unidad_funcional AND u.ID_consorcio = ei.ID_consorcio
            CROSS APPLY (SELECT u.m2_total_uf AS m2_total_uf_val, u.m2_total_consorcio AS ct_val) ca
            CROSS JOIN (SELECT 1) dummy
            -- ct referenced via subselect above
            ;
        END

        -------------------------------
        -- INSERTAR Detalle_expensas prorrateado
        --    Para cada Detalle_Gasto del per�odo prorrateamos su importe por m2
        --    Insertamos un registro en Detalles_expensas por cada UF con ID_detalle_gasto y monto calculado.
        --    Tambi�n insertamos un "Subtotal" por categor�a si se desea (aqu� lo calculamos por UF+categoria)
        -------------------------------

        -- Primero recupero los detalles de gasto del per�odo (ordinarios + extraordinarios)
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

        -- Insert prorrateos por UF
        -- Insertamos para cada detalle_gasto y cada UF el monto proporcional.
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
        --     Calculamos:
        --       * Saldo anterior: tomado desde Estado_financiero del periodo previo si existe
        --       * Ingresos por pago en t�rmino: Pagos_importados.fecha BETWEEN @FechaDesde AND @vencimiento
        --       * Ingresos por pago de expensas adeudadas: Pagos entre vencimiento+1 y segundo_vto
        --       * Ingresos por expensas adelantadas: pagos con fecha > @FechaHasta (SUPOSICI�N)
        --       * Egresos por gastos del mes: @Total_Ordinarios + @Total_Extraordinarios
        --       * Saldo al cierre = saldo_anterior + ingresos_totales - egresos_totales
        -------------------------------

        -- Saldo anterior (busco registro de Estado_financiero del periodo previo)
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

        -- Ingresos por pagos en t�rmino
        DECLARE @IngresosEnTermino DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(importe) FROM Pagos_importados p
                WHERE p.ID_consorcio = @ID_consorcio
                  AND p.fecha BETWEEN @FechaDesde AND @vencimiento
            ), 0);

        -- Ingresos por pagos adeudadas (entre 1er vto y 2do vto)
        DECLARE @IngresosAdeudadas DECIMAL(18,2) =
            ISNULL((
                SELECT SUM(importe) FROM Pagos_importados p
                WHERE p.ID_consorcio = @ID_consorcio
                  AND p.fecha BETWEEN DATEADD(DAY,1,@vencimiento) AND @segundo_vto
            ), 0);

        -- Ingresos por pagos adelantados (SUPOSICI�N: pagos con fecha > FechaHasta)
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

        -- Obtener el ID_estado_financiero actual
        DECLARE @ID_estado_financiero INT = (SELECT ID_estado_financiero FROM Estado_financiero WHERE ID_consorcio = @ID_consorcio AND periodo = LOWER(@periodo));

        -- Insertar Detalle_EstadoFinanciero con los items requeridos por el enunciado
        -- Primero elimino los anteriores para evitar duplicados (idempotencia)
        DELETE FROM Detalle_EstadoFinanciero WHERE ID_estado_financiero = @ID_estado_financiero;

        INSERT INTO Detalle_EstadoFinanciero (ID_estado_financiero, ID_tipo_detalle, monto, descripcion)
        VALUES
            (@ID_estado_financiero, NULL, @SaldoAnterior, 'Saldo anterior'), -- ID_tipo_detalle puede mapear a un cat�logo si lo deseas
            (@ID_estado_financiero, NULL, @IngresosEnTermino, 'Ingresos por pago en t�rmino'),
            (@ID_estado_financiero, NULL, @IngresosAdeudadas, 'Ingresos por pagos adeudados'),
            (@ID_estado_financiero, NULL, @IngresosAdelantados, 'Ingresos por expensas adelantadas'),
            (@ID_estado_financiero, NULL, @EgresosMes, 'Egresos por gastos del mes'),
            (@ID_estado_financiero, NULL, @SaldoCierre, 'Saldo al cierre');

        -------------------------------
        --  ACTUALIZAR Estado_cuenta_prorrateo (tabla por UF)
        --    -> Inserta/actualiza por cada UF: saldo anterior, pagos recibidos, interes_mora (si existe),
        --       expensas_ordinarias, expensas_extraordinarias, total_pagar.
        --    -> Esto alimenta el CSV2 y la trazabilidad por UF.
        -------------------------------

        -- Primero tomamos los pagos por UF en el periodo
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

        -- Inter�s por mora por UF: sumamos Mora.importe asociada a las expensas generadas este per�odo
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

        -- Ahora actualizamos/inserto en Estado_cuenta_prorrateo por cada UF usando #ExpensasInsertadas
        -- Construimos filas temporales con datos por UF
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
            -- total a pagar = saldo_anterior - pagos_recibidos + interes_mora + expensas ordinarias + expensas extraordinarias
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
        -- Actualizar existentes
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

        -- Insertar nuevos
        INSERT INTO Estado_cuenta_prorrateo (ID_unidad_funcional, ID_consorcio, periodo, saldo_anterior, pagos_recibidos, interes_mora, expensas_ordinarias, expensas_extraordinarias, total_pagar)
        SELECT ef.ID_unidad_funcional, ef.ID_consorcio, ef.periodo, ef.saldo_anterior, ef.pagos_recibidos, ef.interes_mora, ef.expensas_ordinarias, ef.expensas_extraordinarias, ef.total_pagar
        FROM #EstadoUF ef
        LEFT JOIN Estado_cuenta_prorrateo ec
            ON ec.ID_unidad_funcional = ef.ID_unidad_funcional
           AND ec.ID_consorcio = ef.ID_consorcio
           AND ec.periodo = ef.periodo
        WHERE ec.ID_estado_de_cuenta IS NULL;

        -------------------------------
        --  SALIDA FINAL: Composici�n del estado financiero (�tem 6) como SELECT
        -------------------------------
        SELECT
            'ESTADO_FINANCIERO' AS Seccion,
            @SaldoAnterior AS SaldoAnterior,
            @IngresosEnTermino AS IngresosEnTermino,
            @IngresosAdeudadas AS IngresosAdeudadas,
            @IngresosAdelantados AS IngresosAdelantados,
            @EgresosMes AS EgresosDelMes,
            @SaldoCierre AS SaldoCierre,
            @periodo AS Periodo
        ;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en SP_GenerarCSV1_Expensas_Completo: %s',16,1,@ErrMsg);
        RETURN;
    END CATCH
END;
GO
