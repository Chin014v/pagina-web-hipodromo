using Dapper;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class UsuarioRepositorio : IUsuarioRepositorio
    {
        private readonly IDbConnection _db;

        public UsuarioRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<UsuarioDTO>> ObtenerTodosAsync()
        {
            const string sql = @"
                SELECT 
                    u.id_usuario AS IdUsuario, 
                    u.nombre AS Nombre, 
                    u.id_rol AS IdRol, 
                    r.nombre_rol AS NombreRol, 
                    u.id_propietario AS IdPropietario, 
                    p.nombre AS NombrePropietario, 
                    u.id_veterinario AS IdVeterinario, 
                    v.nombre AS NombreVeterinario, 
                    u.activo AS Activo, 
                    u.fecha_creacion AS FechaCreacion
                FROM usuario u
                JOIN rol r ON u.id_rol = r.id_rol
                LEFT JOIN propietario p ON u.id_propietario = p.id_propietario
                LEFT JOIN veterinario v ON u.id_veterinario = v.id_veterinario
                ORDER BY u.nombre";

            return await _db.QueryAsync<UsuarioDTO>(sql);
        }

        public async Task<UsuarioDTO> ObtenerPorIdAsync(int id)
        {
            const string sql = @"
                SELECT 
                    u.id_usuario AS IdUsuario, 
                    u.nombre AS Nombre, 
                    u.id_rol AS IdRol, 
                    r.nombre_rol AS NombreRol, 
                    u.id_propietario AS IdPropietario, 
                    p.nombre AS NombrePropietario, 
                    u.id_veterinario AS IdVeterinario, 
                    v.nombre AS NombreVeterinario, 
                    u.activo AS Activo, 
                    u.fecha_creacion AS FechaCreacion
                FROM usuario u
                JOIN rol r ON u.id_rol = r.id_rol
                LEFT JOIN propietario p ON u.id_propietario = p.id_propietario
                LEFT JOIN veterinario v ON u.id_veterinario = v.id_veterinario
                WHERE u.id_usuario = @Id";

            return await _db.QueryFirstOrDefaultAsync<UsuarioDTO>(sql, new { Id = id });
        }

        public async Task<bool> CrearUsuarioAsync(UsuarioDTO u)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_nombre", u.Nombre);
            parameters.Add("p_contrasena_hash", ObtenerHashSHA256(u.Contrasena ?? ""));
            parameters.Add("p_id_rol", u.IdRol);
            parameters.Add("p_id_propietario", u.IdPropietario);
            parameters.Add("p_id_veterinario", u.IdVeterinario);

            await _db.ExecuteAsync("sp_insertar_usuario", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> ActualizarUsuarioAsync(UsuarioDTO u)
        {
            // Si la contraseña viene vacía, conservamos el hash anterior
            string passHash;
            if (string.IsNullOrEmpty(u.Contrasena))
            {
                var existing = await ObtenerPorIdAsync(u.IdUsuario);
                if (existing == null) return false;
                // Leemos el hash existente directo de la BD
                passHash = await _db.QueryFirstOrDefaultAsync<string>("SELECT contrasena_hash FROM usuario WHERE id_usuario = @Id", new { Id = u.IdUsuario });
            }
            else
            {
                passHash = ObtenerHashSHA256(u.Contrasena);
            }

            var parameters = new DynamicParameters();
            parameters.Add("p_id", u.IdUsuario);
            parameters.Add("p_activo", u.Activo);
            parameters.Add("p_contrasena_hash", passHash);
            parameters.Add("p_id_rol", u.IdRol);

            await _db.ExecuteAsync("sp_actualizar_usuario", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarUsuarioAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_usuario", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<UsuarioDTO?> ValidarUsuarioAsync(string username, string password)
        {
            string hash = ObtenerHashSHA256(password);
            const string sql = @"
                SELECT 
                    u.id_usuario AS IdUsuario, 
                    u.nombre AS Nombre, 
                    u.id_rol AS IdRol, 
                    r.nombre_rol AS NombreRol, 
                    u.id_propietario AS IdPropietario, 
                    u.id_veterinario AS IdVeterinario, 
                    u.activo AS Activo
                FROM usuario u
                JOIN rol r ON u.id_rol = r.id_rol
                WHERE LOWER(u.nombre) = LOWER(CAST(@Username AS VARCHAR)) AND u.contrasena_hash = @Hash AND u.activo = TRUE";

            return await _db.QueryFirstOrDefaultAsync<UsuarioDTO>(sql, new { Username = username, Hash = hash });
        }

        public async Task<IEnumerable<RolDTO>> ObtenerRolesAsync()
        {
            return await _db.QueryAsync<RolDTO>("SELECT id_rol AS IdRol, nombre_rol AS NombreRol, descripcion AS Descripcion FROM rol ORDER BY id_rol");
        }

        private string ObtenerHashSHA256(string input)
        {
            using var sha256 = SHA256.Create();
            byte[] bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(input));
            var sb = new StringBuilder();
            foreach (byte b in bytes)
            {
                sb.Append(b.ToString("x2"));
            }
            return sb.ToString();
        }
    }
}
