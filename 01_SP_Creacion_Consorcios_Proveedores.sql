USE Com3641G01;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Creacion_Consorcio_TipoGastos(
    @Ruta NVARCHAR(500),
    @NombreArchivo NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Archivo NVARCHAR(1000) = @Ruta + '\' + @NombreArchivo;
    DECLARE @sql NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar existencia de la hoja Consorcios
        IF OBJECT_ID('tempdb..#ValidarConsorcios') IS NOT NULL DROP TABLE #ValidarConsorcios;
        CREATE TABLE #ValidarConsorcios (
            Consorcio NVARCHAR(255),
            [Nombre del consorcio] NVARCHAR(255),
            Domicilio NVARCHAR(255),
            [Cant unidades funcionales] NVARCHAR(50),
            [m2 totales] NVARCHAR(50)
        );

        SET @sql = N'
            INSERT INTO #ValidarConsorcios
            SELECT TOP 1 *
            FROM OPENROWSET(
                ''Microsoft.ACE.OLEDB.12.0'',
                ''Excel 12.0 Xml;HDR=YES;IMEX=1;Database=' + @Archivo + ''',
                ''SELECT * FROM [Consorcios$]''
            );
        ';
        EXEC sp_executesql @sql;

        IF NOT EXISTS (SELECT 1 FROM #ValidarConsorcios)
            THROW 50000, 'No se encontró la hoja [Consorcios$] en el archivo Excel.', 1;

        -- Validar existencia de la hoja Proveedores
        IF OBJECT_ID('tempdb..#ValidarProveedores') IS NOT NULL DROP TABLE #ValidarProveedores;
        CREATE TABLE #ValidarProveedores (
            F1 NVARCHAR(255),
            F2 NVARCHAR(255),
            F3 NVARCHAR(255),
            [Nombre del consorcio] NVARCHAR(255)
        );

        SET @sql = N'
            INSERT INTO #ValidarProveedores
            SELECT TOP 1 *
            FROM OPENROWSET(
                ''Microsoft.ACE.OLEDB.12.0'',
                ''Excel 12.0 Xml;HDR=YES;IMEX=1;Database=' + @Archivo + ''',
                ''SELECT * FROM [Proveedores$]''
            );
        ';
        EXEC sp_executesql @sql;

        IF NOT EXISTS (SELECT 1 FROM #ValidarProveedores)
            THROW 50001, 'No se encontró la hoja [Proveedores$] en el archivo Excel.', 1;

        -- Cargar Consorcios
        IF OBJECT_ID('tempdb..#ConsorciosExcel') IS NOT NULL DROP TABLE #ConsorciosExcel;
        CREATE TABLE #ConsorciosExcel (
            [Consorcio] NVARCHAR(255),
            [Nombre del consorcio] NVARCHAR(255),
            [Domicilio] NVARCHAR(255),
            [Cant unidades funcionales] NVARCHAR(50),
            [m2 totales] NVARCHAR(50)
        );

        SET @sql = N'
            INSERT INTO #ConsorciosExcel
            SELECT *
            FROM OPENROWSET(
                ''Microsoft.ACE.OLEDB.12.0'',
                ''Excel 12.0 Xml;HDR=YES;IMEX=1;Database=' + @Archivo + ''',
                ''SELECT * FROM [Consorcios$]''
            );
        ';
        EXEC sp_executesql @sql;

        INSERT INTO Consorcios (consorcio, nombre, direccion, cant_unidades, m2_totales)
        SELECT 
            [Consorcio],
            [Nombre del consorcio],
            [Domicilio],
            TRY_CAST([Cant unidades funcionales] AS INT),
            TRY_CAST(REPLACE([m2 totales], ',', '.') AS DECIMAL(10,2))
        FROM #ConsorciosExcel c
        WHERE NOT EXISTS (
            SELECT 1 
            FROM Consorcios co
            WHERE co.consorcio = c.[Consorcio]
              AND co.nombre = c.[Nombre del consorcio]
              AND co.direccion = c.[Domicilio]
        );

        -- Cargar Proveedores y relaciones con Consorcios
        IF OBJECT_ID('tempdb..#ProveedoresExcel') IS NOT NULL DROP TABLE #ProveedoresExcel;
        CREATE TABLE #ProveedoresExcel (
            F1 NVARCHAR(255),
            F2 NVARCHAR(255),
            F3 NVARCHAR(255),
            [Nombre del consorcio] NVARCHAR(255)
        );

        SET @sql = N'
            INSERT INTO #ProveedoresExcel
            SELECT *
            FROM OPENROWSET(
                ''Microsoft.ACE.OLEDB.12.0'',
                ''Excel 12.0 Xml;HDR=YES;IMEX=1;Database=' + @Archivo + ''',
                ''SELECT * FROM [Proveedores$]''
            );
        ';
        EXEC sp_executesql @sql;

        -- Insertar categorías de gasto ordinario
        INSERT INTO CategoriaGastoOrdinario (nombre)
        SELECT DISTINCT F1
        FROM #ProveedoresExcel AS P
        WHERE F1 IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM CategoriaGastoOrdinario tg WHERE tg.nombre = P.F1
        );

        -- Insertar proveedores
        IF COL_LENGTH('Proveedores', 'cuenta') IS NOT NULL
        BEGIN
            INSERT INTO Proveedores (nombre, cuenta)
            SELECT DISTINCT F2, F3
            FROM #ProveedoresExcel AS P
            WHERE F2 IS NOT NULL
              AND NOT EXISTS (
                SELECT 1 FROM Proveedores pr WHERE pr.nombre = P.F2
            );
        END
        ELSE
        BEGIN
            INSERT INTO Proveedores (nombre)
            SELECT DISTINCT F2
            FROM #ProveedoresExcel AS P
            WHERE F2 IS NOT NULL
              AND NOT EXISTS (
                SELECT 1 FROM Proveedores pr WHERE pr.nombre = P.F2
            );
        END;

        -- Insertar relación Consorcio-Proveedor
        INSERT INTO ConsorcioProveedor (ID_Proveedores, ID_consorcio)
        SELECT
            pr.ID_Proveedores,
            c.ID_consorcio
        FROM #ProveedoresExcel AS P
        INNER JOIN Proveedores pr ON pr.nombre = P.F2
        INNER JOIN Consorcios c ON c.nombre = P.[Nombre del consorcio]
        WHERE NOT EXISTS (
            SELECT 1 FROM ConsorcioProveedor cp
            WHERE cp.ID_Proveedores = pr.ID_Proveedores
              AND cp.ID_consorcio = c.ID_consorcio
        );

        COMMIT TRANSACTION;
        PRINT 'Registros insertados correctamente.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE 
            @ErrorMessage NVARCHAR(4000),
            @ErrorSeverity INT,
            @ErrorState INT;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR('Error en SP_Creacion_Consorcio_TipoGastos: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
    END CATCH;
END;
GO


EXEC dbo.SP_Creacion_Consorcio_TipoGastos
    @Ruta = N'C:\TEMP\TP_DB',
    @NombreArchivo = N'datos varios.xlsx';