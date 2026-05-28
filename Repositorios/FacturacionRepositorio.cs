using Dapper;
using System.Data;

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
    }
}
