using Dapper;
using System.Data;
using HipodromoNacional.Models;

namespace HipodromoNacional.Repositories
{
    public class EstabloRepository : IEstabloRepository
    {
        private readonly IDbConnection _db;

        public EstabloRepository(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<EstabloDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion, capacidad AS Capacidad, estado AS Estado FROM establo ORDER BY id_establo");
        }

        public async Task<EstabloDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion, capacidad AS Capacidad, estado AS Estado FROM establo WHERE id_establo = @Id", new { Id = id });
        }

        public async Task<int> CrearEstabloAsync(EstabloDTO e)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_codigo", e.Codigo);
            parameters.Add("p_ubicacion", e.Ubicacion);
            parameters.Add("p_capacidad", e.Capacidad);
            parameters.Add("p_estado", e.Estado);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_establo", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarEstabloAsync(EstabloDTO e)
        {
            // Point 7 specifies we modify at least 3 fields. (e.g. Ubicacion, Capacidad, Estado)
            var parameters = new DynamicParameters();
            parameters.Add("p_id_establo", e.IdEstablo);
            parameters.Add("p_ubicacion", e.Ubicacion);
            parameters.Add("p_capacidad", e.Capacidad);
            parameters.Add("p_estado", e.Estado);

            int rows = await _db.ExecuteAsync("sp_actualizar_establo", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> EliminarEstabloAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_establo", id);
            
            int rows = await _db.ExecuteAsync("sp_eliminar_establo", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }
    }
}
