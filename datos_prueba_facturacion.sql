-- DATOS DE PRUEBA PARA FACTURACIÓN
-- 1. Crear un evento de prueba si no existe
INSERT INTO evento (codigo_evento, nombre, descripcion, tipo_carrera, distancia_metros, fecha, hora, premio_total, precio_inscripcion, estado)
SELECT 'EVT-TEST-001', 'Carrera de Prueba', 'Evento generado para pruebas de facturación', 'Plana', 1200, CURRENT_DATE + INTERVAL '7 days', '14:00:00'::time, 500000.00, 25000.00, 'Programado'
WHERE NOT EXISTS (SELECT 1 FROM evento WHERE codigo_evento = 'EVT-TEST-001');

-- 2. Crear un propietario de prueba si no existe
INSERT INTO propietario (cedula, nombre, apellido1, apellido2, id_pais, id_provincia, id_canton, id_distrito, id_barrio, direccion_exacta, estado)
SELECT '1-2345-6789', 'Juan', 'Prueba', 'Facturacion', 1, 1, 1, 1, 1, 'Direccion de prueba', 'Activo'
WHERE NOT EXISTS (SELECT 1 FROM propietario WHERE cedula = '1-2345-6789');

-- 3. Crear una raza si no existe
INSERT INTO raza (nombre_raza, descripcion, estado)
SELECT 'Pura Sangre', 'Raza de prueba', 'Activo'
WHERE NOT EXISTS (SELECT 1 FROM raza WHERE nombre_raza = 'Pura Sangre');

-- 4. Crear un caballo de prueba
INSERT INTO caballo (codigo_unico, nombre, fecha_nacimiento, sexo, id_raza, peso_kg, estado_salud, id_propietario)
SELECT 'CAB-TEST-001', 'Caballo de Prueba', '2020-01-15', 'Macho', (SELECT id_raza FROM raza WHERE nombre_raza = 'Pura Sangre' LIMIT 1), 450.00, 'Saludable', (SELECT id_propietario FROM propietario WHERE cedula = '1-2345-6789' LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM caballo WHERE codigo_unico = 'CAB-TEST-001');

-- 5. Inscribir el caballo en el evento (APROBADA directamente para poder facturar)
INSERT INTO inscripcion (codigo_inscripcion, id_evento, id_caballo, fecha_inscripcion, estado, observaciones)
SELECT 'INS-TEST-001', (SELECT id_evento FROM evento WHERE codigo_evento = 'EVT-TEST-001' LIMIT 1), (SELECT id_caballo FROM caballo WHERE codigo_unico = 'CAB-TEST-001' LIMIT 1), CURRENT_DATE, 'Aprobada', 'Inscripcion de prueba para facturacion'
WHERE NOT EXISTS (SELECT 1 FROM inscripcion WHERE codigo_inscripcion = 'INS-TEST-001');
