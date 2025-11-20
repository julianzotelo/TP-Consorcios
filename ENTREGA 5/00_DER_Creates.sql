/*  Create DB y tablas
13-11-2025
Comisión 3641 
Grupo 01 
Bases de datos aplicada
Alumno                      | DNI
Pereyra, Facundo Gabriel    | 43105379
Roldan, Francisco Martín    | 42426768
Zotelo, Julian Lorenzo      | 42536473

*/

IF DB_ID('Com3641G01') IS NULL
BEGIN
    PRINT 'Creando base de datos Com3641G01...';
    CREATE DATABASE Com3641G01;
END
ELSE
BEGIN
    PRINT 'La base Com3641G01 ya existe. Se utilizara la existente.';
END;
GO

USE Com3641G01;
GO


-- Elimino las tablas si ya existen para que se creen actualizadas, se borran en este orden por tema de dependencias
PRINT 'Eliminando tablas existentes si las hubiera...';
BEGIN TRY
    DROP TABLE IF EXISTS MORA;
	DROP TABLE IF EXISTS Detalles_expensas;
	DROP TABLE IF EXISTS Expensas;
	DROP TABLE IF EXISTS Estado_cuenta_prorrateo;
	DROP TABLE IF EXISTS Baulera;
	DROP TABLE IF EXISTS Cochera;
    DROP TABLE IF EXISTS Servicios;
	DROP TABLE IF EXISTS UnidadFuncionalPersona;
    DROP TABLE IF EXISTS Pagos_importados;
	DROP TABLE IF EXISTS Unidad_funcional;
	DROP TABLE IF EXISTS PropietarioInquilino;
	DROP TABLE IF EXISTS Factura;
	DROP TABLE IF EXISTS Detalle_Gasto;
	DROP TABLE IF EXISTS Gastos;
	DROP TABLE IF EXISTS CategoriaGastoOrdinario;
	DROP TABLE IF EXISTS TipoGasto;
	DROP TABLE IF EXISTS Detalle_EstadoFinanciero;
	DROP TABLE IF EXISTS Estado_financiero;
	DROP TABLE IF EXISTS ConsorcioProveedor;
	DROP TABLE IF EXISTS Proveedores;
	DROP TABLE IF EXISTS TipoDetalleFinanciero;
    DROP TABLE IF EXISTS Consorcios;
    


    PRINT 'Tablas previas eliminadas correctamente.';

END TRY
BEGIN CATCH
    PRINT 'Error eliminando tablas existentes:';
    PRINT ERROR_MESSAGE();
END CATCH;
GO


-- Creo las tablas actualizadas
PRINT 'Creando tablas nuevas...';
BEGIN TRY
	PRINT 'Creando tabla Consorcios...';

    CREATE TABLE Consorcios (
        ID_consorcio INT IDENTITY(1,1) PRIMARY KEY ,
        consorcio VARCHAR(100) NOT NULL,
        nombre VARCHAR(100) NOT NULL,
        direccion VARCHAR(150) NOT NULL,
        m2_totales DECIMAL(10,2),
        cant_unidades INT,
        CBU_CVU CHAR(22)
    );


	PRINT 'Creando tabla Proveedores...';

    CREATE TABLE Proveedores (
        ID_Proveedores INT IDENTITY(1,1) PRIMARY KEY,
        nombre VARCHAR(100) NOT NULL,
        cuenta VARCHAR(50) 
    );

	PRINT 'Creando tabla ConsorcioProveedor...';

    CREATE TABLE ConsorcioProveedor (
        ID_Proveedores INT NOT NULL,
        ID_consorcio INT NOT NULL,
        CONSTRAINT PK_ConsorcioProveedor PRIMARY KEY (ID_Proveedores, ID_consorcio),
        CONSTRAINT FK_ConsorcioProveedor_Proveedores FOREIGN KEY (ID_Proveedores)
            REFERENCES Proveedores(ID_Proveedores)
            ON DELETE NO ACTION
            ON UPDATE CASCADE,
        CONSTRAINT FK_ConsorcioProveedor_Consorcios FOREIGN KEY (ID_consorcio)
            REFERENCES Consorcios(ID_consorcio)
            ON DELETE NO ACTION
            ON UPDATE CASCADE
    );

	PRINT 'Creando tabla TipoDetalleFinanciero...';

	CREATE TABLE TipoDetalleFinanciero (
		ID_tipo_detalle INT IDENTITY(1,1) PRIMARY KEY,
		tipo_movimiento VARCHAR(10) NOT NULL CHECK (tipo_movimiento IN ('INGRESO','EGRESO')),
		nombre VARCHAR(50) NOT NULL,     
		descripcion VARCHAR(200),
		monto DECIMAL(10,2)
	);


	PRINT 'Creando tabla Estado_financiero...';

    CREATE TABLE Estado_financiero (
        ID_estado_financiero INT IDENTITY(1,1) PRIMARY KEY,
        ID_consorcio INT NOT NULL,
        periodo CHAR(7),
        saldo_anterior DECIMAL(10,2),
		saldo_cierre DECIMAL(10,2),
        CONSTRAINT FK_EstadoFinanciero_Consorcios FOREIGN KEY (ID_consorcio)
            REFERENCES Consorcios(ID_consorcio)
            ON DELETE CASCADE
            ON UPDATE CASCADE
    );
	
	PRINT 'Creando tabla Detalle_EstadoFinanciero...';

	CREATE TABLE Detalle_EstadoFinanciero (
    ID_detalle_estado INT IDENTITY(1,1) PRIMARY KEY,
    ID_estado_financiero INT NOT NULL,
    ID_tipo_detalle INT NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    descripcion VARCHAR(200),
    CONSTRAINT FK_DetalleEstadoFinanciero_EstadoFinanciero FOREIGN KEY (ID_estado_financiero)
        REFERENCES Estado_financiero(ID_estado_financiero)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT FK_DetalleEstadoFinanciero_TipoDetalle FOREIGN KEY (ID_tipo_detalle)
        REFERENCES TipoDetalleFinanciero(ID_tipo_detalle)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
	);

	PRINT 'Creando tabla TipoGasto...';

	CREATE TABLE TipoGasto (
		ID_tipo_gasto INT IDENTITY(1,1) PRIMARY KEY,
		nombre VARCHAR(50) NOT NULL,
		descripcion VARCHAR(200)
	);

	PRINT 'Creando tabla CategoriaGastoOrdinario...';

	CREATE TABLE CategoriaGastoOrdinario (
		ID_categoria INT IDENTITY(1,1) PRIMARY KEY,
		nombre VARCHAR(100) NOT NULL
	);

	PRINT 'Creando tabla Gastos...';

    CREATE TABLE Gastos (
    ID_gastos INT IDENTITY(1,1) PRIMARY KEY,
    ID_consorcio INT NOT NULL,
    ID_tipo_gasto INT NULL,
    ID_categoria INT NULL,
    monto_total DECIMAL(10,2),
    concepto VARCHAR(100),
    mes varchar(20),
    fecha DATE,
    CONSTRAINT FK_Gastos_Consorcios FOREIGN KEY (ID_consorcio)
        REFERENCES Consorcios(ID_consorcio) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT FK_Gastos_TipoGasto FOREIGN KEY (ID_tipo_gasto)
        REFERENCES TipoGasto(ID_tipo_gasto) 
          ON DELETE CASCADE 
          ON UPDATE CASCADE,
    CONSTRAINT FK_Gastos_Categoria FOREIGN KEY (ID_categoria)
        REFERENCES CategoriaGastoOrdinario(ID_categoria) 
          ON DELETE CASCADE 
          ON UPDATE CASCADE
);

	PRINT 'Creando tabla Detalle_Gasto...';

	CREATE TABLE Detalle_Gasto (
		ID_detalle_gasto INT IDENTITY(1,1) PRIMARY KEY,
		ID_gasto INT NOT NULL,
		empresa_persona VARCHAR(100),
		descripcion VARCHAR(200),
		importe DECIMAL(10,2),
		nro_factura VARCHAR(30),
		pago_total BIT NOT NULL DEFAULT 1,
		cuota_actual INT NULL,
		cuota_total INT NULL,
		CONSTRAINT FK_DetalleGasto_Gastos FOREIGN KEY (ID_gasto)
			REFERENCES Gastos(ID_gastos)
			ON DELETE CASCADE
			ON UPDATE CASCADE
	);

	PRINT 'Creando tabla Factura...';

	CREATE TABLE Factura (
		ID_factura INT IDENTITY(1,1) PRIMARY KEY,
		ID_detalle_gasto INT NOT NULL,
		ID_Proveedores INT NOT NULL,
		fecha_emision DATE NOT NULL,
		fecha_vencimiento DATE,
		monto_total DECIMAL(10,2),
		estado VARCHAR(20),
		CONSTRAINT FK_Factura_DetalleGasto FOREIGN KEY (ID_detalle_gasto)
			REFERENCES Detalle_Gasto(ID_detalle_gasto)
			ON DELETE CASCADE
			ON UPDATE CASCADE,
		CONSTRAINT FK_Factura_Proveedores FOREIGN KEY (ID_Proveedores)
			REFERENCES Proveedores(ID_Proveedores)
			ON DELETE NO ACTION
			ON UPDATE CASCADE
	);


CREATE TABLE PropietarioInquilino (
    ID_PropietarioInquilino INT IDENTITY(1,1) PRIMARY KEY,
    DNI INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    telefono VARCHAR(30),
    CVU_CBU CHAR(22) NOT NULL,
    inquilino BIT NOT NULL,
    CONSTRAINT UQ_PropietarioInquilino_DNI_CBU UNIQUE (DNI, CVU_CBU)
);



	PRINT 'Creando tabla Unidad_funcional...';

CREATE TABLE Unidad_funcional (
    ID_unidad_funcional INT NOT NULL,
    ID_consorcio INT NOT NULL,
    departamento VARCHAR(50) NOT NULL,
    piso VARCHAR(5) NOT NULL,
    coeficiente DECIMAL(6,4),
    tiene_cochera BIT NOT NULL,
    tiene_baulera BIT NOT NULL,
    m2 DECIMAL(8,2),
    CONSTRAINT PK_UnidadFuncional PRIMARY KEY (ID_unidad_funcional, ID_consorcio),
    CONSTRAINT FK_UnidadFuncional_Consorcios FOREIGN KEY (ID_consorcio)
        REFERENCES Consorcios(ID_consorcio)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

		PRINT 'Creando tabla UnidadFuncionalPersona...';

	CREATE TABLE UnidadFuncionalPersona (
    ID_unidad_funcional INT NOT NULL,
    ID_consorcio INT NOT NULL,
    ID_PropietarioInquilino INT NOT NULL,
    rol VARCHAR(20) CHECK (rol IN ('PROPIETARIO', 'INQUILINO')),
    fecha_desde DATE,
    fecha_hasta DATE,
    PRIMARY KEY (ID_unidad_funcional, ID_consorcio, ID_PropietarioInquilino, rol),
    FOREIGN KEY (ID_unidad_funcional, ID_consorcio)
        REFERENCES Unidad_funcional(ID_unidad_funcional, ID_consorcio),
    FOREIGN KEY (ID_PropietarioInquilino) REFERENCES PropietarioInquilino(ID_PropietarioInquilino)
);


	PRINT 'Creando tabla Cochera...';

 CREATE TABLE Cochera (
    ID_Cochera INT IDENTITY(1,1) PRIMARY KEY,
    ID_unidad_funcional INT NOT NULL,
    ID_consorcio INT NOT NULL,
    m2 DECIMAL(6,2),
    CONSTRAINT FK_Cochera_UnidadFuncional 
        FOREIGN KEY (ID_unidad_funcional, ID_consorcio)
        REFERENCES Unidad_funcional(ID_unidad_funcional, ID_consorcio)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


	PRINT 'Creando tabla Baulera...';

CREATE TABLE Baulera (
    ID_Baulera INT IDENTITY(1,1) PRIMARY KEY,
    ID_unidad_funcional INT NOT NULL,
    ID_consorcio INT NOT NULL,
    m2 DECIMAL(6,2),
    CONSTRAINT FK_Baulera_UnidadFuncional 
        FOREIGN KEY (ID_unidad_funcional, ID_consorcio)
        REFERENCES Unidad_funcional(ID_unidad_funcional, ID_consorcio)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);



	PRINT 'Creando tabla Expensas...';

    CREATE TABLE Expensas (
    ID_expensas INT IDENTITY(1,1) PRIMARY KEY,
    ID_unidad_funcional INT NOT NULL,
    ID_consorcio INT NOT NULL,
    periodo CHAR(7),
    monto_total DECIMAL(10,2),
    estado VARCHAR(20),
    fecha_vencimiento DATE,
    CONSTRAINT FK_Expensas_UnidadFuncional 
        FOREIGN KEY (ID_unidad_funcional, ID_consorcio)
        REFERENCES Unidad_funcional(ID_unidad_funcional, ID_consorcio)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


	PRINT 'Creando tabla Estado_cuenta_prorrateo...';

CREATE TABLE Estado_cuenta_prorrateo (
    ID_estado_de_cuenta INT IDENTITY(1,1) PRIMARY KEY,
    ID_unidad_funcional INT NOT NULL,
    ID_consorcio INT NOT NULL,
    periodo CHAR(7),
    saldo_anterior DECIMAL(10,2),
    pagos_recibidos DECIMAL(10,2),
    interes_mora DECIMAL(10,2),
    expensas_ordinarias DECIMAL(10,2),
    expensas_extraordinarias DECIMAL(10,2),
    total_pagar DECIMAL(10,2),
    CONSTRAINT FK_EstadoCuenta_UnidadFuncional 
        FOREIGN KEY (ID_unidad_funcional, ID_consorcio)
        REFERENCES Unidad_funcional(ID_unidad_funcional, ID_consorcio)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);



	PRINT 'Creando tabla Detalles_expensas...';

    CREATE TABLE Detalles_expensas (
        ID_detalle_expensas INT IDENTITY(1,1) PRIMARY KEY,
        ID_expensas INT NOT NULL,
        ID_detalle_gasto INT NULL,
        concepto VARCHAR(30),
        monto DECIMAL(10,2),
        descripcion VARCHAR(200),
        CONSTRAINT FK_DetalleExpensas_Expensas FOREIGN KEY (ID_expensas)
            REFERENCES Expensas(ID_expensas)
             ON DELETE CASCADE 
             ON UPDATE CASCADE,
       CONSTRAINT FK_DetalleExpensas_DetalleGasto FOREIGN KEY (ID_detalle_gasto)
            REFERENCES Detalle_Gasto(ID_detalle_gasto)
             ON DELETE NO ACTION
             ON UPDATE NO ACTION
    );

	
	PRINT 'Creando tabla Servicios...';

   CREATE TABLE Servicios (
    ID_servicio INT IDENTITY(1,1) PRIMARY KEY,
    ID_consorcio INT NOT NULL,
    ID_categoria INT NOT NULL, -- FK hacia CategoriaGastoOrdinario
    nombre VARCHAR(50) NOT NULL, -- Luz, Agua, Internet
    empresa VARCHAR(100),
    nro_factura VARCHAR(30),
    importe DECIMAL(10,2), 
    fecha DATE,
    CONSTRAINT FK_Servicios_Consorcios FOREIGN KEY (ID_consorcio)
        REFERENCES Consorcios(ID_consorcio)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_Servicios_Categoria FOREIGN KEY (ID_categoria)
        REFERENCES CategoriaGastoOrdinario(ID_categoria)
        ON DELETE NO ACTION ON UPDATE CASCADE
);

	PRINT 'Creando tabla Mora...';
CREATE TABLE Mora (
    ID_mora INT IDENTITY PRIMARY KEY,
    ID_expensas INT NOT NULL,
    fecha DATE NOT NULL,
    importe DECIMAL(10,2) NOT NULL,
    descripcion VARCHAR(200),
    FOREIGN KEY (ID_expensas) REFERENCES Expensas(ID_expensas)
);

CREATE TABLE TipoPago (
    ID_tipo_pago INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL CHECK (nombre IN ('ORDINARIO','EXTRAORDINARIO')),
    descripcion VARCHAR(200)
);

PRINT 'Creando tabla Pagos_importados...';

CREATE TABLE Pagos_importados (
    ID_pago INT IDENTITY(1,1) PRIMARY KEY,
    fecha DATE NOT NULL,
    cuenta_origen CHAR(22) NOT NULL,
    importe DECIMAL(10,2) NOT NULL,
    asociado BIT DEFAULT 0,
    ID_unidad_funcional INT NULL,
    ID_consorcio INT NULL,
    ID_tipo_pago INT NOT NULL, -- referencia al catálogo TipoPago
    CONSTRAINT FK_Pagos_UnidadFuncional FOREIGN KEY (ID_unidad_funcional, ID_consorcio)
        REFERENCES Unidad_funcional(ID_unidad_funcional, ID_consorcio)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT FK_Pagos_TipoPago FOREIGN KEY (ID_tipo_pago)
        REFERENCES TipoPago(ID_tipo_pago)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
);

    PRINT 'Tablas y relaciones creadas correctamente.';

END TRY
BEGIN CATCH
    PRINT 'Error durante la creaci�n de tablas:';
    PRINT ERROR_MESSAGE();
END CATCH;
GO