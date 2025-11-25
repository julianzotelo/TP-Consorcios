/*  Generacion de estado de cuenta y prorrateo
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
go

CREATE OR ALTER PROCEDURE SP_Generar_EstadoCuenta_Prorrateo
(
    @ID_consorcio INT,
    @periodo CHAR(20)  -- formato: 'marzo-2025'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
    SP_Generar_EstadoCuenta_Prorrateo
    - Calcula el estado de cuentas y prorrateo para todas las UF de un consorcio en @periodo.
    - Inserta o actualiza filas en Estado_cuenta_prorrateo.
    - Devuelve el conjunto listo para exportar a CSV (columnas como en el enunciado / ejemplo).
    - Cumple: % por m2 (incluye cochera/baulera), propietario vigente, saldo anterior, pagos recibidos,
             deuda, inter�s por mora, expensas ordinarias/extraj, total a pagar.
    - No usa cursores; todo set-based.
    */

    BEGIN TRY
       -- BEGIN TRAN;

        -- 1) Validaciones b�sicas y parseo de periodo
        DECLARE @anio INT =  TRY_CAST(SUBSTRING(@periodo, CHARINDEX('-', @periodo) + 1, 4) AS INT);
        DECLARE @mesNombre VARCHAR(20) = LEFT(@periodo, LEN(@periodo) - 5);
        print @mesNombre
        print convert(varchar,@anio)
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
            RAISERROR('Periodo inválido. Usar formato ''mes-YYYY'' (ej: marzo-2025).', 16, 1);
            ROLLBACK;
            RETURN;
        END

        DECLARE @FechaDesde DATE = DATEFROMPARTS(@anio, @mes, 1);
        DECLARE @FechaHasta DATE = EOMONTH(@FechaDesde);

        -- 2) CTE con m2 por UF (incluye m2 de cochera y m2 de baulera)
        ;WITH UF_M2 AS (
            SELECT
                uf.ID_unidad_funcional,
                uf.ID_consorcio,
                uf.departamento,
                uf.piso,
                uf.coeficiente,
                uf.m2 AS m2_uf,
                ISNULL(c.m2_sum, 0) AS m2_cochera,
                ISNULL(b.m2_sum, 0) AS m2_baulera,
                (uf.m2 + ISNULL(c.m2_sum,0) + ISNULL(b.m2_sum,0)) AS m2_total_uf
            FROM Unidad_funcional uf
            LEFT JOIN (
                SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
                FROM Cochera
                GROUP BY ID_unidad_funcional, ID_consorcio
            ) c ON c.ID_unidad_funcional = uf.ID_unidad_funcional AND c.ID_consorcio = uf.ID_consorcio
            LEFT JOIN (
                SELECT ID_unidad_funcional, ID_consorcio, SUM(m2) AS m2_sum
                FROM Baulera
                GROUP BY ID_unidad_funcional, ID_consorcio
            ) b ON b.ID_unidad_funcional = uf.ID_unidad_funcional AND b.ID_consorcio = uf.ID_consorcio
            WHERE uf.ID_consorcio = @ID_consorcio
        ),
        CONS_TOTAL AS (
            SELECT SUM(m2_total_uf) AS m2_total_consorcio FROM UF_M2
        ),

        -- 3) Propietario vigente por UF
        UF_PROPIETARIOS AS (
            SELECT ufp.ID_unidad_funcional, ufp.ID_consorcio,
                   pi.nombre + ' ' + pi.apellido AS propietario,
                   pi.DNI, pi.email, pi.telefono
            FROM UnidadFuncionalPersona ufp
            JOIN PropietarioInquilino pi ON pi.ID_PropietarioInquilino = ufp.ID_PropietarioInquilino
            WHERE ufp.rol = 'PROPIETARIO'
        ),

        -- 4) Expensa del periodo por UF
        EXPensasUF AS (
            SELECT e.ID_expensas, e.ID_unidad_funcional, e.ID_consorcio
            FROM Expensas e
            WHERE e.ID_consorcio = @ID_consorcio AND e.periodo = @periodo
        ),

        -- 5) Detalles clasificados por tipo (para separar ordinario/extraordinario)
        DETALLE_CLASIFICADO AS (
            SELECT
                de.ID_detalle_expensas,
                efu.ID_unidad_funcional,
                efu.ID_expensas,
                de.ID_detalle_gasto,
                de.concepto,
                de.monto,
                de.descripcion,
                g.ID_tipo_gasto
            FROM Detalles_expensas de
            INNER JOIN EXPensasUF efu ON efu.ID_expensas = de.ID_expensas
            LEFT JOIN Detalle_Gasto dg ON dg.ID_detalle_gasto = de.ID_detalle_gasto
            LEFT JOIN Gastos g ON dg.ID_gasto = g.ID_gastos
            WHERE de.concepto NOT LIKE 'Subtotal%' AND de.concepto NOT LIKE 'Total%'
        ),

        SUMAS_POR_UF AS (
            SELECT
            dc.ID_unidad_funcional,
            SUM(CASE
                WHEN dc.ID_tipo_gasto = 1 THEN dc.monto
               -- WHEN dc.ID_tipo_gasto IS NULL AND LOWER(dc.descripcion) LIKE 'servicio%' THEN dc.monto
                ELSE 0 END) AS expensas_ordinarias,
             SUM(CASE WHEN dc.ID_tipo_gasto = 2 THEN dc.monto ELSE 0 END) AS expensas_extraordinarias
             FROM DETALLE_CLASIFICADO dc
             GROUP BY dc.ID_unidad_funcional
            ),

        -- 6) Pagos del periodo por UF
        PAGOS_POR_UF AS (
            SELECT p.ID_unidad_funcional, SUM(p.importe) AS pagos_recibidos
            FROM Pagos_importados p
            WHERE p.ID_consorcio = @ID_consorcio
              AND p.ID_unidad_funcional IS NOT NULL
              AND p.fecha BETWEEN @FechaDesde AND @FechaHasta
            GROUP BY p.ID_unidad_funcional
        ),

        -- 7) Periodo previo (para saldo anterior)
        PeriodoPrevio AS (
            SELECT
                CASE WHEN @mes = 1 THEN 12 ELSE @mes - 1 END AS mes_prev,
                CASE WHEN @mes = 1 THEN @anio - 1 ELSE @anio END AS anio_prev
        ),
        PeriodoPrevioText AS (
            SELECT
                CASE mes_prev
                    WHEN 1 THEN 'enero' WHEN 2 THEN 'febrero' WHEN 3 THEN 'marzo'
                    WHEN 4 THEN 'abril' WHEN 5 THEN 'mayo' WHEN 6 THEN 'junio'
                    WHEN 7 THEN 'julio' WHEN 8 THEN 'agosto' WHEN 9 THEN 'septiembre'
                    WHEN 10 THEN 'octubre' WHEN 11 THEN 'noviembre' WHEN 12 THEN 'diciembre'
                END + '-' + CAST(anio_prev AS VARCHAR(4)) AS periodo_prev
            FROM PeriodoPrevio
        ),
        SALDO_ANTERIOR AS (
            SELECT ec.ID_unidad_funcional, ec.saldo_anterior
            FROM Estado_cuenta_prorrateo ec
            CROSS JOIN PeriodoPrevioText ppt
            WHERE ec.ID_consorcio = @ID_consorcio AND ec.periodo = ppt.periodo_prev
        ),

        -- 8) Inter�s por mora por expensa (suma Mora.importe por expensa)
        INTERES_POR_EXPENSA AS (
            SELECT efu.ID_unidad_funcional, ISNULL(SUM(m.importe),0) AS interes_mora
            FROM EXPensasUF efu
            LEFT JOIN Mora m ON m.ID_expensas = efu.ID_expensas
            GROUP BY efu.ID_unidad_funcional
        )
      
        -- 9) Construcci�n del resultado final por UF
        SELECT
            u.ID_unidad_funcional AS UF,
            CASE WHEN ct.m2_total_consorcio = 0 THEN 0
                 ELSE ROUND((u.m2_total_uf / ct.m2_total_consorcio) * 100.0, 4)
            END AS Porcentaje,
            CONCAT(u.piso, '-', u.departamento) AS PisoDepto,
            -- cantidad de cocheras/bauleras asociadas (informativo)
            ISNULL((SELECT COUNT(1) FROM Cochera c WHERE c.ID_unidad_funcional = u.ID_unidad_funcional AND c.ID_consorcio = u.ID_consorcio),0) AS Cocheras,
            ISNULL((SELECT COUNT(1) FROM Baulera b WHERE b.ID_unidad_funcional = u.ID_unidad_funcional AND b.ID_consorcio = u.ID_consorcio),0) AS Bauleras,
            ISNULL(up.propietario,'') AS Propietario,
            ISNULL(sa.saldo_anterior, 0) AS SaldoAnterior,
            ISNULL(pp.pagos_recibidos, 0) AS PagosRecibidos,
            (ISNULL(sa.saldo_anterior, 0) - ISNULL(pp.pagos_recibidos, 0)) AS Deuda,
            ISNULL(ip.interes_mora, 0) AS InteresPorMora,
            ISNULL(sp.expensas_ordinarias, 0) AS ExpensasOrdinarias,
            ISNULL(sp.expensas_extraordinarias, 0) AS ExpensasExtraordinarias,
            -- total a pagar acumulando deuda + intereses + expensas
            (ISNULL(sa.saldo_anterior, 0) - ISNULL(pp.pagos_recibidos, 0))
                + ISNULL(ip.interes_mora, 0)
                + ISNULL(sp.expensas_ordinarias, 0)
                + ISNULL(sp.expensas_extraordinarias, 0) AS TotalAPagar
        INTO #ResultadoFinal
        FROM UF_M2 u
        CROSS JOIN CONS_TOTAL ct
        LEFT JOIN UF_PROPIETARIOS up ON up.ID_unidad_funcional = u.ID_unidad_funcional
        LEFT JOIN SALDO_ANTERIOR sa ON sa.ID_unidad_funcional = u.ID_unidad_funcional
        LEFT JOIN PAGOS_POR_UF pp ON pp.ID_unidad_funcional = u.ID_unidad_funcional
        LEFT JOIN INTERES_POR_EXPENSA ip ON ip.ID_unidad_funcional = u.ID_unidad_funcional
        LEFT JOIN SUMAS_POR_UF sp ON sp.ID_unidad_funcional = u.ID_unidad_funcional
        ;

        -- 10) Upsert en Estado_cuenta_prorrateo (update + insert)
        -- Actualizar registros ya existentes
        UPDATE ec
        SET
            ec.saldo_anterior = rf.SaldoAnterior,
            ec.pagos_recibidos = rf.PagosRecibidos,
            ec.interes_mora = rf.InteresPorMora,
            ec.expensas_ordinarias = rf.ExpensasOrdinarias,
            ec.expensas_extraordinarias = rf.ExpensasExtraordinarias,
            ec.total_pagar = rf.TotalAPagar
        FROM Estado_cuenta_prorrateo ec
        INNER JOIN #ResultadoFinal rf
            ON ec.ID_unidad_funcional = rf.UF
           AND ec.ID_consorcio = @ID_consorcio
           AND ec.periodo = @periodo;

        -- Insertar registros que no existan
        INSERT INTO Estado_cuenta_prorrateo
            (ID_unidad_funcional, ID_consorcio, periodo, saldo_anterior, pagos_recibidos,
             interes_mora, expensas_ordinarias, expensas_extraordinarias, total_pagar)
        SELECT
            rf.UF,
            @ID_consorcio,
            @periodo,
            rf.SaldoAnterior,
            rf.PagosRecibidos,
            rf.InteresPorMora,
            rf.ExpensasOrdinarias,
            rf.ExpensasExtraordinarias,
            rf.TotalAPagar
        FROM #ResultadoFinal rf
        LEFT JOIN Estado_cuenta_prorrateo ec
            ON ec.ID_unidad_funcional = rf.UF
           AND ec.ID_consorcio = @ID_consorcio
           AND ec.periodo = @periodo
        WHERE ec.ID_estado_de_cuenta IS NULL;

        -- 11) Devolver el resultado final listo para exportar a CSV (orden amigable)
        SELECT
            UF,
            Porcentaje,
            PisoDepto AS [Piso-Depto],
            Cocheras,
            Bauleras,
            Propietario,
            SaldoAnterior AS [Saldo anterior abonado],
            PagosRecibidos AS [Pagos recibidos],
            Deuda,
            InteresPorMora AS [Interes por mora],
            ExpensasOrdinarias AS [Expensas ordinarias],
            ExpensasExtraordinarias AS [Expensas extraordinarias],
            TotalAPagar AS [Total a Pagar]
        FROM #ResultadoFinal
        ORDER BY UF;

        DROP TABLE #ResultadoFinal;

       -- COMMIT;
    END TRY
    BEGIN CATCH
        --IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en SP_Generar_EstadoCuenta_Prorrateo: %s', 16, 1, @err);
    END CATCH
END;
GO


--exec SP_Generar_EstadoCuenta_Prorrateo
-- @ID_consorcio = 1,
--    @periodo = 'abril-2025'  -- formato: 'marzo-2025'