using System.Data;
using Dapper;

namespace HipodromoNacional.Repositorios
{
    public static class DbInitializer
    {
        public static void Initialize(IDbConnection db, string contentRootPath)
        {
            try
            {
                Console.WriteLine("=== Iniciando Migración e Inicialización de Base de Datos ===");
                
                // Ruta del script en la carpeta raíz del proyecto (un nivel arriba del proyecto C#)
                string rootDir = Path.GetFullPath(Path.Combine(contentRootPath, ".."));
                string scriptPath = Path.Combine(rootDir, "09_datos_adicionales_y_correcciones.sql");

                if (!File.Exists(scriptPath))
                {
                    // Intentamos en la misma carpeta del ejecutable por si acaso
                    scriptPath = Path.Combine(contentRootPath, "09_datos_adicionales_y_correcciones.sql");
                }

                if (File.Exists(scriptPath))
                {
                    Console.WriteLine($"Leyendo script de inicialización desde: {scriptPath}");
                    string sql = File.ReadAllText(scriptPath);
                    
                    // Ejecutar el script SQL completo
                    db.Open();
                    db.Execute(sql);
                    Console.WriteLine("Script ejecutado exitosamente en Render Postgres.");
                }
                else
                {
                    Console.WriteLine($"ADVERTENCIA: No se encontró el script SQL en: {scriptPath}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ERROR en la inicialización de base de datos: {ex.Message}");
            }
            finally
            {
                if (db.State == ConnectionState.Open)
                {
                    db.Close();
                }
                Console.WriteLine("=== Proceso de Inicialización Finalizado ===");
            }
        }
    }
}
