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
                
                if (db.State != ConnectionState.Open)
                {
                    db.Open();
                }

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
                    db.Execute(sql);
                    Console.WriteLine("Script de correcciones ejecutado exitosamente en Render Postgres.");
                }
                else
                {
                    Console.WriteLine($"ADVERTENCIA: No se encontró el script SQL en: {scriptPath}");
                }

                // Ejecución automática de las vistas (Punto 2.8)
                string viewsScriptPath = Path.Combine(rootDir, "10_crear_vistas.sql");
                if (!File.Exists(viewsScriptPath))
                {
                    viewsScriptPath = Path.Combine(contentRootPath, "10_crear_vistas.sql");
                }

                if (File.Exists(viewsScriptPath))
                {
                    Console.WriteLine($"Leyendo script de vistas desde: {viewsScriptPath}");
                    string viewsSql = File.ReadAllText(viewsScriptPath);
                    db.Execute(viewsSql);
                    Console.WriteLine("Script de vistas ejecutado exitosamente en Render Postgres.");
                }
                else
                {
                    Console.WriteLine($"ADVERTENCIA: No se encontró el script de vistas en: {viewsScriptPath}");
                }

                // Comprobar división territorial de Costa Rica
                int countBarrios = 0;
                try
                {
                    countBarrios = db.ExecuteScalar<int>("SELECT COUNT(*) FROM public.barrio;");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"No se pudo consultar la tabla barrio: {ex.Message}");
                }

                if (countBarrios < 100)
                {
                    string geoScriptPath = Path.Combine(rootDir, "01.5_geografia_costa_rica.sql");
                    if (!File.Exists(geoScriptPath))
                    {
                        geoScriptPath = Path.Combine(contentRootPath, "01.5_geografia_costa_rica.sql");
                    }

                    if (File.Exists(geoScriptPath))
                    {
                        Console.WriteLine("Limpiando datos de geografía antiguos...");
                        db.Execute(@"
                            ALTER TABLE public.propietario DROP CONSTRAINT IF EXISTS fk_propietario_barrio;
                            TRUNCATE TABLE public.barrio CASCADE;
                            TRUNCATE TABLE public.distrito CASCADE;
                            TRUNCATE TABLE public.canton CASCADE;
                            TRUNCATE TABLE public.provincia CASCADE;
                            TRUNCATE TABLE public.pais CASCADE;
                        ");

                        Console.WriteLine($"Cargando división territorial de Costa Rica desde: {geoScriptPath}...");
                        string geoSql = File.ReadAllText(geoScriptPath);
                        
                        // Usar un timeout extendido (5 minutos) para evitar que falle en bases de datos remotas
                        db.Execute(geoSql, commandTimeout: 300);
                        Console.WriteLine("División territorial de Costa Rica cargada exitosamente.");

                        Console.WriteLine("Actualizando propietarios y restableciendo clave foránea...");
                        db.Execute(@"
                            UPDATE public.propietario
                            SET id_pais = 1,
                                id_provincia = 1,
                                id_canton = 101,
                                id_distrito = 10101,
                                id_barrio = 1010101;

                            ALTER TABLE public.propietario DROP CONSTRAINT IF EXISTS fk_propietario_barrio;
                            ALTER TABLE public.propietario
                                ADD CONSTRAINT fk_propietario_barrio 
                                FOREIGN KEY (id_pais, id_provincia, id_canton, id_distrito, id_barrio) 
                                REFERENCES public.barrio(id_pais, id_provincia, id_canton, id_distrito, id_barrio);
                        ");
                    }
                    else
                    {
                        Console.WriteLine($"ADVERTENCIA: No se encontró el script de geografía en: {geoScriptPath}");
                    }
                }
                else
                {
                    Console.WriteLine($"La división territorial de Costa Rica ya se encuentra cargada ({countBarrios} barrios detectados).");
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
