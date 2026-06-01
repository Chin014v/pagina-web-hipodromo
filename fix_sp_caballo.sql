-- FIX: SPs de Caballo

-- Eliminar SPs viejos
DROP PROCEDURE IF EXISTS public.sp_insertar_caballo(character varying, character varying, date, character varying, integer, numeric, character varying, integer);
DROP PROCEDURE IF EXISTS public.sp_actualizar_caballo(integer, character varying, numeric, integer);
DROP PROCEDURE IF EXISTS public.sp_eliminar_caballo(integer);

-- INSERTAR
CREATE OR REPLACE PROCEDURE public.sp_insertar_caballo(
    IN p_codigo_unico character varying,
    IN p_nombre character varying,
    IN p_fecha_nacimiento date,
    IN p_sexo character varying,
    IN p_id_raza integer,
    IN p_peso_kg numeric,
    IN p_estado_salud character varying,
    IN p_id_propietario integer,
    INOUT p_new_id integer DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nuevo_id integer;
BEGIN
    INSERT INTO caballo (codigo_unico, nombre, fecha_nacimiento, sexo, id_raza, peso_kg, estado_salud, id_propietario)
    VALUES (p_codigo_unico, p_nombre, p_fecha_nacimiento, p_sexo, p_id_raza, p_peso_kg, p_estado_salud, p_id_propietario)
    RETURNING id_caballo INTO v_nuevo_id;
    p_new_id := v_nuevo_id;
END;
$$;

-- ACTUALIZAR
CREATE OR REPLACE PROCEDURE public.sp_actualizar_caballo(
    IN p_id_caballo integer,
    IN p_nombre character varying,
    IN p_peso_kg numeric,
    IN p_estado_salud character varying)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE caballo
    SET nombre = p_nombre,
        peso_kg = p_peso_kg,
        estado_salud = p_estado_salud
    WHERE id_caballo = p_id_caballo;
END;
$$;

-- ELIMINAR
CREATE OR REPLACE PROCEDURE public.sp_eliminar_caballo(
    IN p_id_caballo integer)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM alimentacion WHERE id_caballo = p_id_caballo;
    DELETE FROM asignacion_establo WHERE id_caballo = p_id_caballo;
    DELETE FROM historial_veterinario WHERE id_caballo = p_id_caballo;
    DELETE FROM inscripcion WHERE id_caballo = p_id_caballo;
    DELETE FROM caballo WHERE id_caballo = p_id_caballo;
END;
$$;
