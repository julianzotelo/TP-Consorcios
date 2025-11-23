USE Com3641G01;
GO

-- 1) Crear Master Key
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Com3641G01';
GO

-- 2) Certificado
CREATE CERTIFICATE Cert_Consorcio
WITH SUBJECT = 'Cifrado de columnas sensibles consorcios';
GO

-- 3) Clave simétrica AES-256
CREATE SYMMETRIC KEY SK_Consorcio
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE Cert_Consorcio;
GO

-- 4) Backups de claves (guardar en un almacén seguro)
BACKUP CERTIFICATE Cert_Consorcio
TO FILE = 'C:\TEMP\Cert_Consorcio.cer'
WITH PRIVATE KEY (
    FILE = 'C:\TEMP\Cert_Consorcio.pvk',
    ENCRYPTION BY PASSWORD = 'Com3641G01'
);
GO

----------------------- Encriptar tablas con datos sensibles ------------------------------------

-- Abrir clave para la migración
OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;
GO

-----------------------------
-- PropietarioInquilino
-----------------------------
ALTER TABLE dbo.PropietarioInquilino
ADD DNI_c VARBINARY(256),
    nombre_c VARBINARY(256),
    apellido_c VARBINARY(256),
    email_c VARBINARY(256),
    telefono_c VARBINARY(256),
    CVU_CBU_c VARBINARY(256);
GO

UPDATE dbo.PropietarioInquilino
SET DNI_c      = EncryptByKey(Key_GUID('SK_Consorcio'), CAST(DNI AS VARCHAR(20))),
    nombre_c   = EncryptByKey(Key_GUID('SK_Consorcio'), nombre),
    apellido_c = EncryptByKey(Key_GUID('SK_Consorcio'), apellido),
    email_c    = EncryptByKey(Key_GUID('SK_Consorcio'), email),
    telefono_c = EncryptByKey(Key_GUID('SK_Consorcio'), telefono),
    CVU_CBU_c  = EncryptByKey(Key_GUID('SK_Consorcio'), CVU_CBU);
GO

-----------------------------
-- Consorcios
-----------------------------
ALTER TABLE dbo.Consorcios
ADD CBU_CVU_c VARBINARY(256);
GO

UPDATE dbo.Consorcios
SET CBU_CVU_c = EncryptByKey(Key_GUID('SK_Consorcio'), CBU_CVU);
GO

-----------------------------
-- Proveedores
-----------------------------
ALTER TABLE dbo.Proveedores
ADD cuenta_c VARBINARY(256);
GO

UPDATE dbo.Proveedores
SET cuenta_c = EncryptByKey(Key_GUID('SK_Consorcio'), cuenta);
GO

-----------------------------
-- Pagos_importados
-----------------------------
ALTER TABLE dbo.Pagos_importados
ADD cuenta_origen_c VARBINARY(256);
GO

UPDATE dbo.Pagos_importados
SET cuenta_origen_c = EncryptByKey(Key_GUID('SK_Consorcio'), cuenta_origen);
GO

-- Cerrar clave
CLOSE SYMMETRIC KEY SK_Consorcio;
GO



--------------------- Creacion y ejecucion de SP para limpiar y renombrar las columnas luego de encriptacion ---------------------------------------------


CREATE OR ALTER PROCEDURE dbo.SP_PropietarioInquilino_CleanupAndRename
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Eliminar constraint dependiente
    IF EXISTS (
        SELECT 1 FROM sys.objects 
        WHERE name = 'UQ_PropietarioInquilino_DNI_CBU' AND type = 'UQ'
    )
    BEGIN
        ALTER TABLE dbo.PropietarioInquilino
        DROP CONSTRAINT UQ_PropietarioInquilino_DNI_CBU;
    END

    -- 2. Eliminar columnas en claro (si existen)
    IF COL_LENGTH('dbo.PropietarioInquilino', 'DNI') IS NOT NULL
        ALTER TABLE dbo.PropietarioInquilino DROP COLUMN DNI;

    IF COL_LENGTH('dbo.PropietarioInquilino', 'nombre') IS NOT NULL
        ALTER TABLE dbo.PropietarioInquilino DROP COLUMN nombre;

    IF COL_LENGTH('dbo.PropietarioInquilino', 'apellido') IS NOT NULL
        ALTER TABLE dbo.PropietarioInquilino DROP COLUMN apellido;

    IF COL_LENGTH('dbo.PropietarioInquilino', 'email') IS NOT NULL
        ALTER TABLE dbo.PropietarioInquilino DROP COLUMN email;

    IF COL_LENGTH('dbo.PropietarioInquilino', 'telefono') IS NOT NULL
        ALTER TABLE dbo.PropietarioInquilino DROP COLUMN telefono;

    IF COL_LENGTH('dbo.PropietarioInquilino', 'CVU_CBU') IS NOT NULL
        ALTER TABLE dbo.PropietarioInquilino DROP COLUMN CVU_CBU;

    -- 3. Renombrar columnas cifradas al nombre original
    IF COL_LENGTH('dbo.PropietarioInquilino', 'DNI_c') IS NOT NULL
        EXEC sp_rename 'dbo.PropietarioInquilino.DNI_c', 'DNI', 'COLUMN';

    IF COL_LENGTH('dbo.PropietarioInquilino', 'nombre_c') IS NOT NULL
        EXEC sp_rename 'dbo.PropietarioInquilino.nombre_c', 'nombre', 'COLUMN';

    IF COL_LENGTH('dbo.PropietarioInquilino', 'apellido_c') IS NOT NULL
        EXEC sp_rename 'dbo.PropietarioInquilino.apellido_c', 'apellido', 'COLUMN';

    IF COL_LENGTH('dbo.PropietarioInquilino', 'email_c') IS NOT NULL
        EXEC sp_rename 'dbo.PropietarioInquilino.email_c', 'email', 'COLUMN';

    IF COL_LENGTH('dbo.PropietarioInquilino', 'telefono_c') IS NOT NULL
        EXEC sp_rename 'dbo.PropietarioInquilino.telefono_c', 'telefono', 'COLUMN';

    IF COL_LENGTH('dbo.PropietarioInquilino', 'CVU_CBU_c') IS NOT NULL
        EXEC sp_rename 'dbo.PropietarioInquilino.CVU_CBU_c', 'CVU_CBU', 'COLUMN';

END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Proveedores_CleanupAndRename
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Eliminar constraints dependientes (si hubiera alguno sobre cuenta)
    DECLARE @constraint NVARCHAR(128);
    SELECT TOP 1 @constraint = name
    FROM sys.objects
    WHERE type = 'UQ' AND name LIKE '%Proveedores%' AND name LIKE '%cuenta%';

    IF @constraint IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE dbo.Proveedores DROP CONSTRAINT ' + @constraint);
    END

    -- 2. Eliminar columna en claro
    IF COL_LENGTH('dbo.Proveedores', 'cuenta') IS NOT NULL
        ALTER TABLE dbo.Proveedores DROP COLUMN cuenta;

    -- 3. Renombrar columna cifrada
    IF COL_LENGTH('dbo.Proveedores', 'cuenta_c') IS NOT NULL
        EXEC sp_rename 'dbo.Proveedores.cuenta_c', 'cuenta', 'COLUMN';

END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Consorcios_CleanupAndRename
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Eliminar constraints dependientes (si hubiera alguno sobre CBU_CVU)
    DECLARE @constraint NVARCHAR(128);
    SELECT TOP 1 @constraint = name
    FROM sys.objects
    WHERE type = 'UQ' AND name LIKE '%Consorcios%' AND name LIKE '%CBU%';

    IF @constraint IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE dbo.Consorcios DROP CONSTRAINT ' + @constraint);
    END

    -- 2. Eliminar columna en claro
    IF COL_LENGTH('dbo.Consorcios', 'CBU_CVU') IS NOT NULL
        ALTER TABLE dbo.Consorcios DROP COLUMN CBU_CVU;

    -- 3. Renombrar columna cifrada
    IF COL_LENGTH('dbo.Consorcios', 'CBU_CVU_c') IS NOT NULL
        EXEC sp_rename 'dbo.Consorcios.CBU_CVU_c', 'CBU_CVU', 'COLUMN';
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_PagosImportados_CleanupAndRename
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Eliminar constraints dependientes (si hubiera alguno sobre cuenta_origen)
    DECLARE @constraint NVARCHAR(128);
    SELECT TOP 1 @constraint = name
    FROM sys.objects
    WHERE type = 'UQ' AND name LIKE '%Pagos_importados%' AND name LIKE '%cuenta_origen%';

    IF @constraint IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE dbo.Pagos_importados DROP CONSTRAINT ' + @constraint);
    END

    -- 2. Eliminar columna en claro
    IF COL_LENGTH('dbo.Pagos_importados', 'cuenta_origen') IS NOT NULL
        ALTER TABLE dbo.Pagos_importados DROP COLUMN cuenta_origen;

    -- 3. Renombrar columna cifrada
    IF COL_LENGTH('dbo.Pagos_importados', 'cuenta_origen_c') IS NOT NULL
        EXEC sp_rename 'dbo.Pagos_importados.cuenta_origen_c', 'cuenta_origen', 'COLUMN';
END;
GO

EXEC dbo.SP_PropietarioInquilino_CleanupAndRename
EXEC dbo.SP_Proveedores_CleanupAndRename
EXEC dbo.SP_Consorcios_CleanupAndRename
EXEC dbo.SP_PagosImportados_CleanupAndRename


-------------------- Triggers para encriptacion al insertar datos en tablas sensibles -----------------------------------------------------------------

CREATE OR ALTER TRIGGER TRG_PagosImportados_Encrypt
ON dbo.Pagos_importados
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;

    UPDATE P
    SET cuenta_origen = EncryptByKey(Key_GUID('SK_Consorcio'), i.cuenta_origen)
    FROM dbo.Pagos_importados P
    INNER JOIN inserted i ON P.ID_pago = i.ID_pago;

    CLOSE SYMMETRIC KEY SK_Consorcio;
END;
GO

CREATE OR ALTER TRIGGER TRG_PropietarioInquilino_Encrypt
ON dbo.PropietarioInquilino
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;

    UPDATE P
    SET DNI      = EncryptByKey(Key_GUID('SK_Consorcio'), CAST(i.DNI AS VARCHAR(20))),
        nombre   = EncryptByKey(Key_GUID('SK_Consorcio'), i.nombre),
        apellido = EncryptByKey(Key_GUID('SK_Consorcio'), i.apellido),
        email    = EncryptByKey(Key_GUID('SK_Consorcio'), i.email),
        telefono = EncryptByKey(Key_GUID('SK_Consorcio'), i.telefono),
        CVU_CBU  = EncryptByKey(Key_GUID('SK_Consorcio'), i.CVU_CBU)
    FROM dbo.PropietarioInquilino P
    INNER JOIN inserted i ON P.ID_PropietarioInquilino = i.ID_PropietarioInquilino;

    CLOSE SYMMETRIC KEY SK_Consorcio;
END;
GO

CREATE OR ALTER TRIGGER TRG_Consorcios_Encrypt
ON dbo.Consorcios
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;

    UPDATE C
    SET CBU_CVU = EncryptByKey(Key_GUID('SK_Consorcio'), i.CBU_CVU)
    FROM dbo.Consorcios C
    INNER JOIN inserted i ON C.ID_consorcio = i.ID_consorcio;

    CLOSE SYMMETRIC KEY SK_Consorcio;
END;
GO

CREATE OR ALTER TRIGGER TRG_Proveedores_Encrypt
ON dbo.Proveedores
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;

    UPDATE P
    SET cuenta = EncryptByKey(Key_GUID('SK_Consorcio'), i.cuenta)
    FROM dbo.Proveedores P
    INNER JOIN inserted i ON P.ID_Proveedores = i.ID_Proveedores;

    CLOSE SYMMETRIC KEY SK_Consorcio;
END;
GO


INSERT INTO dbo.PropietarioInquilino (DNI, nombre, apellido, email, telefono, CVU_CBU, inquilino)
VALUES ('30111222', 'Juan', 'Pérez', 'juan.perez@mail.com', '1144556677', '1234567890123456789012', 0);

select *
from PropietarioInquilino


------------------------------------

CREATE OR ALTER PROCEDURE dbo.SP_InsertarPropietarioInquilino
    @DNI VARCHAR(20),
    @nombre VARCHAR(50),
    @apellido VARCHAR(50),
    @email VARCHAR(100),
    @telefono VARCHAR(30),
    @CVU_CBU CHAR(22),
    @inquilino BIT
AS
BEGIN
    SET NOCOUNT ON;
    OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;

    INSERT INTO dbo.PropietarioInquilino (DNI, nombre, apellido, email, telefono, CVU_CBU, inquilino)
    VALUES (
        EncryptByKey(Key_GUID('SK_Consorcio'), @DNI),
        EncryptByKey(Key_GUID('SK_Consorcio'), @nombre),
        EncryptByKey(Key_GUID('SK_Consorcio'), @apellido),
        EncryptByKey(Key_GUID('SK_Consorcio'), @email),
        EncryptByKey(Key_GUID('SK_Consorcio'), @telefono),
        EncryptByKey(Key_GUID('SK_Consorcio'), @CVU_CBU),
        @inquilino
    );

    CLOSE SYMMETRIC KEY SK_Consorcio;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_ActualizarPropietarioInquilino
    @ID_PropietarioInquilino INT,
    @DNI VARCHAR(20) = NULL,
    @nombre VARCHAR(50) = NULL,
    @apellido VARCHAR(50) = NULL,
    @email VARCHAR(100) = NULL,
    @telefono VARCHAR(30) = NULL,
    @CVU_CBU CHAR(22) = NULL,
    @inquilino BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;

    UPDATE dbo.PropietarioInquilino
    SET DNI      = COALESCE(EncryptByKey(Key_GUID('SK_Consorcio'), @DNI), DNI),
        nombre   = COALESCE(EncryptByKey(Key_GUID('SK_Consorcio'), @nombre), nombre),
        apellido = COALESCE(EncryptByKey(Key_GUID('SK_Consorcio'), @apellido), apellido),
        email    = COALESCE(EncryptByKey(Key_GUID('SK_Consorcio'), @email), email),
        telefono = COALESCE(EncryptByKey(Key_GUID('SK_Consorcio'), @telefono), telefono),
        CVU_CBU  = COALESCE(EncryptByKey(Key_GUID('SK_Consorcio'), @CVU_CBU), CVU_CBU),
        inquilino= COALESCE(@inquilino, inquilino)
    WHERE ID_PropietarioInquilino = @ID_PropietarioInquilino;

    CLOSE SYMMETRIC KEY SK_Consorcio;
END;
GO



------------------------------  SP para insertar datos ya cifrados  ---------------------------------------

CREATE OR ALTER PROCEDURE dbo.SP_InsertarPropietarioInquilino
    @DNI VARCHAR(20),
    @nombre VARCHAR(50),
    @apellido VARCHAR(50),
    @email VARCHAR(100),
    @telefono VARCHAR(30),
    @CVU_CBU CHAR(22),
    @inquilino BIT
AS
BEGIN
    SET NOCOUNT ON;

    -- La clave ya debe estar abierta en la sesión ANTES de llamar al SP
    INSERT INTO dbo.PropietarioInquilino (DNI, nombre, apellido, email, telefono, CVU_CBU, inquilino)
    VALUES (
        EncryptByKey(Key_GUID('SK_Consorcio'), @DNI),
        EncryptByKey(Key_GUID('SK_Consorcio'), @nombre),
        EncryptByKey(Key_GUID('SK_Consorcio'), @apellido),
        EncryptByKey(Key_GUID('SK_Consorcio'), @email),
        EncryptByKey(Key_GUID('SK_Consorcio'), @telefono),
        EncryptByKey(Key_GUID('SK_Consorcio'), @CVU_CBU),
        @inquilino
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarConsorcio
    @consorcio VARCHAR(100),
    @nombre VARCHAR(100),
    @direccion VARCHAR(150),
    @m2_totales DECIMAL(10,2),
    @cant_unidades INT,
    @CBU_CVU CHAR(22)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Consorcios (consorcio, nombre, direccion, m2_totales, cant_unidades, CBU_CVU)
    VALUES (
        @consorcio,
        @nombre,
        @direccion,
        @m2_totales,
        @cant_unidades,
        EncryptByKey(Key_GUID('SK_Consorcio'), @CBU_CVU)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarProveedor
    @nombre VARCHAR(100),
    @cuenta VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Proveedores (nombre, cuenta)
    VALUES (
        @nombre,
        EncryptByKey(Key_GUID('SK_Consorcio'), @cuenta)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarPagoImportado
    @fecha DATE,
    @cuenta_origen CHAR(22),
    @importe DECIMAL(10,2),
    @asociado BIT = 0,
    @ID_unidad_funcional INT = NULL,
    @ID_consorcio INT = NULL,
    @ID_tipo_pago INT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Pagos_importados (fecha, cuenta_origen, importe, asociado, ID_unidad_funcional, ID_consorcio, ID_tipo_pago)
    VALUES (
        @fecha,
        EncryptByKey(Key_GUID('SK_Consorcio'), @cuenta_origen),
        @importe,
        @asociado,
        @ID_unidad_funcional,
        @ID_consorcio,
        @ID_tipo_pago
    );
END;
GO


------------------------------  EJEMPLO USO SP INSERCION  ---------------------------------------

-- 1. Abrir la clave en la sesión
OPEN SYMMETRIC KEY SK_Consorcio DECRYPTION BY CERTIFICATE Cert_Consorcio;

-- 2. Ejecutar el SP con parámetros en texto claro
EXEC dbo.SP_InsertarPropietarioInquilino
    @DNI = '30111222',
    @nombre = 'Juan',
    @apellido = 'Pérez',
    @email = 'juan.perez@mail.com',
    @telefono = '1144556677',
    @CVU_CBU = '1234567890123456789012',
    @inquilino = 0;

-- 3. Cerrar la clave
CLOSE SYMMETRIC KEY SK_Consorcio;

