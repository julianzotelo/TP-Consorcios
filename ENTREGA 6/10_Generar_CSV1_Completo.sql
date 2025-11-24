USE Com3641G01;
GO

CREATE OR ALTER PROCEDURE SP_Generar_Expensas_CSV
(
    @ID_consorcio INT,
    @periodo CHAR(20),
    @RutaArchivo VARCHAR(500)  -- Ej: 'C:\Exportaciones\expensas.csv'
)
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------------------------------------------
    -- 1) Correr el SP principal y guardar su output en tabla
    -----------------------------------------------------------
    --IF OBJECT_ID('tempdb..#SalidaExpensas') IS NOT NULL DROP TABLE #SalidaExpensas;

    --CREATE TABLE #SalidaExpensas (
    --    Seccion VARCHAR(100),
    --    Clave VARCHAR(200),
    --    Valor NVARCHAR(1000),
    --    Orden INT
    --);

    INSERT INTO Export_Expensas
    EXEC SP_Generar_Expensas_Completo @ID_consorcio, @periodo;
   -- EXEC SP_Generar_Expensas_Completo_v2 1, 'abril-2025';
   -- return 

    -----------------------------------------------------------
    -- 2) Crear archivo CSV en el servidor
    -----------------------------------------------------------
    DECLARE @Comando VARCHAR(8000);

    -- Borrar archivo previo (si existe)
    SET @Comando = 'del "' + @RutaArchivo + '"';
    EXEC xp_cmdshell @Comando, NO_OUTPUT;


    -----------------------------------------------------------
    -- 3) Agregar encabezados al CSV
    -----------------------------------------------------------
    SET @Comando = 'echo Seccion,Clave,Valor,Orden > "' + @RutaArchivo + '"';
    EXEC xp_cmdshell @Comando;


    -----------------------------------------------------------
    -- 4) Exportar la tabla al CSV
    -----------------------------------------------------------
    SET @Comando = 
        'bcp "SELECT Seccion, Clave, Valor, Orden FROM Com3641G01..Export_Expensas" queryout "' 
        + @RutaArchivo + '" -c -t, -T -S "' + @@SERVERNAME + '"';

    EXEC xp_cmdshell @Comando;

  
    delete Export_expensas;


END;
GO
