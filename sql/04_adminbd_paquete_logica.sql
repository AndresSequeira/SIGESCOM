-- SIGESCOM - Paso 04
-- Ejecutar conectado como ADMINBD.
-- Paquete principal con la logica obligatoria del proyecto.

-- PACKAGE SPECIFICATION:
-- Esta primera parte declara las funciones y procedimientos disponibles.
-- Es como el "indice" publico del paquete: aqui se define que operaciones puede usar ORDS/APEX.
CREATE OR REPLACE PACKAGE pkg_sigescom AS
    -- Valida correo y password_hash. Retorna el id_usuario si el login es correcto, o 0 si falla.
    FUNCTION fn_validar_login (
        p_correo        IN VARCHAR2,
        p_password_hash IN VARCHAR2
    ) RETURN NUMBER;

    -- Verifica si un correo ya existe. Se usa en el endpoint /auth/validar-correo.
    FUNCTION fn_correo_existe (p_correo IN VARCHAR2) RETURN NUMBER;

    -- Registra un usuario nuevo y devuelve su id por parametro OUT.
    -- Este procedimiento mantiene la forma usada en el Laboratorio 11.
    PROCEDURE sp_registrar_usuario (
        p_nombre_completo IN VARCHAR2,
        p_correo          IN VARCHAR2,
        p_password_hash   IN VARCHAR2,
        p_id_departamento IN NUMBER,
        p_telefono        IN VARCHAR2,
        p_puesto          IN VARCHAR2,
        p_id_usuario      OUT NUMBER
    );

    -- Version tipo funcion del registro de usuario. Retorna directamente el id creado.
    FUNCTION fn_registrar_usuario (
        p_nombre_completo IN VARCHAR2,
        p_correo          IN VARCHAR2,
        p_password_hash   IN VARCHAR2,
        p_id_departamento IN NUMBER,
        p_telefono        IN VARCHAR2,
        p_puesto          IN VARCHAR2
    ) RETURN NUMBER;

    -- Genera un codigo temporal para recuperar contrasena.
    -- Tambien guarda IP y user agent si vienen desde Postman o el frontend.
    FUNCTION fn_generar_codigo_reset (
        p_correo      IN VARCHAR2,
        p_ip          IN VARCHAR2 DEFAULT NULL,
        p_user_agent  IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2;

    -- Cambia la contrasena usando un codigo de recuperacion valido y no usado.
    FUNCTION fn_cambiar_password (
        p_codigo_reset       IN VARCHAR2,
        p_password_hash      IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Valida si un codigo de recuperacion existe, no ha expirado y no ha sido usado.
    FUNCTION fn_validar_codigo_reset (p_codigo_reset IN VARCHAR2) RETURN NUMBER;

    -- Funciones de calculo para solicitudes.
    -- Separarlas permite demostrar reglas de negocio dentro de la base de datos.
    FUNCTION fn_calcular_subtotal (p_id_solicitud IN NUMBER) RETURN NUMBER;
    FUNCTION fn_calcular_impuesto (p_subtotal IN NUMBER) RETURN NUMBER;
    FUNCTION fn_requiere_aprobacion_especial (p_total IN NUMBER) RETURN CHAR;

    -- Recalcula subtotal, impuesto, total y marca si requiere aprobacion especial.
    PROCEDURE sp_recalcular_solicitud (p_id_solicitud IN NUMBER);

    -- Crea una solicitud con encabezado y detalle.
    -- El detalle llega como JSON para simular lo que enviaria un frontend externo.
    PROCEDURE sp_crear_solicitud (
        p_id_usuario_solicitante IN NUMBER,
        p_prioridad              IN VARCHAR2,
        p_justificacion          IN VARCHAR2,
        p_observaciones          IN VARCHAR2,
        p_items_json             IN CLOB,
        p_id_solicitud           OUT NUMBER
    );

    -- Cambia una solicitud de BORRADOR o DEVUELTA a PENDIENTE.
    -- Valida que tenga al menos un item antes de enviarla.
    PROCEDURE sp_enviar_solicitud (
        p_id_solicitud IN NUMBER,
        p_id_usuario   IN NUMBER
    );

    -- Elimina una solicitud solo si esta en BORRADOR y pertenece al usuario.
    PROCEDURE sp_eliminar_solicitud_borrador (
        p_id_solicitud IN NUMBER,
        p_id_usuario   IN NUMBER
    );

    -- Activa o inactiva usuarios desde una accion administrativa.
    -- Se usa para aprobar cuentas que quedaron en PENDIENTE_ACTIVACION.
    PROCEDURE sp_cambiar_estado_usuario (
        p_id_admin   IN NUMBER,
        p_id_usuario IN NUMBER,
        p_estado     IN VARCHAR2
    );

    -- Permite aprobar, rechazar o devolver solicitudes.
    -- Valida que el usuario sea APROBADOR o ADMIN.
    PROCEDURE sp_decidir_solicitud (
        p_id_solicitud      IN NUMBER,
        p_id_usuario_accion IN NUMBER,
        p_decision          IN VARCHAR2,
        p_observacion       IN VARCHAR2
    );

    -- Revisa si un usuario tiene un rol activo especifico.
    FUNCTION fn_usuario_tiene_rol (
        p_id_usuario IN NUMBER,
        p_rol        IN VARCHAR2
    ) RETURN NUMBER;
END pkg_sigescom;
/

-- PACKAGE BODY:
-- Aqui esta la implementacion real de cada funcion y procedimiento declarado arriba.
CREATE OR REPLACE PACKAGE BODY pkg_sigescom AS
    -- Funcion interna para obtener el id numerico de un estado usando su codigo.
    FUNCTION get_estado_id (p_codigo IN VARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT id_estado INTO v_id
        FROM estados_solicitud
        WHERE codigo = p_codigo;
        RETURN v_id;
    END;

    -- Funcion interna para leer parametros configurables como impuesto o monto especial.
    FUNCTION get_param_numero (p_codigo IN VARCHAR2) RETURN NUMBER IS
        v_valor NUMBER;
    BEGIN
        SELECT valor_numero INTO v_valor
        FROM parametros_sistema
        WHERE codigo = p_codigo;
        RETURN v_valor;
    END;

    -- Verifica roles activos del usuario. Devuelve 1 si tiene el rol, 0 si no lo tiene.
    FUNCTION fn_usuario_tiene_rol (
        p_id_usuario IN NUMBER,
        p_rol        IN VARCHAR2
    ) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_total
        FROM usuario_rol ur
        JOIN roles r ON r.id_rol = ur.id_rol
        WHERE ur.id_usuario = p_id_usuario
          AND ur.estado = 'ACTIVO'
          AND r.estado = 'ACTIVO'
          AND r.nombre_rol = UPPER(p_rol);

        RETURN CASE WHEN v_total > 0 THEN 1 ELSE 0 END;
    END;

    -- Login del sistema.
    -- Si las credenciales son correctas, actualiza ultimo_login y registra el evento en log_api.
    -- Si fallan, incrementa intentos_fallidos y retorna 0.
    FUNCTION fn_validar_login (
        p_correo        IN VARCHAR2,
        p_password_hash IN VARCHAR2
    ) RETURN NUMBER IS
        v_id_usuario NUMBER;
    BEGIN
        SELECT id_usuario
        INTO v_id_usuario
        FROM usuarios
        WHERE LOWER(correo) = LOWER(p_correo)
          AND password_hash = p_password_hash
          AND estado = 'ACTIVO';

        UPDATE usuarios
        SET ultimo_login = SYSDATE,
            intentos_fallidos = 0,
            bloqueado_hasta = NULL
        WHERE id_usuario = v_id_usuario;

        INSERT INTO log_api (modulo, endpoint, metodo, id_usuario, resultado, mensaje)
        VALUES ('AUTH', '/auth/login', 'POST', v_id_usuario, 'OK', 'Login correcto');

        RETURN v_id_usuario;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            UPDATE usuarios
            SET intentos_fallidos = intentos_fallidos + 1
            WHERE LOWER(correo) = LOWER(p_correo);

            INSERT INTO log_api (modulo, endpoint, metodo, resultado, mensaje)
            VALUES ('AUTH', '/auth/login', 'POST', 'ERROR', 'Credenciales incorrectas');

            RETURN 0;
    END;

    -- Validacion simple para saber si un correo ya esta registrado.
    -- Se usa antes del registro para dar una respuesta clara al frontend.
    FUNCTION fn_correo_existe (p_correo IN VARCHAR2) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_total
        FROM usuarios
        WHERE LOWER(correo) = LOWER(p_correo);

        RETURN CASE WHEN v_total > 0 THEN 1 ELSE 0 END;
    END;

    -- Registro de usuario.
    -- Valida que el departamento exista, crea el usuario como PENDIENTE_ACTIVACION
    -- y le asigna automaticamente el rol SOLICITANTE.
    PROCEDURE sp_registrar_usuario (
        p_nombre_completo IN VARCHAR2,
        p_correo          IN VARCHAR2,
        p_password_hash   IN VARCHAR2,
        p_id_departamento IN NUMBER,
        p_telefono        IN VARCHAR2,
        p_puesto          IN VARCHAR2,
        p_id_usuario      OUT NUMBER
    ) IS
        v_existe NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_existe
        FROM departamentos
        WHERE id_departamento = p_id_departamento
          AND estado = 'ACTIVO';

        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'El departamento no existe o esta inactivo');
        END IF;

        INSERT INTO usuarios (
            nombre_completo, correo, password_hash, id_departamento, telefono, puesto, estado
        ) VALUES (
            p_nombre_completo, LOWER(p_correo), p_password_hash, p_id_departamento,
            p_telefono, p_puesto, 'PENDIENTE_ACTIVACION'
        )
        RETURNING id_usuario INTO p_id_usuario;

        INSERT INTO usuario_rol (id_usuario, id_rol)
        SELECT p_id_usuario, id_rol
        FROM roles
        WHERE nombre_rol = 'SOLICITANTE';

        INSERT INTO log_api (modulo, endpoint, metodo, id_usuario, resultado, mensaje)
        VALUES ('AUTH', '/auth/register', 'POST', p_id_usuario, 'OK', 'Usuario registrado correctamente');
    END;

    FUNCTION fn_registrar_usuario (
        p_nombre_completo IN VARCHAR2,
        p_correo          IN VARCHAR2,
        p_password_hash   IN VARCHAR2,
        p_id_departamento IN NUMBER,
        p_telefono        IN VARCHAR2,
        p_puesto          IN VARCHAR2
    ) RETURN NUMBER IS
        v_id_usuario NUMBER;
    BEGIN
        sp_registrar_usuario(
            p_nombre_completo, p_correo, p_password_hash, p_id_departamento,
            p_telefono, p_puesto, v_id_usuario
        );
        RETURN v_id_usuario;
    END;

    -- Recuperacion de contrasena.
    -- Busca el usuario por correo, genera un codigo unico y lo guarda con expiracion de 30 minutos.
    FUNCTION fn_generar_codigo_reset (
        p_correo      IN VARCHAR2,
        p_ip          IN VARCHAR2 DEFAULT NULL,
        p_user_agent  IN VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_id_usuario NUMBER;
        v_codigo VARCHAR2(100);
    BEGIN
        SELECT id_usuario
        INTO v_id_usuario
        FROM usuarios
        WHERE LOWER(correo) = LOWER(p_correo)
          AND estado IN ('ACTIVO', 'PENDIENTE_ACTIVACION');

        v_codigo := 'RESET-' || RAWTOHEX(SYS_GUID());

        INSERT INTO reset_password (
            id_usuario, codigo_reset, fecha_expiracion, usado, ip_solicitud, user_agent
        ) VALUES (
            v_id_usuario, v_codigo, SYSDATE + (30 / 1440), 'N', p_ip, p_user_agent
        );

        INSERT INTO log_api (modulo, endpoint, metodo, id_usuario, resultado, mensaje)
        VALUES ('AUTH', '/auth/solicitar-reset', 'POST', v_id_usuario, 'OK', 'Codigo de recuperacion generado');

        RETURN v_codigo;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'No existe un usuario activo o pendiente con ese correo');
    END;

    -- Cambio de contrasena.
    -- Solo funciona si el codigo existe, no esta usado y no ha expirado.
    -- Si el usuario estaba pendiente de activacion, lo activa al cambiar la contrasena.
    FUNCTION fn_cambiar_password (
        p_codigo_reset       IN VARCHAR2,
        p_password_hash      IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_id_reset reset_password.id_reset%TYPE;
        v_id_usuario reset_password.id_usuario%TYPE;
    BEGIN
        SELECT id_reset, id_usuario
        INTO v_id_reset, v_id_usuario
        FROM reset_password
        WHERE codigo_reset = p_codigo_reset
          AND usado = 'N'
          AND fecha_expiracion > SYSDATE;

        UPDATE usuarios
        SET password_hash = p_password_hash,
            estado = CASE WHEN estado = 'PENDIENTE_ACTIVACION' THEN 'ACTIVO' ELSE estado END
        WHERE id_usuario = v_id_usuario;

        UPDATE reset_password
        SET usado = 'S',
            fecha_uso = SYSDATE
        WHERE id_reset = v_id_reset;

        INSERT INTO log_api (modulo, endpoint, metodo, id_usuario, resultado, mensaje)
        VALUES ('AUTH', '/auth/cambiar-password', 'POST', v_id_usuario, 'OK', 'Contrasena actualizada');

        RETURN 'OK';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Codigo de recuperacion invalido, usado o expirado');
    END;

    -- Validacion de codigo reset sin cambiar la contrasena todavia.
    -- Si el codigo no sirve, aumenta intentos_validacion para dejar evidencia.
    FUNCTION fn_validar_codigo_reset (p_codigo_reset IN VARCHAR2) RETURN NUMBER IS
        v_id_reset NUMBER;
    BEGIN
        SELECT id_reset
        INTO v_id_reset
        FROM reset_password
        WHERE codigo_reset = p_codigo_reset
          AND usado = 'N'
          AND fecha_expiracion > SYSDATE;

        RETURN 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            UPDATE reset_password
            SET intentos_validacion = intentos_validacion + 1
            WHERE codigo_reset = p_codigo_reset;
            RETURN 0;
    END;

    -- Calcula el subtotal sumando cantidad * precio_estimado de todos los items.
    FUNCTION fn_calcular_subtotal (p_id_solicitud IN NUMBER) RETURN NUMBER IS
        v_subtotal NUMBER;
    BEGIN
        SELECT NVL(SUM(cantidad * precio_estimado), 0)
        INTO v_subtotal
        FROM solicitud_detalle
        WHERE id_solicitud = p_id_solicitud;

        RETURN ROUND(v_subtotal, 2);
    END;

    -- Calcula el impuesto usando el parametro IMPUESTO_VENTAS.
    FUNCTION fn_calcular_impuesto (p_subtotal IN NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN ROUND(NVL(p_subtotal, 0) * get_param_numero('IMPUESTO_VENTAS'), 2);
    END;

    -- Determina si el total supera el parametro MONTO_APROBACION_ESPECIAL.
    FUNCTION fn_requiere_aprobacion_especial (p_total IN NUMBER) RETURN CHAR IS
    BEGIN
        IF NVL(p_total, 0) > get_param_numero('MONTO_APROBACION_ESPECIAL') THEN
            RETURN 'S';
        END IF;
        RETURN 'N';
    END;

    -- Recalcula los montos de una solicitud despues de insertar o cambiar items.
    -- Actualiza subtotal, impuesto, total y la marca de aprobacion especial.
    PROCEDURE sp_recalcular_solicitud (p_id_solicitud IN NUMBER) IS
        v_subtotal NUMBER;
        v_impuesto NUMBER;
        v_total NUMBER;
        v_requiere_especial CHAR(1);
    BEGIN
        v_subtotal := fn_calcular_subtotal(p_id_solicitud);
        v_impuesto := fn_calcular_impuesto(v_subtotal);
        v_total := v_subtotal + v_impuesto;
        v_requiere_especial := fn_requiere_aprobacion_especial(v_total);

        UPDATE solicitudes
        SET subtotal = v_subtotal,
            impuesto = v_impuesto,
            total = v_total,
            requiere_aprobacion_especial = v_requiere_especial,
            fecha_actualizacion = SYSDATE
        WHERE id_solicitud = p_id_solicitud;
    END;

    -- Crea una solicitud completa:
    -- 1. Obtiene el departamento del usuario solicitante.
    -- 2. Inserta el encabezado en estado BORRADOR.
    -- 3. Inserta los items desde un JSON.
    -- 4. Recalcula montos.
    -- 5. Registra historial inicial.
    PROCEDURE sp_crear_solicitud (
        p_id_usuario_solicitante IN NUMBER,
        p_prioridad              IN VARCHAR2,
        p_justificacion          IN VARCHAR2,
        p_observaciones          IN VARCHAR2,
        p_items_json             IN CLOB,
        p_id_solicitud           OUT NUMBER
    ) IS
        v_id_departamento NUMBER;
        v_id_estado_borrador NUMBER;
        v_numero VARCHAR2(30);
        v_items NUMBER;
    BEGIN
        SELECT id_departamento
        INTO v_id_departamento
        FROM usuarios
        WHERE id_usuario = p_id_usuario_solicitante
          AND estado = 'ACTIVO';

        v_numero := 'SOL-' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF3');
        v_id_estado_borrador := get_estado_id('BORRADOR');

        INSERT INTO solicitudes (
            numero_solicitud, id_usuario_solicitante, id_departamento, id_estado,
            prioridad, justificacion, observaciones
        ) VALUES (
            v_numero, p_id_usuario_solicitante, v_id_departamento, v_id_estado_borrador,
            UPPER(p_prioridad), p_justificacion, p_observaciones
        )
        RETURNING id_solicitud INTO p_id_solicitud;

        INSERT INTO solicitud_detalle (
            id_solicitud, tipo_item, descripcion, cantidad, precio_estimado, proveedor_sugerido
        )
        SELECT
            p_id_solicitud,
            UPPER(tipo_item),
            descripcion,
            cantidad,
            precio_estimado,
            proveedor_sugerido
        FROM JSON_TABLE(
            p_items_json,
            '$[*]' COLUMNS (
                tipo_item VARCHAR2(20) PATH '$.tipo_item',
                descripcion VARCHAR2(500) PATH '$.descripcion',
                cantidad NUMBER PATH '$.cantidad',
                precio_estimado NUMBER PATH '$.precio_estimado',
                proveedor_sugerido VARCHAR2(200) PATH '$.proveedor_sugerido'
            )
        );

        SELECT COUNT(*)
        INTO v_items
        FROM solicitud_detalle
        WHERE id_solicitud = p_id_solicitud;

        IF v_items = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'La solicitud debe tener al menos un item');
        END IF;

        sp_recalcular_solicitud(p_id_solicitud);

        INSERT INTO historial_solicitud (
            id_solicitud, id_usuario_accion, estado_anterior, estado_nuevo, observacion
        ) VALUES (
            p_id_solicitud, p_id_usuario_solicitante, NULL, 'BORRADOR', 'Solicitud creada en borrador'
        );
    END;

    -- Envia una solicitud a aprobacion.
    -- Solo permite enviar solicitudes en BORRADOR o DEVUELTA y exige que tengan detalle.
    PROCEDURE sp_enviar_solicitud (
        p_id_solicitud IN NUMBER,
        p_id_usuario   IN NUMBER
    ) IS
        v_estado VARCHAR2(30);
        v_id_estado_pendiente NUMBER;
        v_items NUMBER;
    BEGIN
        SELECT e.codigo
        INTO v_estado
        FROM solicitudes s
        JOIN estados_solicitud e ON e.id_estado = s.id_estado
        WHERE s.id_solicitud = p_id_solicitud
          AND s.id_usuario_solicitante = p_id_usuario;

        IF v_estado NOT IN ('BORRADOR', 'DEVUELTA') THEN
            RAISE_APPLICATION_ERROR(-20005, 'Solo se pueden enviar solicitudes en BORRADOR o DEVUELTA');
        END IF;

        SELECT COUNT(*)
        INTO v_items
        FROM solicitud_detalle
        WHERE id_solicitud = p_id_solicitud;

        IF v_items = 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'No se puede enviar una solicitud sin items');
        END IF;

        sp_recalcular_solicitud(p_id_solicitud);
        v_id_estado_pendiente := get_estado_id('PENDIENTE');

        UPDATE solicitudes
        SET id_estado = v_id_estado_pendiente,
            fecha_envio = SYSDATE,
            fecha_actualizacion = SYSDATE
        WHERE id_solicitud = p_id_solicitud;

        INSERT INTO historial_solicitud (
            id_solicitud, id_usuario_accion, estado_anterior, estado_nuevo, observacion
        ) VALUES (
            p_id_solicitud, p_id_usuario, v_estado, 'PENDIENTE', 'Solicitud enviada a aprobacion'
        );
    END;

    -- Elimina una solicitud en BORRADOR.
    -- No se permite borrar solicitudes ya enviadas, aprobadas, rechazadas o devueltas.
    PROCEDURE sp_eliminar_solicitud_borrador (
        p_id_solicitud IN NUMBER,
        p_id_usuario   IN NUMBER
    ) IS
        v_estado VARCHAR2(30);
    BEGIN
        SELECT e.codigo
        INTO v_estado
        FROM solicitudes s
        JOIN estados_solicitud e ON e.id_estado = s.id_estado
        WHERE s.id_solicitud = p_id_solicitud
          AND s.id_usuario_solicitante = p_id_usuario;

        IF v_estado <> 'BORRADOR' THEN
            RAISE_APPLICATION_ERROR(-20012, 'Solo se pueden eliminar solicitudes en BORRADOR');
        END IF;

        DELETE FROM solicitud_detalle WHERE id_solicitud = p_id_solicitud;
        DELETE FROM historial_solicitud WHERE id_solicitud = p_id_solicitud;
        DELETE FROM solicitudes WHERE id_solicitud = p_id_solicitud;

        INSERT INTO log_api (modulo, endpoint, metodo, id_usuario, resultado, mensaje)
        VALUES ('SOLICITUDES', '/solicitudes/{id}', 'DELETE', p_id_usuario, 'OK', 'Solicitud borrador eliminada');
    END;

    -- Cambia el estado de un usuario.
    -- Solo un usuario con rol ADMIN puede activar, inactivar o bloquear cuentas.
    PROCEDURE sp_cambiar_estado_usuario (
        p_id_admin   IN NUMBER,
        p_id_usuario IN NUMBER,
        p_estado     IN VARCHAR2
    ) IS
        v_estado VARCHAR2(30);
    BEGIN
        IF fn_usuario_tiene_rol(p_id_admin, 'ADMIN') = 0 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Solo un usuario ADMIN puede cambiar estados de usuarios');
        END IF;

        v_estado := UPPER(p_estado);

        IF v_estado NOT IN ('ACTIVO', 'INACTIVO', 'BLOQUEADO') THEN
            RAISE_APPLICATION_ERROR(-20014, 'Estado invalido. Use ACTIVO, INACTIVO o BLOQUEADO');
        END IF;

        UPDATE usuarios
        SET estado = v_estado,
            fecha_actualizacion = SYSDATE
        WHERE id_usuario = p_id_usuario;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20015, 'Usuario no encontrado');
        END IF;

        INSERT INTO bitacora_usuarios (id_usuario, correo, accion, descripcion, fecha_registro)
        SELECT id_usuario, correo, 'CAMBIO_ESTADO', 'Estado cambiado a ' || v_estado, SYSDATE
        FROM usuarios
        WHERE id_usuario = p_id_usuario;

        INSERT INTO log_api (modulo, endpoint, metodo, id_usuario, resultado, mensaje)
        VALUES ('USUARIOS', '/usuarios/{id}/estado', 'PUT', p_id_admin, 'OK', 'Estado de usuario actualizado');
    END;

    -- Decision del aprobador.
    -- Centraliza las acciones APROBAR, RECHAZAR y DEVOLVER.
    -- Registra siempre el cambio en historial_solicitud.
    PROCEDURE sp_decidir_solicitud (
        p_id_solicitud      IN NUMBER,
        p_id_usuario_accion IN NUMBER,
        p_decision          IN VARCHAR2,
        p_observacion       IN VARCHAR2
    ) IS
        v_estado_actual VARCHAR2(30);
        v_estado_nuevo VARCHAR2(30);
        v_id_estado_nuevo NUMBER;
    BEGIN
        IF fn_usuario_tiene_rol(p_id_usuario_accion, 'APROBADOR') = 0
           AND fn_usuario_tiene_rol(p_id_usuario_accion, 'ADMIN') = 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'Solo APROBADOR o ADMIN puede decidir solicitudes');
        END IF;

        IF TRIM(p_observacion) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20008, 'La observacion del aprobador es obligatoria');
        END IF;

        SELECT e.codigo
        INTO v_estado_actual
        FROM solicitudes s
        JOIN estados_solicitud e ON e.id_estado = s.id_estado
        WHERE s.id_solicitud = p_id_solicitud;

        IF v_estado_actual = 'BORRADOR' THEN
            RAISE_APPLICATION_ERROR(-20009, 'No se puede aprobar, rechazar o devolver una solicitud en BORRADOR');
        END IF;

        IF v_estado_actual <> 'PENDIENTE' THEN
            RAISE_APPLICATION_ERROR(-20010, 'Solo se pueden decidir solicitudes PENDIENTES');
        END IF;

        v_estado_nuevo := CASE UPPER(p_decision)
            WHEN 'APROBAR' THEN 'APROBADA'
            WHEN 'RECHAZAR' THEN 'RECHAZADA'
            WHEN 'DEVOLVER' THEN 'DEVUELTA'
            ELSE NULL
        END;

        IF v_estado_nuevo IS NULL THEN
            RAISE_APPLICATION_ERROR(-20011, 'Decision invalida. Use APROBAR, RECHAZAR o DEVOLVER');
        END IF;

        v_id_estado_nuevo := get_estado_id(v_estado_nuevo);

        UPDATE solicitudes
        SET id_estado = v_id_estado_nuevo,
            fecha_cierre = CASE WHEN v_estado_nuevo IN ('APROBADA', 'RECHAZADA') THEN SYSDATE ELSE NULL END,
            fecha_actualizacion = SYSDATE
        WHERE id_solicitud = p_id_solicitud;

        INSERT INTO historial_solicitud (
            id_solicitud, id_usuario_accion, estado_anterior, estado_nuevo, observacion
        ) VALUES (
            p_id_solicitud, p_id_usuario_accion, v_estado_actual, v_estado_nuevo, p_observacion
        );
    END;
END pkg_sigescom;
/

-- WRAPPER: fn_validar_login
-- Funcion independiente que llama al paquete.
-- Se deja asi para mantener compatibilidad con el Laboratorio 11.
CREATE OR REPLACE FUNCTION fn_validar_login (
    p_correo        IN VARCHAR2,
    p_password_hash IN VARCHAR2
) RETURN NUMBER IS
BEGIN
    RETURN pkg_sigescom.fn_validar_login(p_correo, p_password_hash);
END;
/

-- WRAPPER: sp_registrar_usuario
-- Procedimiento independiente que llama al paquete.
-- Se deja con la misma firma del laboratorio para poder usarlo en el handler /auth/register.
CREATE OR REPLACE PROCEDURE sp_registrar_usuario (
    p_nombre_completo IN VARCHAR2,
    p_correo          IN VARCHAR2,
    p_password_hash   IN VARCHAR2,
    p_id_departamento IN NUMBER,
    p_telefono        IN VARCHAR2,
    p_puesto          IN VARCHAR2,
    p_id_usuario      OUT NUMBER
) IS
BEGIN
    pkg_sigescom.sp_registrar_usuario(
        p_nombre_completo, p_correo, p_password_hash, p_id_departamento,
        p_telefono, p_puesto, p_id_usuario
    );
END;
/
