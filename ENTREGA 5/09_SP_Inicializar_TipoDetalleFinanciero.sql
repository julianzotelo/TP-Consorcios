use Com3641G01
go
CREATE OR ALTER PROCEDURE SP_Inicializar_TipoDetalleFinanciero
AS
BEGIN
    SET NOCOUNT ON;

    -- Validamos si ya existe contenido
    IF NOT EXISTS (SELECT 1 FROM TipoDetalleFinanciero)
    BEGIN
        INSERT INTO TipoDetalleFinanciero (tipo_movimiento, nombre, descripcion)
        VALUES
            ('INGRESO', 'Expensas en término', 
                'Total recaudado antes del vencimiento'),

            ('INGRESO', 'Expensas adeudadas', 
                'Pagos recibidos por saldo deudor de períodos anteriores'),

            ('INGRESO', 'Expensas adelantadas', 
                'Pagos recibidos correspondientes a períodos futuros'),

            ('EGRESO', 'Gastos del mes', 
                'Total de los gastos generados en el mes'),

             ('INGRESO', 'Saldo anterior', 
                'Total de los saldos anteriores'),

             ('INGRESO', 'Saldo al cierre', 
                'Total de saldo al cierre');
               

        PRINT 'Tabla TipoDetalleFinanciero inicializada correctamente.';
    END
    ELSE
    BEGIN
        PRINT 'La tabla TipoDetalleFinanciero ya estaba inicializada.';
    END
END;
GO
