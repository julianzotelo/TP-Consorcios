/*  Importar Inquilino-propietarios-datos.csv
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

CREATE OR ALTER PROCEDURE Importar_Inquilinos
    @RutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
    --elimino mi temporal si ya existe
    IF OBJECT_ID('tempdb..#tmpInquilinoUF') IS NOT NULL
            DROP TABLE #tmpInquilinoUF;
    -- Crear tabla temporal con los mismos nombres que el CSV
        CREATE TABLE #tmpInquilinoUF (
            [Nombre] NVARCHAR(100),
            [apellido] NVARCHAR(100),
            [DNI] INT,
            [email personal] NVARCHAR(150),
            [teléfono de contacto] NVARCHAR(50),
            [CVU/CBU] NVARCHAR(50),
            [Inquilino] BIT
        );
        --inporto los datos del csv
         DECLARE @SQL NVARCHAR(MAX);
        SET @SQL = '
            BULK INSERT #tmpInquilinoUF
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '';'',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''ACP''
            );
        ';
        EXEC(@SQL);

        --select * from #tmpInquilinoUF
      

       --inserto en mi tabla inquilino propietario, se valida que no exista un inquilino con ese dni para evitar duplicados
   DECLARE @RegistrosInsertados INT;

        INSERT INTO dbo.PropietarioInquilino (DNI, nombre, apellido, email, telefono, CVU_CBU, inquilino)
        SELECT 
            t.[DNI],
            LTRIM(RTRIM(t.[Nombre])),
            LTRIM(RTRIM(t.[apellido])),
            LTRIM(RTRIM(t.[email personal])),
            LTRIM(RTRIM(t.[teléfono de contacto])),
            LEFT(LTRIM(RTRIM(t.[CVU/CBU])), 22),
            t.[Inquilino]
        FROM #tmpInquilinoUF t
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.PropietarioInquilino p WHERE p.DNI = t.[DNI]
        ) AND t.DNI is not null;

        SET @RegistrosInsertados = @@ROWCOUNT;

        IF @RegistrosInsertados > 0
            PRINT 'Importación completada correctamente. Registros insertados: ' + CAST(@RegistrosInsertados AS NVARCHAR(10));
        ELSE
            PRINT 'No se insertaron registros nuevos. Todos los DNIs ya existían en la tabla.';

    END TRY
    BEGIN CATCH
        PRINT 'Error en la importación: ' + ERROR_MESSAGE();
    END CATCH
END;
GO


EXEC Importar_Inquilinos @RutaArchivo = 'C:\TEMP\TP_DB\Inquilino-propietarios-datos.csv';
