using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class PropietarioRepositorio : IPropietarioRepositorio
    {
        private readonly IDbConnection _db;

        public PropietarioRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<PropietarioDTO>> ObtenerTodosAsync()
        {
            // La lectura puede hacerse directa o con funciones/SPs. Usaremos SQL directo por simplicidad en la lectura.
            return await _db.QueryAsync<PropietarioDTO>("SELECT id_propietario AS IdPropietario, cedula AS Cedula, nombre AS Nombre, apellido1 AS Apellido1, apellido2 AS Apellido2, estado AS Estado FROM propietario ORDER BY id_propietario");
        }

        public async Task<PropietarioDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<PropietarioDTO>("SELECT id_propietario AS IdPropietario, cedula AS Cedula, nombre AS Nombre, apellido1 AS Apellido1, apellido2 AS Apellido2, estado AS Estado FROM propietario WHERE id_propietario = @Id", new { Id = id });
        }

        public async Task<int> CrearPropietarioAsync(PropietarioDTO p, string[] telefonos, string[] tiposTelefonos, string[] correos, string[] tiposCorreos)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_cedula", p.Cedula);
            parameters.Add("p_nombre", p.Nombre);
            parameters.Add("p_apellido1", p.Apellido1);
            parameters.Add("p_apellido2", p.Apellido2);
            parameters.Add("p_id_barrio", p.IdBarrio);
            parameters.Add("p_estado", "Activo");
            
            parameters.Add("p_telefonos", telefonos);
            parameters.Add("p_tipos_telefonos", tiposTelefonos);
            parameters.Add("p_correos", correos);
            parameters.Add("p_tipos_correos", tiposCorreos);
            
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_propietario", parameters, commandType: CommandType.StoredProcedure);

            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarPropietarioAsync(PropietarioUpdateDTO p)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_propietario", p.IdPropietario);
            parameters.Add("p_nombre", p.Nombre);
            parameters.Add("p_apellido1", p.Apellido1);
            parameters.Add("p_estado", p.Estado);

            int rows = await _db.ExecuteAsync("sp_actualizar_propietario", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> EliminarPropietarioAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_propietario", id);
            
            int rows = await _db.ExecuteAsync("sp_eliminar_propietario", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }
    }
}
