
------------------- INDICES -----------------------------

-- Pagos_importados (reportes 1,2,3,4 y 6)

CREATE INDEX IX_Pagos_importados_Fecha
    ON Pagos_importados (fecha);

CREATE INDEX IX_Pagos_importados_TipoPago
    ON Pagos_importados (ID_tipo_pago);

CREATE INDEX IX_Pagos_importados_UF_Consorcio
    ON Pagos_importados (ID_unidad_funcional, ID_consorcio);

-- TipoPago (1,3 y 6)

CREATE INDEX IX_TipoPago_ID
    ON TipoPago (ID_tipo_pago);

-- Unidad_funcional (2 y 6)

CREATE INDEX IX_UnidadFuncional_Consorcio
    ON Unidad_funcional (ID_unidad_funcional, ID_consorcio);

CREATE INDEX IX_UnidadFuncional_Departamento
    ON Unidad_funcional (departamento);

-- Gastos (4)

CREATE INDEX IX_Gastos_Fecha
    ON Gastos (fecha);

-- Estado_cuenta_prorrateo (5)

CREATE INDEX IX_ECP_UF_Consorcio
    ON Estado_cuenta_prorrateo (ID_unidad_funcional, ID_consorcio);

-- UnidadFuncionalPersona (5)

 CREATE INDEX IX_UFP_UF_Consorcio
    ON UnidadFuncionalPersona (ID_unidad_funcional, ID_consorcio);

CREATE INDEX IX_UFP_Rol
    ON UnidadFuncionalPersona (rol);

-- PropietarioInquilino (5)

CREATE INDEX IX_PI_ID
    ON PropietarioInquilino (ID_PropietarioInquilino);
