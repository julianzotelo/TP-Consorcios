IF OBJECT_ID('dbo.01_SP_Creacion_Consorcio_TipoGastos', 'P') IS NOT NULL
    DROP PROCEDURE dbo.01_SP_Creacion_Consorcio_TipoGastos;
GO

CREATE PROCEDURE dbo.01_SP_Creacion_Consorcio_TipoGastos
    @Ruta NVARCHAR(500),
    @NombreArchivo NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Archivo NVARCHAR(1000) = @Ruta + '\' + @NombreArchivo;
    DECLARE @sql NVARCHAR(MAX);

    -- Validar existencia del archivo
    IF NOT EXISTS (
        SELECT * FROM OPENROWSET(
            'Microsoft.ACE.OLEDB.12.0',
            'Excel 12.0;HDR=YES;IMEX=1;Database=' + @Archivo,
            'SELECT * FROM [Consorcios$]'
        )
    )
    BEGIN
        RAISERROR('No se encontró el archivo o la hoja "Consorcios"', 16, 1);
        RETURN;
    END;

    --   Insertar CONSORCIOS
    INSERT INTO Consorcios (ID_consorcio, nombre, direccion, m2_totales, cant_unidades, CBU_CVU)
    SELECT
        A, -- Columna A, ID
        B, -- Columna B, nombre
        C, -- Columna C, dirección
        E, -- Columna E, m2_totales
        D, -- Columna D ,cant_unidades validar bien cada nombre como figure en el select al abrir el xls
        NULL
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;HDR=YES;IMEX=1;Database=' + @Archivo,
        'SELECT * FROM [Consorcios$]'
    ) AS X
    WHERE NOT EXISTS (
        SELECT 1 FROM Consorcios c
        WHERE c.nombre = X.B
          AND c.direccion = X.C
    );

--Insertar TIPO DE GASTO (columna B de hoja Proveedores)
    INSERT INTO TipoGasto (nombre, descripcion)
    SELECT DISTINCT B, B
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;HDR=YES;IMEX=1;Database=' + @Archivo,
        'SELECT * FROM [Proveedores$]'
    ) AS P
    WHERE NOT EXISTS (
        SELECT 1 FROM TipoGasto tg WHERE tg.nombre = P.B
    );

--Insertar PROVEEDORES (columnas C y D)

    INSERT INTO Proveedores (nombre, nroCuit)
    SELECT DISTINCT C, D
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;HDR=YES;IMEX=1;Database=' + @Archivo,
        'SELECT * FROM [Proveedores$]'
    ) AS P
    WHERE NOT EXISTS (
        SELECT 1 FROM Proveedores pr WHERE pr.nombre = P.C AND pr.nroCuit = P.D
    );

-- Insertar relación CONSORCIO - PROVEEDOR

    INSERT INTO ConsorcioProveedor (ID_Proveedores, ID_consorcio)
    SELECT
        pr.ID_Proveedores,
        c.ID_consorcio
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;HDR=YES;IMEX=1;Database=' + @Archivo,
        'SELECT * FROM [Proveedores$]'
    ) AS P
    INNER JOIN Proveedores pr ON pr.nombre = P.C
    INNER JOIN Consorcios c ON c.nombre = P.E
    WHERE NOT EXISTS (
        SELECT 1 FROM ConsorcioProveedor cp
        WHERE cp.ID_Proveedores = pr.ID_Proveedores
          AND cp.ID_consorcio = c.ID_consorcio
    );

    PRINT 'Carga completada correctamente.';
END;
GO
