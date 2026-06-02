using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class ProveedorRepositorio : IProveedorRepositorio
    {
        private readonly IDbConnection _db;

        public ProveedorRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<ProveedorDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<ProveedorDTO>(@"
                SELECT id_proveedor AS IdProveedor, nombre AS Nombre,
                       contacto AS Contacto, telefono AS Telefono,
                       correo AS Correo, estado AS Estado
                FROM proveedor ORDER BY id_proveedor");
        }

        public async Task<ProveedorDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<ProveedorDTO>(@"
                SELECT id_proveedor AS IdProveedor, nombre AS Nombre,
                       contacto AS Contacto, telefono AS Telefono,
                       correo AS Correo, estado AS Estado
                FROM proveedor WHERE id_proveedor = @Id", new { Id = id });
        }

        public async Task<int> CrearProveedorAsync(ProveedorDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_nombre", dto.Nombre);
            parameters.Add("p_contacto", dto.Contacto);
            parameters.Add("p_telefono", dto.Telefono);
            parameters.Add("p_correo", dto.Correo);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_proveedor", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarProveedorAsync(ProveedorDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdProveedor);
            parameters.Add("p_estado", dto.Estado);
            parameters.Add("p_telefono", dto.Telefono);
            parameters.Add("p_correo", dto.Correo);

            await _db.ExecuteAsync("sp_actualizar_proveedor", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarProveedorAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_proveedor", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
