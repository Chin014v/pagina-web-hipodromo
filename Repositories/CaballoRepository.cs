using Dapper;
using System.Data;
using HipodromoNacional.Models;

namespace HipodromoNacional.Repositories
{
    public class CaballoRepository : ICaballoRepository
    {
        private readonly IDbConnection _db;

        public CaballoRepository(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<CaballoDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, codigo_unico AS CodigoUnico, nombre AS Nombre, fecha_nacimiento AS FechaNacimiento, sexo AS Sexo, id_raza AS IdRaza, peso_kg AS PesoKg, estado_salud AS EstadoSalud, id_propietario AS IdPropietario FROM caballo ORDER BY id_caballo");
        }

        public async Task<CaballoDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, codigo_unico AS CodigoUnico, nombre AS Nombre, fecha_nacimiento AS FechaNacimiento, sexo AS Sexo, id_raza AS IdRaza, peso_kg AS PesoKg, estado_salud AS EstadoSalud, id_propietario AS IdPropietario FROM caballo WHERE id_caballo = @Id", new { Id = id });
        }

        public async Task<int> CrearCaballoAsync(CaballoDTO c)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_codigo_unico", c.CodigoUnico);
            parameters.Add("p_nombre", c.Nombre);
            parameters.Add("p_fecha_nacimiento", c.FechaNacimiento);
            parameters.Add("p_sexo", c.Sexo);
            parameters.Add("p_id_raza", c.IdRaza);
            parameters.Add("p_peso_kg", c.PesoKg);
            parameters.Add("p_estado_salud", c.EstadoSalud);
            parameters.Add("p_id_propietario", c.IdPropietario);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_caballo", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarCaballoAsync(CaballoDTO c)
        {
            // Point 7 specifies we modify at least 3 fields. (e.g. Peso, EstadoSalud, Nombre)
            var parameters = new DynamicParameters();
            parameters.Add("p_id_caballo", c.IdCaballo);
            parameters.Add("p_nombre", c.Nombre);
            parameters.Add("p_peso_kg", c.PesoKg);
            parameters.Add("p_estado_salud", c.EstadoSalud);

            int rows = await _db.ExecuteAsync("sp_actualizar_caballo", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }

        public async Task<bool> EliminarCaballoAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id_caballo", id);
            
            int rows = await _db.ExecuteAsync("sp_eliminar_caballo", parameters, commandType: CommandType.StoredProcedure);
            return rows > 0;
        }
    }
}
