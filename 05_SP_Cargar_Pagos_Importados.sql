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

USE Com3641G01;
GO

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

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Creamos una tabla temporal con la estructura del CSV
        IF OBJECT_ID('tempdb..#PagosTemp') IS NOT NULL DROP TABLE #PagosTemp;

        CREATE TABLE #PagosTemp (
            IdPago INT,
            fecha VARCHAR(20),
            CVU_CBU CHAR(22),
            Valor VARCHAR(50)
        );

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

        -- Limpiamos y convertimos los datos
        ;WITH DatosLimpios AS (
            SELECT
                TRY_CAST(IdPago AS INT) AS IdPago,
                TRY_CONVERT(DATE, fecha, 103) AS fecha, -- formato dd/mm/yyyy
                RTRIM(LTRIM(REPLACE(REPLACE(CVU_CBU, ' ', ''), CHAR(13), ''))) AS CVU_CBU,
                TRY_CAST(REPLACE(REPLACE(REPLACE(Valor, '$', ''), '.', ''), ',', '.') AS DECIMAL(10,2)) AS importe
            FROM #PagosTemp
            WHERE CVU_CBU IS NOT NULL AND CVU_CBU <> ''
        )

        -- Insertamos en la tabla Pagos_importados
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
        LEFT JOIN UnidadFuncionalPersona ufp ON ufp.ID_PropietarioInquilino = pi.ID_PropietarioInquilino;

        COMMIT TRANSACTION;
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



EXEC dbo.SP_Cargar_Pagos_Importados 
    @Ruta = 'C:\TEMP\TP_DB',
    @NombreArchivo = 'pagos_consorcios.csv';