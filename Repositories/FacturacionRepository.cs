using Dapper;
using System.Data;

namespace HipodromoNacional.Repositories
{
    public class FacturacionRepository : IFacturacionRepository
    {
        private readonly IDbConnection _db;

        public FacturacionRepository(IDbConnection db)
        {
            _db = db;
        }

        public async Task<bool> EjecutarCalculoFrecuentesAsync()
        {
            int rows = await _db.ExecuteAsync("sp_calcular_propietarios_frecuentes", commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
