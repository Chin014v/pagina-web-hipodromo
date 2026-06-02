using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class InscripcionRepositorio : IInscripcionRepositorio
    {
        private readonly IDbConnection _db;

        public InscripcionRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<InscripcionDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<InscripcionDTO>(@"
                SELECT i.id_inscripcion AS IdInscripcion, i.codigo_inscripcion AS CodigoInscripcion,
                       i.id_evento AS IdEvento, i.id_caballo AS IdCaballo,
                       i.fecha_inscripcion AS FechaInscripcion, i.estado AS Estado,
                       i.observaciones AS Observaciones,
                       e.nombre AS NombreEvento, c.nombre AS NombreCaballo
                FROM inscripcion i
                JOIN evento e ON i.id_evento = e.id_evento
                JOIN caballo c ON i.id_caballo = c.id_caballo
                ORDER BY i.id_inscripcion");
        }

        public async Task<InscripcionDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<InscripcionDTO>(@"
                SELECT i.id_inscripcion AS IdInscripcion, i.codigo_inscripcion AS CodigoInscripcion,
                       i.id_evento AS IdEvento, i.id_caballo AS IdCaballo,
                       i.fecha_inscripcion AS FechaInscripcion, i.estado AS Estado,
                       i.observaciones AS Observaciones,
                       e.nombre AS NombreEvento, c.nombre AS NombreCaballo
                FROM inscripcion i
                JOIN evento e ON i.id_evento = e.id_evento
                JOIN caballo c ON i.id_caballo = c.id_caballo
                WHERE i.id_inscripcion = @Id", new { Id = id });
        }

        public async Task<int> CrearInscripcionAsync(InscripcionDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_codigo", dto.CodigoInscripcion);
            parameters.Add("p_id_evento", dto.IdEvento);
            parameters.Add("p_id_caballo", dto.IdCaballo);
            parameters.Add("p_fecha", dto.FechaInscripcion.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_observaciones", dto.Observaciones);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_inscripcion", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarInscripcionAsync(InscripcionDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdInscripcion);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_observaciones", dto.Observaciones);
            parameters.Add("p_fecha", dto.FechaInscripcion.ToDateTime(TimeOnly.MinValue), DbType.Date);

            await _db.ExecuteAsync("sp_actualizar_inscripcion", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarInscripcionAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_inscripcion", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
