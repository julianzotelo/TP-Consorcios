/*  Importar Uf por consorcio.txt
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

CREATE OR ALTER PROCEDURE dbo.SP_Cargar_UnidadesFuncionales(
    @Ruta NVARCHAR(500),
    @NombreArchivo NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET IMPLICIT_TRANSACTIONS OFF;

    DECLARE @ArchivoCompleto NVARCHAR(1000);
    SET @ArchivoCompleto = @Ruta + '\' + @NombreArchivo;

    PRINT 'Iniciando carga desde: ' + @ArchivoCompleto;

    -- Crear tabla staging
    IF OBJECT_ID('dbo.Tmp_UnidadesFuncionales', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.Tmp_UnidadesFuncionales (
            NombreConsorcio NVARCHAR(100),
            nroUnidadFuncional INT,
            Piso NVARCHAR(10),
            Departamento NVARCHAR(10),
            Coeficiente NVARCHAR(10),
            m2_Unidad_Funcional NVARCHAR(10),
            Bauleras NVARCHAR(2),
            Cochera NVARCHAR(2),
            m2_Baulera NVARCHAR(10),
            m2_Cochera NVARCHAR(10)
        );
    END
    ELSE
        TRUNCATE TABLE dbo.Tmp_UnidadesFuncionales;

    -- Cargar el archivo TXT
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = '
        BULK INSERT dbo.Tmp_UnidadesFuncionales
        FROM ''' + @ArchivoCompleto + '''
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ''\t'',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''ACP''
        );
    ';
    EXEC(@SQL);

    PRINT 'Archivo cargado correctamente en tabla staging.';

    DECLARE @InsertedUF INT = 0,
            @InsertedBauleras INT = 0,
            @InsertedCocheras INT = 0;

    -- Insertar Unidades Funcionales
    BEGIN TRAN;
    INSERT INTO Unidad_funcional (
        ID_unidad_funcional,
        ID_consorcio,
        departamento,
        piso,
        coeficiente,
        tiene_cochera,
        tiene_baulera,
        m2
    )
    SELECT 
        CAST(T.nroUnidadFuncional AS INT),
        C.ID_consorcio,
        T.Departamento,
        T.Piso,
        TRY_CAST(REPLACE(T.Coeficiente, ',', '.') AS DECIMAL(6,4)),
        CASE WHEN UPPER(T.Cochera) = 'SI' THEN 1 ELSE 0 END,
        CASE WHEN UPPER(T.Bauleras) = 'SI' THEN 1 ELSE 0 END,
        TRY_CAST(REPLACE(T.m2_Unidad_funcional, ',', '.') AS DECIMAL(8,2))
    FROM dbo.Tmp_UnidadesFuncionales T
    INNER JOIN Consorcios C ON C.nombre = T.NombreConsorcio
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Unidad_funcional UF 
        WHERE UF.ID_unidad_funcional = T.nroUnidadFuncional
          AND UF.ID_consorcio = C.ID_consorcio
    );

    SET @InsertedUF = @@ROWCOUNT;
    COMMIT;

    IF @InsertedUF > 0
        PRINT CAST(@InsertedUF AS VARCHAR(10)) + ' unidades funcionales insertadas correctamente.';
    ELSE
        PRINT 'No se insertaron nuevas unidades funcionales.';

    -- Insertar Bauleras (ajustada a la FK compuesta)
    BEGIN TRAN;
    INSERT INTO Baulera (ID_unidad_funcional, ID_consorcio, m2)
    SELECT 
        UF.ID_unidad_funcional,
        UF.ID_consorcio,
        TRY_CAST(REPLACE(T.m2_Baulera, ',', '.') AS DECIMAL(6,2))
    FROM dbo.Tmp_UnidadesFuncionales T
    INNER JOIN Consorcios C ON C.nombre = T.NombreConsorcio
    INNER JOIN Unidad_funcional UF 
        ON UF.ID_unidad_funcional = T.nroUnidadFuncional
       AND UF.ID_consorcio = C.ID_consorcio
    WHERE UPPER(T.Bauleras) = 'SI'
      AND NOT EXISTS (
            SELECT 1 FROM Baulera B 
            WHERE B.ID_unidad_funcional = UF.ID_unidad_funcional
              AND B.ID_consorcio = UF.ID_consorcio
      );

    SET @InsertedBauleras = @@ROWCOUNT;
    COMMIT;

    IF @InsertedBauleras > 0
        PRINT CAST(@InsertedBauleras AS VARCHAR(10)) + ' bauleras insertadas correctamente.';
    ELSE
        PRINT 'No se insertaron nuevas bauleras.';

    -- Insertar Cocheras (ajustada a la FK compuesta)
    BEGIN TRAN;
    INSERT INTO Cochera (ID_unidad_funcional, ID_consorcio, m2)
    SELECT 
        UF.ID_unidad_funcional,
        UF.ID_consorcio,
        TRY_CAST(REPLACE(T.m2_Cochera, ',', '.') AS DECIMAL(6,2))
    FROM dbo.Tmp_UnidadesFuncionales T
    INNER JOIN Consorcios C ON C.nombre = T.NombreConsorcio
    INNER JOIN Unidad_funcional UF 
        ON UF.ID_unidad_funcional = T.nroUnidadFuncional
       AND UF.ID_consorcio = C.ID_consorcio
    WHERE UPPER(T.Cochera) = 'SI'
      AND NOT EXISTS (
            SELECT 1 FROM Cochera CO 
            WHERE CO.ID_unidad_funcional = UF.ID_unidad_funcional
              AND CO.ID_consorcio = UF.ID_consorcio
      );

    SET @InsertedCocheras = @@ROWCOUNT;
    COMMIT;

    IF @InsertedCocheras > 0
        PRINT CAST(@InsertedCocheras AS VARCHAR(10)) + ' cocheras insertadas correctamente.';
    ELSE
        PRINT 'No se insertaron nuevas cocheras.';

    -- Limpiar tabla staging
    TRUNCATE TABLE dbo.Tmp_UnidadesFuncionales;

    PRINT 'Resumen de carga:';
    PRINT 'Unidades funcionales insertadas: ' + CAST(@InsertedUF AS VARCHAR(10));
    PRINT 'Bauleras insertadas: ' + CAST(@InsertedBauleras AS VARCHAR(10));
    PRINT 'Cocheras insertadas: ' + CAST(@InsertedCocheras AS VARCHAR(10));
    PRINT 'Proceso completado correctamente para: ' + @NombreArchivo;
END;
GO


EXEC dbo.SP_Cargar_UnidadesFuncionales @Ruta = 'C:\TEMP\TP_DB',@NombreArchivo = 'UF por consorcio.txt';



 


    