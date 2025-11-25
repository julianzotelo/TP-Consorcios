USE Com3641G01;
GO

CREATE OR ALTER PROCEDURE SP_Generar_Documentacion_CSV
(
    @ID_consorcio INT,
    @periodo CHAR(20),
    @Ruta VARCHAR(500),                 -- carpeta destino
    @NombreCSV_Expensas VARCHAR(255),  -- nombre del primer archivo
    @NombreCSV_Prorrateo VARCHAR(255)  -- nombre del segundo archivo
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RutaArchivoExpensas VARCHAR(800);

    SET @RutaArchivoExpensas = @Ruta + '\' + @NombreCSV_Expensas;
    -----------------------------------------------------------
    -- 1) Correr el SP principal y guardar su output en tabla
    -----------------------------------------------------------

    INSERT INTO Export_Expensas
    EXEC SP_Generar_Expensas_Completo @ID_consorcio, @periodo;
   -- EXEC SP_Generar_Expensas_Completo_v2 1, 'abril-2025';

    -----------------------------------------------------------
    -- 2) Crear archivo CSV en el servidor
    -----------------------------------------------------------
    DECLARE @Comando VARCHAR(8000);

    -- Borrar archivo previo (si existe)
    SET @Comando = 'del "' + @RutaArchivoExpensas + '"';
    EXEC xp_cmdshell @Comando, NO_OUTPUT;


    -----------------------------------------------------------
    -- 3) Agregar encabezados al CSV
    -----------------------------------------------------------
    SET @Comando = 'echo Seccion,Clave,Valor,Orden > "' + @RutaArchivoExpensas + '"';
    EXEC xp_cmdshell @Comando;


    -----------------------------------------------------------
    -- 4) Exportar la tabla al CSV
    -----------------------------------------------------------
    SET @Comando = 
        'bcp "SELECT Seccion, Clave, Valor, Orden FROM Com3641G01..Export_Expensas" queryout "' 
        + @RutaArchivoExpensas + '" -c -t, -T -S "' + @@SERVERNAME + '"';

    EXEC xp_cmdshell @Comando;

    ----------------


  --elimino los registros de mi tabla para que no sea un archivo acumulativo 
    TRUNCATE TABLE Export_expensas;

    
    ------------------------------------------------------------
    -- 2) Generar el segundo CSV (Prorrateo)
    ------------------------------------------------------------

    -- Limpiar tabla f�sica antes de llenarla
    TRUNCATE TABLE Export_EstadoCuentaProrrateo;

    -- Insertar el contenido del SP prorrateo
    INSERT INTO Export_EstadoCuentaProrrateo
    (
        UF,
        Porcentaje,
        [Piso-Depto],
        Cocheras,
        Bauleras,
        Propietario,
        [Saldo anterior abonado],
        [Pagos recibidos],
        Deuda,
        [Interes por mora],
        [Expensas ordinarias],
        [Expensas extraordinarias],
        [Total a Pagar]
    )
    EXEC SP_Generar_EstadoCuenta_Prorrateo
        @ID_Consorcio,
        @Periodo;


    ------------------------------------------------------------
    -- 3) Crear CSV del estado de cuenta prorrateado
    ------------------------------------------------------------
    DECLARE @RutaArchivoProrrateo VARCHAR(800);
    DECLARE @Cmd VARCHAR(8000);

    SET @RutaArchivoProrrateo = @Ruta + '\' + @NombreCSV_Prorrateo;

    -- Borrar si existe
    SET @Cmd = 'del "' + @RutaArchivoProrrateo + '"';
    EXEC xp_cmdshell @Cmd, NO_OUTPUT;

    -- Escribir encabezados
    SET @Cmd = 'echo UF,Porcentaje,Piso-Depto,Cocheras,Bauleras,Propietario,[Saldo anterior abonado],[Pagos recibidos],Deuda,[Interes por mora],[Expensas ordinarias],[Expensas extraordinarias],[Total a Pagar] > "' 
               + @RutaArchivoProrrateo + '"';
    EXEC xp_cmdshell @Cmd;

    -- Exportar datos
    SET @Cmd = 
        'bcp "SELECT UF,Porcentaje,[Piso-Depto],Cocheras,Bauleras,Propietario,[Saldo anterior abonado],[Pagos recibidos],Deuda,[Interes por mora],[Expensas ordinarias],[Expensas extraordinarias],[Total a Pagar] FROM Com3641G01..Export_EstadoCuentaProrrateo" ' +
        'queryout "' + @RutaArchivoProrrateo + '" -c -t, -T -S "' + @@SERVERNAME + '"';

    EXEC xp_cmdshell @Cmd;

     --elimino los registros de mi tabla para que no sea un archivo acumulativo 
    TRUNCATE TABLE Export_EstadoCuentaProrrateo;


END;
GO
