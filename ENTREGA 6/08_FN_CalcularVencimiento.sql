/*  Funcion que calcula el quinto dia habil (vencimiento)
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

CREATE OR ALTER FUNCTION fn_CalcularVencimiento(@mesNombre VARCHAR(20))
RETURNS DATE
AS
BEGIN
    DECLARE @anio INT;
    DECLARE @mes INT;
    DECLARE @fecha DATE;
    DECLARE @contador INT;

    -- Tomar el año actual
    SET @anio = YEAR(GETDATE());

    -- Limpiar el nombre del mes
    SET @mesNombre = LTRIM(RTRIM(@mesNombre));

    -- Convertir nombre del mes a número
    SET @mes = CASE LOWER(@mesNombre)
        WHEN 'enero' THEN 1 WHEN 'febrero' THEN 2 WHEN 'marzo' THEN 3
        WHEN 'abril' THEN 4 WHEN 'mayo' THEN 5 WHEN 'junio' THEN 6
        WHEN 'julio' THEN 7 WHEN 'agosto' THEN 8 WHEN 'septiembre' THEN 9
        WHEN 'octubre' THEN 10 WHEN 'noviembre' THEN 11 WHEN 'diciembre' THEN 12
        ELSE NULL
    END;

    -- Validar mes
    IF @mes IS NULL OR @mes < 1 OR @mes > 12
        RETURN NULL;

    -- Primer día del mes
    SET @fecha = DATEFROMPARTS(@anio, @mes, 1);
    SET @contador = 0;

    -- Contar días hábiles
    WHILE @contador < 5
    BEGIN
        IF DATEPART(WEEKDAY, @fecha) BETWEEN 2 AND 6
            SET @contador += 1;

        IF @contador < 5
            SET @fecha = DATEADD(DAY, 1, @fecha);
    END

    RETURN @fecha;
END;
GO




