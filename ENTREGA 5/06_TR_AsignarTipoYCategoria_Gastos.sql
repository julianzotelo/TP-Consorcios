/*  Trigger Asignar Tipo Y Categoria
13-11-2025
Comisión 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Martín    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/

use Com3641G01
go

CREATE OR ALTER TRIGGER TR_AsignarTipoYCategoria_Gastos
ON dbo.Gastos
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    --valido que existan todas mis categorias de gastos ordinarios
     DECLARE @Categorias TABLE (nombre NVARCHAR(100));
    INSERT INTO @Categorias (nombre)
    VALUES 
        ('GASTOS BANCARIOS'),
        ('GASTOS DE ADMINISTRACION'),
        ('GASTOS DE LIMPIEZA'),
        ('SEGUROS'),
        ('SERVICIOS PUBLICOS'),
        ('GASTOS GENERALES'); -- añadimos esta para cubrir todas

    INSERT INTO CategoriaGastoOrdinario (nombre)
    SELECT c.nombre
    FROM @Categorias c
    WHERE NOT EXISTS (
        SELECT 1 FROM CategoriaGastoOrdinario cg WHERE UPPER(cg.nombre) = UPPER(c.nombre)
    );

    --valido que existan los tipos de gastos
     IF NOT EXISTS (SELECT 1 FROM TipoGasto)
    BEGIN
        INSERT INTO TipoGasto (nombre, descripcion)
        VALUES ('Ordinario', 'Gasto de tipo ordinario'),
               ('Extraordinario', 'Gasto de tipo extraordinario');
    END

    DECLARE @ID_TipoOrdinario INT = (SELECT TOP 1 ID_tipo_gasto FROM TipoGasto WHERE nombre = 'Ordinario');
    DECLARE @ID_TipoExtraordinario INT = (SELECT TOP 1 ID_tipo_gasto FROM TipoGasto WHERE nombre = 'Extraordinario');

    /*  Actualizar tipo y categoría según concepto */
    UPDATE g
    SET 
        g.ID_tipo_gasto =
            CASE 
                WHEN c.ID_categoria IS NOT NULL THEN @ID_TipoOrdinario
                ELSE @ID_TipoExtraordinario
            END,
        g.ID_categoria = c.ID_categoria
    FROM Gastos g
    INNER JOIN inserted i ON g.ID_gastos = i.ID_gastos
    LEFT JOIN CategoriaGastoOrdinario c 
    on
         -- Coincidencias exactas o parciales normales
         UPPER(i.concepto) LIKE '%' + REPLACE(UPPER(c.nombre), 'GASTOS ', '') + '%'
        OR UPPER(c.nombre) LIKE '%' + UPPER(i.concepto) + '%'
        OR 
        -- Coincidencia especial para servicios públicos
        (UPPER(i.concepto) LIKE 'SERVICIOS PUBLICOS%' AND UPPER(c.nombre) = 'SERVICIOS PUBLICOS')

    /*  Insertar automáticamente en Servicios si es un gasto de tipo “SERVICIOS PUBLICOS” */
    INSERT INTO Servicios (ID_consorcio, ID_categoria, nombre, importe, fecha)
    SELECT 
        g.ID_consorcio,
        g.ID_categoria,
        CASE 
            WHEN UPPER(i.concepto) LIKE '%LUZ%' THEN 'Luz'
            WHEN UPPER(i.concepto) LIKE '%AGUA%' THEN 'Agua'
            WHEN UPPER(i.concepto) LIKE '%INTERNET%' THEN 'Internet'
            ELSE i.concepto
        END AS nombre,
        g.monto_total,
        g.fecha
    FROM inserted i
    INNER JOIN Gastos g ON i.ID_gastos = g.ID_gastos
    INNER JOIN CategoriaGastoOrdinario c ON g.ID_categoria = c.ID_categoria
    WHERE UPPER(c.nombre) LIKE '%SERVICIOS PUBLICOS%';
END;
GO
