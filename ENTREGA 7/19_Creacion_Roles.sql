-- ==========================================================
-- CREACIÓN DE ROLES POR ÁREA
-- ==========================================================
CREATE ROLE Role_AdminGeneral;
CREATE ROLE Role_AdminBancario;
CREATE ROLE Role_AdminOperativo;
CREATE ROLE Role_Sistemas;

-- ==========================================================
-- ASIGNACIÓN DE PERMISOS A ROLES
-- ==========================================================

-- Administrativo General: Actualización de UF + Reportes 
GRANT SELECT, UPDATE ON dbo.Unidad_funcional TO Role_AdminGeneral;
GRANT EXECUTE ON dbo.GenerarReportes TO Role_AdminGeneral;
GRANT EXECUTE ON dbo.SP_InsertarConsorcio TO Role_AdminGeneral;
GRANT EXECUTE ON dbo.SP_InsertarPropietarioInquilino TO Role_AdminGeneral;
GRANT EXECUTE ON dbo.SP_InsertarProveedor TO Role_AdminGeneral;

-- Administrativo Bancario: Importación bancaria + Reportes 
GRANT INSERT, SELECT ON dbo.Pagos_importados TO Role_AdminBancario;
GRANT SELECT ON dbo.Estado_financiero TO Role_AdminBancario;
GRANT EXECUTE ON dbo.GenerarReportes TO Role_AdminBancario;
GRANT EXECUTE ON dbo.SP_InsertarPagoImportado TO Role_AdminBancario;


-- Administrativo Operativo: Actualización de UF + Reportes 
GRANT SELECT, UPDATE ON dbo.Unidad_funcional TO Role_AdminOperativo;
GRANT SELECT ON dbo.Detalles_expensas TO Role_AdminOperativo;
GRANT EXECUTE ON dbo.GenerarReportes TO Role_AdminOperativo;
GRANT EXECUTE ON dbo.SP_InsertarPropietarioInquilino TO Role_AdminOperativo;

-- Sistemas: Solo Reportes
GRANT EXECUTE ON dbo.GenerarReportes TO Role_Sistemas;

-- ==========================================================
-- CREACIÓN DE USUARIOS Y ASIGNACIÓN A ROLES
-- ==========================================================

-- Administrativo General
CREATE LOGIN usuario_maria WITH PASSWORD = 'ClaveSegura1!';
CREATE USER usuario_maria FOR LOGIN usuario_maria;
ALTER ROLE Role_AdminGeneral ADD MEMBER usuario_maria;

-- Administrativo Bancario
CREATE LOGIN usuario_juan WITH PASSWORD = 'ClaveSegura2!';
CREATE USER usuario_juan FOR LOGIN usuario_juan;
ALTER ROLE Role_AdminBancario ADD MEMBER usuario_juan;

-- Administrativo Operativo
CREATE LOGIN usuario_carla WITH PASSWORD = 'ClaveSegura3!';
CREATE USER usuario_carla FOR LOGIN usuario_carla;
ALTER ROLE Role_AdminOperativo ADD MEMBER usuario_carla;

-- Sistemas
CREATE LOGIN usuario_diego WITH PASSWORD = 'ClaveSegura4!';
CREATE USER usuario_diego FOR LOGIN usuario_diego;
ALTER ROLE Role_Sistemas ADD MEMBER usuario_diego;
