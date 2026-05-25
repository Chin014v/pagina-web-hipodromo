namespace HipodromoNacional.Models
{
    public class PropietarioDTO
    {
        public int IdPropietario { get; set; }
        public string Cedula { get; set; }
        public string Nombre { get; set; }
        public string Apellido1 { get; set; }
        public string Apellido2 { get; set; }
        public int IdBarrio { get; set; }
        public bool DescuentoProximaFactura { get; set; }
        public string Estado { get; set; }
    }

    public class PropietarioUpdateDTO
    {
        public int IdPropietario { get; set; }
        public string Nombre { get; set; }
        public string Apellido1 { get; set; }
        public string Estado { get; set; }
    }

    public class CaballoDTO
    {
        public int IdCaballo { get; set; }
        public string CodigoUnico { get; set; }
        public string Nombre { get; set; }
        public DateOnly FechaNacimiento { get; set; } = DateOnly.FromDateTime(DateTime.Today);
        public string Sexo { get; set; }
        public int IdRaza { get; set; }
        public decimal PesoKg { get; set; }
        public string EstadoSalud { get; set; }
        public int IdPropietario { get; set; }
    }

    public class EventoDTO
    {
        public int IdEvento { get; set; }
        public string CodigoEvento { get; set; }
        public string Nombre { get; set; }
        public DateTime Fecha { get; set; } = DateTime.Now;
        public string TipoCarrera { get; set; }
        public decimal DistanciaMetros { get; set; }
        public decimal PremioTotal { get; set; }
        public decimal PrecioInscripcion { get; set; }
        public string Estado { get; set; }
    }

    public class EstabloDTO
    {
        public int IdEstablo { get; set; }
        public string Codigo { get; set; }
        public string Ubicacion { get; set; }
        public int Capacidad { get; set; }
        public string Estado { get; set; }
    }
}
