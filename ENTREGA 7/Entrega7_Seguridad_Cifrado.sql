-- Entrega 7 - Seguridad y Cifrado


-- 1. Creación de Roles
CREATE ROLE Rol_AdminConsorcio;
CREATE ROLE Rol_Operador;
CREATE ROLE Rol_Consulta;

-- 2. Asignación de permisos (ejemplos)
GRANT SELECT, INSERT, UPDATE ON dbo.InquilinoPropietarios TO Rol_Operador;
GRANT SELECT ON dbo.InquilinoPropietarios TO Rol_Consulta;

-- 3. Modificar estructura para incorporar cifrado
ALTER TABLE dbo.InquilinoPropietarios ADD Email_Cifrado VARBINARY(MAX), Telefono_Cifrado VARBINARY(MAX);

-- 4. Cifrado de datos existentes
UPDATE dbo.InquilinoPropietarios
SET Email_Cifrado = EncryptByPassPhrase('ClaveSegura123', Email),
    Telefono_Cifrado = EncryptByPassPhrase('ClaveSegura123', Telefono);

-- 5. Store Procedure actualizado para insert/update con cifrado
CREATE OR ALTER PROCEDURE sp_InsertarInquilinoCifrado
    @Nombre NVARCHAR(100),
    @Apellido NVARCHAR(100),
    @DNI NVARCHAR(50),
    @Email NVARCHAR(150),
    @Telefono NVARCHAR(50)
AS
BEGIN
    INSERT INTO dbo.InquilinoPropietarios (Nombre, Apellido, DNI, Email_Cifrado, Telefono_Cifrado)
    VALUES (
        @Nombre,
        @Apellido,
        @DNI,
        EncryptByPassPhrase('ClaveSegura123', @Email),
        EncryptByPassPhrase('ClaveSegura123', @Telefono)
    );
END;

-- 6. Vista para desencriptar (solo lectura)
CREATE OR ALTER VIEW vw_InquilinosDesencriptados
AS
SELECT 
    Nombre,
    Apellido,
    DNI,
    CONVERT(NVARCHAR(150), DecryptByPassPhrase('ClaveSegura123', Email_Cifrado)) AS Email,
    CONVERT(NVARCHAR(50), DecryptByPassPhrase('ClaveSegura123', Telefono_Cifrado)) AS Telefono
FROM dbo.InquilinoPropietarios;

-- 7. Política de Backup (documentación)
-- Backups diarios diferenciales, semanales completos, mensuales archivados.
-- RPO recomendado: 24 horas.

