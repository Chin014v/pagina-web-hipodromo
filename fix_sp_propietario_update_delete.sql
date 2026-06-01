-- Crear nuevo SP de ACTUALIZAR (nuevos parámetros)
CREATE OR REPLACE PROCEDURE public.sp_actualizar_propietario(
    IN p_id_propietario integer,
    IN p_nombre character varying,
    IN p_apellido1 character varying,
    IN p_estado character varying)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE propietario
    SET nombre = p_nombre,
        apellido1 = p_apellido1,
        estado = p_estado
    WHERE id_propietario = p_id_propietario;
END;
$$;

-- Crear nuevo SP de ELIMINAR (elimina hijos primero)
CREATE OR REPLACE PROCEDURE public.sp_eliminar_propietario(
    IN p_id_propietario integer)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM telefono_propietario WHERE id_propietario = p_id_propietario;
    DELETE FROM correo_propietario WHERE id_propietario = p_id_propietario;
    DELETE FROM beneficio_propietario WHERE id_propietario = p_id_propietario;
    DELETE FROM propietario WHERE id_propietario = p_id_propietario;
END;
$$;
