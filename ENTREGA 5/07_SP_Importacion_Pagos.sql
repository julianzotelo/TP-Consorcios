/*  Importar Servicios.Servicios.json
13-11-2025
Comisión 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Martín    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/

use Com3641G01
go

CREATE OR ALTER PROCEDURE dbo.SP_Cargar_Gastos_Desde_JSON
    @RutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InsertadosGastos INT = 0;
    DECLARE @ServiciosAntes INT = 0;
    DECLARE @ServiciosDespues INT = 0;
    DECLARE @InsertadosServicios INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

  
        -- Contar servicios antes (por trigger)

        SELECT @ServiciosAntes = COUNT(*) FROM Servicios;

      
        -- Leer archivo JSON
    
        DECLARE @json NVARCHAR(MAX);
        DECLARE @sql NVARCHAR(MAX);

        SET @sql = N'SELECT @jsonOUT = BulkColumn FROM OPENROWSET(BULK ''' + @RutaArchivo + ''', SINGLE_CLOB) AS j;';
        EXEC sp_executesql @sql, N'@jsonOUT NVARCHAR(MAX) OUTPUT', @jsonOUT=@json OUTPUT;

        IF @json IS NULL
        BEGIN
            RAISERROR('No se pudo leer el archivo JSON.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

     
        -- Crear tabla temporal
   
        IF OBJECT_ID('tempdb..#tmpGastos') IS NOT NULL DROP TABLE #tmpGastos;

        SELECT 
            [Nombre del consorcio],
            Mes,
            [BANCARIOS],
            [LIMPIEZA],
            [ADMINISTRACION],
            [SEGUROS],
            [GASTOS GENERALES],
            [SERVICIOS PUBLICOS-Agua],
            [SERVICIOS PUBLICOS-Luz]
        INTO #tmpGastos
        FROM OPENJSON(@json)
        WITH (
            [Nombre del consorcio] NVARCHAR(100) '$."Nombre del consorcio"',
            Mes NVARCHAR(20) '$.Mes',
            [BANCARIOS] NVARCHAR(50) '$.BANCARIOS',
            [LIMPIEZA] NVARCHAR(50) '$.LIMPIEZA',
            [ADMINISTRACION] NVARCHAR(50) '$.ADMINISTRACION',
            [SEGUROS] NVARCHAR(50) '$.SEGUROS',
            [GASTOS GENERALES] NVARCHAR(50) '$."GASTOS GENERALES"',
            [SERVICIOS PUBLICOS-Agua] NVARCHAR(50) '$."SERVICIOS PUBLICOS-Agua"',
            [SERVICIOS PUBLICOS-Luz] NVARCHAR(50) '$."SERVICIOS PUBLICOS-Luz"'
        );

   
        -- Insertar en Gastos
   
        WITH GastosUnpivot AS (
            SELECT 
                [Nombre del consorcio],
                Mes,
                Categoria,
                REPLACE(REPLACE(REPLACE(Valor, '$', ''), '.', ''), ',', '.') AS Valor
            FROM #tmpGastos
            UNPIVOT (
                Valor FOR Categoria IN (
                    [BANCARIOS], [LIMPIEZA], [ADMINISTRACION], [SEGUROS], 
                    [GASTOS GENERALES], [SERVICIOS PUBLICOS-Agua], [SERVICIOS PUBLICOS-Luz]
                )
            ) AS unpvt
        )
        INSERT INTO Gastos (ID_consorcio, ID_tipo_gasto, ID_categoria, monto_total, concepto, fecha, mes)
        SELECT 
            c.ID_consorcio,
            NULL,
            NULL,
            TRY_CAST(Valor AS DECIMAL(10,2)),
            Categoria,
            GETDATE(),
            g.Mes
        FROM GastosUnpivot g
        INNER JOIN Consorcios c ON c.nombre = g.[Nombre del consorcio]
        WHERE TRY_CAST(Valor AS DECIMAL(10,2)) IS NOT NULL
        AND NOT EXISTS (
            SELECT 1 
            FROM Gastos gx
            WHERE gx.ID_consorcio = c.ID_consorcio
              AND gx.concepto = g.Categoria
              AND gx.mes = g.Mes
        );


        -- Cantidad insertada en Gastos
 
        SET @InsertadosGastos = @@ROWCOUNT;


        -- Contar servicios después (trigger)
 
        SELECT @ServiciosDespues = COUNT(*) FROM Servicios;

        SET @InsertadosServicios = @ServiciosDespues - @ServiciosAntes;

        COMMIT TRANSACTION;

    
        PRINT 'Importación completada correctamente.';
        PRINT 'Gastos insertados: ' + CAST(@InsertadosGastos AS NVARCHAR(10));
        PRINT 'Servicios creados automáticamente por trigger: ' + CAST(@InsertadosServicios AS NVARCHAR(10));

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        PRINT 'Error al importar gastos: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
