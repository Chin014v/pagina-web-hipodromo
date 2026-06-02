using Dapper;
using System.Data;
using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public class VeterinarioRepositorio : IVeterinarioRepositorio
    {
        private readonly IDbConnection _db;

        public VeterinarioRepositorio(IDbConnection db)
        {
            _db = db;
        }

        public async Task<IEnumerable<HistorialVeterinarioDTO>> ObtenerTodosAsync()
        {
            return await _db.QueryAsync<HistorialVeterinarioDTO>(@"
                SELECT h.id_historial AS IdHistorial, h.codigo_registro AS CodigoRegistro,
                       h.id_caballo AS IdCaballo, h.id_veterinario AS IdVeterinario,
                       h.diagnostico AS Diagnostico, h.tratamiento AS Tratamiento,
                       h.fecha_revision AS FechaRevision,
                       h.fecha_vencimiento_certificado AS FechaVencimientoCertificado,
                       h.certificado_vigente AS CertificadoVigente, h.observaciones AS Observaciones,
                       c.nombre AS NombreCaballo,
                       v.nombre || ' ' || v.apellido1 AS NombreVeterinario
                FROM historial_veterinario h
                JOIN caballo c ON h.id_caballo = c.id_caballo
                JOIN veterinario v ON h.id_veterinario = v.id_veterinario
                ORDER BY h.id_historial");
        }

        public async Task<HistorialVeterinarioDTO> ObtenerPorIdAsync(int id)
        {
            return await _db.QueryFirstOrDefaultAsync<HistorialVeterinarioDTO>(@"
                SELECT h.id_historial AS IdHistorial, h.codigo_registro AS CodigoRegistro,
                       h.id_caballo AS IdCaballo, h.id_veterinario AS IdVeterinario,
                       h.diagnostico AS Diagnostico, h.tratamiento AS Tratamiento,
                       h.fecha_revision AS FechaRevision,
                       h.fecha_vencimiento_certificado AS FechaVencimientoCertificado,
                       h.certificado_vigente AS CertificadoVigente, h.observaciones AS Observaciones,
                       c.nombre AS NombreCaballo,
                       v.nombre || ' ' || v.apellido1 AS NombreVeterinario
                FROM historial_veterinario h
                JOIN caballo c ON h.id_caballo = c.id_caballo
                JOIN veterinario v ON h.id_veterinario = v.id_veterinario
                WHERE h.id_historial = @Id", new { Id = id });
        }

        public async Task<int> CrearHistorialAsync(HistorialVeterinarioDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_codigo", dto.CodigoRegistro);
            parameters.Add("p_id_caballo", dto.IdCaballo);
            parameters.Add("p_id_veterinario", dto.IdVeterinario);
            parameters.Add("p_diagnostico", dto.Diagnostico);
            parameters.Add("p_tratamiento", dto.Tratamiento);
            parameters.Add("p_fecha_revision", dto.FechaRevision.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_fecha_vencimiento", dto.FechaVencimientoCertificado.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_observaciones", dto.Observaciones);
            parameters.Add("p_new_id", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await _db.ExecuteAsync("sp_insertar_historial_veterinario", parameters, commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("p_new_id");
        }

        public async Task<bool> ActualizarHistorialAsync(HistorialVeterinarioDTO dto)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", dto.IdHistorial);
            parameters.Add("p_certificado_vigente", dto.CertificadoVigente);
            parameters.Add("p_fecha_vencimiento", dto.FechaVencimientoCertificado.ToDateTime(TimeOnly.MinValue), DbType.Date);
            parameters.Add("p_observaciones", dto.Observaciones);

            await _db.ExecuteAsync("sp_actualizar_historial_veterinario", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }

        public async Task<bool> EliminarHistorialAsync(int id)
        {
            var parameters = new DynamicParameters();
            parameters.Add("p_id", id);

            await _db.ExecuteAsync("sp_eliminar_historial_veterinario", parameters, commandType: CommandType.StoredProcedure);
            return true;
        }
    }
}
