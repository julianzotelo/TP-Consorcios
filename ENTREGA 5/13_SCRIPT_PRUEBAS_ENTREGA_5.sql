/*  SCRIPT con las pruebas y ejecuciones de cada SP
13-11-2025
Comisi�n 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Mart�n    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/

use Com3641G01
go 

--validaci�n de que el script de creaci�n de bd y tablas qued� ok

PRINT 'INICIANDO TESTING DE ESTRUCTURA';
DECLARE @tabla VARCHAR(100);
DECLARE @TablasEsperadas TABLE (
    nombre_tabla VARCHAR(100)
);

INSERT INTO @TablasEsperadas (nombre_tabla)
VALUES 
    ('Consorcios'),
    ('Proveedores'),
    ('ConsorcioProveedor'),
    ('TipoDetalleFinanciero'),
    ('Estado_financiero'),
    ('Detalle_EstadoFinanciero'),
    ('TipoGasto'),
    ('CategoriaGastoOrdinario'),
    ('Gastos'),
    ('Detalle_Gasto'),
    ('PropietarioInquilino'),
    ('Unidad_funcional'),
    ('UnidadFuncionalPersona'),
    ('Cochera'),
    ('Baulera'),
    ('Expensas'),
    ('Estado_cuenta_prorrateo'),
    ('Detalles_expensas'),
    ('Pagos_importados'),
    ('Servicios'),
    ('Mora'),
    ('Export_Expensas'),
    ('Export_EstadoCuentaProrrateo');

PRINT 'Validando existencia de tablas...';

SELECT 
    t.nombre_tabla,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM sys.tables 
            WHERE name = t.nombre_tabla
        ) THEN 'OK - Tabla creada'
        ELSE 'ERROR - Tabla NO existe'
    END AS Resultado
FROM @TablasEsperadas t;

PRINT 'FIN TESTING DE ESTRUCTURA';

GO
-- Ejecuci�n del primer sp - excel
PRINT 'EJECUCIPON SP_Creacion_Consorcio_Proveerdores'

EXEC dbo.SP_Creacion_Consorcio_Proveerdores
    @Ruta = N'C:\TEMP\TP_DB',
    @NombreArchivo = N'datos varios.xlsx';

PRINT ' VALIDANDO RESULTADOS DESPU�S DEL SP';
--En los mensajes en la primera ejecuci�n tiene que arrojar cantidad real de registros insertados, 
--Segunda ejecuci�n esos mismos mensajes deberian estar en CEOR

-- Consorcios importados
SELECT COUNT(*) AS Cant_Consorcios
FROM Consorcios;

-- Categor�as importadas
SELECT COUNT(*) AS Cant_Categorias
FROM CategoriaGastoOrdinario;

-- Proveedores importados
SELECT COUNT(*) AS Cant_Proveedores
FROM Proveedores;

-- Relaciones correctas
SELECT COUNT(*) AS Cant_ConsorcioProveedores
FROM ConsorcioProveedor;

PRINT 'Validaciones ejecutadas correctamente';

go

-- Ejecuci�n del segundo sp - txt
PRINT 'EJECUCIPON SP_Cargar_UnidadesFuncionales'

EXEC dbo.SP_Cargar_UnidadesFuncionales 
@Ruta = 'C:\TEMP\TP_DB',
@NombreArchivo = 'UF por consorcio.txt';

PRINT ' VALIDANDO RESULTADOS DESPU�S DEL SP';
--En los mensajes en la primera ejecuci�n tiene que arrojar cantidad real de registros insertados, 
--Segunda ejecuci�n esos mismos mensajes deberian estar en CEOR

-- Unidad_funcional
SELECT COUNT(*) AS Cant_UnidadFuncional
FROM Unidad_funcional;

-- CategoriaGastoOrdinario
SELECT COUNT(*) AS Cant_Categorias
FROM CategoriaGastoOrdinario;

-- Baulera
SELECT COUNT(*) AS Cant_Bauleras
FROM Baulera;

-- Cochera
SELECT COUNT(*) AS Cant_Cocheras
FROM Cochera;

PRINT 'Validaciones ejecutadas correctamente';

go

-- Ejecuci�n del tercer sp - csv
PRINT 'EJECUCIPON Importar_Inquilinos'

EXEC Importar_Inquilinos @RutaArchivo = 'C:\TEMP\TP_DB\Inquilino-propietarios-datos.csv';

PRINT ' VALIDANDO RESULTADOS DESPU�S DEL SP';
--En los mensajes en la primera ejecuci�n tiene que arrojar cantidad real de registros insertados, 
--Segunda ejecuci�n mensaje "No se insertaron registros nuevos. Todos los DNIs ya exist�an en la tabla."

-- PropietarioInquilino
SELECT COUNT(*) AS Cant_UnidadFuncional
FROM PropietarioInquilino;

PRINT 'Validaciones ejecutadas correctamente';

go
	
-- Ejecuci�n del cuarto sp - csv
PRINT 'EJECUCIPON SP_Vincular_Unidades_PropietariosInquilinos'

exec SP_Vincular_Unidades_PropietariosInquilinos @RutaArchivo = 'C:\TEMP\TP_DB\Inquilino-propietarios-UF.csv'

PRINT ' VALIDANDO RESULTADOS DESPU�S DEL SP';
--En los mensajes en la primera ejecuci�n tiene que arrojar cantidad real de registros insertados, 
--Segunda ejecuci�n mensaje "Registros insertados: 0"

-- UnidadFuncionalPersona
SELECT COUNT(*) AS Cant_UnidadFuncionalPersona
FROM UnidadFuncionalPersona;

PRINT 'Validaciones ejecutadas correctamente';

go

	
-- Ejecuci�n del quinto sp - csv
PRINT 'EJECUCIPON SP_Cargar_Pagos_Importados'

EXEC dbo.SP_Cargar_Pagos_Importados 
    @Ruta = 'C:\TEMP\TP_DB',
    @NombreArchivo = 'pagos_consorcios.csv';

PRINT ' VALIDANDO RESULTADOS DESPU�S DEL SP';
--En los mensajes en la primera ejecuci�n tiene que arrojar cantidad real de registros insertados,  
--tambien cantidad de registros duplicados
--Segunda ejecuci�n mensaje "Registros insertados: 0 y todos los dem�s registros aparecen ignorados por duplicados"

-- Pagos_importados
SELECT COUNT(*) AS Cant_Pagos_importados
FROM Pagos_importados;

PRINT 'Validaciones ejecutadas correctamente';

go

PRINT '--- Validando existencia del trigger TR_AsignarTipoYCategoria_Gastos ---';

IF EXISTS (
    SELECT 1 
    FROM sys.triggers 
    WHERE name = 'TR_AsignarTipoYCategoria_Gastos'
      AND parent_id = OBJECT_ID('dbo.Gastos')
)
    PRINT 'OK - El trigger TR_AsignarTipoYCategoria_Gastos existe.';
ELSE
    PRINT 'ERROR - El trigger TR_AsignarTipoYCategoria_Gastos NO existe.';

go

-- Ejecuci�n del sexto sp - csv
PRINT 'EJECUCIPON SP_Cargar_Gastos_Desde_JSON'

EXEC dbo.SP_Cargar_Gastos_Desde_JSON 
    @RutaArchivo = 'C:\TEMP\TP_DB\Servicios.Servicios.json';

PRINT ' VALIDANDO RESULTADOS DESPU�S DEL SP';
--En los mensajes en la primera ejecuci�n tiene que arrojar cantidad real de registros insertados, 
--Segunda ejecuci�n mensaje "Registros insertados: 0"

-- Pagos_importados
SELECT COUNT(*) AS Cant_CategoriaGastoOrdinario
FROM CategoriaGastoOrdinario;

SELECT COUNT(*) AS Cant_Gastos
FROM Gastos;

SELECT COUNT(*) AS Cant_Servicios
FROM Servicios;

SELECT COUNT(*) AS Cant_TipoGasto
FROM TipoGasto;

PRINT 'Validaciones ejecutadas correctamente';

go

--valido que se haya creado mi funcion
IF OBJECT_ID('dbo.fn_CalcularVencimiento', 'FN') IS NOT NULL
    PRINT 'La funci�n existe ';
ELSE
    PRINT 'La funci�n NO existe ';

go

--ejecuto sp que inserta mis tipos de detalles financieros

EXEC SP_Inicializar_TipoDetalleFinanciero;
GO

-- =============================================
-- Script de testing para generar las expensas y la documentacion que pide el enunciado
-- =============================================

-- Par�metros de prueba
DECLARE @ID_consorcio INT = 1;
DECLARE @periodo CHAR(20) = 'abril-2025';

EXEC SP_Generar_Documentacion_CSV
     @ID_Consorcio = @ID_consorcio,
     @Periodo = @periodo,
     @Ruta = 'C:\TEMP\TP_DB\ReportesGenerados',
     @NombreCSV_Expensas = 'Expensas.csv',
     @NombreCSV_Prorrateo = 'Prorrateo.csv';


-- Consultar resultados para verificar que se gener� correctamente
-- 1) Encabezado
SELECT * FROM Consorcios WHERE ID_consorcio = @ID_consorcio;

-- 2) Expensas generadas
SELECT * FROM Expensas WHERE ID_consorcio = @ID_consorcio AND periodo = LOWER(@periodo);

-- 3) Detalles de expensas
SELECT * FROM Detalles_expensas 
WHERE ID_expensas IN (SELECT ID_expensas FROM Expensas WHERE ID_consorcio = @ID_consorcio AND periodo = LOWER(@periodo));

-- 4) Estado financiero
SELECT * FROM Estado_financiero WHERE ID_consorcio = @ID_consorcio AND periodo = LOWER(@periodo);
SELECT * FROM Detalle_EstadoFinanciero WHERE ID_estado_financiero IN 
      (SELECT ID_estado_financiero FROM Estado_financiero WHERE ID_consorcio = @ID_consorcio AND periodo = LOWER(@periodo));

-- 5) Estado de cuenta prorrateo por UF
SELECT * FROM Estado_cuenta_prorrateo WHERE ID_consorcio = @ID_consorcio AND periodo = LOWER(@periodo);


