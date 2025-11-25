/*  SCRIPT CREACION DE INDICES - ENTREGA 6
13-11-2025
Comisión 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Martín    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/


-- Pagos_importados (reportes 1,2,3,4 y 6)

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pagos_importados_Fecha' AND object_id = OBJECT_ID('Pagos_importados'))
    CREATE INDEX IX_Pagos_importados_Fecha ON Pagos_importados (fecha);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pagos_importados_UF_Consorcio' AND object_id = OBJECT_ID('Pagos_importados'))
    CREATE INDEX IX_Pagos_importados_UF_Consorcio ON Pagos_importados (ID_unidad_funcional, ID_consorcio);


-- TipoPago (1,3 y 6)

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TipoPago_ID' AND object_id = OBJECT_ID('TipoPago'))
    CREATE INDEX IX_TipoPago_ID ON TipoPago (ID_tipo_pago);


-- Unidad_funcional (2 y 6)

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UnidadFuncional_Consorcio' AND object_id = OBJECT_ID('Unidad_funcional'))
    CREATE INDEX IX_UnidadFuncional_Consorcio ON Unidad_funcional (ID_unidad_funcional, ID_consorcio);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UnidadFuncional_Departamento' AND object_id = OBJECT_ID('Unidad_funcional'))
    CREATE INDEX IX_UnidadFuncional_Departamento ON Unidad_funcional (departamento);


-- Gastos (4)

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Gastos_Fecha' AND object_id = OBJECT_ID('Gastos'))
    CREATE INDEX IX_Gastos_Fecha ON Gastos (fecha);


-- Estado_cuenta_prorrateo (5)

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ECP_UF_Consorcio' AND object_id = OBJECT_ID('Estado_cuenta_prorrateo'))
    CREATE INDEX IX_ECP_UF_Consorcio ON Estado_cuenta_prorrateo (ID_unidad_funcional, ID_consorcio);


-- UnidadFuncionalPersona (5)

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UFP_UF_Consorcio' AND object_id = OBJECT_ID('UnidadFuncionalPersona'))
    CREATE INDEX IX_UFP_UF_Consorcio ON UnidadFuncionalPersona (ID_unidad_funcional, ID_consorcio);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UFP_Rol' AND object_id = OBJECT_ID('UnidadFuncionalPersona'))
    CREATE INDEX IX_UFP_Rol ON UnidadFuncionalPersona (rol);


-- PropietarioInquilino (5)

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PI_ID' AND object_id = OBJECT_ID('PropietarioInquilino'))
    CREATE INDEX IX_PI_ID ON PropietarioInquilino (ID_PropietarioInquilino);
