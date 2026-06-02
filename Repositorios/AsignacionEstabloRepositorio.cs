using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class AsignacionEstabloRepositorio : IAsignacionEstabloRepositorio
    {
        private readonly IDbConnection _db;

        public AsignacionEstabloRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<AsignacionEstabloDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<AsignacionEstabloDTO>(@"
                SELECT a.id_asignacion AS IdAsignacion, a.id_caballo AS IdCaballo,
                       a.id_establo AS IdEstablo, a.fecha_asignacion AS FechaAsignacion,
                       a.fecha_salida AS FechaSalida, a.estado AS Estado,
                       c.nombre AS NombreCaballo, e.codigo AS CodigoEstablo
                FROM asignacion_establo a
                JOIN caballo c ON a.id_caballo = c.id_caballo
                JOIN establo e ON a.id_establo = e.id_establo
                ORDER BY a.id_asignacion");
        }

        public async Task<AsignacionEstabloDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<AsignacionEstabloDTO>(@"
                SELECT a.id_asignacion AS IdAsignacion, a.id_caballo AS IdCaballo,
                       a.id_establo AS IdEstablo, a.fecha_asignacion AS FechaAsignacion,
                       a.fecha_salida AS FechaSalida, a.estado AS Estado,
                       c.nombre AS NombreCaballo, e.codigo AS CodigoEstablo
                FROM asignacion_establo a
                JOIN caballo c ON a.id_caballo = c.id_caballo
                JOIN establo e ON a.id_establo = e.id_establo
                WHERE a.id_asignacion = @Id", new { Id = id });
        }

        public async Task<int> CrearAsignacionAsync(AsignacionEstabloDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_caballo", dto.IdCaballo);
            parameters.Add("p_id_establo", dto.IdEstablo);
            parameters.Add("p_fecha_asignacion", dto.FechaAsignacion.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_asignacion_establo", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarAsignacionAsync(AsignacionEstabloDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdAsignacion);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_fecha_salida", dto.FechaSalida?.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_id_establo", dto.IdEstablo);

            await _db.ExecuteAsync("sp_actualizar_asignacion_establo", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarAsignacionAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_asignacion_establo", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
