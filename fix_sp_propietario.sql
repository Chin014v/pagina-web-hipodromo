-- Fix sp_insertar_propietario para que coincida con la llamada desde C#

DROP PROCEDURE IF EXISTS public.sp_insertar_propietario(
    character varying, character varying, character varying, character varying,
    integer, integer, integer, integer, integer, character varying);

CREATE OR REPLACE PROCEDURE public.sp_insertar_propietario(
    IN p_cedula character varying,
    IN p_nombre character varying,
    IN p_apellido1 character varying,
    IN p_apellido2 character varying,
    IN p_id_barrio integer,
    IN p_estado character varying,
    IN p_telefonos text[],
    IN p_tipos_telefonos text[],
    IN p_correos text[],
    IN p_tipos_correos text[],
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_pais INTEGER;
    v_id_provincia INTEGER;
    v_id_canton INTEGER;
    v_id_distrito INTEGER;
    v_nuevo_id INTEGER;
    i INTEGER;
BEGIN
    -- Obtener la dirección completa a partir del id_barrio
    SELECT b.id_pais, b.id_provincia, b.id_canton, b.id_distrito
    INTO v_id_pais, v_id_provincia, v_id_canton, v_id_distrito
    FROM barrio b
    WHERE b.id_barrio = p_id_barrio;

    IF v_id_pais IS NULL THEN
        RAISE EXCEPTION 'El barrio con id % no existe.', p_id_barrio;
    END IF;

    -- Insertar el propietario
    INSERT INTO propietario (
        cedula, nombre, apellido1, apellido2,
        id_pais, id_provincia, id_canton, id_distrito, id_barrio,
        descuento_proxima_factura, estado
    ) VALUES (
        p_cedula, p_nombre, p_apellido1, p_apellido2,
        v_id_pais, v_id_provincia, v_id_canton, v_id_distrito, p_id_barrio,
        FALSE, p_estado
    )
    RETURNING id_propietario INTO v_nuevo_id;

    p_new_id := v_nuevo_id;

    -- Insertar teléfonos
    IF p_telefonos IS NOT NULL AND array_length(p_telefonos, 1) > 0 THEN
        FOR i IN 1..array_length(p_telefonos, 1) LOOP
            INSERT INTO telefono_propietario (id_propietario, numero, tipo)
            VALUES (v_nuevo_id, p_telefonos[i], p_tipos_telefonos[i]);
        END LOOP;
    END IF;

    -- Insertar correos
    IF p_correos IS NOT NULL AND array_length(p_correos, 1) > 0 THEN
        FOR i IN 1..array_length(p_correos, 1) LOOP
            INSERT INTO correo_propietario (id_propietario, correo, tipo)
            VALUES (v_nuevo_id, p_correos[i], p_tipos_correos[i]);
        END LOOP;
    END IF;
END;
$$;
