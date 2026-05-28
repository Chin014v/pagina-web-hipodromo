using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class EventoRepositorio : IEventoRepositorio
    {
        private readonly IDbConnection _db;

        public EventoRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<EventoDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<EventoDTO>("SELECT id_evento AS IdEvento, codigo_evento AS CodigoEvento, nombre AS Nombre, fecha AS Fecha, tipo_carrera AS TipoCarrera, distancia_metros AS DistanciaMetros, premio_total AS PremioTotal, precio_inscripcion AS PrecioInscripcion, estado AS Estado FROM evento ORDER BY fecha DESC");
        }

        public async Task<EventoDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<EventoDTO>("SELECT id_evento AS IdEvento, codigo_evento AS CodigoEvento, nombre AS Nombre, fecha AS Fecha, tipo_carrera AS TipoCarrera, distancia_metros AS DistanciaMetros, premio_total AS PremioTotal, precio_inscripcion AS PrecioInscripcion, estado AS Estado FROM evento WHERE id_evento = @Id", new { Id = id });
        }

        public async Task<int> CrearEventoAsync(EventoDTO e)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_codigo_evento", e.CodigoEvento);
            parameters.Add("p_nombre", e.Nombre);
            parameters.Add("p_fecha", e.Fecha);
            parameters.Add("p_tipo_carrera", e.TipoCarrera);
            parameters.Add("p_distancia_metros", e.DistanciaMetros);
            parameters.Add("p_premio_total", e.PremioTotal);
            parameters.Add("p_precio_inscripcion", e.PrecioInscripcion);
            parameters.Add("p_estado", e.Estado);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_evento", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarEventoAsync(EventoDTO e)
        {
            // Point 7 specifies we modify at least 3 fields. (e.g. Fecha, PremioTotal, Estado)
            var parameters = new DynamicParameters();
            parameters.Add("p_id_evento", e.IdEvento);
            parameters.Add("p_fecha", e.Fecha);
            parameters.Add("p_premio_total", e.PremioTotal);
            parameters.Add("p_estado", e.Estado);

            int rows = await _db.ExecuteAsync("sp_actualizar_evento", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> EliminarEventoAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_evento", id);
            
            int rows = await _db.ExecuteAsync("sp_eliminar_evento", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }
    }
}
