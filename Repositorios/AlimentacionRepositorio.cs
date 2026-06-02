using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class AlimentacionRepositorio : IAlimentacionRepositorio
    {
        private readonly IDbConnection _db;

        public AlimentacionRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<AlimentacionDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<AlimentacionDTO>(@"
                SELECT a.id_alimentacion AS IdAlimentacion, a.id_caballo AS IdCaballo,
                       a.id_suministro AS IdSuministro, a.fecha AS Fecha,
                       a.cantidad AS Cantidad, a.unidad AS Unidad,
                       a.observaciones AS Observaciones,
                       c.nombre AS NombreCaballo, s.nombre_suministro AS NombreSuministro
                FROM alimentacion a
                JOIN caballo c ON a.id_caballo = c.id_caballo
                JOIN suministro s ON a.id_suministro = s.id_suministro
                ORDER BY a.id_alimentacion");
        }

        public async Task<AlimentacionDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<AlimentacionDTO>(@"
                SELECT a.id_alimentacion AS IdAlimentacion, a.id_caballo AS IdCaballo,
                       a.id_suministro AS IdSuministro, a.fecha AS Fecha,
                       a.cantidad AS Cantidad, a.unidad AS Unidad,
                       a.observaciones AS Observaciones,
                       c.nombre AS NombreCaballo, s.nombre_suministro AS NombreSuministro
                FROM alimentacion a
                JOIN caballo c ON a.id_caballo = c.id_caballo
                JOIN suministro s ON a.id_suministro = s.id_suministro
                WHERE a.id_alimentacion = @Id", new { Id = id });
        }

        public async Task<int> CrearAlimentacionAsync(AlimentacionDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_caballo", dto.IdCaballo);
            parameters.Add("p_id_suministro", dto.IdSuministro);
            parameters.Add("p_fecha", dto.Fecha.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_cantidad", dto.Cantidad);
            parameters.Add("p_unidad", dto.Unidad);
            parameters.Add("p_observaciones", dto.Observaciones);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_alimentacion", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarAlimentacionAsync(AlimentacionDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdAlimentacion);
            parameters.Add("p_cantidad", dto.Cantidad);
            parameters.Add("p_observaciones", dto.Observaciones);
            parameters.Add("p_fecha", dto.Fecha.ToDateTime(TimeOnly.MinValue), DbType.Date);

            await _db.ExecuteAsync("sp_actualizar_alimentacion", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarAlimentacionAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_alimentacion", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
