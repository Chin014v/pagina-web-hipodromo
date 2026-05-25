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
}
