using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class SuministroRepositorio : ISuministroRepositorio
    {
        private readonly IDbConnection _db;

        public SuministroRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<SuministroDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<SuministroDTO>(@"
                SELECT s.id_suministro AS IdSuministro, s.codigo AS Codigo,
                       s.nombre_suministro AS NombreSuministro, s.tipo AS Tipo,
                       s.id_proveedor AS IdProveedor, s.cantidad_disponible AS CantidadDisponible,
                       s.fecha_ingreso AS FechaIngreso, s.unidad_medida AS UnidadMedida,
                       s.estado AS Estado, p.nombre AS NombreProveedor
                FROM suministro s
                JOIN proveedor p ON s.id_proveedor = p.id_proveedor
                ORDER BY s.id_suministro");
        }

        public async Task<SuministroDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<SuministroDTO>(@"
                SELECT s.id_suministro AS IdSuministro, s.codigo AS Codigo,
                       s.nombre_suministro AS NombreSuministro, s.tipo AS Tipo,
                       s.id_proveedor AS IdProveedor, s.cantidad_disponible AS CantidadDisponible,
                       s.fecha_ingreso AS FechaIngreso, s.unidad_medida AS UnidadMedida,
                       s.estado AS Estado, p.nombre AS NombreProveedor
                FROM suministro s
                JOIN proveedor p ON s.id_proveedor = p.id_proveedor
                WHERE s.id_suministro = @Id", new { Id = id });
        }

        public async Task<int> CrearSuministroAsync(SuministroDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_codigo", dto.Codigo);
            parameters.Add("p_nombre", dto.NombreSuministro);
            parameters.Add("p_tipo", dto.Tipo);
            parameters.Add("p_id_proveedor", dto.IdProveedor);
            parameters.Add("p_cantidad", dto.CantidadDisponible);
            parameters.Add("p_fecha_ingreso", dto.FechaIngreso.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_unidad", dto.UnidadMedida);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_suministro", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarSuministroAsync(SuministroDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdSuministro);
            parameters.Add("p_cantidad", dto.CantidadDisponible);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_fecha_ingreso", dto.FechaIngreso.ToDateTime(TimeOnly.MinValue), DbType.Date);

            int rows = await _db.ExecuteAsync("sp_actualizar_suministro", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> EliminarSuministroAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            int rows = await _db.ExecuteAsync("sp_eliminar_suministro", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }
    }
}
