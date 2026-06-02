using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class RazaRepositorio : IRazaRepositorio
    {
        private readonly IDbConnection _db;

        public RazaRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<RazaDTO>> ObtenerTodasAsync()
        {
            return await _db.QueryAsync<RazaDTO>(
                "SELECT id_raza AS IdRaza, nombre_raza AS NombreRaza, descripcion AS Descripcion, estado AS Estado FROM raza ORDER BY nombre_raza"
            );
        }

        public async Task<RazaDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<RazaDTO>(
                "SELECT id_raza AS IdRaza, nombre_raza AS NombreRaza, descripcion AS Descripcion, estado AS Estado FROM raza WHERE id_raza = @Id",
                new { Id = id }
            );
        }

        public async Task<bool> CrearRazaAsync(RazaDTO r)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_nombre", r.NombreRaza);
            parameters.Add("p_descripcion", r.Descripcion);
            parameters.Add("p_estado", r.Estado ?? "Activo");

            await _db.ExecuteAsync("sp_insertar_raza", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> ActualizarRazaAsync(RazaDTO r)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", r.IdRaza);
            parameters.Add("p_nombre", r.NombreRaza);
            parameters.Add("p_descripcion", r.Descripcion);
            parameters.Add("p_estado", r.Estado);

            await _db.ExecuteAsync("sp_actualizar_raza", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarRazaAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_raza", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
