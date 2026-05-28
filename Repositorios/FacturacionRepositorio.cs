using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class FacturacionRepositorio : IFacturacionRepositorio
    {
        private readonly IDbConnection _db;

        public FacturacionRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<bool> EjecutarCalculoFrecuentesAsync()
        {
            await _db.ExecuteAsync("sp_calcular_propietarios_frecuentes", commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<int> CrearFacturaAsync(int idPropietario, int idEvento, int? idMetodoPago, string referencia, string numeroComprobante)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_propietario", idPropietario);
            parameters.Add("p_id_evento", idEvento);
            parameters.Add("p_id_metodo_pago", idMetodoPago);
            parameters.Add("p_referencia", referencia);
            parameters.Add("p_numero_comprobante", numeroComprobante);
            parameters.Add("p_new_id_factura", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_crear_factura", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id_factura");
        }

        public async Task<FacturaDetalleDTO?> ObtenerFacturaDetalleAsync(int idFactura)
        {
            var queryFactura = @"
                SELECT 
                    f.id_factura AS IdFactura,
                    f.codigo_factura AS CodigoFactura,
                    p.nombre || ' ' || p.apellido1 || ' ' || COALESCE(p.apellido2, '') AS ClienteNombre,
                    p.cedula AS ClienteCedula,
                    e.nombre AS EventoNombre,
                    e.codigo_evento AS EventoCodigo,
                    f.subtotal AS Subtotal,
                    f.porcentaje_descuento AS PorcentajeDescuento,
                    f.monto_descuento AS MontoDescuento,
                    f.base_imponible AS BaseImponible,
                    f.impuesto_iva AS ImpuestoIva,
                    f.comision_admin AS ComisionAdmin,
                    f.total AS Total,
                    ep.nombre_estado AS EstadoPago,
                    f.fecha_emision AS FechaEmision,
                    f.fecha_vencimiento AS FechaVencimiento,
                    mp.nombre_metodo_pago AS MetodoPago,
                    ht.referencia AS ReferenciaPago,
                    ht.numero_comprobante AS ComprobantePago,
                    ht.fecha_pago AS FechaPago
                FROM factura f
                JOIN propietario p ON f.id_propietario = p.id_propietario
                JOIN evento e ON f.id_evento = e.id_evento
                JOIN estado_pago ep ON f.id_estado_pago = ep.id_estado_pago
                LEFT JOIN historial_transaccion ht ON f.id_factura = ht.id_factura AND ht.estado = 'Registrado'
                LEFT JOIN metodo_pago mp ON ht.id_metodo_pago = mp.id_metodo_pago
                WHERE f.id_factura = @IdFactura;";

            var factura = await _db.QueryFirstOrDefaultAsync<FacturaDetalleDTO>(queryFactura, new { IdFactura = idFactura });

            if (factura != null)
            {
                var queryLineas = @"
                    SELECT 
                        df.id_detalle AS IdDetalle,
                        df.descripcion AS Descripcion,
                        df.cantidad AS Cantidad,
                        df.precio_unitario AS PrecioUnitario,
                        df.subtotal_linea AS SubtotalLinea
                    FROM detalle_factura df
                    WHERE df.id_factura = @IdFactura;";

                var lineas = await _db.QueryAsync<FacturaLineaDTO>(queryLineas, new { IdFactura = idFactura });
                factura.Lineas = lineas.ToList();
            }

            return factura;
        }
    }
}
