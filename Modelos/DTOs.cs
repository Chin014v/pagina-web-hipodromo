using System.ComponentModel.DataAnnotations;

namespace HipodromoNacional.Modelos
{
    public class PropietarioDTO
    {
        public int IdPropietario { get; set; }

        [Required(ErrorMessage = "La cédula es obligatoria.")]
        public string? Cedula { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }

        [Required(ErrorMessage = "El primer apellido es obligatorio.")]
        public string? Apellido1 { get; set; }

        public string? Apellido2 { get; set; }
        public int IdBarrio { get; set; }
        public bool DescuentoProximaFactura { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }
    }

    public class PropietarioUpdateDTO
    {
        public int IdPropietario { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }

        [Required(ErrorMessage = "El primer apellido es obligatorio.")]
        public string? Apellido1 { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }
    }

    public class CaballoDTO
    {
        public int IdCaballo { get; set; }

        [Required(ErrorMessage = "El código único es obligatorio.")]
        [RegularExpression(@"^[A-Z]{3}-\d{3}$", ErrorMessage = "El código del caballo debe tener el formato CAB-000 (3 letras mayúsculas, un guion y 3 números).")]
        public string? CodigoUnico { get; set; }

        [Required(ErrorMessage = "El nombre del caballo es obligatorio.")]
        public string? Nombre { get; set; }

        public DateOnly FechaNacimiento { get; set; } = DateOnly.FromDateTime(DateTime.Today);

        [Required(ErrorMessage = "Seleccione el sexo del caballo.")]
        public string? Sexo { get; set; }

        [Required(ErrorMessage = "Seleccione una raza.")]
        [Range(1, int.MaxValue, ErrorMessage = "Seleccione una raza.")]
        public int IdRaza { get; set; }

        [Required(ErrorMessage = "El peso es obligatorio.")]
        [Range(0.1, double.MaxValue, ErrorMessage = "El peso debe ser mayor a 0.")]
        public decimal PesoKg { get; set; }

        [Required(ErrorMessage = "Seleccione el estado de salud.")]
        public string? EstadoSalud { get; set; }

        [Required(ErrorMessage = "Seleccione un propietario.")]
        [Range(1, int.MaxValue, ErrorMessage = "Seleccione un propietario.")]
        public int IdPropietario { get; set; }
    }

    public class EventoDTO
    {
        public int IdEvento { get; set; }

        [Required(ErrorMessage = "El código del evento es obligatorio.")]
        [RegularExpression(@"^[A-Z]{3}-\d{3}$", ErrorMessage = "El código del evento debe tener el formato EVE-000 (3 letras mayúsculas, un guion y 3 números).")]
        public string? CodigoEvento { get; set; }

        [Required(ErrorMessage = "El nombre de la carrera es obligatorio.")]
        public string? Nombre { get; set; }

        [Required(ErrorMessage = "La fecha y hora son obligatorias.")]
        public DateTime Fecha { get; set; } = DateTime.Now;

        [Required(ErrorMessage = "El tipo de carrera es obligatorio.")]
        public string? TipoCarrera { get; set; }

        [Required(ErrorMessage = "La distancia es obligatoria.")]
        [Range(1, double.MaxValue, ErrorMessage = "La distancia debe ser mayor a 0.")]
        public decimal DistanciaMetros { get; set; }

        [Required(ErrorMessage = "El premio total es obligatorio.")]
        [Range(0.01, double.MaxValue, ErrorMessage = "El premio debe ser mayor a 0.")]
        public decimal PremioTotal { get; set; }

        [Required(ErrorMessage = "El precio de inscripción es obligatorio.")]
        [Range(0.01, double.MaxValue, ErrorMessage = "El precio debe ser mayor a 0.")]
        public decimal PrecioInscripcion { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }
    }

    public class EstabloDTO
    {
        public int IdEstablo { get; set; }

        [Required(ErrorMessage = "El código es obligatorio.")]
        public string? Codigo { get; set; }

        [Required(ErrorMessage = "La ubicación es obligatoria.")]
        public string? Ubicacion { get; set; }

        [Required(ErrorMessage = "La capacidad es obligatoria.")]
        [Range(1, int.MaxValue, ErrorMessage = "La capacidad debe ser al menos 1.")]
        public int Capacidad { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }
    }

    public class FacturaDetalleDTO
    {
        public int IdFactura { get; set; }
        public string? CodigoFactura { get; set; }
        public string? ClienteNombre { get; set; }
        public string? ClienteCedula { get; set; }
        public string? EventoNombre { get; set; }
        public string? EventoCodigo { get; set; }
        public decimal Subtotal { get; set; }
        public decimal PorcentajeDescuento { get; set; }
        public decimal MontoDescuento { get; set; }
        public decimal BaseImponible { get; set; }
        public decimal ImpuestoIva { get; set; }
        public decimal ComisionAdmin { get; set; }
        public decimal Total { get; set; }
        public string? EstadoPago { get; set; }
        public DateOnly FechaEmision { get; set; }
        public DateOnly? FechaVencimiento { get; set; }

        public string? MetodoPago { get; set; }
        public string? ReferenciaPago { get; set; }
        public string? ComprobantePago { get; set; }
        public DateTime? FechaPago { get; set; }

        public List<FacturaLineaDTO> Lineas { get; set; } = new();
    }

    public class FacturaLineaDTO
    {
        public int IdDetalle { get; set; }
        public string? Descripcion { get; set; }
        public decimal Cantidad { get; set; }
        public decimal PrecioUnitario { get; set; }
        public decimal SubtotalLinea { get; set; }
    }

    public class InscripcionDTO
    {
        public int IdInscripcion { get; set; }

        [Required(ErrorMessage = "El código de inscripción es obligatorio.")]
        public string? CodigoInscripcion { get; set; }

        [Required(ErrorMessage = "El evento es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El evento es obligatorio.")]
        public int IdEvento { get; set; }

        [Required(ErrorMessage = "El caballo es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El caballo es obligatorio.")]
        public int IdCaballo { get; set; }

        [Required(ErrorMessage = "La fecha de inscripción es obligatoria.")]
        public DateOnly FechaInscripcion { get; set; } = DateOnly.FromDateTime(DateTime.Today);

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }

        public string? Observaciones { get; set; }

        public string? NombreEvento { get; set; }
        public string? NombreCaballo { get; set; }
    }

    public class ResultadoDTO
    {
        public int IdResultado { get; set; }

        [Required(ErrorMessage = "La inscripción es obligatoria.")]
        [Range(1, int.MaxValue, ErrorMessage = "La inscripción es obligatoria.")]
        public int IdInscripcion { get; set; }

        [Required(ErrorMessage = "La posición es obligatoria.")]
        [Range(1, int.MaxValue, ErrorMessage = "La posición debe ser al menos 1.")]
        public int Posicion { get; set; }

        [Required(ErrorMessage = "El tiempo es obligatorio.")]
        public TimeOnly TiempoRegistro { get; set; }

        [Required(ErrorMessage = "El premio es obligatorio.")]
        [Range(0, double.MaxValue, ErrorMessage = "El premio no puede ser negativo.")]
        public decimal PremioObtenido { get; set; }

        public string? Observaciones { get; set; }
        public DateOnly FechaRegistro { get; set; } = DateOnly.FromDateTime(DateTime.Today);

        public string? NombreCaballo { get; set; }
        public string? NombreEvento { get; set; }
    }

    public class HistorialVeterinarioDTO
    {
        public int IdHistorial { get; set; }

        [Required(ErrorMessage = "El código de registro es obligatorio.")]
        public string? CodigoRegistro { get; set; }

        [Required(ErrorMessage = "El caballo es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El caballo es obligatorio.")]
        public int IdCaballo { get; set; }

        [Required(ErrorMessage = "El veterinario es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El veterinario es obligatorio.")]
        public int IdVeterinario { get; set; }

        [Required(ErrorMessage = "El diagnóstico es obligatorio.")]
        public string? Diagnostico { get; set; }

        public string? Tratamiento { get; set; }

        [Required(ErrorMessage = "La fecha de revisión es obligatoria.")]
        public DateOnly FechaRevision { get; set; } = DateOnly.FromDateTime(DateTime.Today);

        [Required(ErrorMessage = "La fecha de vencimiento del certificado es obligatoria.")]
        public DateOnly FechaVencimientoCertificado { get; set; }

        public bool CertificadoVigente { get; set; }
        public string? Observaciones { get; set; }

        public string? NombreCaballo { get; set; }
        public string? NombreVeterinario { get; set; }
    }

    public class AlertaCertificacionDTO
    {
        public int IdAlerta { get; set; }

        [Required(ErrorMessage = "El caballo es obligatorio.")]
        public int IdCaballo { get; set; }

        [Required(ErrorMessage = "El mensaje es obligatorio.")]
        public string? Mensaje { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }

        [Required(ErrorMessage = "La fecha de alerta es obligatoria.")]
        public DateTime FechaAlerta { get; set; }

        public string? NombreCaballo { get; set; }
    }

    public class SuministroDTO
    {
        public int IdSuministro { get; set; }

        [Required(ErrorMessage = "El código es obligatorio.")]
        public string? Codigo { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? NombreSuministro { get; set; }

        [Required(ErrorMessage = "El tipo es obligatorio.")]
        public string? Tipo { get; set; }

        [Required(ErrorMessage = "El proveedor es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El proveedor es obligatorio.")]
        public int IdProveedor { get; set; }

        [Required(ErrorMessage = "La cantidad disponible es obligatoria.")]
        [Range(0, double.MaxValue, ErrorMessage = "La cantidad no puede ser negativa.")]
        public decimal CantidadDisponible { get; set; }

        [Required(ErrorMessage = "La fecha de ingreso es obligatoria.")]
        public DateOnly FechaIngreso { get; set; } = DateOnly.FromDateTime(DateTime.Today);

        [Required(ErrorMessage = "La unidad de medida es obligatoria.")]
        public string? UnidadMedida { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }

        public string? NombreProveedor { get; set; }
    }

    public class AlimentacionDTO
    {
        public int IdAlimentacion { get; set; }

        [Required(ErrorMessage = "El caballo es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El caballo es obligatorio.")]
        public int IdCaballo { get; set; }

        [Required(ErrorMessage = "El suministro es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El suministro es obligatorio.")]
        public int IdSuministro { get; set; }

        [Required(ErrorMessage = "La fecha es obligatoria.")]
        public DateOnly Fecha { get; set; } = DateOnly.FromDateTime(DateTime.Today);

        [Required(ErrorMessage = "La cantidad es obligatoria.")]
        [Range(0, double.MaxValue, ErrorMessage = "La cantidad no puede ser negativa.")]
        public decimal Cantidad { get; set; }

        [Required(ErrorMessage = "La unidad es obligatoria.")]
        public string? Unidad { get; set; }

        public string? Observaciones { get; set; }

        public string? NombreCaballo { get; set; }
        public string? NombreSuministro { get; set; }
    }

    public class AsignacionEstabloDTO
    {
        public int IdAsignacion { get; set; }

        [Required(ErrorMessage = "El caballo es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El caballo es obligatorio.")]
        public int IdCaballo { get; set; }

        [Required(ErrorMessage = "El establo es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El establo es obligatorio.")]
        public int IdEstablo { get; set; }

        [Required(ErrorMessage = "La fecha de asignación es obligatoria.")]
        public DateOnly FechaAsignacion { get; set; } = DateOnly.FromDateTime(DateTime.Today);

        public DateOnly? FechaSalida { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }

        public string? NombreCaballo { get; set; }
        public string? CodigoEstablo { get; set; }
    }

    public class ProveedorDTO
    {
        public int IdProveedor { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }

        public string? Contacto { get; set; }
        public string? Telefono { get; set; }

        [EmailAddress(ErrorMessage = "Ingrese un correo electrónico válido.")]
        public string? Correo { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }
    }

    public class BeneficioPropietarioDTO
    {
        public int IdBeneficio { get; set; }

        [Required(ErrorMessage = "El propietario es obligatorio.")]
        [Range(1, int.MaxValue, ErrorMessage = "El propietario es obligatorio.")]
        public int IdPropietario { get; set; }

        [Required(ErrorMessage = "El tipo de beneficio es obligatorio.")]
        public string? TipoBeneficio { get; set; }

        [Required(ErrorMessage = "El descuento es obligatorio.")]
        [Range(0, 100, ErrorMessage = "El descuento debe estar entre 0 y 100.")]
        public decimal PorcentajeDescuento { get; set; }

        public DateOnly FechaAsignacion { get; set; }
        public DateOnly? FechaAplicacion { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }

        public string? NombrePropietario { get; set; }
    }

    public class AuditoriaDTO
    {
        public long IdBitacora { get; set; }
        public int IdRegistroAfectado { get; set; }
        public string? TablaAfectada { get; set; }
        public string? Accion { get; set; }
        public string? UsuarioBd { get; set; }
        public DateTime FechaRegistro { get; set; }
        public string? DatosAnteriores { get; set; }
        public string? DatosNuevos { get; set; }
    }

    public class RazaDTO
    {
        public int IdRaza { get; set; }

        [Required(ErrorMessage = "El nombre de la raza es obligatorio.")]
        public string? NombreRaza { get; set; }

        public string? Descripcion { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }
    }

    public class VeterinarioDTO
    {
        public int IdVeterinario { get; set; }

        [Required(ErrorMessage = "La cédula es obligatoria.")]
        public string? Cedula { get; set; }

        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }

        [Required(ErrorMessage = "El primer apellido es obligatorio.")]
        public string? Apellido1 { get; set; }

        public string? Apellido2 { get; set; }

        [Required(ErrorMessage = "El número de colegio es obligatorio.")]
        public string? NumeroColegio { get; set; }

        public string? Telefono { get; set; }

        [EmailAddress(ErrorMessage = "Ingrese un correo electrónico válido.")]
        public string? Correo { get; set; }

        [Required(ErrorMessage = "El estado es obligatorio.")]
        public string? Estado { get; set; }
    }

    public class RolDTO
    {
        public int IdRol { get; set; }
        public string? NombreRol { get; set; }
        public string? Descripcion { get; set; }
    }

    public class UsuarioDTO
    {
        public int IdUsuario { get; set; }

        [Required(ErrorMessage = "El nombre de usuario es obligatorio.")]
        public string? Nombre { get; set; }

        public string? Contrasena { get; set; }
        public string? ContrasenaHash { get; set; }

        [Required(ErrorMessage = "Seleccione un rol.")]
        [Range(1, int.MaxValue, ErrorMessage = "Seleccione un rol.")]
        public int IdRol { get; set; }
        public string? NombreRol { get; set; }

        public int? IdPropietario { get; set; }
        public string? NombrePropietario { get; set; }

        public int? IdVeterinario { get; set; }
        public string? NombreVeterinario { get; set; }

        public bool Activo { get; set; } = true;
        public DateTime FechaCreacion { get; set; } = DateTime.Now;
    }
}
