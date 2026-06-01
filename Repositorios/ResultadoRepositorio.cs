using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class ResultadoRepositorio : IResultadoRepositorio
    {
        private readonly IDbConnection _db;

        public ResultadoRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<ResultadoDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<ResultadoDTO>(@"
                SELECT r.id_resultado AS IdResultado, r.id_inscripcion AS IdInscripcion,
                       r.posicion AS Posicion, r.tiempo_registro AS TiempoRegistro,
                       r.premio_obtenido AS PremioObtenido, r.observaciones AS Observaciones,
                       r.fecha_registro AS FechaRegistro,
                       c.nombre AS NombreCaballo, e.nombre AS NombreEvento
                FROM resultado_carrera r
                JOIN inscripcion i ON r.id_inscripcion = i.id_inscripcion
                JOIN caballo c ON i.id_caballo = c.id_caballo
                JOIN evento e ON i.id_evento = e.id_evento
                ORDER BY r.id_resultado");
        }

        public async Task<ResultadoDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<ResultadoDTO>(@"
                SELECT r.id_resultado AS IdResultado, r.id_inscripcion AS IdInscripcion,
                       r.posicion AS Posicion, r.tiempo_registro AS TiempoRegistro,
                       r.premio_obtenido AS PremioObtenido, r.observaciones AS Observaciones,
                       r.fecha_registro AS FechaRegistro,
                       c.nombre AS NombreCaballo, e.nombre AS NombreEvento
                FROM resultado_carrera r
                JOIN inscripcion i ON r.id_inscripcion = i.id_inscripcion
                JOIN caballo c ON i.id_caballo = c.id_caballo
                JOIN evento e ON i.id_evento = e.id_evento
                WHERE r.id_resultado = @Id", new { Id = id });
        }

        public async Task<int> CrearResultadoAsync(ResultadoDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_inscripcion", dto.IdInscripcion);
            parameters.Add("p_posicion", dto.Posicion);
            parameters.Add("p_tiempo", dto.TiempoRegistro);
            parameters.Add("p_premio", dto.PremioObtenido);
            parameters.Add("p_observaciones", dto.Observaciones);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_resultado_carrera", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarResultadoAsync(ResultadoDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdResultado);
            parameters.Add("p_posicion", dto.Posicion);
            parameters.Add("p_premio_obtenido", dto.PremioObtenido);
            parameters.Add("p_observaciones", dto.Observaciones);

            int rows = await _db.ExecuteAsync("sp_actualizar_resultado_carrera", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> EliminarResultadoAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            int rows = await _db.ExecuteAsync("sp_eliminar_resultado_carrera", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> CalcularPremiosEventoAsync(int idEvento)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_evento", idEvento);

            await _db.ExecuteAsync("sp_calcular_premios_evento", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
