/* COTIZACION DOLAR */

CREATE TABLE Cotizaciones (
    IdCotizacion INT IDENTITY PRIMARY KEY,
    DolarARS DECIMAL(10,2),
    Fecha DATETIME DEFAULT GETDATE()
);

/* Invoke-WebRequest -Uri "https://v6.exchangerate-api.com/v6/4841a08beee8620f048403e9/latest/USD" -OutFile "C:\temp\cotizacion.json" */

CREATE PROCEDURE sp_ActualizarCotizacionDolar
AS
BEGIN
    DECLARE @json NVARCHAR(MAX);

    -- Leer archivo JSON descargado
    SELECT @json = BulkColumn
    FROM OPENROWSET (BULK 'C:\temp\cotizacion.json', SINGLE_CLOB) AS j;

    -- Insertar en tabla
    INSERT INTO Cotizaciones(DolarARS, Fecha)
    VALUES (
        TRY_CAST(JSON_VALUE(@json, '$.conversion_rates.ARS') AS DECIMAL(10,2)),
        GETDATE()
    );
END;


EXEC sp_ActualizarCotizacionDolar;


SELECT *
FROM Cotizaciones



/* FERIADOS */

CREATE TABLE Feriados (
    IdFeriado INT IDENTITY PRIMARY KEY,
    Fecha DATE,
    Tipo NVARCHAR(50),
    Nombre NVARCHAR(100)
);

/* Invoke-WebRequest -Uri "https://api.argentinadatos.com/v1/feriados/2025" -OutFile "C:\temp\feriados.json" */


CREATE PROCEDURE sp_ActualizarFeriados
AS
BEGIN
    DECLARE @json NVARCHAR(MAX);

    -- Leer archivo JSON descargado previamente
    SELECT @json = BulkColumn
    FROM OPENROWSET (BULK 'C:\temp\feriados.json', SINGLE_CLOB) AS j;

    -- Insertar en tabla
    INSERT INTO Feriados(Fecha, Tipo, Nombre)
    SELECT 
        fecha, tipo, nombre
    FROM OPENJSON(@json)
    WITH (
        fecha DATE '$.fecha',
        tipo NVARCHAR(50) '$.tipo',
        nombre NVARCHAR(100) '$.nombre'
    );
END;


EXEC sp_ActualizarFeriados;


-- Consultar si una fecha es feriado
DECLARE @fecha DATE = '2025-12-25';

IF EXISTS (SELECT 1 FROM Feriados WHERE Fecha = @fecha)
    PRINT 'No emitir comprobante: es feriado';
ELSE
    PRINT 'Emitir comprobante normalmente';


SELECT * FROM feriados