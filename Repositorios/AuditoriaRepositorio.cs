using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class AuditoriaRepositorio : IAuditoriaRepositorio
    {
        private readonly IDbConnection _db;

        public AuditoriaRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<string>> ObtenerTablasConBitacoraAsync()
        {
            return await _db.QueryAsync<string>(@"
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = 'public'
                  AND table_name LIKE 'bitacora_%'
                  AND table_name NOT LIKE '%_2026_t%'
                  AND table_name NOT LIKE '%_otros'
                  AND table_name NOT LIKE 'bitacora_%_pkey'
                ORDER BY table_name");
        }

        public async Task<IEnumerable<AuditoriaDTO>> ObtenerPorTablaAsync(string nombreTabla)
        {
            var sql = $@"
                SELECT id_bitacora AS IdBitacora, id_registro_afectado AS IdRegistroAfectado,
                       tabla_afectada AS TablaAfectada, accion AS Accion,
                       usuario_bd AS UsuarioBd, fecha_registro AS FechaRegistro,
                       datos_anteriores::text AS DatosAnteriores,
                       datos_nuevos::text AS DatosNuevos
                FROM {nombreTabla}
                ORDER BY id_bitacora DESC
                LIMIT 200";

            return await _db.QueryAsync<AuditoriaDTO>(sql);
        }
    }
}
