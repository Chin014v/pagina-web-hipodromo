using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class BeneficioRepositorio : IBeneficioRepositorio
    {
        private readonly IDbConnection _db;

        public BeneficioRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<BeneficioPropietarioDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<BeneficioPropietarioDTO>(@"
                SELECT b.id_beneficio AS IdBeneficio, b.id_propietario AS IdPropietario,
                       b.tipo_beneficio AS TipoBeneficio,
                       b.porcentaje_descuento AS PorcentajeDescuento,
                       b.fecha_asignacion AS FechaAsignacion,
                       b.fecha_aplicacion AS FechaAplicacion, b.estado AS Estado,
                       p.nombre || ' ' || p.apellido1 AS NombrePropietario
                FROM beneficio_propietario b
                JOIN propietario p ON b.id_propietario = p.id_propietario
                ORDER BY b.id_beneficio");
        }

        public async Task<BeneficioPropietarioDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<BeneficioPropietarioDTO>(@"
                SELECT b.id_beneficio AS IdBeneficio, b.id_propietario AS IdPropietario,
                       b.tipo_beneficio AS TipoBeneficio,
                       b.porcentaje_descuento AS PorcentajeDescuento,
                       b.fecha_asignacion AS FechaAsignacion,
                       b.fecha_aplicacion AS FechaAplicacion, b.estado AS Estado,
                       p.nombre || ' ' || p.apellido1 AS NombrePropietario
                FROM beneficio_propietario b
                JOIN propietario p ON b.id_propietario = p.id_propietario
                WHERE b.id_beneficio = @Id", new { Id = id });
        }

        public async Task<int> CrearBeneficioAsync(BeneficioPropietarioDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_propietario", dto.IdPropietario);
            parameters.Add("p_tipo", dto.TipoBeneficio);
            parameters.Add("p_porcentaje", dto.PorcentajeDescuento);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_beneficio_propietario", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarBeneficioAsync(BeneficioPropietarioDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdBeneficio);
            parameters.Add("p_porcentaje", dto.PorcentajeDescuento);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_fecha_aplicacion", dto.FechaAplicacion?.ToDateTime(TimeOnly.MinValue), DbType.Date);

            int rows = await _db.ExecuteAsync("sp_actualizar_beneficio_propietario", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> EliminarBeneficioAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            int rows = await _db.ExecuteAsync("sp_eliminar_beneficio_propietario", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }
    }
}
