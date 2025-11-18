/*  Importar Inquilino-propietarios-UF.csv
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

CREATE OR ALTER PROCEDURE SP_Vincular_Unidades_PropietariosInquilinos
    @RutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Si existe la tabla temporal, eliminarla
        IF OBJECT_ID('tempdb..#tmpVinculos') IS NOT NULL
            DROP TABLE #tmpVinculos;

        -- Crear tabla temporal con la estructura del CSV
        CREATE TABLE #tmpVinculos (
            [CVU/CBU] NVARCHAR(50),
            [Nombre del consorcio] NVARCHAR(100),
            [nroUnidadFuncional] INT,
            [piso] NVARCHAR(10),
            [departamento] NVARCHAR(50)
        );

        -- Cargar los datos desde el CSV
        DECLARE @SQL NVARCHAR(MAX);
        SET @SQL = '
            BULK INSERT #tmpVinculos
            FROM ''' + @RutaArchivo + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = ''|'',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''ACP''
            );
        ';
        EXEC(@SQL);

       --select * from #tmpVinculos

        -- vinculo mis tablas Propietarios/Inquilinos con Unidades Funcionales
       

        DECLARE @RegistrosInsertados INT = 0;

        INSERT INTO UnidadFuncionalPersona (ID_unidad_funcional, ID_consorcio, ID_PropietarioInquilino, rol, fecha_desde, fecha_hasta)
        SELECT 
            uf.ID_unidad_funcional,
            uf.ID_consorcio,
            pi.ID_PropietarioInquilino,
            CASE WHEN pi.inquilino = 1 THEN 'INQUILINO' ELSE 'PROPIETARIO' END AS rol,
            NULL AS fecha_desde,
            NULL AS fecha_hasta
        FROM #tmpVinculos t
        INNER JOIN PropietarioInquilino pi
            ON LTRIM(RTRIM(pi.CVU_CBU)) = LTRIM(RTRIM(t.[CVU/CBU]))
        INNER JOIN Consorcios c
            ON LTRIM(RTRIM(c.nombre)) = LTRIM(RTRIM(t.[Nombre del consorcio]))
        INNER JOIN Unidad_funcional uf
            ON uf.ID_consorcio = c.ID_consorcio
            AND uf.ID_unidad_funcional = t.[nroUnidadFuncional]
            AND LTRIM(RTRIM(uf.piso)) = LTRIM(RTRIM(t.[piso]))
            AND LTRIM(RTRIM(uf.departamento)) = LTRIM(RTRIM(t.[departamento]))
        WHERE NOT EXISTS (
            SELECT 1 FROM UnidadFuncionalPersona ufp
            WHERE ufp.ID_unidad_funcional = uf.ID_unidad_funcional
              AND ufp.ID_consorcio = uf.ID_consorcio
              AND ufp.ID_PropietarioInquilino = pi.ID_PropietarioInquilino
              AND ufp.rol = CASE WHEN pi.inquilino = 1 THEN 'INQUILINO' ELSE 'PROPIETARIO' END
        );

        SET @RegistrosInsertados = @@ROWCOUNT;

        PRINT 'Importación y vinculación completadas. Registros insertados: ' + CAST(@RegistrosInsertados AS NVARCHAR(10));

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Error durante la importación: ' + ERROR_MESSAGE();
    END CATCH
END;
GO


