-- ============================================================
-- FIX COMPLETO: Todos los SPs para que coincidan con C#
-- ============================================================

-- ==================== EVENTO ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_evento(character varying, character varying, timestamp without time zone, character varying, numeric, numeric, numeric, character varying);
DROP PROCEDURE IF EXISTS public.sp_actualizar_evento(integer, character varying, numeric, timestamp without time zone);
DROP PROCEDURE IF EXISTS public.sp_eliminar_evento(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_evento(
    IN p_codigo_evento character varying, IN p_nombre character varying,
    IN p_fecha timestamp without time zone, IN p_tipo_carrera character varying,
    IN p_distancia_metros numeric, IN p_premio_total numeric,
    IN p_precio_inscripcion numeric, IN p_estado character varying,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO evento (codigo_evento, nombre, fecha, tipo_carrera, distancia_metros, premio_total, precio_inscripcion, estado)
    VALUES (p_codigo_evento, p_nombre, p_fecha, p_tipo_carrera, p_distancia_metros, p_premio_total, p_precio_inscripcion, p_estado)
    RETURNING id_evento INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_evento(
    IN p_id_evento integer, IN p_fecha timestamp without time zone,
    IN p_premio_total numeric, IN p_estado character varying)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE evento SET fecha = p_fecha, premio_total = p_premio_total, estado = p_estado
    WHERE id_evento = p_id_evento;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_evento(IN p_id_evento integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM resultado_carrera WHERE id_inscripcion IN (SELECT id_inscripcion FROM inscripcion WHERE id_evento = p_id_evento);
    DELETE FROM inscripcion WHERE id_evento = p_id_evento;
    DELETE FROM detalle_factura WHERE id_factura IN (SELECT id_factura FROM factura WHERE id_evento = p_id_evento);
    DELETE FROM historial_transaccion WHERE id_factura IN (SELECT id_factura FROM factura WHERE id_evento = p_id_evento);
    DELETE FROM factura WHERE id_evento = p_id_evento;
    DELETE FROM evento WHERE id_evento = p_id_evento;
END;
$$;

-- ==================== ESTABLO ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_establo(character varying, character varying, integer, character varying);
DROP PROCEDURE IF EXISTS public.sp_actualizar_establo(integer, character varying, integer, character varying);
DROP PROCEDURE IF EXISTS public.sp_eliminar_establo(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_establo(
    IN p_codigo character varying, IN p_ubicacion character varying,
    IN p_capacidad integer, IN p_estado character varying,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO establo (codigo, ubicacion, capacidad, estado)
    VALUES (p_codigo, p_ubicacion, p_capacidad, p_estado)
    RETURNING id_establo INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_establo(
    IN p_id_establo integer, IN p_ubicacion character varying,
    IN p_capacidad integer, IN p_estado character varying)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE establo SET ubicacion = p_ubicacion, capacidad = p_capacidad, estado = p_estado
    WHERE id_establo = p_id_establo;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_establo(IN p_id_establo integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM asignacion_establo WHERE id_establo = p_id_establo;
    DELETE FROM establo WHERE id_establo = p_id_establo;
END;
$$;

-- ==================== INSCRIPCION ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_inscripcion(character varying, integer, integer, date, character varying, text);
DROP PROCEDURE IF EXISTS public.sp_actualizar_inscripcion(integer, character varying, text, date);
DROP PROCEDURE IF EXISTS public.sp_eliminar_inscripcion(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_inscripcion(
    IN p_codigo character varying, IN p_id_evento integer,
    IN p_id_caballo integer, IN p_fecha date,
    IN p_estado character varying, IN p_observaciones text,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO inscripcion (codigo_inscripcion, id_evento, id_caballo, fecha_inscripcion, estado, observaciones)
    VALUES (p_codigo, p_id_evento, p_id_caballo, p_fecha, p_estado, p_observaciones)
    RETURNING id_inscripcion INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_inscripcion(
    IN p_id integer, IN p_estado character varying,
    IN p_observaciones text, IN p_fecha date)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE inscripcion SET estado = p_estado, observaciones = p_observaciones, fecha_inscripcion = p_fecha
    WHERE id_inscripcion = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_inscripcion(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM resultado_carrera WHERE id_inscripcion = p_id;
    DELETE FROM detalle_factura WHERE id_inscripcion = p_id;
    DELETE FROM inscripcion WHERE id_inscripcion = p_id;
END;
$$;

-- ==================== RESULTADO CARRERA ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_resultado_carrera(integer, integer, time without time zone, numeric, text);
DROP PROCEDURE IF EXISTS public.sp_actualizar_resultado_carrera(integer, integer, numeric, text);
DROP PROCEDURE IF EXISTS public.sp_eliminar_resultado_carrera(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_resultado_carrera(
    IN p_id_inscripcion integer, IN p_posicion integer,
    IN p_tiempo time without time zone, IN p_premio numeric,
    IN p_observaciones text, INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO resultado_carrera (id_inscripcion, posicion, tiempo_registro, premio_obtenido, observaciones)
    VALUES (p_id_inscripcion, p_posicion, p_tiempo, p_premio, p_observaciones)
    RETURNING id_resultado INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_resultado_carrera(
    IN p_id integer, IN p_posicion integer,
    IN p_premio_obtenido numeric, IN p_observaciones text)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE resultado_carrera SET posicion = p_posicion, premio_obtenido = p_premio_obtenido, observaciones = p_observaciones
    WHERE id_resultado = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_resultado_carrera(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM resultado_carrera WHERE id_resultado = p_id;
END;
$$;

-- ==================== HISTORIAL VETERINARIO ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_historial_veterinario(character varying, integer, integer, text, text, date, date, text);
DROP PROCEDURE IF EXISTS public.sp_actualizar_historial_veterinario(integer, boolean, date, text);
DROP PROCEDURE IF EXISTS public.sp_eliminar_historial_veterinario(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_historial_veterinario(
    IN p_codigo character varying, IN p_id_caballo integer,
    IN p_id_veterinario integer, IN p_diagnostico text,
    IN p_tratamiento text, IN p_fecha_revision date,
    IN p_fecha_vencimiento date, IN p_observaciones text,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO historial_veterinario (codigo_registro, id_caballo, id_veterinario, diagnostico, tratamiento, fecha_revision, fecha_vencimiento_certificado, certificado_vigente, observaciones)
    VALUES (p_codigo, p_id_caballo, p_id_veterinario, p_diagnostico, p_tratamiento, p_fecha_revision, p_fecha_vencimiento,
        CASE WHEN p_fecha_vencimiento >= CURRENT_DATE THEN TRUE ELSE FALSE END, p_observaciones)
    RETURNING id_historial INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_historial_veterinario(
    IN p_id integer, IN p_certificado_vigente boolean,
    IN p_fecha_vencimiento date, IN p_observaciones text)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE historial_veterinario
    SET certificado_vigente = p_certificado_vigente,
        fecha_vencimiento_certificado = p_fecha_vencimiento,
        observaciones = p_observaciones
    WHERE id_historial = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_historial_veterinario(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM historial_veterinario WHERE id_historial = p_id;
END;
$$;

-- ==================== SUMINISTRO ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_suministro(character varying, character varying, character varying, integer, numeric, date, character varying, character varying);
DROP PROCEDURE IF EXISTS public.sp_actualizar_suministro(integer, numeric, character varying, date);
DROP PROCEDURE IF EXISTS public.sp_eliminar_suministro(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_suministro(
    IN p_codigo character varying, IN p_nombre character varying,
    IN p_tipo character varying, IN p_id_proveedor integer,
    IN p_cantidad numeric, IN p_fecha_ingreso date,
    IN p_unidad character varying, IN p_estado character varying,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO suministro (codigo, nombre_suministro, tipo, id_proveedor, cantidad_disponible, fecha_ingreso, unidad_medida, estado)
    VALUES (p_codigo, p_nombre, p_tipo, p_id_proveedor, p_cantidad, p_fecha_ingreso, p_unidad, p_estado)
    RETURNING id_suministro INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_suministro(
    IN p_id integer, IN p_cantidad numeric,
    IN p_estado character varying, IN p_fecha_ingreso date)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE suministro SET cantidad_disponible = p_cantidad, estado = p_estado, fecha_ingreso = p_fecha_ingreso
    WHERE id_suministro = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_suministro(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM alimentacion WHERE id_suministro = p_id;
    DELETE FROM suministro WHERE id_suministro = p_id;
END;
$$;

-- ==================== ALIMENTACION ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_alimentacion(integer, integer, date, numeric, character varying, text);
DROP PROCEDURE IF EXISTS public.sp_actualizar_alimentacion(integer, numeric, text, date);
DROP PROCEDURE IF EXISTS public.sp_eliminar_alimentacion(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_alimentacion(
    IN p_id_caballo integer, IN p_id_suministro integer,
    IN p_fecha date, IN p_cantidad numeric,
    IN p_unidad character varying, IN p_observaciones text,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO alimentacion (id_caballo, id_suministro, fecha, cantidad, unidad, observaciones)
    VALUES (p_id_caballo, p_id_suministro, p_fecha, p_cantidad, p_unidad, p_observaciones)
    RETURNING id_alimentacion INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_alimentacion(
    IN p_id integer, IN p_cantidad numeric,
    IN p_observaciones text, IN p_fecha date)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE alimentacion SET cantidad = p_cantidad, observaciones = p_observaciones, fecha = p_fecha
    WHERE id_alimentacion = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_alimentacion(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM alimentacion WHERE id_alimentacion = p_id;
END;
$$;

-- ==================== ASIGNACION ESTABLO ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_asignacion_establo(integer, integer, date, character varying);
DROP PROCEDURE IF EXISTS public.sp_actualizar_asignacion_establo(integer, character varying, date, integer);
DROP PROCEDURE IF EXISTS public.sp_eliminar_asignacion_establo(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_asignacion_establo(
    IN p_id_caballo integer, IN p_id_establo integer,
    IN p_fecha_asignacion date, IN p_estado character varying,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO asignacion_establo (id_caballo, id_establo, fecha_asignacion, estado)
    VALUES (p_id_caballo, p_id_establo, p_fecha_asignacion, p_estado)
    RETURNING id_asignacion INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_asignacion_establo(
    IN p_id integer, IN p_estado character varying,
    IN p_fecha_salida date, IN p_id_establo integer)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE asignacion_establo SET estado = p_estado, fecha_salida = p_fecha_salida, id_establo = p_id_establo
    WHERE id_asignacion = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_asignacion_establo(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM asignacion_establo WHERE id_asignacion = p_id;
END;
$$;

-- ==================== PROVEEDOR ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_proveedor(character varying, character varying, character varying, character varying, character varying);
DROP PROCEDURE IF EXISTS public.sp_actualizar_proveedor(integer, character varying, character varying, character varying);
DROP PROCEDURE IF EXISTS public.sp_eliminar_proveedor(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_proveedor(
    IN p_nombre character varying, IN p_contacto character varying,
    IN p_telefono character varying, IN p_correo character varying,
    IN p_estado character varying, INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO proveedor (nombre, contacto, telefono, correo, estado)
    VALUES (p_nombre, p_contacto, p_telefono, p_correo, p_estado)
    RETURNING id_proveedor INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_proveedor(
    IN p_id integer, IN p_estado character varying,
    IN p_telefono character varying, IN p_correo character varying)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE proveedor SET estado = p_estado, telefono = p_telefono, correo = p_correo
    WHERE id_proveedor = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_proveedor(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM suministro WHERE id_proveedor = p_id;
    DELETE FROM proveedor WHERE id_proveedor = p_id;
END;
$$;

-- ==================== BENEFICIO PROPIETARIO ====================
DROP PROCEDURE IF EXISTS public.sp_insertar_beneficio_propietario(integer, character varying, numeric, character varying);
DROP PROCEDURE IF EXISTS public.sp_actualizar_beneficio_propietario(integer, numeric, character varying, date);
DROP PROCEDURE IF EXISTS public.sp_eliminar_beneficio_propietario(integer);

CREATE OR REPLACE PROCEDURE public.sp_insertar_beneficio_propietario(
    IN p_id_propietario integer, IN p_tipo character varying,
    IN p_porcentaje numeric, IN p_estado character varying,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_id integer;
BEGIN
    INSERT INTO beneficio_propietario (id_propietario, tipo_beneficio, porcentaje_descuento, fecha_asignacion, estado)
    VALUES (p_id_propietario, p_tipo, p_porcentaje, CURRENT_DATE, p_estado)
    RETURNING id_beneficio INTO v_id;
    p_new_id := v_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_actualizar_beneficio_propietario(
    IN p_id integer, IN p_porcentaje numeric,
    IN p_estado character varying, IN p_fecha_aplicacion date)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE beneficio_propietario
    SET porcentaje_descuento = p_porcentaje, estado = p_estado, fecha_aplicacion = p_fecha_aplicacion
    WHERE id_beneficio = p_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_eliminar_beneficio_propietario(IN p_id integer)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM beneficio_propietario WHERE id_beneficio = p_id;
END;
$$;

-- ==================== FACTURACION ====================
-- Crear sp_crear_factura (usando la función existente fn_generar_factura_propietario_evento)
CREATE OR REPLACE PROCEDURE public.sp_crear_factura(
    IN p_id_propietario integer, IN p_id_evento integer,
    IN p_id_metodo_pago integer DEFAULT NULL,
    IN p_referencia character varying DEFAULT NULL,
    IN p_numero_comprobante character varying DEFAULT NULL,
    INOUT p_new_id_factura integer DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    v_id_factura integer;
BEGIN
    -- Generar la factura usando la función existente
    v_id_factura := fn_generar_factura_propietario_evento(p_id_propietario, p_id_evento);

    -- Si hay método de pago, registrar la transacción
    IF p_id_metodo_pago IS NOT NULL THEN
        INSERT INTO historial_transaccion (id_factura, monto, id_metodo_pago, referencia, numero_comprobante, estado)
        SELECT v_id_factura, f.total, p_id_metodo_pago, p_referencia, p_numero_comprobante, 'Registrado'
        FROM factura f WHERE f.id_factura = v_id_factura;
    END IF;

    p_new_id_factura := v_id_factura;
END;
$$;

-- Crear sp_calcular_propietarios_frecuentes
CREATE OR REPLACE PROCEDURE public.sp_calcular_propietarios_frecuentes()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE propietario
    SET descuento_proxima_factura = TRUE
    WHERE id_propietario IN (
        SELECT f.id_propietario
        FROM factura f
        INNER JOIN estado_pago ep ON ep.id_estado_pago = f.id_estado_pago
        WHERE f.fecha_emision >= (CURRENT_DATE - INTERVAL '6 months')
          AND ep.nombre_estado IN ('Pagada', 'Parcial')
        GROUP BY f.id_propietario
        HAVING SUM(f.total) > 500000
    );

    INSERT INTO beneficio_propietario (id_propietario, tipo_beneficio, porcentaje_descuento, fecha_asignacion, estado)
    SELECT f.id_propietario, 'Descuento por facturacion mayor a 500000 en los ultimos 6 meses',
           10.00, CURRENT_DATE, 'Pendiente'
    FROM factura f
    INNER JOIN estado_pago ep ON ep.id_estado_pago = f.id_estado_pago
    WHERE f.fecha_emision >= (CURRENT_DATE - INTERVAL '6 months')
      AND ep.nombre_estado IN ('Pagada', 'Parcial')
    GROUP BY f.id_propietario
    HAVING SUM(f.total) > 500000
       AND NOT EXISTS (
            SELECT 1 FROM beneficio_propietario bp
            WHERE bp.id_propietario = f.id_propietario AND bp.estado = 'Pendiente'
       );
END;
$$;
