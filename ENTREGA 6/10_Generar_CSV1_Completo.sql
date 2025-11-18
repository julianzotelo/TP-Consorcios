/*  sp
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
CREATE OR ALTER PROCEDURE dbo.SP_Generar_ReporteCSV
(
    @Ruta NVARCHAR(500),
    @NombreArchivo NVARCHAR(255),
    @IdConsorcio INT,
    @periodo varchar(50)
)
AS
BEGIN
    SET NOCOUNT ON;


    -- Ejecutamos tu SP actual y guardamos resultado en #
 

    CREATE TABLE #ResultadoFinal
    (
        Seccion VARCHAR(200),
        Campo VARCHAR(200),
        Valor VARCHAR(500)
        -- ajustar
    );

    INSERT INTO #ResultadoFinal
    EXEC dbo.SP_Generar_Expensas_Completo @IdConsorcio, @periodo

 
    -- encabezado del CSV
 
    DECLARE @Header NVARCHAR(MAX);

    SELECT @Header = STRING_AGG(QUOTENAME(name), ',')
    FROM tempdb.sys.columns
    WHERE object_id = OBJECT_ID('tempdb..#ResultadoFinal');


    -- filas del CSV
 
    DECLARE @Contenido NVARCHAR(MAX);

    SELECT 
        @Contenido = STRING_AGG(
            CONCAT(
                '"', REPLACE(COALESCE(Seccion, ''), '"', '""'), '",',
                '"', REPLACE(COALESCE(Campo, ''), '"', '""'), '",',
                '"', REPLACE(COALESCE(Valor, ''), '"', '""'), '"'
            ),
            CHAR(13) + CHAR(10)
        )
    FROM #ResultadoFinal;


    --  temporal para el archivo

    CREATE TABLE #CSV (Linea NVARCHAR(MAX));

    INSERT INTO #CSV (Linea)
    VALUES(@Header),
          (@Contenido);

    --------------------------------------------------------
    --  exporto con BCP
    --------------------------------------------------------
    DECLARE @Comando NVARCHAR(2000);
    DECLARE @ArchivoCompleto NVARCHAR(1000);

    SET @ArchivoCompleto = @Ruta + '\' + @NombreArchivo;

    SET @Comando =
        'bcp "SELECT Linea FROM tempdb..#CSV" queryout "' +
        @ArchivoCompleto + '" -c -t, -T';

    EXEC xp_cmdshell @Comando;

END;
GO

--EXEC dbo.SP_Generar_ReporteCSV
--     @Ruta = 'C:\ReportesConsorcio',
--     @NombreArchivo = 'Consorcio_21_11.csv',
--     @IdConsorcio = 1,
--     @periodo = 'Marzo-2025'