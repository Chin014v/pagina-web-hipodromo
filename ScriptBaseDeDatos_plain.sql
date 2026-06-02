-- Plain SQL dump converted from pg_dump custom format
-- Original database: hipodromo_nacional_scriptnuevo

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- ENCODING: ENCODING
SET client_encoding = 'UTF8';

-- STDSTRINGS: STDSTRINGS
SET standard_conforming_strings = 'on';

-- SEARCHPATH: SEARCHPATH
SELECT pg_catalog.set_config('search_path', '', false);

-- DATABASE: hipodromo_nacional_scriptnuevo
CREATE DATABASE hipodromo_nacional_scriptnuevo WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF8';

-- FUNCTION: fn_actualizar_estado_factura_por_pago()
CREATE FUNCTION public.fn_actualizar_estado_factura_por_pago() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_factura INT;
    v_total_factura NUMERIC(12,2);
    v_total_pagado NUMERIC(12,2);
    v_id_estado_pendiente INT;
    v_id_estado_parcial INT;
    v_id_estado_pagada INT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_factura := OLD.id_factura;
    ELSE
        v_id_factura := NEW.id_factura;
    END IF;

    SELECT id_estado_pago INTO v_id_estado_pendiente FROM estado_pago WHERE nombre_estado = 'Pendiente';
    SELECT id_estado_pago INTO v_id_estado_parcial FROM estado_pago WHERE nombre_estado = 'Parcial';
    SELECT id_estado_pago INTO v_id_estado_pagada FROM estado_pago WHERE nombre_estado = 'Pagada';

    IF v_id_estado_pendiente IS NULL OR v_id_estado_parcial IS NULL OR v_id_estado_pagada IS NULL THEN
        RAISE EXCEPTION 'Faltan estados de pago base: Pendiente, Parcial o Pagada.';
    END IF;

    SELECT total INTO v_total_factura
    FROM factura
    WHERE id_factura = v_id_factura;

    SELECT COALESCE(SUM(monto), 0) INTO v_total_pagado
    FROM historial_transaccion
    WHERE id_factura = v_id_factura
      AND estado = 'Registrado';

    UPDATE factura
    SET id_estado_pago = CASE
        WHEN v_total_pagado >= v_total_factura THEN v_id_estado_pagada
        WHEN v_total_pagado > 0 THEN v_id_estado_parcial
        ELSE v_id_estado_pendiente
    END
    WHERE id_factura = v_id_factura;

    RETURN NULL;
END;
$$;

-- FUNCTION: fn_descontar_suministro_alimentacion()
CREATE FUNCTION public.fn_descontar_suministro_alimentacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_cantidad_actual NUMERIC(10,2);
BEGIN
    SELECT cantidad_disponible INTO v_cantidad_actual
    FROM suministro
    WHERE id_suministro = NEW.id_suministro;

    IF v_cantidad_actual IS NULL THEN
        RAISE EXCEPTION 'El suministro no existe.';
    END IF;

    IF v_cantidad_actual < NEW.cantidad THEN
        RAISE EXCEPTION 'Cantidad insuficiente del suministro. Disponible: %, solicitado: %',
            v_cantidad_actual, NEW.cantidad;
    END IF;

    UPDATE suministro
    SET cantidad_disponible = cantidad_disponible - NEW.cantidad,
        estado = CASE WHEN (cantidad_disponible - NEW.cantidad) <= 0 THEN 'Agotado' ELSE estado END
    WHERE id_suministro = NEW.id_suministro;

    RETURN NEW;
END;
$$;

-- FUNCTION: fn_generar_factura_propietario_evento(integer, integer)
CREATE FUNCTION public.fn_generar_factura_propietario_evento(p_id_propietario integer, p_id_evento integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_factura INT;
    v_subtotal NUMERIC(12,2);
    v_porcentaje_descuento NUMERIC(5,2);
    v_monto_descuento NUMERIC(12,2);
    v_base_imponible NUMERIC(12,2);
    v_impuesto_iva NUMERIC(12,2);
    v_comision_admin NUMERIC(12,2);
    v_total NUMERIC(12,2);
    v_descuento_activo BOOLEAN;
    v_id_estado_pendiente INT;
BEGIN
    SELECT COALESCE(SUM(e.precio_inscripcion), 0)
    INTO v_subtotal
    FROM inscripcion i
    INNER JOIN caballo c ON c.id_caballo = i.id_caballo
    INNER JOIN evento e ON e.id_evento = i.id_evento
    WHERE c.id_propietario = p_id_propietario
      AND i.id_evento = p_id_evento
      AND i.estado = 'Aprobada';

    IF v_subtotal IS NULL OR v_subtotal = 0 THEN
        RAISE EXCEPTION 'No hay inscripciones aprobadas para facturar.';
    END IF;

    SELECT id_estado_pago INTO v_id_estado_pendiente
    FROM estado_pago
    WHERE nombre_estado = 'Pendiente';

    IF v_id_estado_pendiente IS NULL THEN
        RAISE EXCEPTION 'No existe el estado de pago Pendiente.';
    END IF;

    SELECT descuento_proxima_factura INTO v_descuento_activo
    FROM propietario
    WHERE id_propietario = p_id_propietario;

    v_porcentaje_descuento := CASE WHEN v_descuento_activo THEN 10 ELSE 0 END;
    v_monto_descuento := ROUND(v_subtotal * (v_porcentaje_descuento / 100), 2);
    v_base_imponible := v_subtotal - v_monto_descuento;
    v_impuesto_iva := ROUND(v_base_imponible * 0.13, 2);
    v_comision_admin := ROUND(v_base_imponible * 0.05, 2);
    v_total := v_base_imponible + v_impuesto_iva + v_comision_admin;

    INSERT INTO factura (
        codigo_factura, id_propietario, id_evento, subtotal, porcentaje_descuento,
        monto_descuento, base_imponible, impuesto_iva, comision_admin, total,
        id_estado_pago, fecha_emision, fecha_vencimiento
    ) VALUES (
        'FAC-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISSMS'),
        p_id_propietario, p_id_evento, v_subtotal, v_porcentaje_descuento,
        v_monto_descuento, v_base_imponible, v_impuesto_iva, v_comision_admin, v_total,
        v_id_estado_pendiente, CURRENT_DATE, CURRENT_DATE + INTERVAL '15 days'
    ) RETURNING id_factura INTO v_id_factura;

    INSERT INTO detalle_factura (id_factura, id_inscripcion, descripcion, cantidad, precio_unitario, subtotal_linea)
    SELECT v_id_factura,
           i.id_inscripcion,
           'Inscripcion al evento ' || e.nombre,
           1,
           e.precio_inscripcion,
           e.precio_inscripcion
    FROM inscripcion i
    INNER JOIN caballo c ON c.id_caballo = i.id_caballo
    INNER JOIN evento e ON e.id_evento = i.id_evento
    WHERE c.id_propietario = p_id_propietario
      AND i.id_evento = p_id_evento
      AND i.estado = 'Aprobada';

    IF v_descuento_activo THEN
        UPDATE propietario SET descuento_proxima_factura = FALSE
        WHERE id_propietario = p_id_propietario;

        UPDATE beneficio_propietario
        SET estado = 'Aplicado', fecha_aplicacion = CURRENT_DATE
        WHERE id_propietario = p_id_propietario
          AND estado = 'Pendiente'
          AND porcentaje_descuento = 10.00;
    END IF;

    RETURN v_id_factura;
END;
$$;

-- FUNCTION: fn_registrar_bitacora()
CREATE FUNCTION public.fn_registrar_bitacora() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    nombre_bitacora TEXT;
    columna_pk_nombre TEXT;
    id_detectado INT;
BEGIN
    nombre_bitacora := 'bitacora_' || lower(TG_TABLE_NAME);
    columna_pk_nombre := TG_ARGV[0];

    IF TG_OP = 'INSERT' THEN
        id_detectado := (to_jsonb(NEW) ->> columna_pk_nombre)::INT;
        EXECUTE format('
            INSERT INTO %I (id_registro_afectado, tabla_afectada, accion, usuario_bd, fecha_registro, datos_anteriores, datos_nuevos)
            VALUES ($1, $2, $3, CURRENT_USER, CURRENT_TIMESTAMP, NULL, to_jsonb($4))
        ', nombre_bitacora)
        USING id_detectado, TG_TABLE_NAME, TG_OP, NEW;
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        id_detectado := (to_jsonb(NEW) ->> columna_pk_nombre)::INT;
        EXECUTE format('
            INSERT INTO %I (id_registro_afectado, tabla_afectada, accion, usuario_bd, fecha_registro, datos_anteriores, datos_nuevos)
            VALUES ($1, $2, $3, CURRENT_USER, CURRENT_TIMESTAMP, to_jsonb($4), to_jsonb($5))
        ', nombre_bitacora)
        USING id_detectado, TG_TABLE_NAME, TG_OP, OLD, NEW;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        id_detectado := (to_jsonb(OLD) ->> columna_pk_nombre)::INT;
        EXECUTE format('
            INSERT INTO %I (id_registro_afectado, tabla_afectada, accion, usuario_bd, fecha_registro, datos_anteriores, datos_nuevos)
            VALUES ($1, $2, $3, CURRENT_USER, CURRENT_TIMESTAMP, to_jsonb($4), NULL)
        ', nombre_bitacora)
        USING id_detectado, TG_TABLE_NAME, TG_OP, OLD;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$_$;

-- FUNCTION: fn_validar_certificacion_vigente(integer)
CREATE FUNCTION public.fn_validar_certificacion_vigente(p_id_caballo integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    existe_certificacion BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM historial_veterinario hv
        WHERE hv.id_caballo = p_id_caballo
          AND hv.certificado_vigente = TRUE
          AND hv.fecha_vencimiento_certificado >= CURRENT_DATE
        ORDER BY hv.fecha_revision DESC
        LIMIT 1
    ) INTO existe_certificacion;

    RETURN existe_certificacion;
END;
$$;

-- FUNCTION: fn_validar_estado_certificacion()
CREATE FUNCTION public.fn_validar_estado_certificacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    texto_notificacion VARCHAR(500);
BEGIN
    IF NEW.fecha_vencimiento_certificado <= CURRENT_DATE THEN
        texto_notificacion := 'ALERTA: Certificacion veterinaria vencida para el caballo ID: ' || NEW.id_caballo;

        INSERT INTO alerta_certificacion (id_caballo, mensaje, estado, fecha_alerta)
        VALUES (NEW.id_caballo, texto_notificacion, 'Pendiente', CURRENT_TIMESTAMP);

        NEW.certificado_vigente := FALSE;
    ELSE
        NEW.certificado_vigente := TRUE;
    END IF;

    RETURN NEW;
END;
$$;

-- PROCEDURE: sp_actualizar_alerta_certificacion(integer, character varying)
CREATE PROCEDURE public.sp_actualizar_alerta_certificacion(IN p_id integer, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE alerta_certificacion SET estado = p_estado WHERE id_alerta = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_alimentacion(integer, numeric, text, date)
CREATE PROCEDURE public.sp_actualizar_alimentacion(IN p_id integer, IN p_cantidad numeric, IN p_observaciones text, IN p_fecha date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: cantidad (corrección de error en el registro de
    -- consumo), observaciones (notas sobre comportamiento o anomalías
    -- en la alimentación) y fecha (corrección de fecha de registro).
    UPDATE alimentacion
    SET cantidad = p_cantidad,
        observaciones = p_observaciones,
        fecha = p_fecha
    WHERE id_alimentacion = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_asignacion_establo(integer, character varying, date, integer)
CREATE PROCEDURE public.sp_actualizar_asignacion_establo(IN p_id integer, IN p_estado character varying, IN p_fecha_salida date, IN p_id_establo integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (finalizar o mantener activa la asignación),
    -- fecha_salida (registrar el egreso efectivo del caballo del establo)
    -- e id_establo (traslado del caballo a otro espacio disponible).
    UPDATE asignacion_establo
    SET estado = p_estado,
        fecha_salida = p_fecha_salida,
        id_establo = p_id_establo
    WHERE id_asignacion = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_barrio(integer, integer, integer, integer, integer, character varying)
CREATE PROCEDURE public.sp_actualizar_barrio(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_id_distrito integer, IN p_id_barrio integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE barrio SET nombre_barrio = p_nombre
    WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia
      AND id_canton = p_id_canton AND id_distrito = p_id_distrito AND id_barrio = p_id_barrio;
END;
$$;

-- PROCEDURE: sp_actualizar_beneficio_propietario(integer, numeric, character varying, date)
CREATE PROCEDURE public.sp_actualizar_beneficio_propietario(IN p_id integer, IN p_porcentaje numeric, IN p_estado character varying, IN p_fecha_aplicacion date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: porcentaje_descuento (ajuste de política comercial),
    -- estado (ciclo de vida del beneficio) y fecha_aplicacion (registro de aplicación).
    UPDATE beneficio_propietario
    SET porcentaje_descuento = p_porcentaje,
        estado = p_estado,
        fecha_aplicacion = p_fecha_aplicacion
    WHERE id_beneficio = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_caballo(integer, character varying, numeric, integer)
CREATE PROCEDURE public.sp_actualizar_caballo(IN p_id integer, IN p_estado_salud character varying, IN p_peso_kg numeric, IN p_id_propietario integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado_salud (campo más dinámico, cambia tras cada
    -- revisión veterinaria), peso_kg (varía continuamente con alimentación
    -- y entrenamiento) e id_propietario (para registrar transferencias de
    -- propiedad del animal).
    UPDATE caballo
    SET estado_salud = p_estado_salud,
        peso_kg = p_peso_kg,
        id_propietario = p_id_propietario
    WHERE id_caballo = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_canton(integer, integer, integer, character varying)
CREATE PROCEDURE public.sp_actualizar_canton(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE canton SET nombre_canton = p_nombre
    WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia AND id_canton = p_id_canton;
END;
$$;

-- PROCEDURE: sp_actualizar_correo_propietario(integer, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_correo_propietario(IN p_id integer, IN p_correo character varying, IN p_tipo character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE correo_propietario SET correo = p_correo, tipo = p_tipo WHERE id_correo = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_detalle_factura(integer, character varying, numeric, numeric)
CREATE PROCEDURE public.sp_actualizar_detalle_factura(IN p_id integer, IN p_descripcion character varying, IN p_precio_unitario numeric, IN p_subtotal_linea numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: descripcion (corrección del concepto facturado),
    -- precio_unitario (ajuste de tarifa por corrección administrativa)
    -- y subtotal_linea (recalculo tras corrección de precio o cantidad).
    UPDATE detalle_factura
    SET descripcion = p_descripcion,
        precio_unitario = p_precio_unitario,
        subtotal_linea = p_subtotal_linea
    WHERE id_detalle = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_distrito(integer, integer, integer, integer, character varying)
CREATE PROCEDURE public.sp_actualizar_distrito(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_id_distrito integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE distrito SET nombre_distrito = p_nombre
    WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia
      AND id_canton = p_id_canton AND id_distrito = p_id_distrito;
END;
$$;

-- PROCEDURE: sp_actualizar_establo(integer, character varying, integer, character varying)
CREATE PROCEDURE public.sp_actualizar_establo(IN p_id integer, IN p_estado character varying, IN p_capacidad integer, IN p_ubicacion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (disponibilidad del establo para asignaciones),
    -- capacidad (ajuste por remodelación o ampliación física) y ubicacion
    -- (corrección de descripción o detalle de la ubicación interna).
    UPDATE establo
    SET estado = p_estado,
        capacidad = p_capacidad,
        ubicacion = p_ubicacion
    WHERE id_establo = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_estado_pago(integer, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_estado_pago(IN p_id integer, IN p_nombre character varying, IN p_descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE estado_pago SET nombre_estado = p_nombre, descripcion = p_descripcion WHERE id_estado_pago = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_evento(integer, character varying, numeric, timestamp without time zone)
CREATE PROCEDURE public.sp_actualizar_evento(IN p_id integer, IN p_estado character varying, IN p_premio_total numeric, IN p_fecha timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (transición del ciclo de vida del evento),
    -- premio_total (ajuste por nuevos patrocinios o cambios reglamentarios)
    -- y fecha (reprogramación por condiciones climáticas u otras causas).
    UPDATE evento
    SET estado = p_estado,
        premio_total = p_premio_total,
        fecha = p_fecha
    WHERE id_evento = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_factura(integer, integer, date, numeric)
CREATE PROCEDURE public.sp_actualizar_factura(IN p_id integer, IN p_id_estado_pago integer, IN p_fecha_vencimiento date, IN p_porcentaje_descuento numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: id_estado_pago (refleja el avance del pago de la
    -- factura), fecha_vencimiento (extensión de plazo por acuerdo
    -- administrativo con el propietario) y porcentaje_descuento
    -- (corrección de descuento aplicado por error o ajuste comercial).
    UPDATE factura
    SET id_estado_pago = p_id_estado_pago,
        fecha_vencimiento = p_fecha_vencimiento,
        porcentaje_descuento = p_porcentaje_descuento
    WHERE id_factura = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_historial_transaccion(integer, character varying, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_historial_transaccion(IN p_id integer, IN p_estado character varying, IN p_referencia character varying, IN p_numero_comprobante character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (anulación de la transacción cuando hay error
    -- o reverso), referencia (corrección del número de referencia bancaria)
    -- y numero_comprobante (corrección del comprobante de pago emitido).
    UPDATE historial_transaccion
    SET estado = p_estado,
        referencia = p_referencia,
        numero_comprobante = p_numero_comprobante
    WHERE id_transaccion = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_historial_veterinario(integer, boolean, date, text)
CREATE PROCEDURE public.sp_actualizar_historial_veterinario(IN p_id integer, IN p_certificado_vigente boolean, IN p_fecha_vencimiento date, IN p_observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: certificado_vigente (resultado de nueva revisión o
    -- vencimiento detectado), fecha_vencimiento_certificado (extensión del
    -- plazo de la certificación) y observaciones (notas adicionales
    -- incorporadas después de la revisión inicial).
    UPDATE historial_veterinario
    SET certificado_vigente = p_certificado_vigente,
        fecha_vencimiento_certificado = p_fecha_vencimiento,
        observaciones = p_observaciones
    WHERE id_historial = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_inscripcion(integer, character varying, text, date)
CREATE PROCEDURE public.sp_actualizar_inscripcion(IN p_id integer, IN p_estado character varying, IN p_observaciones text, IN p_fecha date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (resultado de la validación médica y
    -- reglamentaria de la inscripción), observaciones (motivo de rechazo
    -- o notas del administrador) y fecha_inscripcion (corrección
    -- administrativa de la fecha de registro).
    UPDATE inscripcion
    SET estado = p_estado,
        observaciones = p_observaciones,
        fecha_inscripcion = p_fecha
    WHERE id_inscripcion = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_metodo_pago(integer, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_metodo_pago(IN p_id integer, IN p_nombre character varying, IN p_descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE metodo_pago SET nombre_metodo_pago = p_nombre, descripcion = p_descripcion WHERE id_metodo_pago = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_pais(integer, character varying)
CREATE PROCEDURE public.sp_actualizar_pais(IN p_id integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE pais SET nombre_pais = p_nombre WHERE id_pais = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_propietario(integer, character varying, integer, integer, integer, integer, integer, boolean)
CREATE PROCEDURE public.sp_actualizar_propietario(IN p_id integer, IN p_estado character varying, IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_id_distrito integer, IN p_id_barrio integer, IN p_descuento boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (activación/desactivación del propietario),
    -- dirección completa (cambio de residencia frecuente) y
    -- descuento_proxima_factura (aplicación manual de beneficios por admin).
    UPDATE propietario
    SET estado = p_estado,
        id_pais = p_id_pais,
        id_provincia = p_id_provincia,
        id_canton = p_id_canton,
        id_distrito = p_id_distrito,
        id_barrio = p_id_barrio,
        descuento_proxima_factura = p_descuento
    WHERE id_propietario = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_propietarios_frecuentes()
CREATE PROCEDURE public.sp_actualizar_propietarios_frecuentes()
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
    SELECT f.id_propietario,
           'Descuento por facturacion mayor a 500000 en los ultimos 6 meses',
           10.00,
           CURRENT_DATE,
           'Pendiente'
    FROM factura f
    INNER JOIN estado_pago ep ON ep.id_estado_pago = f.id_estado_pago
    WHERE f.fecha_emision >= (CURRENT_DATE - INTERVAL '6 months')
      AND ep.nombre_estado IN ('Pagada', 'Parcial')
    GROUP BY f.id_propietario
    HAVING SUM(f.total) > 500000
       AND NOT EXISTS (
            SELECT 1
            FROM beneficio_propietario bp
            WHERE bp.id_propietario = f.id_propietario
              AND bp.estado = 'Pendiente'
       );
END;
$$;

-- PROCEDURE: sp_actualizar_proveedor(integer, character varying, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_proveedor(IN p_id integer, IN p_estado character varying, IN p_telefono character varying, IN p_correo character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (activar/desactivar proveedor según vigencia
    -- del contrato), telefono (número de contacto operativo) y correo
    -- (dirección para envío de órdenes de compra y comunicaciones).
    UPDATE proveedor
    SET estado = p_estado,
        telefono = p_telefono,
        correo = p_correo
    WHERE id_proveedor = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_provincia(integer, integer, character varying)
CREATE PROCEDURE public.sp_actualizar_provincia(IN p_id_pais integer, IN p_id_provincia integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE provincia SET nombre_provincia = p_nombre
    WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia;
END;
$$;

-- PROCEDURE: sp_actualizar_raza(integer, character varying, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_raza(IN p_id integer, IN p_nombre character varying, IN p_descripcion character varying, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE raza SET nombre_raza = p_nombre, descripcion = p_descripcion, estado = p_estado WHERE id_raza = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_resultado_carrera(integer, integer, numeric, text)
CREATE PROCEDURE public.sp_actualizar_resultado_carrera(IN p_id integer, IN p_posicion integer, IN p_premio_obtenido numeric, IN p_observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: posicion (corrección oficial emitida por el jurado
    -- de la carrera), premio_obtenido (recalculo tras apelación o ajuste
    -- de premiación) y observaciones (notas del jurado o aclaraciones
    -- sobre incidencias durante la carrera).
    UPDATE resultado_carrera
    SET posicion = p_posicion,
        premio_obtenido = p_premio_obtenido,
        observaciones = p_observaciones
    WHERE id_resultado = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_rol(integer, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_rol(IN p_id integer, IN p_nombre character varying, IN p_descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE rol SET nombre_rol = p_nombre, descripcion = p_descripcion WHERE id_rol = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_suministro(integer, numeric, character varying, date)
CREATE PROCEDURE public.sp_actualizar_suministro(IN p_id integer, IN p_cantidad numeric, IN p_estado character varying, IN p_fecha_ingreso date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: cantidad_disponible (ajuste por conteo físico de
    -- inventario), estado (refleja disponibilidad real: Disponible/Agotado)
    -- y fecha_ingreso (corrección de fecha o registro de reingreso de lote).
    UPDATE suministro
    SET cantidad_disponible = p_cantidad,
        estado = p_estado,
        fecha_ingreso = p_fecha_ingreso
    WHERE id_suministro = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_telefono_propietario(integer, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_telefono_propietario(IN p_id integer, IN p_numero character varying, IN p_tipo character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE telefono_propietario SET numero = p_numero, tipo = p_tipo WHERE id_telefono = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_usuario(integer, boolean, character varying, integer)
CREATE PROCEDURE public.sp_actualizar_usuario(IN p_id integer, IN p_activo boolean, IN p_contrasena_hash character varying, IN p_id_rol integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: activo (habilitar/deshabilitar acceso al sistema),
    -- contrasena_hash (actualización periódica de contraseña por seguridad)
    -- e id_rol (reasignación de permisos por cambio de función del usuario).
    UPDATE usuario
    SET activo = p_activo,
        contrasena_hash = p_contrasena_hash,
        id_rol = p_id_rol
    WHERE id_usuario = p_id;
END;
$$;

-- PROCEDURE: sp_actualizar_veterinario(integer, character varying, character varying, character varying)
CREATE PROCEDURE public.sp_actualizar_veterinario(IN p_id integer, IN p_estado character varying, IN p_telefono character varying, IN p_correo character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Se actualizan: estado (habilitación/inhabilitación del veterinario),
    -- telefono (cambio de número de contacto) y correo (actualización de
    -- dirección de correo oficial para notificaciones del sistema).
    UPDATE veterinario
    SET estado = p_estado,
        telefono = p_telefono,
        correo = p_correo
    WHERE id_veterinario = p_id;
END;
$$;

-- PROCEDURE: sp_calcular_premios_evento(integer)
CREATE PROCEDURE public.sp_calcular_premios_evento(IN p_id_evento integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_premio_total NUMERIC(12,2);
    r RECORD;
    v_posicion INT := 1;
BEGIN
    SELECT premio_total INTO v_premio_total
    FROM evento
    WHERE id_evento = p_id_evento;

    IF v_premio_total IS NULL THEN
        RAISE EXCEPTION 'El evento no existe.';
    END IF;

    -- 1. Asignar posiciones basadas en tiempo (tiempo menor gana)
    FOR r IN (
        SELECT rc.id_resultado
        FROM resultado_carrera rc
        JOIN inscripcion i ON rc.id_inscripcion = i.id_inscripcion
        WHERE i.id_evento = p_id_evento
        ORDER BY rc.tiempo_registro ASC
    ) LOOP
        UPDATE resultado_carrera
        SET posicion = v_posicion
        WHERE id_resultado = r.id_resultado;
        
        v_posicion := v_posicion + 1;
    END LOOP;

    -- 2. Actualizar premios en base a la nueva posición recalculada
    UPDATE resultado_carrera rc
    SET premio_obtenido = CASE
        WHEN rc.posicion = 1 THEN ROUND(v_premio_total * 0.50, 2)
        WHEN rc.posicion = 2 THEN ROUND(v_premio_total * 0.30, 2)
        WHEN rc.posicion = 3 THEN ROUND(v_premio_total * 0.20, 2)
        ELSE 0
    END
    FROM inscripcion i
    WHERE rc.id_inscripcion = i.id_inscripcion
      AND i.id_evento = p_id_evento;
END;
$$;

-- PROCEDURE: sp_crear_estructura_bitacora(text)
CREATE PROCEDURE public.sp_crear_estructura_bitacora(IN nombre_tabla_origen text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    nombre_bitacora TEXT;
BEGIN
    nombre_bitacora := 'bitacora_' || lower(nombre_tabla_origen);

    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id_bitacora BIGINT GENERATED BY DEFAULT AS IDENTITY,
            id_registro_afectado INT NOT NULL,
            tabla_afectada VARCHAR(80) NOT NULL,
            accion VARCHAR(20) NOT NULL,
            usuario_bd VARCHAR(80) NOT NULL,
            fecha_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            datos_anteriores JSONB,
            datos_nuevos JSONB,
            PRIMARY KEY (id_bitacora, fecha_registro)
        ) PARTITION BY RANGE (fecha_registro);
    ', nombre_bitacora);

    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I
        PARTITION OF %I
        FOR VALUES FROM (''2026-01-01'') TO (''2026-04-01'');
    ', nombre_bitacora || '_2026_t1', nombre_bitacora);

    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I
        PARTITION OF %I
        FOR VALUES FROM (''2026-04-01'') TO (''2026-07-01'');
    ', nombre_bitacora || '_2026_t2', nombre_bitacora);

    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I
        PARTITION OF %I
        FOR VALUES FROM (''2026-07-01'') TO (''2026-10-01'');
    ', nombre_bitacora || '_2026_t3', nombre_bitacora);

    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I
        PARTITION OF %I
        FOR VALUES FROM (''2026-10-01'') TO (''2027-01-01'');
    ', nombre_bitacora || '_2026_t4', nombre_bitacora);

    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I
        PARTITION OF %I
        DEFAULT;
    ', nombre_bitacora || '_otros', nombre_bitacora);
END;
$$;

-- PROCEDURE: sp_eliminar_alerta_certificacion(integer)
CREATE PROCEDURE public.sp_eliminar_alerta_certificacion(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM alerta_certificacion WHERE id_alerta = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_alimentacion(integer)
CREATE PROCEDURE public.sp_eliminar_alimentacion(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM alimentacion WHERE id_alimentacion = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_asignacion_establo(integer)
CREATE PROCEDURE public.sp_eliminar_asignacion_establo(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM asignacion_establo WHERE id_asignacion = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_barrio(integer, integer, integer, integer, integer)
CREATE PROCEDURE public.sp_eliminar_barrio(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_id_distrito integer, IN p_id_barrio integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM barrio
    WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia
      AND id_canton = p_id_canton AND id_distrito = p_id_distrito AND id_barrio = p_id_barrio;
END;
$$;

-- PROCEDURE: sp_eliminar_beneficio_propietario(integer)
CREATE PROCEDURE public.sp_eliminar_beneficio_propietario(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM beneficio_propietario WHERE id_beneficio = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_caballo(integer)
CREATE PROCEDURE public.sp_eliminar_caballo(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM caballo WHERE id_caballo = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_canton(integer, integer, integer)
CREATE PROCEDURE public.sp_eliminar_canton(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM canton WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia AND id_canton = p_id_canton;
END;
$$;

-- PROCEDURE: sp_eliminar_correo_propietario(integer)
CREATE PROCEDURE public.sp_eliminar_correo_propietario(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM correo_propietario WHERE id_correo = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_detalle_factura(integer)
CREATE PROCEDURE public.sp_eliminar_detalle_factura(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM detalle_factura WHERE id_detalle = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_distrito(integer, integer, integer, integer)
CREATE PROCEDURE public.sp_eliminar_distrito(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_id_distrito integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM distrito
    WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia
      AND id_canton = p_id_canton AND id_distrito = p_id_distrito;
END;
$$;

-- PROCEDURE: sp_eliminar_establo(integer)
CREATE PROCEDURE public.sp_eliminar_establo(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM establo WHERE id_establo = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_estado_pago(integer)
CREATE PROCEDURE public.sp_eliminar_estado_pago(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM estado_pago WHERE id_estado_pago = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_evento(integer)
CREATE PROCEDURE public.sp_eliminar_evento(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM evento WHERE id_evento = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_factura(integer)
CREATE PROCEDURE public.sp_eliminar_factura(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM factura WHERE id_factura = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_historial_transaccion(integer)
CREATE PROCEDURE public.sp_eliminar_historial_transaccion(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM historial_transaccion WHERE id_transaccion = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_historial_veterinario(integer)
CREATE PROCEDURE public.sp_eliminar_historial_veterinario(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM historial_veterinario WHERE id_historial = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_inscripcion(integer)
CREATE PROCEDURE public.sp_eliminar_inscripcion(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM inscripcion WHERE id_inscripcion = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_metodo_pago(integer)
CREATE PROCEDURE public.sp_eliminar_metodo_pago(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM metodo_pago WHERE id_metodo_pago = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_pais(integer)
CREATE PROCEDURE public.sp_eliminar_pais(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM pais WHERE id_pais = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_propietario(integer)
CREATE PROCEDURE public.sp_eliminar_propietario(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM propietario WHERE id_propietario = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_proveedor(integer)
CREATE PROCEDURE public.sp_eliminar_proveedor(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM proveedor WHERE id_proveedor = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_provincia(integer, integer)
CREATE PROCEDURE public.sp_eliminar_provincia(IN p_id_pais integer, IN p_id_provincia integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM provincia WHERE id_pais = p_id_pais AND id_provincia = p_id_provincia;
END;
$$;

-- PROCEDURE: sp_eliminar_raza(integer)
CREATE PROCEDURE public.sp_eliminar_raza(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM raza WHERE id_raza = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_resultado_carrera(integer)
CREATE PROCEDURE public.sp_eliminar_resultado_carrera(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM resultado_carrera WHERE id_resultado = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_rol(integer)
CREATE PROCEDURE public.sp_eliminar_rol(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM rol WHERE id_rol = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_suministro(integer)
CREATE PROCEDURE public.sp_eliminar_suministro(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM suministro WHERE id_suministro = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_telefono_propietario(integer)
CREATE PROCEDURE public.sp_eliminar_telefono_propietario(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM telefono_propietario WHERE id_telefono = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_usuario(integer)
CREATE PROCEDURE public.sp_eliminar_usuario(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM usuario WHERE id_usuario = p_id;
END;
$$;

-- PROCEDURE: sp_eliminar_veterinario(integer)
CREATE PROCEDURE public.sp_eliminar_veterinario(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM veterinario WHERE id_veterinario = p_id;
END;
$$;

-- PROCEDURE: sp_insertar_alerta_certificacion(integer, character varying)
CREATE PROCEDURE public.sp_insertar_alerta_certificacion(IN p_id_caballo integer, IN p_mensaje character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO alerta_certificacion (id_caballo, mensaje, estado)
    VALUES (p_id_caballo, p_mensaje, 'Pendiente');
END;
$$;

-- PROCEDURE: sp_insertar_alimentacion(integer, integer, date, numeric, character varying, text)
CREATE PROCEDURE public.sp_insertar_alimentacion(IN p_id_caballo integer, IN p_id_suministro integer, IN p_fecha date, IN p_cantidad numeric, IN p_unidad character varying, IN p_observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO alimentacion (id_caballo, id_suministro, fecha, cantidad, unidad, observaciones)
    VALUES (p_id_caballo, p_id_suministro, p_fecha, p_cantidad, p_unidad, p_observaciones);
END;
$$;

-- PROCEDURE: sp_insertar_asignacion_establo(integer, integer, date, character varying)
CREATE PROCEDURE public.sp_insertar_asignacion_establo(IN p_id_caballo integer, IN p_id_establo integer, IN p_fecha_asignacion date, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO asignacion_establo (id_caballo, id_establo, fecha_asignacion, estado)
    VALUES (p_id_caballo, p_id_establo, p_fecha_asignacion, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_barrio(integer, integer, integer, integer, character varying)
CREATE PROCEDURE public.sp_insertar_barrio(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_id_distrito integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO barrio (id_pais, id_provincia, id_canton, id_distrito, nombre_barrio)
    VALUES (p_id_pais, p_id_provincia, p_id_canton, p_id_distrito, p_nombre);
END;
$$;

-- PROCEDURE: sp_insertar_beneficio_propietario(integer, character varying, numeric, character varying)
CREATE PROCEDURE public.sp_insertar_beneficio_propietario(IN p_id_propietario integer, IN p_tipo character varying, IN p_porcentaje numeric, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO beneficio_propietario (id_propietario, tipo_beneficio, porcentaje_descuento, fecha_asignacion, estado)
    VALUES (p_id_propietario, p_tipo, p_porcentaje, CURRENT_DATE, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_caballo(character varying, character varying, date, character varying, integer, numeric, character varying, integer)
CREATE PROCEDURE public.sp_insertar_caballo(IN p_codigo character varying, IN p_nombre character varying, IN p_fecha_nacimiento date, IN p_sexo character varying, IN p_id_raza integer, IN p_peso_kg numeric, IN p_estado_salud character varying, IN p_id_propietario integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO caballo (codigo_unico, nombre, fecha_nacimiento, sexo, id_raza, peso_kg, estado_salud, id_propietario)
    VALUES (p_codigo, p_nombre, p_fecha_nacimiento, p_sexo, p_id_raza, p_peso_kg, p_estado_salud, p_id_propietario);
END;
$$;

-- PROCEDURE: sp_insertar_canton(integer, integer, character varying)
CREATE PROCEDURE public.sp_insertar_canton(IN p_id_pais integer, IN p_id_provincia integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO canton (id_pais, id_provincia, nombre_canton) VALUES (p_id_pais, p_id_provincia, p_nombre);
END;
$$;

-- PROCEDURE: sp_insertar_correo_propietario(integer, character varying, character varying)
CREATE PROCEDURE public.sp_insertar_correo_propietario(IN p_id_propietario integer, IN p_correo character varying, IN p_tipo character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO correo_propietario (id_propietario, correo, tipo) VALUES (p_id_propietario, p_correo, p_tipo);
END;
$$;

-- PROCEDURE: sp_insertar_detalle_factura(integer, integer, character varying, numeric, numeric)
CREATE PROCEDURE public.sp_insertar_detalle_factura(IN p_id_factura integer, IN p_id_inscripcion integer, IN p_descripcion character varying, IN p_cantidad numeric, IN p_precio_unitario numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO detalle_factura (
        id_factura, id_inscripcion, descripcion,
        cantidad, precio_unitario, subtotal_linea
    ) VALUES (
        p_id_factura, p_id_inscripcion, p_descripcion,
        p_cantidad, p_precio_unitario,
        ROUND(p_cantidad * p_precio_unitario, 2)
    );
END;
$$;

-- PROCEDURE: sp_insertar_distrito(integer, integer, integer, character varying)
CREATE PROCEDURE public.sp_insertar_distrito(IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO distrito (id_pais, id_provincia, id_canton, nombre_distrito)
    VALUES (p_id_pais, p_id_provincia, p_id_canton, p_nombre);
END;
$$;

-- PROCEDURE: sp_insertar_establo(character varying, character varying, integer, character varying)
CREATE PROCEDURE public.sp_insertar_establo(IN p_codigo character varying, IN p_ubicacion character varying, IN p_capacidad integer, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO establo (codigo, ubicacion, capacidad, estado)
    VALUES (p_codigo, p_ubicacion, p_capacidad, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_estado_pago(character varying, character varying)
CREATE PROCEDURE public.sp_insertar_estado_pago(IN p_nombre character varying, IN p_descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO estado_pago (nombre_estado, descripcion) VALUES (p_nombre, p_descripcion);
END;
$$;

-- PROCEDURE: sp_insertar_evento(character varying, character varying, timestamp without time zone, character varying, numeric, numeric, numeric, character varying)
CREATE PROCEDURE public.sp_insertar_evento(IN p_codigo character varying, IN p_nombre character varying, IN p_fecha timestamp without time zone, IN p_tipo character varying, IN p_distancia numeric, IN p_premio numeric, IN p_precio_inscripcion numeric, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO evento (codigo_evento, nombre, fecha, tipo_carrera, distancia_metros, premio_total, precio_inscripcion, estado)
    VALUES (p_codigo, p_nombre, p_fecha, p_tipo, p_distancia, p_premio, p_precio_inscripcion, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_factura(character varying, integer, integer, numeric, numeric, integer, date)
CREATE PROCEDURE public.sp_insertar_factura(IN p_codigo_factura character varying, IN p_id_propietario integer, IN p_id_evento integer, IN p_subtotal numeric, IN p_porcentaje_desc numeric, IN p_id_estado_pago integer, IN p_fecha_vencimiento date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_monto_descuento  DECIMAL(12,2);
    v_base_imponible   DECIMAL(12,2);
    v_impuesto_iva     DECIMAL(12,2);
    v_comision_admin   DECIMAL(12,2);
    v_total            DECIMAL(12,2);
BEGIN
    v_monto_descuento := ROUND(p_subtotal * (p_porcentaje_desc / 100), 2);
    v_base_imponible  := p_subtotal - v_monto_descuento;
    v_impuesto_iva    := ROUND(v_base_imponible * 0.13, 2);
    v_comision_admin  := ROUND(v_base_imponible * 0.05, 2);
    v_total           := v_base_imponible + v_impuesto_iva + v_comision_admin;

    INSERT INTO factura (
        codigo_factura, id_propietario, id_evento,
        subtotal, porcentaje_descuento, monto_descuento,
        base_imponible, impuesto_iva, comision_admin, total,
        id_estado_pago, fecha_emision, fecha_vencimiento
    ) VALUES (
        p_codigo_factura, p_id_propietario, p_id_evento,
        p_subtotal, p_porcentaje_desc, v_monto_descuento,
        v_base_imponible, v_impuesto_iva, v_comision_admin, v_total,
        p_id_estado_pago, CURRENT_DATE, p_fecha_vencimiento
    );
END;
$$;

-- PROCEDURE: sp_insertar_historial_transaccion(integer, numeric, integer, character varying, character varying)
CREATE PROCEDURE public.sp_insertar_historial_transaccion(IN p_id_factura integer, IN p_monto numeric, IN p_id_metodo_pago integer, IN p_referencia character varying, IN p_numero_comprobante character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO historial_transaccion (
        id_factura, monto, id_metodo_pago,
        referencia, numero_comprobante, estado
    ) VALUES (
        p_id_factura, p_monto, p_id_metodo_pago,
        p_referencia, p_numero_comprobante, 'Registrado'
    );
END;
$$;

-- PROCEDURE: sp_insertar_historial_veterinario(character varying, integer, integer, text, text, date, date, text)
CREATE PROCEDURE public.sp_insertar_historial_veterinario(IN p_codigo character varying, IN p_id_caballo integer, IN p_id_veterinario integer, IN p_diagnostico text, IN p_tratamiento text, IN p_fecha_revision date, IN p_fecha_vencimiento date, IN p_observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO historial_veterinario (
        codigo_registro, id_caballo, id_veterinario, diagnostico, tratamiento,
        fecha_revision, fecha_vencimiento_certificado, certificado_vigente, observaciones
    ) VALUES (
        p_codigo, p_id_caballo, p_id_veterinario, p_diagnostico, p_tratamiento,
        p_fecha_revision, p_fecha_vencimiento,
        CASE WHEN p_fecha_vencimiento >= CURRENT_DATE THEN TRUE ELSE FALSE END,
        p_observaciones
    );
END;
$$;

-- PROCEDURE: sp_insertar_inscripcion(character varying, integer, integer, date, character varying, text)
CREATE PROCEDURE public.sp_insertar_inscripcion(IN p_codigo character varying, IN p_id_evento integer, IN p_id_caballo integer, IN p_fecha date, IN p_estado character varying, IN p_observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO inscripcion (codigo_inscripcion, id_evento, id_caballo, fecha_inscripcion, estado, observaciones)
    VALUES (p_codigo, p_id_evento, p_id_caballo, p_fecha, p_estado, p_observaciones);
END;
$$;

-- PROCEDURE: sp_insertar_metodo_pago(character varying, character varying)
CREATE PROCEDURE public.sp_insertar_metodo_pago(IN p_nombre character varying, IN p_descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO metodo_pago (nombre_metodo_pago, descripcion) VALUES (p_nombre, p_descripcion);
END;
$$;

-- PROCEDURE: sp_insertar_pais(character varying)
CREATE PROCEDURE public.sp_insertar_pais(IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO pais (nombre_pais) VALUES (p_nombre);
END;
$$;

-- PROCEDURE: sp_insertar_propietario(character varying, character varying, character varying, character varying, integer, integer, integer, integer, integer, character varying)
CREATE PROCEDURE public.sp_insertar_propietario(IN p_cedula character varying, IN p_nombre character varying, IN p_apellido1 character varying, IN p_apellido2 character varying, IN p_id_pais integer, IN p_id_provincia integer, IN p_id_canton integer, IN p_id_distrito integer, IN p_id_barrio integer, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO propietario (cedula, nombre, apellido1, apellido2, id_pais, id_provincia,
        id_canton, id_distrito, id_barrio, descuento_proxima_factura, estado)
    VALUES (p_cedula, p_nombre, p_apellido1, p_apellido2, p_id_pais, p_id_provincia,
        p_id_canton, p_id_distrito, p_id_barrio, FALSE, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_proveedor(character varying, character varying, character varying, character varying, character varying)
CREATE PROCEDURE public.sp_insertar_proveedor(IN p_nombre character varying, IN p_contacto character varying, IN p_telefono character varying, IN p_correo character varying, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO proveedor (nombre, contacto, telefono, correo, estado)
    VALUES (p_nombre, p_contacto, p_telefono, p_correo, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_provincia(integer, character varying)
CREATE PROCEDURE public.sp_insertar_provincia(IN p_id_pais integer, IN p_nombre character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO provincia (id_pais, nombre_provincia) VALUES (p_id_pais, p_nombre);
END;
$$;

-- PROCEDURE: sp_insertar_raza(character varying, character varying, character varying)
CREATE PROCEDURE public.sp_insertar_raza(IN p_nombre character varying, IN p_descripcion character varying, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO raza (nombre_raza, descripcion, estado) VALUES (p_nombre, p_descripcion, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_resultado_carrera(integer, integer, time without time zone, numeric, text)
CREATE PROCEDURE public.sp_insertar_resultado_carrera(IN p_id_inscripcion integer, IN p_posicion integer, IN p_tiempo time without time zone, IN p_premio numeric, IN p_observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO resultado_carrera (id_inscripcion, posicion, tiempo_registro, premio_obtenido, observaciones)
    VALUES (p_id_inscripcion, p_posicion, p_tiempo, p_premio, p_observaciones);
END;
$$;

-- PROCEDURE: sp_insertar_rol(character varying, character varying)
CREATE PROCEDURE public.sp_insertar_rol(IN p_nombre character varying, IN p_descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO rol (nombre_rol, descripcion) VALUES (p_nombre, p_descripcion);
END;
$$;

-- PROCEDURE: sp_insertar_suministro(character varying, character varying, character varying, integer, numeric, date, character varying, character varying)
CREATE PROCEDURE public.sp_insertar_suministro(IN p_codigo character varying, IN p_nombre character varying, IN p_tipo character varying, IN p_id_proveedor integer, IN p_cantidad numeric, IN p_fecha_ingreso date, IN p_unidad character varying, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO suministro (codigo, nombre_suministro, tipo, id_proveedor, cantidad_disponible, fecha_ingreso, unidad_medida, estado)
    VALUES (p_codigo, p_nombre, p_tipo, p_id_proveedor, p_cantidad, p_fecha_ingreso, p_unidad, p_estado);
END;
$$;

-- PROCEDURE: sp_insertar_telefono_propietario(integer, character varying, character varying)
CREATE PROCEDURE public.sp_insertar_telefono_propietario(IN p_id_propietario integer, IN p_numero character varying, IN p_tipo character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO telefono_propietario (id_propietario, numero, tipo) VALUES (p_id_propietario, p_numero, p_tipo);
END;
$$;

-- PROCEDURE: sp_insertar_usuario(character varying, character varying, integer, integer, integer)
CREATE PROCEDURE public.sp_insertar_usuario(IN p_nombre character varying, IN p_contrasena_hash character varying, IN p_id_rol integer, IN p_id_propietario integer, IN p_id_veterinario integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO usuario (nombre, contrasena_hash, id_rol, id_propietario, id_veterinario, activo)
    VALUES (p_nombre, p_contrasena_hash, p_id_rol, p_id_propietario, p_id_veterinario, TRUE);
END;
$$;

-- PROCEDURE: sp_insertar_veterinario(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying)
CREATE PROCEDURE public.sp_insertar_veterinario(IN p_cedula character varying, IN p_nombre character varying, IN p_apellido1 character varying, IN p_apellido2 character varying, IN p_numero_colegio character varying, IN p_telefono character varying, IN p_correo character varying, IN p_estado character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO veterinario (cedula, nombre, apellido1, apellido2, numero_colegio, telefono, correo, estado)
    VALUES (p_cedula, p_nombre, p_apellido1, p_apellido2, p_numero_colegio, p_telefono, p_correo, p_estado);
END;
$$;

-- PROCEDURE: sp_registrar_pago_factura(integer, numeric, integer, character varying, character varying)
CREATE PROCEDURE public.sp_registrar_pago_factura(IN p_id_factura integer, IN p_monto numeric, IN p_id_metodo_pago integer, IN p_referencia character varying, IN p_numero_comprobante character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO historial_transaccion (id_factura, monto, id_metodo_pago, referencia, numero_comprobante, estado)
    VALUES (p_id_factura, p_monto, p_id_metodo_pago, p_referencia, p_numero_comprobante, 'Registrado');
END;
$$;

-- TABLE: alerta_certificacion
CREATE TABLE public.alerta_certificacion (
    id_alerta integer NOT NULL,
    id_caballo integer NOT NULL,
    mensaje character varying(500) NOT NULL,
    estado character varying(20) DEFAULT 'Pendiente'::character varying NOT NULL,
    fecha_alerta timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_alerta_certificacion_estado CHECK (((estado)::text = ANY ((ARRAY['Pendiente'::character varying, 'Atendida'::character varying])::text[])))
);

-- SEQUENCE: alerta_certificacion_id_alerta_seq
ALTER TABLE public.alerta_certificacion ALTER COLUMN id_alerta ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.alerta_certificacion_id_alerta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: alimentacion
CREATE TABLE public.alimentacion (
    id_alimentacion integer NOT NULL,
    id_caballo integer NOT NULL,
    id_suministro integer NOT NULL,
    fecha date NOT NULL,
    cantidad numeric(8,2) NOT NULL,
    unidad character varying(20) NOT NULL,
    observaciones text,
    CONSTRAINT ck_alimentacion_cantidad CHECK ((cantidad > (0)::numeric))
);

-- SEQUENCE: alimentacion_id_alimentacion_seq
ALTER TABLE public.alimentacion ALTER COLUMN id_alimentacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.alimentacion_id_alimentacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: asignacion_establo
CREATE TABLE public.asignacion_establo (
    id_asignacion integer NOT NULL,
    id_caballo integer NOT NULL,
    id_establo integer NOT NULL,
    fecha_asignacion date NOT NULL,
    fecha_salida date,
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_asignacion_estado CHECK (((estado)::text = ANY ((ARRAY['Activa'::character varying, 'Finalizada'::character varying])::text[]))),
    CONSTRAINT ck_asignacion_fechas CHECK (((fecha_salida IS NULL) OR (fecha_salida >= fecha_asignacion)))
);

-- SEQUENCE: asignacion_establo_id_asignacion_seq
ALTER TABLE public.asignacion_establo ALTER COLUMN id_asignacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.asignacion_establo_id_asignacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: barrio
CREATE TABLE public.barrio (
    id_pais integer NOT NULL,
    id_provincia integer NOT NULL,
    id_canton integer NOT NULL,
    id_distrito integer NOT NULL,
    id_barrio integer NOT NULL,
    nombre_barrio character varying(100) NOT NULL
);

-- SEQUENCE: barrio_id_barrio_seq
ALTER TABLE public.barrio ALTER COLUMN id_barrio ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.barrio_id_barrio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: beneficio_propietario
CREATE TABLE public.beneficio_propietario (
    id_beneficio integer NOT NULL,
    id_propietario integer NOT NULL,
    tipo_beneficio character varying(100) NOT NULL,
    porcentaje_descuento numeric(5,2) NOT NULL,
    fecha_asignacion date DEFAULT CURRENT_DATE NOT NULL,
    fecha_aplicacion date,
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_beneficio_estado CHECK (((estado)::text = ANY ((ARRAY['Pendiente'::character varying, 'Aplicado'::character varying, 'Cancelado'::character varying])::text[]))),
    CONSTRAINT ck_beneficio_porcentaje CHECK (((porcentaje_descuento >= (0)::numeric) AND (porcentaje_descuento <= (100)::numeric)))
);

-- SEQUENCE: beneficio_propietario_id_beneficio_seq
ALTER TABLE public.beneficio_propietario ALTER COLUMN id_beneficio ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.beneficio_propietario_id_beneficio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_alimentacion
CREATE TABLE public.bitacora_alimentacion (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_alimentacion_2026_t1
CREATE TABLE public.bitacora_alimentacion_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_alimentacion_2026_t2
CREATE TABLE public.bitacora_alimentacion_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_alimentacion_2026_t3
CREATE TABLE public.bitacora_alimentacion_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_alimentacion_2026_t4
CREATE TABLE public.bitacora_alimentacion_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_alimentacion_id_bitacora_seq
ALTER TABLE public.bitacora_alimentacion ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_alimentacion_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_alimentacion_otros
CREATE TABLE public.bitacora_alimentacion_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_asignacion_establo
CREATE TABLE public.bitacora_asignacion_establo (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_asignacion_establo_2026_t1
CREATE TABLE public.bitacora_asignacion_establo_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_asignacion_establo_2026_t2
CREATE TABLE public.bitacora_asignacion_establo_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_asignacion_establo_2026_t3
CREATE TABLE public.bitacora_asignacion_establo_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_asignacion_establo_2026_t4
CREATE TABLE public.bitacora_asignacion_establo_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_asignacion_establo_id_bitacora_seq
ALTER TABLE public.bitacora_asignacion_establo ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_asignacion_establo_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_asignacion_establo_otros
CREATE TABLE public.bitacora_asignacion_establo_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_barrio
CREATE TABLE public.bitacora_barrio (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_barrio_2026_t1
CREATE TABLE public.bitacora_barrio_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_barrio_2026_t2
CREATE TABLE public.bitacora_barrio_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_barrio_2026_t3
CREATE TABLE public.bitacora_barrio_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_barrio_2026_t4
CREATE TABLE public.bitacora_barrio_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_barrio_id_bitacora_seq
ALTER TABLE public.bitacora_barrio ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_barrio_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_barrio_otros
CREATE TABLE public.bitacora_barrio_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_beneficio_propietario
CREATE TABLE public.bitacora_beneficio_propietario (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_beneficio_propietario_2026_t1
CREATE TABLE public.bitacora_beneficio_propietario_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_beneficio_propietario_2026_t2
CREATE TABLE public.bitacora_beneficio_propietario_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_beneficio_propietario_2026_t3
CREATE TABLE public.bitacora_beneficio_propietario_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_beneficio_propietario_2026_t4
CREATE TABLE public.bitacora_beneficio_propietario_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_beneficio_propietario_id_bitacora_seq
ALTER TABLE public.bitacora_beneficio_propietario ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_beneficio_propietario_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_beneficio_propietario_otros
CREATE TABLE public.bitacora_beneficio_propietario_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_caballo
CREATE TABLE public.bitacora_caballo (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_caballo_2026_t1
CREATE TABLE public.bitacora_caballo_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_caballo_2026_t2
CREATE TABLE public.bitacora_caballo_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_caballo_2026_t3
CREATE TABLE public.bitacora_caballo_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_caballo_2026_t4
CREATE TABLE public.bitacora_caballo_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_caballo_id_bitacora_seq
ALTER TABLE public.bitacora_caballo ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_caballo_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_caballo_otros
CREATE TABLE public.bitacora_caballo_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_detalle_factura
CREATE TABLE public.bitacora_detalle_factura (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_detalle_factura_2026_t1
CREATE TABLE public.bitacora_detalle_factura_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_detalle_factura_2026_t2
CREATE TABLE public.bitacora_detalle_factura_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_detalle_factura_2026_t3
CREATE TABLE public.bitacora_detalle_factura_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_detalle_factura_2026_t4
CREATE TABLE public.bitacora_detalle_factura_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_detalle_factura_id_bitacora_seq
ALTER TABLE public.bitacora_detalle_factura ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_detalle_factura_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_detalle_factura_otros
CREATE TABLE public.bitacora_detalle_factura_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_evento
CREATE TABLE public.bitacora_evento (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_evento_2026_t1
CREATE TABLE public.bitacora_evento_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_evento_2026_t2
CREATE TABLE public.bitacora_evento_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_evento_2026_t3
CREATE TABLE public.bitacora_evento_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_evento_2026_t4
CREATE TABLE public.bitacora_evento_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_evento_id_bitacora_seq
ALTER TABLE public.bitacora_evento ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_evento_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_evento_otros
CREATE TABLE public.bitacora_evento_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_factura
CREATE TABLE public.bitacora_factura (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_factura_2026_t1
CREATE TABLE public.bitacora_factura_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_factura_2026_t2
CREATE TABLE public.bitacora_factura_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_factura_2026_t3
CREATE TABLE public.bitacora_factura_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_factura_2026_t4
CREATE TABLE public.bitacora_factura_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_factura_id_bitacora_seq
ALTER TABLE public.bitacora_factura ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_factura_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_factura_otros
CREATE TABLE public.bitacora_factura_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_transaccion
CREATE TABLE public.bitacora_historial_transaccion (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_historial_transaccion_2026_t1
CREATE TABLE public.bitacora_historial_transaccion_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_transaccion_2026_t2
CREATE TABLE public.bitacora_historial_transaccion_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_transaccion_2026_t3
CREATE TABLE public.bitacora_historial_transaccion_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_transaccion_2026_t4
CREATE TABLE public.bitacora_historial_transaccion_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_historial_transaccion_id_bitacora_seq
ALTER TABLE public.bitacora_historial_transaccion ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_historial_transaccion_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_historial_transaccion_otros
CREATE TABLE public.bitacora_historial_transaccion_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_veterinario
CREATE TABLE public.bitacora_historial_veterinario (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_historial_veterinario_2026_t1
CREATE TABLE public.bitacora_historial_veterinario_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_veterinario_2026_t2
CREATE TABLE public.bitacora_historial_veterinario_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_veterinario_2026_t3
CREATE TABLE public.bitacora_historial_veterinario_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_historial_veterinario_2026_t4
CREATE TABLE public.bitacora_historial_veterinario_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_historial_veterinario_id_bitacora_seq
ALTER TABLE public.bitacora_historial_veterinario ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_historial_veterinario_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_historial_veterinario_otros
CREATE TABLE public.bitacora_historial_veterinario_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_inscripcion
CREATE TABLE public.bitacora_inscripcion (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_inscripcion_2026_t1
CREATE TABLE public.bitacora_inscripcion_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_inscripcion_2026_t2
CREATE TABLE public.bitacora_inscripcion_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_inscripcion_2026_t3
CREATE TABLE public.bitacora_inscripcion_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_inscripcion_2026_t4
CREATE TABLE public.bitacora_inscripcion_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_inscripcion_id_bitacora_seq
ALTER TABLE public.bitacora_inscripcion ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_inscripcion_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_inscripcion_otros
CREATE TABLE public.bitacora_inscripcion_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_propietario
CREATE TABLE public.bitacora_propietario (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_propietario_2026_t1
CREATE TABLE public.bitacora_propietario_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_propietario_2026_t2
CREATE TABLE public.bitacora_propietario_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_propietario_2026_t3
CREATE TABLE public.bitacora_propietario_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_propietario_2026_t4
CREATE TABLE public.bitacora_propietario_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_propietario_id_bitacora_seq
ALTER TABLE public.bitacora_propietario ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_propietario_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_propietario_otros
CREATE TABLE public.bitacora_propietario_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_proveedor
CREATE TABLE public.bitacora_proveedor (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_proveedor_2026_t1
CREATE TABLE public.bitacora_proveedor_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_proveedor_2026_t2
CREATE TABLE public.bitacora_proveedor_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_proveedor_2026_t3
CREATE TABLE public.bitacora_proveedor_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_proveedor_2026_t4
CREATE TABLE public.bitacora_proveedor_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_proveedor_id_bitacora_seq
ALTER TABLE public.bitacora_proveedor ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_proveedor_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_proveedor_otros
CREATE TABLE public.bitacora_proveedor_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_resultado_carrera
CREATE TABLE public.bitacora_resultado_carrera (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_resultado_carrera_2026_t1
CREATE TABLE public.bitacora_resultado_carrera_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_resultado_carrera_2026_t2
CREATE TABLE public.bitacora_resultado_carrera_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_resultado_carrera_2026_t3
CREATE TABLE public.bitacora_resultado_carrera_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_resultado_carrera_2026_t4
CREATE TABLE public.bitacora_resultado_carrera_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_resultado_carrera_id_bitacora_seq
ALTER TABLE public.bitacora_resultado_carrera ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_resultado_carrera_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_resultado_carrera_otros
CREATE TABLE public.bitacora_resultado_carrera_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_suministro
CREATE TABLE public.bitacora_suministro (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_suministro_2026_t1
CREATE TABLE public.bitacora_suministro_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_suministro_2026_t2
CREATE TABLE public.bitacora_suministro_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_suministro_2026_t3
CREATE TABLE public.bitacora_suministro_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_suministro_2026_t4
CREATE TABLE public.bitacora_suministro_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_suministro_id_bitacora_seq
ALTER TABLE public.bitacora_suministro ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_suministro_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_suministro_otros
CREATE TABLE public.bitacora_suministro_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_usuario
CREATE TABLE public.bitacora_usuario (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_usuario_2026_t1
CREATE TABLE public.bitacora_usuario_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_usuario_2026_t2
CREATE TABLE public.bitacora_usuario_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_usuario_2026_t3
CREATE TABLE public.bitacora_usuario_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_usuario_2026_t4
CREATE TABLE public.bitacora_usuario_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_usuario_id_bitacora_seq
ALTER TABLE public.bitacora_usuario ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_usuario_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_usuario_otros
CREATE TABLE public.bitacora_usuario_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_veterinario
CREATE TABLE public.bitacora_veterinario (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
)
PARTITION BY RANGE (fecha_registro);

-- TABLE: bitacora_veterinario_2026_t1
CREATE TABLE public.bitacora_veterinario_2026_t1 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_veterinario_2026_t2
CREATE TABLE public.bitacora_veterinario_2026_t2 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_veterinario_2026_t3
CREATE TABLE public.bitacora_veterinario_2026_t3 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: bitacora_veterinario_2026_t4
CREATE TABLE public.bitacora_veterinario_2026_t4 (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- SEQUENCE: bitacora_veterinario_id_bitacora_seq
ALTER TABLE public.bitacora_veterinario ALTER COLUMN id_bitacora ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.bitacora_veterinario_id_bitacora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: bitacora_veterinario_otros
CREATE TABLE public.bitacora_veterinario_otros (
    id_bitacora bigint NOT NULL,
    id_registro_afectado integer NOT NULL,
    tabla_afectada character varying(80) NOT NULL,
    accion character varying(20) NOT NULL,
    usuario_bd character varying(80) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);

-- TABLE: caballo
CREATE TABLE public.caballo (
    id_caballo integer NOT NULL,
    codigo_unico character varying(20) NOT NULL,
    nombre character varying(100) NOT NULL,
    fecha_nacimiento date NOT NULL,
    sexo character varying(10) NOT NULL,
    id_raza integer NOT NULL,
    peso_kg numeric(6,2) NOT NULL,
    estado_salud character varying(30) NOT NULL,
    id_propietario integer NOT NULL,
    CONSTRAINT ck_caballo_estado_salud CHECK (((estado_salud)::text = ANY ((ARRAY['Saludable'::character varying, 'EnTratamiento'::character varying, 'NoApto'::character varying])::text[]))),
    CONSTRAINT ck_caballo_peso CHECK ((peso_kg > (0)::numeric)),
    CONSTRAINT ck_caballo_sexo CHECK (((sexo)::text = ANY ((ARRAY['Macho'::character varying, 'Hembra'::character varying])::text[])))
);

-- SEQUENCE: caballo_id_caballo_seq
ALTER TABLE public.caballo ALTER COLUMN id_caballo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.caballo_id_caballo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: canton
CREATE TABLE public.canton (
    id_pais integer NOT NULL,
    id_provincia integer NOT NULL,
    id_canton integer NOT NULL,
    nombre_canton character varying(100) NOT NULL
);

-- SEQUENCE: canton_id_canton_seq
ALTER TABLE public.canton ALTER COLUMN id_canton ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.canton_id_canton_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: correo_propietario
CREATE TABLE public.correo_propietario (
    id_correo integer NOT NULL,
    id_propietario integer NOT NULL,
    correo character varying(150) NOT NULL,
    tipo character varying(20) NOT NULL,
    CONSTRAINT ck_correo_tipo CHECK (((tipo)::text = ANY ((ARRAY['Personal'::character varying, 'Trabajo'::character varying, 'Otro'::character varying])::text[])))
);

-- SEQUENCE: correo_propietario_id_correo_seq
ALTER TABLE public.correo_propietario ALTER COLUMN id_correo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.correo_propietario_id_correo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: detalle_factura
CREATE TABLE public.detalle_factura (
    id_detalle integer NOT NULL,
    id_factura integer NOT NULL,
    id_inscripcion integer NOT NULL,
    descripcion character varying(200) NOT NULL,
    cantidad numeric(8,2) NOT NULL,
    precio_unitario numeric(12,2) NOT NULL,
    subtotal_linea numeric(12,2) NOT NULL,
    CONSTRAINT ck_detalle_cantidad CHECK ((cantidad > (0)::numeric)),
    CONSTRAINT ck_detalle_precio CHECK ((precio_unitario >= (0)::numeric)),
    CONSTRAINT ck_detalle_subtotal CHECK ((subtotal_linea >= (0)::numeric))
);

-- SEQUENCE: detalle_factura_id_detalle_seq
ALTER TABLE public.detalle_factura ALTER COLUMN id_detalle ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.detalle_factura_id_detalle_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: distrito
CREATE TABLE public.distrito (
    id_pais integer NOT NULL,
    id_provincia integer NOT NULL,
    id_canton integer NOT NULL,
    id_distrito integer NOT NULL,
    nombre_distrito character varying(100) NOT NULL
);

-- SEQUENCE: distrito_id_distrito_seq
ALTER TABLE public.distrito ALTER COLUMN id_distrito ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.distrito_id_distrito_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: establo
CREATE TABLE public.establo (
    id_establo integer NOT NULL,
    codigo character varying(20) NOT NULL,
    ubicacion character varying(200) NOT NULL,
    capacidad integer NOT NULL,
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_establo_capacidad CHECK ((capacidad > 0)),
    CONSTRAINT ck_establo_estado CHECK (((estado)::text = ANY ((ARRAY['Disponible'::character varying, 'Lleno'::character varying, 'Mantenimiento'::character varying])::text[])))
);

-- SEQUENCE: establo_id_establo_seq
ALTER TABLE public.establo ALTER COLUMN id_establo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.establo_id_establo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: estado_pago
CREATE TABLE public.estado_pago (
    id_estado_pago integer NOT NULL,
    nombre_estado character varying(30) NOT NULL,
    descripcion character varying(200)
);

-- SEQUENCE: estado_pago_id_estado_pago_seq
ALTER TABLE public.estado_pago ALTER COLUMN id_estado_pago ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.estado_pago_id_estado_pago_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: evento
CREATE TABLE public.evento (
    id_evento integer NOT NULL,
    codigo_evento character varying(20) NOT NULL,
    nombre character varying(150) NOT NULL,
    fecha timestamp without time zone NOT NULL,
    tipo_carrera character varying(80) NOT NULL,
    distancia_metros numeric(8,2) NOT NULL,
    premio_total numeric(12,2) NOT NULL,
    precio_inscripcion numeric(10,2) NOT NULL,
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_evento_distancia CHECK ((distancia_metros > (0)::numeric)),
    CONSTRAINT ck_evento_estado CHECK (((estado)::text = ANY ((ARRAY['Programado'::character varying, 'EnCurso'::character varying, 'Finalizado'::character varying, 'Cancelado'::character varying])::text[]))),
    CONSTRAINT ck_evento_precio_inscripcion CHECK ((precio_inscripcion >= (0)::numeric)),
    CONSTRAINT ck_evento_premio CHECK ((premio_total >= (0)::numeric))
);

-- SEQUENCE: evento_id_evento_seq
ALTER TABLE public.evento ALTER COLUMN id_evento ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.evento_id_evento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: factura
CREATE TABLE public.factura (
    id_factura integer NOT NULL,
    codigo_factura character varying(30) NOT NULL,
    id_propietario integer NOT NULL,
    id_evento integer NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    porcentaje_descuento numeric(5,2) NOT NULL,
    monto_descuento numeric(12,2) NOT NULL,
    base_imponible numeric(12,2) NOT NULL,
    impuesto_iva numeric(12,2) NOT NULL,
    comision_admin numeric(12,2) NOT NULL,
    total numeric(12,2) NOT NULL,
    id_estado_pago integer NOT NULL,
    fecha_emision date DEFAULT CURRENT_DATE NOT NULL,
    fecha_vencimiento date,
    CONSTRAINT ck_factura_base_imponible CHECK ((base_imponible >= (0)::numeric)),
    CONSTRAINT ck_factura_comision CHECK ((comision_admin >= (0)::numeric)),
    CONSTRAINT ck_factura_fechas CHECK (((fecha_vencimiento IS NULL) OR (fecha_vencimiento >= fecha_emision))),
    CONSTRAINT ck_factura_impuesto_iva CHECK ((impuesto_iva >= (0)::numeric)),
    CONSTRAINT ck_factura_monto_descuento CHECK ((monto_descuento >= (0)::numeric)),
    CONSTRAINT ck_factura_porcentaje_descuento CHECK (((porcentaje_descuento >= (0)::numeric) AND (porcentaje_descuento <= (100)::numeric))),
    CONSTRAINT ck_factura_subtotal CHECK ((subtotal >= (0)::numeric)),
    CONSTRAINT ck_factura_total CHECK ((total >= (0)::numeric))
);

-- SEQUENCE: factura_id_factura_seq
ALTER TABLE public.factura ALTER COLUMN id_factura ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.factura_id_factura_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: historial_transaccion
CREATE TABLE public.historial_transaccion (
    id_transaccion integer NOT NULL,
    id_factura integer NOT NULL,
    fecha_pago timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    monto numeric(12,2) NOT NULL,
    id_metodo_pago integer NOT NULL,
    referencia character varying(100),
    numero_comprobante character varying(100),
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_transaccion_estado CHECK (((estado)::text = ANY ((ARRAY['Registrado'::character varying, 'Anulado'::character varying])::text[]))),
    CONSTRAINT ck_transaccion_monto CHECK ((monto > (0)::numeric))
);

-- SEQUENCE: historial_transaccion_id_transaccion_seq
ALTER TABLE public.historial_transaccion ALTER COLUMN id_transaccion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.historial_transaccion_id_transaccion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: historial_veterinario
CREATE TABLE public.historial_veterinario (
    id_historial integer NOT NULL,
    codigo_registro character varying(20) NOT NULL,
    id_caballo integer NOT NULL,
    id_veterinario integer NOT NULL,
    diagnostico text NOT NULL,
    tratamiento text,
    fecha_revision date NOT NULL,
    fecha_vencimiento_certificado date NOT NULL,
    certificado_vigente boolean NOT NULL,
    observaciones text,
    CONSTRAINT ck_historial_fechas CHECK ((fecha_vencimiento_certificado >= fecha_revision))
);

-- SEQUENCE: historial_veterinario_id_historial_seq
ALTER TABLE public.historial_veterinario ALTER COLUMN id_historial ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.historial_veterinario_id_historial_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: inscripcion
CREATE TABLE public.inscripcion (
    id_inscripcion integer NOT NULL,
    codigo_inscripcion character varying(20) NOT NULL,
    id_evento integer NOT NULL,
    id_caballo integer NOT NULL,
    fecha_inscripcion date NOT NULL,
    estado character varying(20) NOT NULL,
    observaciones text,
    CONSTRAINT ck_inscripcion_estado CHECK (((estado)::text = ANY ((ARRAY['Pendiente'::character varying, 'Aprobada'::character varying, 'Rechazada'::character varying, 'Cancelada'::character varying])::text[])))
);

-- SEQUENCE: inscripcion_id_inscripcion_seq
ALTER TABLE public.inscripcion ALTER COLUMN id_inscripcion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.inscripcion_id_inscripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: metodo_pago
CREATE TABLE public.metodo_pago (
    id_metodo_pago integer NOT NULL,
    nombre_metodo_pago character varying(50) NOT NULL,
    descripcion character varying(200)
);

-- SEQUENCE: metodo_pago_id_metodo_pago_seq
ALTER TABLE public.metodo_pago ALTER COLUMN id_metodo_pago ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.metodo_pago_id_metodo_pago_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: pais
CREATE TABLE public.pais (
    id_pais integer NOT NULL,
    nombre_pais character varying(100) NOT NULL
);

-- SEQUENCE: pais_id_pais_seq
ALTER TABLE public.pais ALTER COLUMN id_pais ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.pais_id_pais_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: propietario
CREATE TABLE public.propietario (
    id_propietario integer NOT NULL,
    cedula character varying(20) NOT NULL,
    nombre character varying(80) NOT NULL,
    apellido1 character varying(50) NOT NULL,
    apellido2 character varying(50),
    id_pais integer NOT NULL,
    id_provincia integer NOT NULL,
    id_canton integer NOT NULL,
    id_distrito integer NOT NULL,
    id_barrio integer NOT NULL,
    descuento_proxima_factura boolean DEFAULT false NOT NULL,
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_propietario_estado CHECK (((estado)::text = ANY ((ARRAY['Activo'::character varying, 'Inactivo'::character varying])::text[])))
);

-- SEQUENCE: propietario_id_propietario_seq
ALTER TABLE public.propietario ALTER COLUMN id_propietario ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.propietario_id_propietario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: proveedor
CREATE TABLE public.proveedor (
    id_proveedor integer NOT NULL,
    nombre character varying(150) NOT NULL,
    contacto character varying(100),
    telefono character varying(20),
    correo character varying(150),
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_proveedor_estado CHECK (((estado)::text = ANY ((ARRAY['Activo'::character varying, 'Inactivo'::character varying])::text[])))
);

-- SEQUENCE: proveedor_id_proveedor_seq
ALTER TABLE public.proveedor ALTER COLUMN id_proveedor ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.proveedor_id_proveedor_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: provincia
CREATE TABLE public.provincia (
    id_pais integer NOT NULL,
    id_provincia integer NOT NULL,
    nombre_provincia character varying(100) NOT NULL
);

-- SEQUENCE: provincia_id_provincia_seq
ALTER TABLE public.provincia ALTER COLUMN id_provincia ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.provincia_id_provincia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: raza
CREATE TABLE public.raza (
    id_raza integer NOT NULL,
    nombre_raza character varying(80) NOT NULL,
    descripcion character varying(200),
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_raza_estado CHECK (((estado)::text = ANY ((ARRAY['Activo'::character varying, 'Inactivo'::character varying])::text[])))
);

-- SEQUENCE: raza_id_raza_seq
ALTER TABLE public.raza ALTER COLUMN id_raza ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.raza_id_raza_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: resultado_carrera
CREATE TABLE public.resultado_carrera (
    id_resultado integer NOT NULL,
    id_inscripcion integer NOT NULL,
    posicion integer NOT NULL,
    tiempo_registro time without time zone NOT NULL,
    premio_obtenido numeric(12,2) NOT NULL,
    observaciones text,
    fecha_registro date DEFAULT CURRENT_DATE NOT NULL,
    CONSTRAINT ck_resultado_posicion CHECK ((posicion > 0)),
    CONSTRAINT ck_resultado_premio CHECK ((premio_obtenido >= (0)::numeric))
);

-- SEQUENCE: resultado_carrera_id_resultado_seq
ALTER TABLE public.resultado_carrera ALTER COLUMN id_resultado ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.resultado_carrera_id_resultado_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: rol
CREATE TABLE public.rol (
    id_rol integer NOT NULL,
    nombre_rol character varying(50) NOT NULL,
    descripcion character varying(200)
);

-- SEQUENCE: rol_id_rol_seq
ALTER TABLE public.rol ALTER COLUMN id_rol ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.rol_id_rol_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: suministro
CREATE TABLE public.suministro (
    id_suministro integer NOT NULL,
    codigo character varying(20) NOT NULL,
    nombre_suministro character varying(150) NOT NULL,
    tipo character varying(80) NOT NULL,
    id_proveedor integer NOT NULL,
    cantidad_disponible numeric(10,2) NOT NULL,
    fecha_ingreso date NOT NULL,
    unidad_medida character varying(20) NOT NULL,
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_suministro_cantidad CHECK ((cantidad_disponible >= (0)::numeric)),
    CONSTRAINT ck_suministro_estado CHECK (((estado)::text = ANY ((ARRAY['Disponible'::character varying, 'Agotado'::character varying, 'Inactivo'::character varying])::text[]))),
    CONSTRAINT ck_suministro_tipo CHECK (((tipo)::text = ANY ((ARRAY['Alimento'::character varying, 'Medicina'::character varying, 'Limpieza'::character varying, 'Herramienta'::character varying, 'Otro'::character varying])::text[])))
);

-- SEQUENCE: suministro_id_suministro_seq
ALTER TABLE public.suministro ALTER COLUMN id_suministro ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.suministro_id_suministro_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: telefono_propietario
CREATE TABLE public.telefono_propietario (
    id_telefono integer NOT NULL,
    id_propietario integer NOT NULL,
    numero character varying(20) NOT NULL,
    tipo character varying(20) NOT NULL,
    CONSTRAINT ck_telefono_tipo CHECK (((tipo)::text = ANY ((ARRAY['Personal'::character varying, 'Trabajo'::character varying, 'Otro'::character varying])::text[])))
);

-- SEQUENCE: telefono_propietario_id_telefono_seq
ALTER TABLE public.telefono_propietario ALTER COLUMN id_telefono ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.telefono_propietario_id_telefono_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: usuario
CREATE TABLE public.usuario (
    id_usuario integer NOT NULL,
    nombre character varying(50) NOT NULL,
    contrasena_hash character varying(255) NOT NULL,
    id_rol integer NOT NULL,
    id_propietario integer,
    id_veterinario integer,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_usuario_tipo_persona CHECK ((NOT ((id_propietario IS NOT NULL) AND (id_veterinario IS NOT NULL))))
);

-- SEQUENCE: usuario_id_usuario_seq
ALTER TABLE public.usuario ALTER COLUMN id_usuario ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.usuario_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE: veterinario
CREATE TABLE public.veterinario (
    id_veterinario integer NOT NULL,
    cedula character varying(20) NOT NULL,
    nombre character varying(80) NOT NULL,
    apellido1 character varying(50) NOT NULL,
    apellido2 character varying(50),
    numero_colegio character varying(30) NOT NULL,
    telefono character varying(20),
    correo character varying(150),
    estado character varying(20) NOT NULL,
    CONSTRAINT ck_veterinario_estado CHECK (((estado)::text = ANY ((ARRAY['Activo'::character varying, 'Inactivo'::character varying])::text[])))
);

-- SEQUENCE: veterinario_id_veterinario_seq
ALTER TABLE public.veterinario ALTER COLUMN id_veterinario ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.veterinario_id_veterinario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

-- TABLE ATTACH: bitacora_alimentacion_2026_t1
ALTER TABLE ONLY public.bitacora_alimentacion ATTACH PARTITION public.bitacora_alimentacion_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_alimentacion_2026_t2
ALTER TABLE ONLY public.bitacora_alimentacion ATTACH PARTITION public.bitacora_alimentacion_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_alimentacion_2026_t3
ALTER TABLE ONLY public.bitacora_alimentacion ATTACH PARTITION public.bitacora_alimentacion_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_alimentacion_2026_t4
ALTER TABLE ONLY public.bitacora_alimentacion ATTACH PARTITION public.bitacora_alimentacion_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_alimentacion_otros
ALTER TABLE ONLY public.bitacora_alimentacion ATTACH PARTITION public.bitacora_alimentacion_otros DEFAULT;

-- TABLE ATTACH: bitacora_asignacion_establo_2026_t1
ALTER TABLE ONLY public.bitacora_asignacion_establo ATTACH PARTITION public.bitacora_asignacion_establo_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_asignacion_establo_2026_t2
ALTER TABLE ONLY public.bitacora_asignacion_establo ATTACH PARTITION public.bitacora_asignacion_establo_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_asignacion_establo_2026_t3
ALTER TABLE ONLY public.bitacora_asignacion_establo ATTACH PARTITION public.bitacora_asignacion_establo_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_asignacion_establo_2026_t4
ALTER TABLE ONLY public.bitacora_asignacion_establo ATTACH PARTITION public.bitacora_asignacion_establo_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_asignacion_establo_otros
ALTER TABLE ONLY public.bitacora_asignacion_establo ATTACH PARTITION public.bitacora_asignacion_establo_otros DEFAULT;

-- TABLE ATTACH: bitacora_barrio_2026_t1
ALTER TABLE ONLY public.bitacora_barrio ATTACH PARTITION public.bitacora_barrio_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_barrio_2026_t2
ALTER TABLE ONLY public.bitacora_barrio ATTACH PARTITION public.bitacora_barrio_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_barrio_2026_t3
ALTER TABLE ONLY public.bitacora_barrio ATTACH PARTITION public.bitacora_barrio_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_barrio_2026_t4
ALTER TABLE ONLY public.bitacora_barrio ATTACH PARTITION public.bitacora_barrio_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_barrio_otros
ALTER TABLE ONLY public.bitacora_barrio ATTACH PARTITION public.bitacora_barrio_otros DEFAULT;

-- TABLE ATTACH: bitacora_beneficio_propietario_2026_t1
ALTER TABLE ONLY public.bitacora_beneficio_propietario ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_beneficio_propietario_2026_t2
ALTER TABLE ONLY public.bitacora_beneficio_propietario ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_beneficio_propietario_2026_t3
ALTER TABLE ONLY public.bitacora_beneficio_propietario ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_beneficio_propietario_2026_t4
ALTER TABLE ONLY public.bitacora_beneficio_propietario ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_beneficio_propietario_otros
ALTER TABLE ONLY public.bitacora_beneficio_propietario ATTACH PARTITION public.bitacora_beneficio_propietario_otros DEFAULT;

-- TABLE ATTACH: bitacora_caballo_2026_t1
ALTER TABLE ONLY public.bitacora_caballo ATTACH PARTITION public.bitacora_caballo_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_caballo_2026_t2
ALTER TABLE ONLY public.bitacora_caballo ATTACH PARTITION public.bitacora_caballo_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_caballo_2026_t3
ALTER TABLE ONLY public.bitacora_caballo ATTACH PARTITION public.bitacora_caballo_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_caballo_2026_t4
ALTER TABLE ONLY public.bitacora_caballo ATTACH PARTITION public.bitacora_caballo_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_caballo_otros
ALTER TABLE ONLY public.bitacora_caballo ATTACH PARTITION public.bitacora_caballo_otros DEFAULT;

-- TABLE ATTACH: bitacora_detalle_factura_2026_t1
ALTER TABLE ONLY public.bitacora_detalle_factura ATTACH PARTITION public.bitacora_detalle_factura_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_detalle_factura_2026_t2
ALTER TABLE ONLY public.bitacora_detalle_factura ATTACH PARTITION public.bitacora_detalle_factura_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_detalle_factura_2026_t3
ALTER TABLE ONLY public.bitacora_detalle_factura ATTACH PARTITION public.bitacora_detalle_factura_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_detalle_factura_2026_t4
ALTER TABLE ONLY public.bitacora_detalle_factura ATTACH PARTITION public.bitacora_detalle_factura_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_detalle_factura_otros
ALTER TABLE ONLY public.bitacora_detalle_factura ATTACH PARTITION public.bitacora_detalle_factura_otros DEFAULT;

-- TABLE ATTACH: bitacora_evento_2026_t1
ALTER TABLE ONLY public.bitacora_evento ATTACH PARTITION public.bitacora_evento_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_evento_2026_t2
ALTER TABLE ONLY public.bitacora_evento ATTACH PARTITION public.bitacora_evento_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_evento_2026_t3
ALTER TABLE ONLY public.bitacora_evento ATTACH PARTITION public.bitacora_evento_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_evento_2026_t4
ALTER TABLE ONLY public.bitacora_evento ATTACH PARTITION public.bitacora_evento_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_evento_otros
ALTER TABLE ONLY public.bitacora_evento ATTACH PARTITION public.bitacora_evento_otros DEFAULT;

-- TABLE ATTACH: bitacora_factura_2026_t1
ALTER TABLE ONLY public.bitacora_factura ATTACH PARTITION public.bitacora_factura_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_factura_2026_t2
ALTER TABLE ONLY public.bitacora_factura ATTACH PARTITION public.bitacora_factura_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_factura_2026_t3
ALTER TABLE ONLY public.bitacora_factura ATTACH PARTITION public.bitacora_factura_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_factura_2026_t4
ALTER TABLE ONLY public.bitacora_factura ATTACH PARTITION public.bitacora_factura_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_factura_otros
ALTER TABLE ONLY public.bitacora_factura ATTACH PARTITION public.bitacora_factura_otros DEFAULT;

-- TABLE ATTACH: bitacora_historial_transaccion_2026_t1
ALTER TABLE ONLY public.bitacora_historial_transaccion ATTACH PARTITION public.bitacora_historial_transaccion_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_transaccion_2026_t2
ALTER TABLE ONLY public.bitacora_historial_transaccion ATTACH PARTITION public.bitacora_historial_transaccion_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_transaccion_2026_t3
ALTER TABLE ONLY public.bitacora_historial_transaccion ATTACH PARTITION public.bitacora_historial_transaccion_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_transaccion_2026_t4
ALTER TABLE ONLY public.bitacora_historial_transaccion ATTACH PARTITION public.bitacora_historial_transaccion_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_transaccion_otros
ALTER TABLE ONLY public.bitacora_historial_transaccion ATTACH PARTITION public.bitacora_historial_transaccion_otros DEFAULT;

-- TABLE ATTACH: bitacora_historial_veterinario_2026_t1
ALTER TABLE ONLY public.bitacora_historial_veterinario ATTACH PARTITION public.bitacora_historial_veterinario_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_veterinario_2026_t2
ALTER TABLE ONLY public.bitacora_historial_veterinario ATTACH PARTITION public.bitacora_historial_veterinario_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_veterinario_2026_t3
ALTER TABLE ONLY public.bitacora_historial_veterinario ATTACH PARTITION public.bitacora_historial_veterinario_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_veterinario_2026_t4
ALTER TABLE ONLY public.bitacora_historial_veterinario ATTACH PARTITION public.bitacora_historial_veterinario_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_historial_veterinario_otros
ALTER TABLE ONLY public.bitacora_historial_veterinario ATTACH PARTITION public.bitacora_historial_veterinario_otros DEFAULT;

-- TABLE ATTACH: bitacora_inscripcion_2026_t1
ALTER TABLE ONLY public.bitacora_inscripcion ATTACH PARTITION public.bitacora_inscripcion_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_inscripcion_2026_t2
ALTER TABLE ONLY public.bitacora_inscripcion ATTACH PARTITION public.bitacora_inscripcion_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_inscripcion_2026_t3
ALTER TABLE ONLY public.bitacora_inscripcion ATTACH PARTITION public.bitacora_inscripcion_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_inscripcion_2026_t4
ALTER TABLE ONLY public.bitacora_inscripcion ATTACH PARTITION public.bitacora_inscripcion_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_inscripcion_otros
ALTER TABLE ONLY public.bitacora_inscripcion ATTACH PARTITION public.bitacora_inscripcion_otros DEFAULT;

-- TABLE ATTACH: bitacora_propietario_2026_t1
ALTER TABLE ONLY public.bitacora_propietario ATTACH PARTITION public.bitacora_propietario_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_propietario_2026_t2
ALTER TABLE ONLY public.bitacora_propietario ATTACH PARTITION public.bitacora_propietario_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_propietario_2026_t3
ALTER TABLE ONLY public.bitacora_propietario ATTACH PARTITION public.bitacora_propietario_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_propietario_2026_t4
ALTER TABLE ONLY public.bitacora_propietario ATTACH PARTITION public.bitacora_propietario_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_propietario_otros
ALTER TABLE ONLY public.bitacora_propietario ATTACH PARTITION public.bitacora_propietario_otros DEFAULT;

-- TABLE ATTACH: bitacora_proveedor_2026_t1
ALTER TABLE ONLY public.bitacora_proveedor ATTACH PARTITION public.bitacora_proveedor_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_proveedor_2026_t2
ALTER TABLE ONLY public.bitacora_proveedor ATTACH PARTITION public.bitacora_proveedor_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_proveedor_2026_t3
ALTER TABLE ONLY public.bitacora_proveedor ATTACH PARTITION public.bitacora_proveedor_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_proveedor_2026_t4
ALTER TABLE ONLY public.bitacora_proveedor ATTACH PARTITION public.bitacora_proveedor_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_proveedor_otros
ALTER TABLE ONLY public.bitacora_proveedor ATTACH PARTITION public.bitacora_proveedor_otros DEFAULT;

-- TABLE ATTACH: bitacora_resultado_carrera_2026_t1
ALTER TABLE ONLY public.bitacora_resultado_carrera ATTACH PARTITION public.bitacora_resultado_carrera_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_resultado_carrera_2026_t2
ALTER TABLE ONLY public.bitacora_resultado_carrera ATTACH PARTITION public.bitacora_resultado_carrera_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_resultado_carrera_2026_t3
ALTER TABLE ONLY public.bitacora_resultado_carrera ATTACH PARTITION public.bitacora_resultado_carrera_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_resultado_carrera_2026_t4
ALTER TABLE ONLY public.bitacora_resultado_carrera ATTACH PARTITION public.bitacora_resultado_carrera_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_resultado_carrera_otros
ALTER TABLE ONLY public.bitacora_resultado_carrera ATTACH PARTITION public.bitacora_resultado_carrera_otros DEFAULT;

-- TABLE ATTACH: bitacora_suministro_2026_t1
ALTER TABLE ONLY public.bitacora_suministro ATTACH PARTITION public.bitacora_suministro_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_suministro_2026_t2
ALTER TABLE ONLY public.bitacora_suministro ATTACH PARTITION public.bitacora_suministro_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_suministro_2026_t3
ALTER TABLE ONLY public.bitacora_suministro ATTACH PARTITION public.bitacora_suministro_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_suministro_2026_t4
ALTER TABLE ONLY public.bitacora_suministro ATTACH PARTITION public.bitacora_suministro_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_suministro_otros
ALTER TABLE ONLY public.bitacora_suministro ATTACH PARTITION public.bitacora_suministro_otros DEFAULT;

-- TABLE ATTACH: bitacora_usuario_2026_t1
ALTER TABLE ONLY public.bitacora_usuario ATTACH PARTITION public.bitacora_usuario_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_usuario_2026_t2
ALTER TABLE ONLY public.bitacora_usuario ATTACH PARTITION public.bitacora_usuario_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_usuario_2026_t3
ALTER TABLE ONLY public.bitacora_usuario ATTACH PARTITION public.bitacora_usuario_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_usuario_2026_t4
ALTER TABLE ONLY public.bitacora_usuario ATTACH PARTITION public.bitacora_usuario_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_usuario_otros
ALTER TABLE ONLY public.bitacora_usuario ATTACH PARTITION public.bitacora_usuario_otros DEFAULT;

-- TABLE ATTACH: bitacora_veterinario_2026_t1
ALTER TABLE ONLY public.bitacora_veterinario ATTACH PARTITION public.bitacora_veterinario_2026_t1 FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-04-01 00:00:00');

-- TABLE ATTACH: bitacora_veterinario_2026_t2
ALTER TABLE ONLY public.bitacora_veterinario ATTACH PARTITION public.bitacora_veterinario_2026_t2 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-07-01 00:00:00');

-- TABLE ATTACH: bitacora_veterinario_2026_t3
ALTER TABLE ONLY public.bitacora_veterinario ATTACH PARTITION public.bitacora_veterinario_2026_t3 FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-10-01 00:00:00');

-- TABLE ATTACH: bitacora_veterinario_2026_t4
ALTER TABLE ONLY public.bitacora_veterinario ATTACH PARTITION public.bitacora_veterinario_2026_t4 FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2027-01-01 00:00:00');

-- TABLE ATTACH: bitacora_veterinario_otros
ALTER TABLE ONLY public.bitacora_veterinario ATTACH PARTITION public.bitacora_veterinario_otros DEFAULT;

-- SEQUENCE SET: alerta_certificacion_id_alerta_seq
SELECT pg_catalog.setval('public.alerta_certificacion_id_alerta_seq', 25, true);

-- SEQUENCE SET: alimentacion_id_alimentacion_seq
SELECT pg_catalog.setval('public.alimentacion_id_alimentacion_seq', 25, true);

-- SEQUENCE SET: asignacion_establo_id_asignacion_seq
SELECT pg_catalog.setval('public.asignacion_establo_id_asignacion_seq', 25, true);

-- SEQUENCE SET: barrio_id_barrio_seq
SELECT pg_catalog.setval('public.barrio_id_barrio_seq', 25, true);

-- SEQUENCE SET: beneficio_propietario_id_beneficio_seq
SELECT pg_catalog.setval('public.beneficio_propietario_id_beneficio_seq', 25, true);

-- SEQUENCE SET: bitacora_alimentacion_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_alimentacion_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_asignacion_establo_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_asignacion_establo_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_barrio_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_barrio_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_beneficio_propietario_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_beneficio_propietario_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_caballo_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_caballo_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_detalle_factura_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_detalle_factura_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_evento_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_evento_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_factura_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_factura_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_historial_transaccion_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_historial_transaccion_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_historial_veterinario_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_historial_veterinario_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_inscripcion_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_inscripcion_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_propietario_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_propietario_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_proveedor_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_proveedor_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_resultado_carrera_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_resultado_carrera_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_suministro_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_suministro_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_usuario_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_usuario_id_bitacora_seq', 25, true);

-- SEQUENCE SET: bitacora_veterinario_id_bitacora_seq
SELECT pg_catalog.setval('public.bitacora_veterinario_id_bitacora_seq', 25, true);

-- SEQUENCE SET: caballo_id_caballo_seq
SELECT pg_catalog.setval('public.caballo_id_caballo_seq', 25, true);

-- SEQUENCE SET: canton_id_canton_seq
SELECT pg_catalog.setval('public.canton_id_canton_seq', 25, true);

-- SEQUENCE SET: correo_propietario_id_correo_seq
SELECT pg_catalog.setval('public.correo_propietario_id_correo_seq', 25, true);

-- SEQUENCE SET: detalle_factura_id_detalle_seq
SELECT pg_catalog.setval('public.detalle_factura_id_detalle_seq', 25, true);

-- SEQUENCE SET: distrito_id_distrito_seq
SELECT pg_catalog.setval('public.distrito_id_distrito_seq', 25, true);

-- SEQUENCE SET: establo_id_establo_seq
SELECT pg_catalog.setval('public.establo_id_establo_seq', 25, true);

-- SEQUENCE SET: estado_pago_id_estado_pago_seq
SELECT pg_catalog.setval('public.estado_pago_id_estado_pago_seq', 25, true);

-- SEQUENCE SET: evento_id_evento_seq
SELECT pg_catalog.setval('public.evento_id_evento_seq', 25, true);

-- SEQUENCE SET: factura_id_factura_seq
SELECT pg_catalog.setval('public.factura_id_factura_seq', 25, true);

-- SEQUENCE SET: historial_transaccion_id_transaccion_seq
SELECT pg_catalog.setval('public.historial_transaccion_id_transaccion_seq', 25, true);

-- SEQUENCE SET: historial_veterinario_id_historial_seq
SELECT pg_catalog.setval('public.historial_veterinario_id_historial_seq', 25, true);

-- SEQUENCE SET: inscripcion_id_inscripcion_seq
SELECT pg_catalog.setval('public.inscripcion_id_inscripcion_seq', 25, true);

-- SEQUENCE SET: metodo_pago_id_metodo_pago_seq
SELECT pg_catalog.setval('public.metodo_pago_id_metodo_pago_seq', 25, true);

-- SEQUENCE SET: pais_id_pais_seq
SELECT pg_catalog.setval('public.pais_id_pais_seq', 25, true);

-- SEQUENCE SET: propietario_id_propietario_seq
SELECT pg_catalog.setval('public.propietario_id_propietario_seq', 25, true);

-- SEQUENCE SET: proveedor_id_proveedor_seq
SELECT pg_catalog.setval('public.proveedor_id_proveedor_seq', 25, true);

-- SEQUENCE SET: provincia_id_provincia_seq
SELECT pg_catalog.setval('public.provincia_id_provincia_seq', 25, true);

-- SEQUENCE SET: raza_id_raza_seq
SELECT pg_catalog.setval('public.raza_id_raza_seq', 25, true);

-- SEQUENCE SET: resultado_carrera_id_resultado_seq
SELECT pg_catalog.setval('public.resultado_carrera_id_resultado_seq', 25, true);

-- SEQUENCE SET: rol_id_rol_seq
SELECT pg_catalog.setval('public.rol_id_rol_seq', 25, true);

-- SEQUENCE SET: suministro_id_suministro_seq
SELECT pg_catalog.setval('public.suministro_id_suministro_seq', 25, true);

-- SEQUENCE SET: telefono_propietario_id_telefono_seq
SELECT pg_catalog.setval('public.telefono_propietario_id_telefono_seq', 25, true);

-- SEQUENCE SET: usuario_id_usuario_seq
SELECT pg_catalog.setval('public.usuario_id_usuario_seq', 25, true);

-- SEQUENCE SET: veterinario_id_veterinario_seq
SELECT pg_catalog.setval('public.veterinario_id_veterinario_seq', 25, true);

-- CONSTRAINT: alerta_certificacion alerta_certificacion_pkey
ALTER TABLE ONLY public.alerta_certificacion
    ADD CONSTRAINT alerta_certificacion_pkey PRIMARY KEY (id_alerta);

-- CONSTRAINT: alimentacion alimentacion_pkey
ALTER TABLE ONLY public.alimentacion
    ADD CONSTRAINT alimentacion_pkey PRIMARY KEY (id_alimentacion);

-- CONSTRAINT: asignacion_establo asignacion_establo_pkey
ALTER TABLE ONLY public.asignacion_establo
    ADD CONSTRAINT asignacion_establo_pkey PRIMARY KEY (id_asignacion);

-- CONSTRAINT: beneficio_propietario beneficio_propietario_pkey
ALTER TABLE ONLY public.beneficio_propietario
    ADD CONSTRAINT beneficio_propietario_pkey PRIMARY KEY (id_beneficio);

-- CONSTRAINT: bitacora_alimentacion bitacora_alimentacion_pkey
ALTER TABLE ONLY public.bitacora_alimentacion
    ADD CONSTRAINT bitacora_alimentacion_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_alimentacion_2026_t1 bitacora_alimentacion_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_alimentacion_2026_t1
    ADD CONSTRAINT bitacora_alimentacion_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_alimentacion_2026_t2 bitacora_alimentacion_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_alimentacion_2026_t2
    ADD CONSTRAINT bitacora_alimentacion_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_alimentacion_2026_t3 bitacora_alimentacion_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_alimentacion_2026_t3
    ADD CONSTRAINT bitacora_alimentacion_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_alimentacion_2026_t4 bitacora_alimentacion_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_alimentacion_2026_t4
    ADD CONSTRAINT bitacora_alimentacion_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_alimentacion_otros bitacora_alimentacion_otros_pkey
ALTER TABLE ONLY public.bitacora_alimentacion_otros
    ADD CONSTRAINT bitacora_alimentacion_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_asignacion_establo bitacora_asignacion_establo_pkey
ALTER TABLE ONLY public.bitacora_asignacion_establo
    ADD CONSTRAINT bitacora_asignacion_establo_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_asignacion_establo_2026_t1 bitacora_asignacion_establo_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_asignacion_establo_2026_t1
    ADD CONSTRAINT bitacora_asignacion_establo_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_asignacion_establo_2026_t2 bitacora_asignacion_establo_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_asignacion_establo_2026_t2
    ADD CONSTRAINT bitacora_asignacion_establo_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_asignacion_establo_2026_t3 bitacora_asignacion_establo_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_asignacion_establo_2026_t3
    ADD CONSTRAINT bitacora_asignacion_establo_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_asignacion_establo_2026_t4 bitacora_asignacion_establo_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_asignacion_establo_2026_t4
    ADD CONSTRAINT bitacora_asignacion_establo_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_asignacion_establo_otros bitacora_asignacion_establo_otros_pkey
ALTER TABLE ONLY public.bitacora_asignacion_establo_otros
    ADD CONSTRAINT bitacora_asignacion_establo_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_barrio bitacora_barrio_pkey
ALTER TABLE ONLY public.bitacora_barrio
    ADD CONSTRAINT bitacora_barrio_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_barrio_2026_t1 bitacora_barrio_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_barrio_2026_t1
    ADD CONSTRAINT bitacora_barrio_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_barrio_2026_t2 bitacora_barrio_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_barrio_2026_t2
    ADD CONSTRAINT bitacora_barrio_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_barrio_2026_t3 bitacora_barrio_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_barrio_2026_t3
    ADD CONSTRAINT bitacora_barrio_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_barrio_2026_t4 bitacora_barrio_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_barrio_2026_t4
    ADD CONSTRAINT bitacora_barrio_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_barrio_otros bitacora_barrio_otros_pkey
ALTER TABLE ONLY public.bitacora_barrio_otros
    ADD CONSTRAINT bitacora_barrio_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_beneficio_propietario bitacora_beneficio_propietario_pkey
ALTER TABLE ONLY public.bitacora_beneficio_propietario
    ADD CONSTRAINT bitacora_beneficio_propietario_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_beneficio_propietario_2026_t1 bitacora_beneficio_propietario_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_beneficio_propietario_2026_t1
    ADD CONSTRAINT bitacora_beneficio_propietario_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_beneficio_propietario_2026_t2 bitacora_beneficio_propietario_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_beneficio_propietario_2026_t2
    ADD CONSTRAINT bitacora_beneficio_propietario_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_beneficio_propietario_2026_t3 bitacora_beneficio_propietario_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_beneficio_propietario_2026_t3
    ADD CONSTRAINT bitacora_beneficio_propietario_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_beneficio_propietario_2026_t4 bitacora_beneficio_propietario_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_beneficio_propietario_2026_t4
    ADD CONSTRAINT bitacora_beneficio_propietario_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_beneficio_propietario_otros bitacora_beneficio_propietario_otros_pkey
ALTER TABLE ONLY public.bitacora_beneficio_propietario_otros
    ADD CONSTRAINT bitacora_beneficio_propietario_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_caballo bitacora_caballo_pkey
ALTER TABLE ONLY public.bitacora_caballo
    ADD CONSTRAINT bitacora_caballo_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_caballo_2026_t1 bitacora_caballo_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_caballo_2026_t1
    ADD CONSTRAINT bitacora_caballo_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_caballo_2026_t2 bitacora_caballo_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_caballo_2026_t2
    ADD CONSTRAINT bitacora_caballo_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_caballo_2026_t3 bitacora_caballo_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_caballo_2026_t3
    ADD CONSTRAINT bitacora_caballo_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_caballo_2026_t4 bitacora_caballo_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_caballo_2026_t4
    ADD CONSTRAINT bitacora_caballo_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_caballo_otros bitacora_caballo_otros_pkey
ALTER TABLE ONLY public.bitacora_caballo_otros
    ADD CONSTRAINT bitacora_caballo_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_detalle_factura bitacora_detalle_factura_pkey
ALTER TABLE ONLY public.bitacora_detalle_factura
    ADD CONSTRAINT bitacora_detalle_factura_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_detalle_factura_2026_t1 bitacora_detalle_factura_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_detalle_factura_2026_t1
    ADD CONSTRAINT bitacora_detalle_factura_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_detalle_factura_2026_t2 bitacora_detalle_factura_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_detalle_factura_2026_t2
    ADD CONSTRAINT bitacora_detalle_factura_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_detalle_factura_2026_t3 bitacora_detalle_factura_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_detalle_factura_2026_t3
    ADD CONSTRAINT bitacora_detalle_factura_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_detalle_factura_2026_t4 bitacora_detalle_factura_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_detalle_factura_2026_t4
    ADD CONSTRAINT bitacora_detalle_factura_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_detalle_factura_otros bitacora_detalle_factura_otros_pkey
ALTER TABLE ONLY public.bitacora_detalle_factura_otros
    ADD CONSTRAINT bitacora_detalle_factura_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_evento bitacora_evento_pkey
ALTER TABLE ONLY public.bitacora_evento
    ADD CONSTRAINT bitacora_evento_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_evento_2026_t1 bitacora_evento_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_evento_2026_t1
    ADD CONSTRAINT bitacora_evento_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_evento_2026_t2 bitacora_evento_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_evento_2026_t2
    ADD CONSTRAINT bitacora_evento_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_evento_2026_t3 bitacora_evento_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_evento_2026_t3
    ADD CONSTRAINT bitacora_evento_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_evento_2026_t4 bitacora_evento_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_evento_2026_t4
    ADD CONSTRAINT bitacora_evento_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_evento_otros bitacora_evento_otros_pkey
ALTER TABLE ONLY public.bitacora_evento_otros
    ADD CONSTRAINT bitacora_evento_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_factura bitacora_factura_pkey
ALTER TABLE ONLY public.bitacora_factura
    ADD CONSTRAINT bitacora_factura_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_factura_2026_t1 bitacora_factura_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_factura_2026_t1
    ADD CONSTRAINT bitacora_factura_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_factura_2026_t2 bitacora_factura_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_factura_2026_t2
    ADD CONSTRAINT bitacora_factura_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_factura_2026_t3 bitacora_factura_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_factura_2026_t3
    ADD CONSTRAINT bitacora_factura_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_factura_2026_t4 bitacora_factura_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_factura_2026_t4
    ADD CONSTRAINT bitacora_factura_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_factura_otros bitacora_factura_otros_pkey
ALTER TABLE ONLY public.bitacora_factura_otros
    ADD CONSTRAINT bitacora_factura_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_transaccion bitacora_historial_transaccion_pkey
ALTER TABLE ONLY public.bitacora_historial_transaccion
    ADD CONSTRAINT bitacora_historial_transaccion_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_transaccion_2026_t1 bitacora_historial_transaccion_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_historial_transaccion_2026_t1
    ADD CONSTRAINT bitacora_historial_transaccion_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_transaccion_2026_t2 bitacora_historial_transaccion_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_historial_transaccion_2026_t2
    ADD CONSTRAINT bitacora_historial_transaccion_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_transaccion_2026_t3 bitacora_historial_transaccion_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_historial_transaccion_2026_t3
    ADD CONSTRAINT bitacora_historial_transaccion_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_transaccion_2026_t4 bitacora_historial_transaccion_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_historial_transaccion_2026_t4
    ADD CONSTRAINT bitacora_historial_transaccion_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_transaccion_otros bitacora_historial_transaccion_otros_pkey
ALTER TABLE ONLY public.bitacora_historial_transaccion_otros
    ADD CONSTRAINT bitacora_historial_transaccion_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_veterinario bitacora_historial_veterinario_pkey
ALTER TABLE ONLY public.bitacora_historial_veterinario
    ADD CONSTRAINT bitacora_historial_veterinario_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_veterinario_2026_t1 bitacora_historial_veterinario_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_historial_veterinario_2026_t1
    ADD CONSTRAINT bitacora_historial_veterinario_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_veterinario_2026_t2 bitacora_historial_veterinario_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_historial_veterinario_2026_t2
    ADD CONSTRAINT bitacora_historial_veterinario_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_veterinario_2026_t3 bitacora_historial_veterinario_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_historial_veterinario_2026_t3
    ADD CONSTRAINT bitacora_historial_veterinario_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_veterinario_2026_t4 bitacora_historial_veterinario_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_historial_veterinario_2026_t4
    ADD CONSTRAINT bitacora_historial_veterinario_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_historial_veterinario_otros bitacora_historial_veterinario_otros_pkey
ALTER TABLE ONLY public.bitacora_historial_veterinario_otros
    ADD CONSTRAINT bitacora_historial_veterinario_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_inscripcion bitacora_inscripcion_pkey
ALTER TABLE ONLY public.bitacora_inscripcion
    ADD CONSTRAINT bitacora_inscripcion_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_inscripcion_2026_t1 bitacora_inscripcion_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_inscripcion_2026_t1
    ADD CONSTRAINT bitacora_inscripcion_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_inscripcion_2026_t2 bitacora_inscripcion_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_inscripcion_2026_t2
    ADD CONSTRAINT bitacora_inscripcion_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_inscripcion_2026_t3 bitacora_inscripcion_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_inscripcion_2026_t3
    ADD CONSTRAINT bitacora_inscripcion_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_inscripcion_2026_t4 bitacora_inscripcion_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_inscripcion_2026_t4
    ADD CONSTRAINT bitacora_inscripcion_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_inscripcion_otros bitacora_inscripcion_otros_pkey
ALTER TABLE ONLY public.bitacora_inscripcion_otros
    ADD CONSTRAINT bitacora_inscripcion_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_propietario bitacora_propietario_pkey
ALTER TABLE ONLY public.bitacora_propietario
    ADD CONSTRAINT bitacora_propietario_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_propietario_2026_t1 bitacora_propietario_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_propietario_2026_t1
    ADD CONSTRAINT bitacora_propietario_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_propietario_2026_t2 bitacora_propietario_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_propietario_2026_t2
    ADD CONSTRAINT bitacora_propietario_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_propietario_2026_t3 bitacora_propietario_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_propietario_2026_t3
    ADD CONSTRAINT bitacora_propietario_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_propietario_2026_t4 bitacora_propietario_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_propietario_2026_t4
    ADD CONSTRAINT bitacora_propietario_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_propietario_otros bitacora_propietario_otros_pkey
ALTER TABLE ONLY public.bitacora_propietario_otros
    ADD CONSTRAINT bitacora_propietario_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_proveedor bitacora_proveedor_pkey
ALTER TABLE ONLY public.bitacora_proveedor
    ADD CONSTRAINT bitacora_proveedor_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_proveedor_2026_t1 bitacora_proveedor_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_proveedor_2026_t1
    ADD CONSTRAINT bitacora_proveedor_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_proveedor_2026_t2 bitacora_proveedor_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_proveedor_2026_t2
    ADD CONSTRAINT bitacora_proveedor_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_proveedor_2026_t3 bitacora_proveedor_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_proveedor_2026_t3
    ADD CONSTRAINT bitacora_proveedor_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_proveedor_2026_t4 bitacora_proveedor_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_proveedor_2026_t4
    ADD CONSTRAINT bitacora_proveedor_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_proveedor_otros bitacora_proveedor_otros_pkey
ALTER TABLE ONLY public.bitacora_proveedor_otros
    ADD CONSTRAINT bitacora_proveedor_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_resultado_carrera bitacora_resultado_carrera_pkey
ALTER TABLE ONLY public.bitacora_resultado_carrera
    ADD CONSTRAINT bitacora_resultado_carrera_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_resultado_carrera_2026_t1 bitacora_resultado_carrera_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_resultado_carrera_2026_t1
    ADD CONSTRAINT bitacora_resultado_carrera_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_resultado_carrera_2026_t2 bitacora_resultado_carrera_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_resultado_carrera_2026_t2
    ADD CONSTRAINT bitacora_resultado_carrera_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_resultado_carrera_2026_t3 bitacora_resultado_carrera_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_resultado_carrera_2026_t3
    ADD CONSTRAINT bitacora_resultado_carrera_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_resultado_carrera_2026_t4 bitacora_resultado_carrera_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_resultado_carrera_2026_t4
    ADD CONSTRAINT bitacora_resultado_carrera_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_resultado_carrera_otros bitacora_resultado_carrera_otros_pkey
ALTER TABLE ONLY public.bitacora_resultado_carrera_otros
    ADD CONSTRAINT bitacora_resultado_carrera_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_suministro bitacora_suministro_pkey
ALTER TABLE ONLY public.bitacora_suministro
    ADD CONSTRAINT bitacora_suministro_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_suministro_2026_t1 bitacora_suministro_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_suministro_2026_t1
    ADD CONSTRAINT bitacora_suministro_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_suministro_2026_t2 bitacora_suministro_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_suministro_2026_t2
    ADD CONSTRAINT bitacora_suministro_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_suministro_2026_t3 bitacora_suministro_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_suministro_2026_t3
    ADD CONSTRAINT bitacora_suministro_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_suministro_2026_t4 bitacora_suministro_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_suministro_2026_t4
    ADD CONSTRAINT bitacora_suministro_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_suministro_otros bitacora_suministro_otros_pkey
ALTER TABLE ONLY public.bitacora_suministro_otros
    ADD CONSTRAINT bitacora_suministro_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_usuario bitacora_usuario_pkey
ALTER TABLE ONLY public.bitacora_usuario
    ADD CONSTRAINT bitacora_usuario_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_usuario_2026_t1 bitacora_usuario_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_usuario_2026_t1
    ADD CONSTRAINT bitacora_usuario_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_usuario_2026_t2 bitacora_usuario_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_usuario_2026_t2
    ADD CONSTRAINT bitacora_usuario_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_usuario_2026_t3 bitacora_usuario_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_usuario_2026_t3
    ADD CONSTRAINT bitacora_usuario_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_usuario_2026_t4 bitacora_usuario_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_usuario_2026_t4
    ADD CONSTRAINT bitacora_usuario_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_usuario_otros bitacora_usuario_otros_pkey
ALTER TABLE ONLY public.bitacora_usuario_otros
    ADD CONSTRAINT bitacora_usuario_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_veterinario bitacora_veterinario_pkey
ALTER TABLE ONLY public.bitacora_veterinario
    ADD CONSTRAINT bitacora_veterinario_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_veterinario_2026_t1 bitacora_veterinario_2026_t1_pkey
ALTER TABLE ONLY public.bitacora_veterinario_2026_t1
    ADD CONSTRAINT bitacora_veterinario_2026_t1_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_veterinario_2026_t2 bitacora_veterinario_2026_t2_pkey
ALTER TABLE ONLY public.bitacora_veterinario_2026_t2
    ADD CONSTRAINT bitacora_veterinario_2026_t2_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_veterinario_2026_t3 bitacora_veterinario_2026_t3_pkey
ALTER TABLE ONLY public.bitacora_veterinario_2026_t3
    ADD CONSTRAINT bitacora_veterinario_2026_t3_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_veterinario_2026_t4 bitacora_veterinario_2026_t4_pkey
ALTER TABLE ONLY public.bitacora_veterinario_2026_t4
    ADD CONSTRAINT bitacora_veterinario_2026_t4_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: bitacora_veterinario_otros bitacora_veterinario_otros_pkey
ALTER TABLE ONLY public.bitacora_veterinario_otros
    ADD CONSTRAINT bitacora_veterinario_otros_pkey PRIMARY KEY (id_bitacora, fecha_registro);

-- CONSTRAINT: caballo caballo_codigo_unico_key
ALTER TABLE ONLY public.caballo
    ADD CONSTRAINT caballo_codigo_unico_key UNIQUE (codigo_unico);

-- CONSTRAINT: caballo caballo_pkey
ALTER TABLE ONLY public.caballo
    ADD CONSTRAINT caballo_pkey PRIMARY KEY (id_caballo);

-- CONSTRAINT: correo_propietario correo_propietario_pkey
ALTER TABLE ONLY public.correo_propietario
    ADD CONSTRAINT correo_propietario_pkey PRIMARY KEY (id_correo);

-- CONSTRAINT: detalle_factura detalle_factura_pkey
ALTER TABLE ONLY public.detalle_factura
    ADD CONSTRAINT detalle_factura_pkey PRIMARY KEY (id_detalle);

-- CONSTRAINT: establo establo_codigo_key
ALTER TABLE ONLY public.establo
    ADD CONSTRAINT establo_codigo_key UNIQUE (codigo);

-- CONSTRAINT: establo establo_pkey
ALTER TABLE ONLY public.establo
    ADD CONSTRAINT establo_pkey PRIMARY KEY (id_establo);

-- CONSTRAINT: estado_pago estado_pago_nombre_estado_key
ALTER TABLE ONLY public.estado_pago
    ADD CONSTRAINT estado_pago_nombre_estado_key UNIQUE (nombre_estado);

-- CONSTRAINT: estado_pago estado_pago_pkey
ALTER TABLE ONLY public.estado_pago
    ADD CONSTRAINT estado_pago_pkey PRIMARY KEY (id_estado_pago);

-- CONSTRAINT: evento evento_codigo_evento_key
ALTER TABLE ONLY public.evento
    ADD CONSTRAINT evento_codigo_evento_key UNIQUE (codigo_evento);

-- CONSTRAINT: evento evento_pkey
ALTER TABLE ONLY public.evento
    ADD CONSTRAINT evento_pkey PRIMARY KEY (id_evento);

-- CONSTRAINT: factura factura_codigo_factura_key
ALTER TABLE ONLY public.factura
    ADD CONSTRAINT factura_codigo_factura_key UNIQUE (codigo_factura);

-- CONSTRAINT: factura factura_pkey
ALTER TABLE ONLY public.factura
    ADD CONSTRAINT factura_pkey PRIMARY KEY (id_factura);

-- CONSTRAINT: historial_transaccion historial_transaccion_pkey
ALTER TABLE ONLY public.historial_transaccion
    ADD CONSTRAINT historial_transaccion_pkey PRIMARY KEY (id_transaccion);

-- CONSTRAINT: historial_veterinario historial_veterinario_codigo_registro_key
ALTER TABLE ONLY public.historial_veterinario
    ADD CONSTRAINT historial_veterinario_codigo_registro_key UNIQUE (codigo_registro);

-- CONSTRAINT: historial_veterinario historial_veterinario_pkey
ALTER TABLE ONLY public.historial_veterinario
    ADD CONSTRAINT historial_veterinario_pkey PRIMARY KEY (id_historial);

-- CONSTRAINT: inscripcion inscripcion_codigo_inscripcion_key
ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT inscripcion_codigo_inscripcion_key UNIQUE (codigo_inscripcion);

-- CONSTRAINT: inscripcion inscripcion_pkey
ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT inscripcion_pkey PRIMARY KEY (id_inscripcion);

-- CONSTRAINT: metodo_pago metodo_pago_nombre_metodo_pago_key
ALTER TABLE ONLY public.metodo_pago
    ADD CONSTRAINT metodo_pago_nombre_metodo_pago_key UNIQUE (nombre_metodo_pago);

-- CONSTRAINT: metodo_pago metodo_pago_pkey
ALTER TABLE ONLY public.metodo_pago
    ADD CONSTRAINT metodo_pago_pkey PRIMARY KEY (id_metodo_pago);

-- CONSTRAINT: pais pais_nombre_pais_key
ALTER TABLE ONLY public.pais
    ADD CONSTRAINT pais_nombre_pais_key UNIQUE (nombre_pais);

-- CONSTRAINT: pais pais_pkey
ALTER TABLE ONLY public.pais
    ADD CONSTRAINT pais_pkey PRIMARY KEY (id_pais);

-- CONSTRAINT: barrio pk_barrio
ALTER TABLE ONLY public.barrio
    ADD CONSTRAINT pk_barrio PRIMARY KEY (id_pais, id_provincia, id_canton, id_distrito, id_barrio);

-- CONSTRAINT: canton pk_canton
ALTER TABLE ONLY public.canton
    ADD CONSTRAINT pk_canton PRIMARY KEY (id_pais, id_provincia, id_canton);

-- CONSTRAINT: distrito pk_distrito
ALTER TABLE ONLY public.distrito
    ADD CONSTRAINT pk_distrito PRIMARY KEY (id_pais, id_provincia, id_canton, id_distrito);

-- CONSTRAINT: provincia pk_provincia
ALTER TABLE ONLY public.provincia
    ADD CONSTRAINT pk_provincia PRIMARY KEY (id_pais, id_provincia);

-- CONSTRAINT: propietario propietario_cedula_key
ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_cedula_key UNIQUE (cedula);

-- CONSTRAINT: propietario propietario_pkey
ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT propietario_pkey PRIMARY KEY (id_propietario);

-- CONSTRAINT: proveedor proveedor_pkey
ALTER TABLE ONLY public.proveedor
    ADD CONSTRAINT proveedor_pkey PRIMARY KEY (id_proveedor);

-- CONSTRAINT: raza raza_nombre_raza_key
ALTER TABLE ONLY public.raza
    ADD CONSTRAINT raza_nombre_raza_key UNIQUE (nombre_raza);

-- CONSTRAINT: raza raza_pkey
ALTER TABLE ONLY public.raza
    ADD CONSTRAINT raza_pkey PRIMARY KEY (id_raza);

-- CONSTRAINT: resultado_carrera resultado_carrera_id_inscripcion_key
ALTER TABLE ONLY public.resultado_carrera
    ADD CONSTRAINT resultado_carrera_id_inscripcion_key UNIQUE (id_inscripcion);

-- CONSTRAINT: resultado_carrera resultado_carrera_pkey
ALTER TABLE ONLY public.resultado_carrera
    ADD CONSTRAINT resultado_carrera_pkey PRIMARY KEY (id_resultado);

-- CONSTRAINT: rol rol_nombre_rol_key
ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_nombre_rol_key UNIQUE (nombre_rol);

-- CONSTRAINT: rol rol_pkey
ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (id_rol);

-- CONSTRAINT: suministro suministro_codigo_key
ALTER TABLE ONLY public.suministro
    ADD CONSTRAINT suministro_codigo_key UNIQUE (codigo);

-- CONSTRAINT: suministro suministro_pkey
ALTER TABLE ONLY public.suministro
    ADD CONSTRAINT suministro_pkey PRIMARY KEY (id_suministro);

-- CONSTRAINT: telefono_propietario telefono_propietario_pkey
ALTER TABLE ONLY public.telefono_propietario
    ADD CONSTRAINT telefono_propietario_pkey PRIMARY KEY (id_telefono);

-- CONSTRAINT: barrio uq_barrio_nombre_por_distrito
ALTER TABLE ONLY public.barrio
    ADD CONSTRAINT uq_barrio_nombre_por_distrito UNIQUE (id_pais, id_provincia, id_canton, id_distrito, nombre_barrio);

-- CONSTRAINT: canton uq_canton_nombre_por_provincia
ALTER TABLE ONLY public.canton
    ADD CONSTRAINT uq_canton_nombre_por_provincia UNIQUE (id_pais, id_provincia, nombre_canton);

-- CONSTRAINT: distrito uq_distrito_nombre_por_canton
ALTER TABLE ONLY public.distrito
    ADD CONSTRAINT uq_distrito_nombre_por_canton UNIQUE (id_pais, id_provincia, id_canton, nombre_distrito);

-- CONSTRAINT: inscripcion uq_inscripcion_evento_caballo
ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT uq_inscripcion_evento_caballo UNIQUE (id_evento, id_caballo);

-- CONSTRAINT: provincia uq_provincia_nombre_por_pais
ALTER TABLE ONLY public.provincia
    ADD CONSTRAINT uq_provincia_nombre_por_pais UNIQUE (id_pais, nombre_provincia);

-- CONSTRAINT: usuario usuario_nombre_key
ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_nombre_key UNIQUE (nombre);

-- CONSTRAINT: usuario usuario_pkey
ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id_usuario);

-- CONSTRAINT: veterinario veterinario_cedula_key
ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT veterinario_cedula_key UNIQUE (cedula);

-- CONSTRAINT: veterinario veterinario_numero_colegio_key
ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT veterinario_numero_colegio_key UNIQUE (numero_colegio);

-- CONSTRAINT: veterinario veterinario_pkey
ALTER TABLE ONLY public.veterinario
    ADD CONSTRAINT veterinario_pkey PRIMARY KEY (id_veterinario);

-- INDEX ATTACH: bitacora_alimentacion_2026_t1_pkey
ALTER INDEX public.bitacora_alimentacion_pkey ATTACH PARTITION public.bitacora_alimentacion_2026_t1_pkey;

-- INDEX ATTACH: bitacora_alimentacion_2026_t2_pkey
ALTER INDEX public.bitacora_alimentacion_pkey ATTACH PARTITION public.bitacora_alimentacion_2026_t2_pkey;

-- INDEX ATTACH: bitacora_alimentacion_2026_t3_pkey
ALTER INDEX public.bitacora_alimentacion_pkey ATTACH PARTITION public.bitacora_alimentacion_2026_t3_pkey;

-- INDEX ATTACH: bitacora_alimentacion_2026_t4_pkey
ALTER INDEX public.bitacora_alimentacion_pkey ATTACH PARTITION public.bitacora_alimentacion_2026_t4_pkey;

-- INDEX ATTACH: bitacora_alimentacion_otros_pkey
ALTER INDEX public.bitacora_alimentacion_pkey ATTACH PARTITION public.bitacora_alimentacion_otros_pkey;

-- INDEX ATTACH: bitacora_asignacion_establo_2026_t1_pkey
ALTER INDEX public.bitacora_asignacion_establo_pkey ATTACH PARTITION public.bitacora_asignacion_establo_2026_t1_pkey;

-- INDEX ATTACH: bitacora_asignacion_establo_2026_t2_pkey
ALTER INDEX public.bitacora_asignacion_establo_pkey ATTACH PARTITION public.bitacora_asignacion_establo_2026_t2_pkey;

-- INDEX ATTACH: bitacora_asignacion_establo_2026_t3_pkey
ALTER INDEX public.bitacora_asignacion_establo_pkey ATTACH PARTITION public.bitacora_asignacion_establo_2026_t3_pkey;

-- INDEX ATTACH: bitacora_asignacion_establo_2026_t4_pkey
ALTER INDEX public.bitacora_asignacion_establo_pkey ATTACH PARTITION public.bitacora_asignacion_establo_2026_t4_pkey;

-- INDEX ATTACH: bitacora_asignacion_establo_otros_pkey
ALTER INDEX public.bitacora_asignacion_establo_pkey ATTACH PARTITION public.bitacora_asignacion_establo_otros_pkey;

-- INDEX ATTACH: bitacora_barrio_2026_t1_pkey
ALTER INDEX public.bitacora_barrio_pkey ATTACH PARTITION public.bitacora_barrio_2026_t1_pkey;

-- INDEX ATTACH: bitacora_barrio_2026_t2_pkey
ALTER INDEX public.bitacora_barrio_pkey ATTACH PARTITION public.bitacora_barrio_2026_t2_pkey;

-- INDEX ATTACH: bitacora_barrio_2026_t3_pkey
ALTER INDEX public.bitacora_barrio_pkey ATTACH PARTITION public.bitacora_barrio_2026_t3_pkey;

-- INDEX ATTACH: bitacora_barrio_2026_t4_pkey
ALTER INDEX public.bitacora_barrio_pkey ATTACH PARTITION public.bitacora_barrio_2026_t4_pkey;

-- INDEX ATTACH: bitacora_barrio_otros_pkey
ALTER INDEX public.bitacora_barrio_pkey ATTACH PARTITION public.bitacora_barrio_otros_pkey;

-- INDEX ATTACH: bitacora_beneficio_propietario_2026_t1_pkey
ALTER INDEX public.bitacora_beneficio_propietario_pkey ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t1_pkey;

-- INDEX ATTACH: bitacora_beneficio_propietario_2026_t2_pkey
ALTER INDEX public.bitacora_beneficio_propietario_pkey ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t2_pkey;

-- INDEX ATTACH: bitacora_beneficio_propietario_2026_t3_pkey
ALTER INDEX public.bitacora_beneficio_propietario_pkey ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t3_pkey;

-- INDEX ATTACH: bitacora_beneficio_propietario_2026_t4_pkey
ALTER INDEX public.bitacora_beneficio_propietario_pkey ATTACH PARTITION public.bitacora_beneficio_propietario_2026_t4_pkey;

-- INDEX ATTACH: bitacora_beneficio_propietario_otros_pkey
ALTER INDEX public.bitacora_beneficio_propietario_pkey ATTACH PARTITION public.bitacora_beneficio_propietario_otros_pkey;

-- INDEX ATTACH: bitacora_caballo_2026_t1_pkey
ALTER INDEX public.bitacora_caballo_pkey ATTACH PARTITION public.bitacora_caballo_2026_t1_pkey;

-- INDEX ATTACH: bitacora_caballo_2026_t2_pkey
ALTER INDEX public.bitacora_caballo_pkey ATTACH PARTITION public.bitacora_caballo_2026_t2_pkey;

-- INDEX ATTACH: bitacora_caballo_2026_t3_pkey
ALTER INDEX public.bitacora_caballo_pkey ATTACH PARTITION public.bitacora_caballo_2026_t3_pkey;

-- INDEX ATTACH: bitacora_caballo_2026_t4_pkey
ALTER INDEX public.bitacora_caballo_pkey ATTACH PARTITION public.bitacora_caballo_2026_t4_pkey;

-- INDEX ATTACH: bitacora_caballo_otros_pkey
ALTER INDEX public.bitacora_caballo_pkey ATTACH PARTITION public.bitacora_caballo_otros_pkey;

-- INDEX ATTACH: bitacora_detalle_factura_2026_t1_pkey
ALTER INDEX public.bitacora_detalle_factura_pkey ATTACH PARTITION public.bitacora_detalle_factura_2026_t1_pkey;

-- INDEX ATTACH: bitacora_detalle_factura_2026_t2_pkey
ALTER INDEX public.bitacora_detalle_factura_pkey ATTACH PARTITION public.bitacora_detalle_factura_2026_t2_pkey;

-- INDEX ATTACH: bitacora_detalle_factura_2026_t3_pkey
ALTER INDEX public.bitacora_detalle_factura_pkey ATTACH PARTITION public.bitacora_detalle_factura_2026_t3_pkey;

-- INDEX ATTACH: bitacora_detalle_factura_2026_t4_pkey
ALTER INDEX public.bitacora_detalle_factura_pkey ATTACH PARTITION public.bitacora_detalle_factura_2026_t4_pkey;

-- INDEX ATTACH: bitacora_detalle_factura_otros_pkey
ALTER INDEX public.bitacora_detalle_factura_pkey ATTACH PARTITION public.bitacora_detalle_factura_otros_pkey;

-- INDEX ATTACH: bitacora_evento_2026_t1_pkey
ALTER INDEX public.bitacora_evento_pkey ATTACH PARTITION public.bitacora_evento_2026_t1_pkey;

-- INDEX ATTACH: bitacora_evento_2026_t2_pkey
ALTER INDEX public.bitacora_evento_pkey ATTACH PARTITION public.bitacora_evento_2026_t2_pkey;

-- INDEX ATTACH: bitacora_evento_2026_t3_pkey
ALTER INDEX public.bitacora_evento_pkey ATTACH PARTITION public.bitacora_evento_2026_t3_pkey;

-- INDEX ATTACH: bitacora_evento_2026_t4_pkey
ALTER INDEX public.bitacora_evento_pkey ATTACH PARTITION public.bitacora_evento_2026_t4_pkey;

-- INDEX ATTACH: bitacora_evento_otros_pkey
ALTER INDEX public.bitacora_evento_pkey ATTACH PARTITION public.bitacora_evento_otros_pkey;

-- INDEX ATTACH: bitacora_factura_2026_t1_pkey
ALTER INDEX public.bitacora_factura_pkey ATTACH PARTITION public.bitacora_factura_2026_t1_pkey;

-- INDEX ATTACH: bitacora_factura_2026_t2_pkey
ALTER INDEX public.bitacora_factura_pkey ATTACH PARTITION public.bitacora_factura_2026_t2_pkey;

-- INDEX ATTACH: bitacora_factura_2026_t3_pkey
ALTER INDEX public.bitacora_factura_pkey ATTACH PARTITION public.bitacora_factura_2026_t3_pkey;

-- INDEX ATTACH: bitacora_factura_2026_t4_pkey
ALTER INDEX public.bitacora_factura_pkey ATTACH PARTITION public.bitacora_factura_2026_t4_pkey;

-- INDEX ATTACH: bitacora_factura_otros_pkey
ALTER INDEX public.bitacora_factura_pkey ATTACH PARTITION public.bitacora_factura_otros_pkey;

-- INDEX ATTACH: bitacora_historial_transaccion_2026_t1_pkey
ALTER INDEX public.bitacora_historial_transaccion_pkey ATTACH PARTITION public.bitacora_historial_transaccion_2026_t1_pkey;

-- INDEX ATTACH: bitacora_historial_transaccion_2026_t2_pkey
ALTER INDEX public.bitacora_historial_transaccion_pkey ATTACH PARTITION public.bitacora_historial_transaccion_2026_t2_pkey;

-- INDEX ATTACH: bitacora_historial_transaccion_2026_t3_pkey
ALTER INDEX public.bitacora_historial_transaccion_pkey ATTACH PARTITION public.bitacora_historial_transaccion_2026_t3_pkey;

-- INDEX ATTACH: bitacora_historial_transaccion_2026_t4_pkey
ALTER INDEX public.bitacora_historial_transaccion_pkey ATTACH PARTITION public.bitacora_historial_transaccion_2026_t4_pkey;

-- INDEX ATTACH: bitacora_historial_transaccion_otros_pkey
ALTER INDEX public.bitacora_historial_transaccion_pkey ATTACH PARTITION public.bitacora_historial_transaccion_otros_pkey;

-- INDEX ATTACH: bitacora_historial_veterinario_2026_t1_pkey
ALTER INDEX public.bitacora_historial_veterinario_pkey ATTACH PARTITION public.bitacora_historial_veterinario_2026_t1_pkey;

-- INDEX ATTACH: bitacora_historial_veterinario_2026_t2_pkey
ALTER INDEX public.bitacora_historial_veterinario_pkey ATTACH PARTITION public.bitacora_historial_veterinario_2026_t2_pkey;

-- INDEX ATTACH: bitacora_historial_veterinario_2026_t3_pkey
ALTER INDEX public.bitacora_historial_veterinario_pkey ATTACH PARTITION public.bitacora_historial_veterinario_2026_t3_pkey;

-- INDEX ATTACH: bitacora_historial_veterinario_2026_t4_pkey
ALTER INDEX public.bitacora_historial_veterinario_pkey ATTACH PARTITION public.bitacora_historial_veterinario_2026_t4_pkey;

-- INDEX ATTACH: bitacora_historial_veterinario_otros_pkey
ALTER INDEX public.bitacora_historial_veterinario_pkey ATTACH PARTITION public.bitacora_historial_veterinario_otros_pkey;

-- INDEX ATTACH: bitacora_inscripcion_2026_t1_pkey
ALTER INDEX public.bitacora_inscripcion_pkey ATTACH PARTITION public.bitacora_inscripcion_2026_t1_pkey;

-- INDEX ATTACH: bitacora_inscripcion_2026_t2_pkey
ALTER INDEX public.bitacora_inscripcion_pkey ATTACH PARTITION public.bitacora_inscripcion_2026_t2_pkey;

-- INDEX ATTACH: bitacora_inscripcion_2026_t3_pkey
ALTER INDEX public.bitacora_inscripcion_pkey ATTACH PARTITION public.bitacora_inscripcion_2026_t3_pkey;

-- INDEX ATTACH: bitacora_inscripcion_2026_t4_pkey
ALTER INDEX public.bitacora_inscripcion_pkey ATTACH PARTITION public.bitacora_inscripcion_2026_t4_pkey;

-- INDEX ATTACH: bitacora_inscripcion_otros_pkey
ALTER INDEX public.bitacora_inscripcion_pkey ATTACH PARTITION public.bitacora_inscripcion_otros_pkey;

-- INDEX ATTACH: bitacora_propietario_2026_t1_pkey
ALTER INDEX public.bitacora_propietario_pkey ATTACH PARTITION public.bitacora_propietario_2026_t1_pkey;

-- INDEX ATTACH: bitacora_propietario_2026_t2_pkey
ALTER INDEX public.bitacora_propietario_pkey ATTACH PARTITION public.bitacora_propietario_2026_t2_pkey;

-- INDEX ATTACH: bitacora_propietario_2026_t3_pkey
ALTER INDEX public.bitacora_propietario_pkey ATTACH PARTITION public.bitacora_propietario_2026_t3_pkey;

-- INDEX ATTACH: bitacora_propietario_2026_t4_pkey
ALTER INDEX public.bitacora_propietario_pkey ATTACH PARTITION public.bitacora_propietario_2026_t4_pkey;

-- INDEX ATTACH: bitacora_propietario_otros_pkey
ALTER INDEX public.bitacora_propietario_pkey ATTACH PARTITION public.bitacora_propietario_otros_pkey;

-- INDEX ATTACH: bitacora_proveedor_2026_t1_pkey
ALTER INDEX public.bitacora_proveedor_pkey ATTACH PARTITION public.bitacora_proveedor_2026_t1_pkey;

-- INDEX ATTACH: bitacora_proveedor_2026_t2_pkey
ALTER INDEX public.bitacora_proveedor_pkey ATTACH PARTITION public.bitacora_proveedor_2026_t2_pkey;

-- INDEX ATTACH: bitacora_proveedor_2026_t3_pkey
ALTER INDEX public.bitacora_proveedor_pkey ATTACH PARTITION public.bitacora_proveedor_2026_t3_pkey;

-- INDEX ATTACH: bitacora_proveedor_2026_t4_pkey
ALTER INDEX public.bitacora_proveedor_pkey ATTACH PARTITION public.bitacora_proveedor_2026_t4_pkey;

-- INDEX ATTACH: bitacora_proveedor_otros_pkey
ALTER INDEX public.bitacora_proveedor_pkey ATTACH PARTITION public.bitacora_proveedor_otros_pkey;

-- INDEX ATTACH: bitacora_resultado_carrera_2026_t1_pkey
ALTER INDEX public.bitacora_resultado_carrera_pkey ATTACH PARTITION public.bitacora_resultado_carrera_2026_t1_pkey;

-- INDEX ATTACH: bitacora_resultado_carrera_2026_t2_pkey
ALTER INDEX public.bitacora_resultado_carrera_pkey ATTACH PARTITION public.bitacora_resultado_carrera_2026_t2_pkey;

-- INDEX ATTACH: bitacora_resultado_carrera_2026_t3_pkey
ALTER INDEX public.bitacora_resultado_carrera_pkey ATTACH PARTITION public.bitacora_resultado_carrera_2026_t3_pkey;

-- INDEX ATTACH: bitacora_resultado_carrera_2026_t4_pkey
ALTER INDEX public.bitacora_resultado_carrera_pkey ATTACH PARTITION public.bitacora_resultado_carrera_2026_t4_pkey;

-- INDEX ATTACH: bitacora_resultado_carrera_otros_pkey
ALTER INDEX public.bitacora_resultado_carrera_pkey ATTACH PARTITION public.bitacora_resultado_carrera_otros_pkey;

-- INDEX ATTACH: bitacora_suministro_2026_t1_pkey
ALTER INDEX public.bitacora_suministro_pkey ATTACH PARTITION public.bitacora_suministro_2026_t1_pkey;

-- INDEX ATTACH: bitacora_suministro_2026_t2_pkey
ALTER INDEX public.bitacora_suministro_pkey ATTACH PARTITION public.bitacora_suministro_2026_t2_pkey;

-- INDEX ATTACH: bitacora_suministro_2026_t3_pkey
ALTER INDEX public.bitacora_suministro_pkey ATTACH PARTITION public.bitacora_suministro_2026_t3_pkey;

-- INDEX ATTACH: bitacora_suministro_2026_t4_pkey
ALTER INDEX public.bitacora_suministro_pkey ATTACH PARTITION public.bitacora_suministro_2026_t4_pkey;

-- INDEX ATTACH: bitacora_suministro_otros_pkey
ALTER INDEX public.bitacora_suministro_pkey ATTACH PARTITION public.bitacora_suministro_otros_pkey;

-- INDEX ATTACH: bitacora_usuario_2026_t1_pkey
ALTER INDEX public.bitacora_usuario_pkey ATTACH PARTITION public.bitacora_usuario_2026_t1_pkey;

-- INDEX ATTACH: bitacora_usuario_2026_t2_pkey
ALTER INDEX public.bitacora_usuario_pkey ATTACH PARTITION public.bitacora_usuario_2026_t2_pkey;

-- INDEX ATTACH: bitacora_usuario_2026_t3_pkey
ALTER INDEX public.bitacora_usuario_pkey ATTACH PARTITION public.bitacora_usuario_2026_t3_pkey;

-- INDEX ATTACH: bitacora_usuario_2026_t4_pkey
ALTER INDEX public.bitacora_usuario_pkey ATTACH PARTITION public.bitacora_usuario_2026_t4_pkey;

-- INDEX ATTACH: bitacora_usuario_otros_pkey
ALTER INDEX public.bitacora_usuario_pkey ATTACH PARTITION public.bitacora_usuario_otros_pkey;

-- INDEX ATTACH: bitacora_veterinario_2026_t1_pkey
ALTER INDEX public.bitacora_veterinario_pkey ATTACH PARTITION public.bitacora_veterinario_2026_t1_pkey;

-- INDEX ATTACH: bitacora_veterinario_2026_t2_pkey
ALTER INDEX public.bitacora_veterinario_pkey ATTACH PARTITION public.bitacora_veterinario_2026_t2_pkey;

-- INDEX ATTACH: bitacora_veterinario_2026_t3_pkey
ALTER INDEX public.bitacora_veterinario_pkey ATTACH PARTITION public.bitacora_veterinario_2026_t3_pkey;

-- INDEX ATTACH: bitacora_veterinario_2026_t4_pkey
ALTER INDEX public.bitacora_veterinario_pkey ATTACH PARTITION public.bitacora_veterinario_2026_t4_pkey;

-- INDEX ATTACH: bitacora_veterinario_otros_pkey
ALTER INDEX public.bitacora_veterinario_pkey ATTACH PARTITION public.bitacora_veterinario_otros_pkey;

-- TRIGGER: historial_transaccion trg_actualizar_estado_factura_por_pago
CREATE TRIGGER trg_actualizar_estado_factura_por_pago AFTER INSERT OR DELETE OR UPDATE ON public.historial_transaccion FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_estado_factura_por_pago();

-- TRIGGER: alimentacion trg_bitacora_alimentacion
CREATE TRIGGER trg_bitacora_alimentacion AFTER INSERT OR DELETE OR UPDATE ON public.alimentacion FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_alimentacion');

-- TRIGGER: asignacion_establo trg_bitacora_asignacion_establo
CREATE TRIGGER trg_bitacora_asignacion_establo AFTER INSERT OR DELETE OR UPDATE ON public.asignacion_establo FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_asignacion');

-- TRIGGER: barrio trg_bitacora_barrio
CREATE TRIGGER trg_bitacora_barrio AFTER INSERT OR DELETE OR UPDATE ON public.barrio FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_barrio');

-- TRIGGER: beneficio_propietario trg_bitacora_beneficio_propietario
CREATE TRIGGER trg_bitacora_beneficio_propietario AFTER INSERT OR DELETE OR UPDATE ON public.beneficio_propietario FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_beneficio');

-- TRIGGER: caballo trg_bitacora_caballo
CREATE TRIGGER trg_bitacora_caballo AFTER INSERT OR DELETE OR UPDATE ON public.caballo FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_caballo');

-- TRIGGER: detalle_factura trg_bitacora_detalle_factura
CREATE TRIGGER trg_bitacora_detalle_factura AFTER INSERT OR DELETE OR UPDATE ON public.detalle_factura FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_detalle');

-- TRIGGER: evento trg_bitacora_evento
CREATE TRIGGER trg_bitacora_evento AFTER INSERT OR DELETE OR UPDATE ON public.evento FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_evento');

-- TRIGGER: factura trg_bitacora_factura
CREATE TRIGGER trg_bitacora_factura AFTER INSERT OR DELETE OR UPDATE ON public.factura FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_factura');

-- TRIGGER: historial_transaccion trg_bitacora_historial_transaccion
CREATE TRIGGER trg_bitacora_historial_transaccion AFTER INSERT OR DELETE OR UPDATE ON public.historial_transaccion FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_transaccion');

-- TRIGGER: historial_veterinario trg_bitacora_historial_veterinario
CREATE TRIGGER trg_bitacora_historial_veterinario AFTER INSERT OR DELETE OR UPDATE ON public.historial_veterinario FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_historial');

-- TRIGGER: inscripcion trg_bitacora_inscripcion
CREATE TRIGGER trg_bitacora_inscripcion AFTER INSERT OR DELETE OR UPDATE ON public.inscripcion FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_inscripcion');

-- TRIGGER: propietario trg_bitacora_propietario
CREATE TRIGGER trg_bitacora_propietario AFTER INSERT OR DELETE OR UPDATE ON public.propietario FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_propietario');

-- TRIGGER: proveedor trg_bitacora_proveedor
CREATE TRIGGER trg_bitacora_proveedor AFTER INSERT OR DELETE OR UPDATE ON public.proveedor FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_proveedor');

-- TRIGGER: resultado_carrera trg_bitacora_resultado_carrera
CREATE TRIGGER trg_bitacora_resultado_carrera AFTER INSERT OR DELETE OR UPDATE ON public.resultado_carrera FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_resultado');

-- TRIGGER: suministro trg_bitacora_suministro
CREATE TRIGGER trg_bitacora_suministro AFTER INSERT OR DELETE OR UPDATE ON public.suministro FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_suministro');

-- TRIGGER: usuario trg_bitacora_usuario
CREATE TRIGGER trg_bitacora_usuario AFTER INSERT OR DELETE OR UPDATE ON public.usuario FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_usuario');

-- TRIGGER: veterinario trg_bitacora_veterinario
CREATE TRIGGER trg_bitacora_veterinario AFTER INSERT OR DELETE OR UPDATE ON public.veterinario FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_bitacora('id_veterinario');

-- TRIGGER: alimentacion trg_descontar_suministro_alimentacion
CREATE TRIGGER trg_descontar_suministro_alimentacion AFTER INSERT ON public.alimentacion FOR EACH ROW EXECUTE FUNCTION public.fn_descontar_suministro_alimentacion();

-- TRIGGER: historial_veterinario trg_validar_estado_certificacion
CREATE TRIGGER trg_validar_estado_certificacion BEFORE INSERT OR UPDATE ON public.historial_veterinario FOR EACH ROW EXECUTE FUNCTION public.fn_validar_estado_certificacion();

-- FK CONSTRAINT: alerta_certificacion fk_alerta_certificacion_caballo
ALTER TABLE ONLY public.alerta_certificacion
    ADD CONSTRAINT fk_alerta_certificacion_caballo FOREIGN KEY (id_caballo) REFERENCES public.caballo(id_caballo);

-- FK CONSTRAINT: alimentacion fk_alimentacion_caballo
ALTER TABLE ONLY public.alimentacion
    ADD CONSTRAINT fk_alimentacion_caballo FOREIGN KEY (id_caballo) REFERENCES public.caballo(id_caballo);

-- FK CONSTRAINT: alimentacion fk_alimentacion_suministro
ALTER TABLE ONLY public.alimentacion
    ADD CONSTRAINT fk_alimentacion_suministro FOREIGN KEY (id_suministro) REFERENCES public.suministro(id_suministro);

-- FK CONSTRAINT: asignacion_establo fk_asignacion_caballo
ALTER TABLE ONLY public.asignacion_establo
    ADD CONSTRAINT fk_asignacion_caballo FOREIGN KEY (id_caballo) REFERENCES public.caballo(id_caballo);

-- FK CONSTRAINT: asignacion_establo fk_asignacion_establo
ALTER TABLE ONLY public.asignacion_establo
    ADD CONSTRAINT fk_asignacion_establo FOREIGN KEY (id_establo) REFERENCES public.establo(id_establo);

-- FK CONSTRAINT: barrio fk_barrio_distrito
ALTER TABLE ONLY public.barrio
    ADD CONSTRAINT fk_barrio_distrito FOREIGN KEY (id_pais, id_provincia, id_canton, id_distrito) REFERENCES public.distrito(id_pais, id_provincia, id_canton, id_distrito);

-- FK CONSTRAINT: beneficio_propietario fk_beneficio_propietario
ALTER TABLE ONLY public.beneficio_propietario
    ADD CONSTRAINT fk_beneficio_propietario FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);

-- FK CONSTRAINT: caballo fk_caballo_propietario
ALTER TABLE ONLY public.caballo
    ADD CONSTRAINT fk_caballo_propietario FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);

-- FK CONSTRAINT: caballo fk_caballo_raza
ALTER TABLE ONLY public.caballo
    ADD CONSTRAINT fk_caballo_raza FOREIGN KEY (id_raza) REFERENCES public.raza(id_raza);

-- FK CONSTRAINT: canton fk_canton_provincia
ALTER TABLE ONLY public.canton
    ADD CONSTRAINT fk_canton_provincia FOREIGN KEY (id_pais, id_provincia) REFERENCES public.provincia(id_pais, id_provincia);

-- FK CONSTRAINT: correo_propietario fk_correo_propietario
ALTER TABLE ONLY public.correo_propietario
    ADD CONSTRAINT fk_correo_propietario FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);

-- FK CONSTRAINT: detalle_factura fk_detalle_factura
ALTER TABLE ONLY public.detalle_factura
    ADD CONSTRAINT fk_detalle_factura FOREIGN KEY (id_factura) REFERENCES public.factura(id_factura);

-- FK CONSTRAINT: detalle_factura fk_detalle_inscripcion
ALTER TABLE ONLY public.detalle_factura
    ADD CONSTRAINT fk_detalle_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES public.inscripcion(id_inscripcion);

-- FK CONSTRAINT: distrito fk_distrito_canton
ALTER TABLE ONLY public.distrito
    ADD CONSTRAINT fk_distrito_canton FOREIGN KEY (id_pais, id_provincia, id_canton) REFERENCES public.canton(id_pais, id_provincia, id_canton);

-- FK CONSTRAINT: factura fk_factura_estado_pago
ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_estado_pago FOREIGN KEY (id_estado_pago) REFERENCES public.estado_pago(id_estado_pago);

-- FK CONSTRAINT: factura fk_factura_evento
ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_evento FOREIGN KEY (id_evento) REFERENCES public.evento(id_evento);

-- FK CONSTRAINT: factura fk_factura_propietario
ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_propietario FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);

-- FK CONSTRAINT: historial_veterinario fk_historial_caballo
ALTER TABLE ONLY public.historial_veterinario
    ADD CONSTRAINT fk_historial_caballo FOREIGN KEY (id_caballo) REFERENCES public.caballo(id_caballo);

-- FK CONSTRAINT: historial_veterinario fk_historial_veterinario
ALTER TABLE ONLY public.historial_veterinario
    ADD CONSTRAINT fk_historial_veterinario FOREIGN KEY (id_veterinario) REFERENCES public.veterinario(id_veterinario);

-- FK CONSTRAINT: inscripcion fk_inscripcion_caballo
ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT fk_inscripcion_caballo FOREIGN KEY (id_caballo) REFERENCES public.caballo(id_caballo);

-- FK CONSTRAINT: inscripcion fk_inscripcion_evento
ALTER TABLE ONLY public.inscripcion
    ADD CONSTRAINT fk_inscripcion_evento FOREIGN KEY (id_evento) REFERENCES public.evento(id_evento);

-- FK CONSTRAINT: propietario fk_propietario_barrio
ALTER TABLE ONLY public.propietario
    ADD CONSTRAINT fk_propietario_barrio FOREIGN KEY (id_pais, id_provincia, id_canton, id_distrito, id_barrio) REFERENCES public.barrio(id_pais, id_provincia, id_canton, id_distrito, id_barrio);

-- FK CONSTRAINT: provincia fk_provincia_pais
ALTER TABLE ONLY public.provincia
    ADD CONSTRAINT fk_provincia_pais FOREIGN KEY (id_pais) REFERENCES public.pais(id_pais);

-- FK CONSTRAINT: resultado_carrera fk_resultado_inscripcion
ALTER TABLE ONLY public.resultado_carrera
    ADD CONSTRAINT fk_resultado_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES public.inscripcion(id_inscripcion);

-- FK CONSTRAINT: suministro fk_suministro_proveedor
ALTER TABLE ONLY public.suministro
    ADD CONSTRAINT fk_suministro_proveedor FOREIGN KEY (id_proveedor) REFERENCES public.proveedor(id_proveedor);

-- FK CONSTRAINT: telefono_propietario fk_telefono_propietario
ALTER TABLE ONLY public.telefono_propietario
    ADD CONSTRAINT fk_telefono_propietario FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);

-- FK CONSTRAINT: historial_transaccion fk_transaccion_factura
ALTER TABLE ONLY public.historial_transaccion
    ADD CONSTRAINT fk_transaccion_factura FOREIGN KEY (id_factura) REFERENCES public.factura(id_factura);

-- FK CONSTRAINT: historial_transaccion fk_transaccion_metodo_pago
ALTER TABLE ONLY public.historial_transaccion
    ADD CONSTRAINT fk_transaccion_metodo_pago FOREIGN KEY (id_metodo_pago) REFERENCES public.metodo_pago(id_metodo_pago);

-- FK CONSTRAINT: usuario fk_usuario_propietario
ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_propietario FOREIGN KEY (id_propietario) REFERENCES public.propietario(id_propietario);

-- FK CONSTRAINT: usuario fk_usuario_rol
ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES public.rol(id_rol);

-- FK CONSTRAINT: usuario fk_usuario_veterinario
ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_veterinario FOREIGN KEY (id_veterinario) REFERENCES public.veterinario(id_veterinario);

