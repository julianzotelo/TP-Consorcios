/*  Importar pagos_consorcios.csv
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

CREATE OR ALTER PROCEDURE dbo.SP_Cargar_Pagos_Importados
    @Ruta NVARCHAR(500),
    @NombreArchivo NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET IMPLICIT_TRANSACTIONS OFF;

    DECLARE @ArchivoCompleto NVARCHAR(1000);
    SET @ArchivoCompleto = @Ruta + '\' + @NombreArchivo;

    -- Contadores
    DECLARE 
        @CantLeidos INT = 0,
        @CantInsertados INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Tabla temporal
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL DROP TABLE #PagosTemp;

        CREATE TABLE #PagosTemp (
            IdPago INT,
            fecha VARCHAR(20),
            CVU_CBU CHAR(22),
            Valor VARCHAR(50)
        );

        -- Bulk insert
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = N'
            BULK INSERT #PagosTemp
            FROM ''' + @ArchivoCompleto + '''
            WITH (
                FORMAT = ''CSV'',
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''ACP'',
                TABLOCK
            );
        ';
        EXEC (@sql);

        -- Contador de registros leídos
        SELECT @CantLeidos = COUNT(*) FROM #PagosTemp;

        ;WITH DatosLimpios AS (
            SELECT
                TRY_CAST(IdPago AS INT) AS IdPago,
                TRY_CONVERT(DATE, fecha, 103) AS fecha,
                RTRIM(LTRIM(REPLACE(REPLACE(CVU_CBU, ' ', ''), CHAR(13), ''))) AS CVU_CBU,
                TRY_CAST(REPLACE(REPLACE(REPLACE(Valor, '$', ''), '.', ''), ',', '.') AS DECIMAL(10,2)) AS importe
            FROM #PagosTemp
            WHERE CVU_CBU IS NOT NULL AND CVU_CBU <> ''
        )

        INSERT INTO Pagos_importados (fecha, cuenta_origen, importe, asociado, ID_unidad_funcional, ID_consorcio)
        SELECT 
            dl.fecha,
            dl.CVU_CBU,
            dl.importe,
            CASE WHEN ufp.ID_unidad_funcional IS NOT NULL THEN 1 ELSE 0 END AS asociado,
            ufp.ID_unidad_funcional,
            ufp.ID_consorcio
        FROM DatosLimpios dl
        LEFT JOIN PropietarioInquilino pi ON pi.CVU_CBU = dl.CVU_CBU
        LEFT JOIN UnidadFuncionalPersona ufp ON ufp.ID_PropietarioInquilino = pi.ID_PropietarioInquilino
        WHERE NOT EXISTS (
            SELECT 1 
            FROM Pagos_importados p
            WHERE p.fecha = dl.fecha
              AND p.cuenta_origen = dl.CVU_CBU
              AND p.importe = dl.importe
        );

        -- Cantidad insertada
        SET @CantInsertados = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT 'Importación realizada con éxito';
        PRINT ' - Registros leídos: ' + CAST(@CantLeidos AS NVARCHAR);
        PRINT ' - Registros insertados (sin duplicados): ' + CAST(@CantInsertados AS NVARCHAR);
        PRINT ' - Registros ignorados por duplicación: ' + CAST(@CantLeidos - @CantInsertados AS NVARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(),
                @ErrorSeverity INT = ERROR_SEVERITY(),
                @ErrorState INT = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO

