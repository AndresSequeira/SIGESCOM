-- SIGESCOM - Paso 05
-- Ejecutar conectado como ADMINBD.
-- Este script crea modulos ORDS. Si prefiere hacerlo visualmente en APEX,
-- use estos bloques PL/SQL como Source de cada handler.

-- Habilita el schema ADMINBD para publicar servicios REST con ORDS.
-- El alias adminbd forma parte de la URL final de los endpoints.
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'ADMINBD',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'adminbd',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

BEGIN
    -- MODULO ORDS: auth
    -- Agrupa endpoints relacionados con autenticacion, registro y recuperacion de contrasena.
    ORDS.DEFINE_MODULE(
        p_module_name    => 'auth',
        p_base_path      => '/auth/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'Autenticacion, registro y recuperacion de contrasena de SIGESCOM'
    );

    -- ENDPOINT: POST /auth/register
    -- Recibe los datos del formulario de registro y llama al procedimiento de registro.
    ORDS.DEFINE_TEMPLATE('auth', 'register');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'register',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_id_usuario NUMBER;
BEGIN
    pkg_sigescom.sp_registrar_usuario(
        :nombre_completo, :correo, :password_hash, :id_departamento,
        :telefono, :puesto, v_id_usuario
    );
    COMMIT;
    :status := 201;
    sys.htp.p('{"success":true,"message":"Usuario registrado correctamente","usuario_id":' || v_id_usuario || ',"estado":"PENDIENTE_ACTIVACION"}');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: POST /auth/login
    -- Valida correo y password_hash. Si son correctos, devuelve informacion basica del perfil.
    ORDS.DEFINE_TEMPLATE('auth', 'login');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'login',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_id_usuario NUMBER;
BEGIN
    v_id_usuario := pkg_sigescom.fn_validar_login(:correo, :password_hash);
    IF v_id_usuario > 0 THEN
        COMMIT;
        :status := 200;
        FOR r IN (
            SELECT u.id_usuario, u.nombre_completo, u.correo, d.nombre departamento,
                   LISTAGG(ro.nombre_rol, ',') WITHIN GROUP (ORDER BY ro.nombre_rol) roles
            FROM usuarios u
            JOIN departamentos d ON d.id_departamento = u.id_departamento
            JOIN usuario_rol ur ON ur.id_usuario = u.id_usuario AND ur.estado = 'ACTIVO'
            JOIN roles ro ON ro.id_rol = ur.id_rol
            WHERE u.id_usuario = v_id_usuario
            GROUP BY u.id_usuario, u.nombre_completo, u.correo, d.nombre
        ) LOOP
            sys.htp.p('{"success":true,"usuario":{"id":' || r.id_usuario ||
                      ',"nombre":"' || r.nombre_completo ||
                      '","correo":"' || r.correo ||
                      '","rol":"' || r.roles ||
                      '","departamento":"' || r.departamento || '"}}');
        END LOOP;
    ELSE
        COMMIT;
        :status := 401;
        sys.htp.p('{"success":false,"message":"Credenciales incorrectas"}');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: POST /auth/validar-correo
    -- Permite saber si un correo ya existe antes de intentar registrar el usuario.
    ORDS.DEFINE_TEMPLATE('auth', 'validar-correo');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'validar-correo',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    :status := 200;
    IF pkg_sigescom.fn_correo_existe(:correo) = 1 THEN
        sys.htp.p('{"success":true,"existe":true,"message":"El correo ya esta registrado"}');
    ELSE
        sys.htp.p('{"success":true,"existe":false,"message":"Correo disponible"}');
    END IF;
END;
]'
    );

    -- ENDPOINT: GET /auth/perfil
    -- Devuelve datos del usuario autenticado usando el parametro id_usuario.
    ORDS.DEFINE_TEMPLATE('auth', 'perfil');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'perfil',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_item,
        p_source      => q'[
SELECT u.id_usuario id, u.nombre_completo nombre, u.correo, d.nombre departamento,
       LISTAGG(r.nombre_rol, ',') WITHIN GROUP (ORDER BY r.nombre_rol) rol
FROM usuarios u
JOIN departamentos d ON d.id_departamento = u.id_departamento
JOIN usuario_rol ur ON ur.id_usuario = u.id_usuario AND ur.estado = 'ACTIVO'
JOIN roles r ON r.id_rol = ur.id_rol
WHERE u.id_usuario = TO_NUMBER(:id_usuario)
GROUP BY u.id_usuario, u.nombre_completo, u.correo, d.nombre
]'
    );

    -- ENDPOINT: POST /auth/logout
    -- Registra el cierre de sesion en log_api.
    -- En este proyecto no se implementa token real, pero se deja el endpoint para completar el flujo.
    ORDS.DEFINE_TEMPLATE('auth', 'logout');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'logout',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    INSERT INTO log_api (modulo, endpoint, metodo, id_usuario, resultado, mensaje)
    VALUES ('AUTH', '/auth/logout', 'POST', :id_usuario, 'OK', 'Logout registrado');
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Sesion cerrada"}');
END;
]'
    );

    -- ENDPOINT: POST /auth/solicitar-reset
    -- Genera un codigo temporal para recuperar contrasena.
    ORDS.DEFINE_TEMPLATE('auth', 'solicitar-reset');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'solicitar-reset',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_codigo VARCHAR2(100);
BEGIN
    v_codigo := pkg_sigescom.fn_generar_codigo_reset(:correo, :ip_solicitud, :user_agent);
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Codigo generado","codigo_reset":"' || v_codigo || '","expira_minutos":30}');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: POST /auth/validar-reset
    -- Verifica si un codigo reset existe, no ha expirado y no ha sido usado.
    ORDS.DEFINE_TEMPLATE('auth', 'validar-reset');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'validar-reset',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    IF pkg_sigescom.fn_validar_codigo_reset(:codigo_reset) = 1 THEN
        COMMIT;
        :status := 200;
        sys.htp.p('{"success":true,"message":"Codigo valido"}');
    ELSE
        COMMIT;
        :status := 400;
        sys.htp.p('{"success":false,"message":"Codigo invalido, usado o expirado"}');
    END IF;
END;
]'
    );

    -- ENDPOINT: POST /auth/cambiar-password
    -- Actualiza la contrasena usando un codigo reset valido.
    ORDS.DEFINE_TEMPLATE('auth', 'cambiar-password');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'auth',
        p_pattern     => 'cambiar-password',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    IF pkg_sigescom.fn_cambiar_password(:codigo_reset, :password_hash) = 'OK' THEN
        COMMIT;
        :status := 200;
        sys.htp.p('{"success":true,"message":"Contrasena actualizada correctamente"}');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- MODULO ORDS: catalogos
    -- Agrupa endpoints de listas simples usadas por formularios.
    ORDS.DEFINE_MODULE(
        p_module_name    => 'catalogos',
        p_base_path      => '/catalogos/',
        p_items_per_page => 100,
        p_status         => 'PUBLISHED'
    );

    -- ENDPOINT: GET /catalogos/departamentos
    -- Devuelve departamentos activos para llenar listas desplegables.
    ORDS.DEFINE_TEMPLATE('catalogos', 'departamentos');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'catalogos',
        p_pattern     => 'departamentos',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => 'SELECT id_departamento, nombre FROM departamentos WHERE estado = ''ACTIVO'' ORDER BY nombre'
    );

    -- MODULO ORDS: usuarios
    -- Agrupa endpoints administrativos para consultar y activar cuentas.
    ORDS.DEFINE_MODULE(
        p_module_name    => 'usuarios',
        p_base_path      => '/usuarios/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED'
    );

    -- ENDPOINT: GET /usuarios/pendientes
    -- Lista usuarios pendientes de activacion para que un ADMIN pueda aprobarlos.
    ORDS.DEFINE_TEMPLATE('usuarios', 'pendientes');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'usuarios',
        p_pattern     => 'pendientes',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT u.id_usuario, u.nombre_completo, u.correo, d.nombre departamento,
       u.telefono, u.puesto, u.estado, u.fecha_creacion
FROM usuarios u
JOIN departamentos d ON d.id_departamento = u.id_departamento
WHERE u.estado = 'PENDIENTE_ACTIVACION'
ORDER BY u.fecha_creacion DESC
]'
    );

    -- ENDPOINT: GET /usuarios
    -- Lista usuarios con filtros basicos por estado y correo.
    ORDS.DEFINE_TEMPLATE('usuarios', '/');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'usuarios',
        p_pattern     => '/',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT u.id_usuario, u.nombre_completo, u.correo, d.nombre departamento,
       u.telefono, u.puesto, u.estado, u.fecha_creacion
FROM usuarios u
JOIN departamentos d ON d.id_departamento = u.id_departamento
WHERE (:estado IS NULL OR u.estado = UPPER(:estado))
  AND (:correo IS NULL OR LOWER(u.correo) LIKE '%' || LOWER(:correo) || '%')
ORDER BY u.fecha_creacion DESC
]'
    );

    -- ENDPOINT: PUT /usuarios/{id}/estado
    -- Cambia el estado de un usuario. Se debe enviar id_admin y estado.
    ORDS.DEFINE_TEMPLATE('usuarios', ':id/estado');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'usuarios',
        p_pattern     => ':id/estado',
        p_method      => 'PUT',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    pkg_sigescom.sp_cambiar_estado_usuario(
        p_id_admin   => TO_NUMBER(:id_admin),
        p_id_usuario => TO_NUMBER(:id),
        p_estado     => :estado
    );
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Estado de usuario actualizado"}');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- MODULO ORDS: solicitudes
    -- Agrupa endpoints para crear, consultar, enviar y decidir solicitudes de compra.
    ORDS.DEFINE_MODULE(
        p_module_name    => 'solicitudes',
        p_base_path      => '/solicitudes/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED'
    );

    -- ENDPOINT: POST /solicitudes/
    -- Crea una solicitud completa en estado BORRADOR con sus items de detalle.
    ORDS.DEFINE_TEMPLATE('solicitudes', '/');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => '/',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
DECLARE
    v_id_solicitud NUMBER;
BEGIN
    pkg_sigescom.sp_crear_solicitud(
        :id_usuario_solicitante, :prioridad, :justificacion, :observaciones,
        :items_json, v_id_solicitud
    );
    COMMIT;
    :status := 201;
    sys.htp.p('{"success":true,"message":"Solicitud creada","id_solicitud":' || v_id_solicitud || '}');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: GET /solicitudes/
    -- Consulta solicitudes aplicando filtros por estado, departamento, fechas, prioridad y monto.
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => '/',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT
    s.id_solicitud id,
    s.numero_solicitud,
    u.nombre_completo solicitante,
    d.nombre departamento,
    e.codigo estado,
    s.prioridad,
    s.total,
    CASE s.requiere_aprobacion_especial WHEN 'S' THEN 'true' ELSE 'false' END requiere_aprobacion_especial,
    s.fecha_solicitud
FROM solicitudes s
JOIN usuarios u ON u.id_usuario = s.id_usuario_solicitante
JOIN departamentos d ON d.id_departamento = s.id_departamento
JOIN estados_solicitud e ON e.id_estado = s.id_estado
WHERE (:estado IS NULL OR e.codigo = UPPER(:estado))
  AND (:departamento IS NULL OR s.id_departamento = TO_NUMBER(:departamento))
  AND (:fechaInicio IS NULL OR TRUNC(s.fecha_solicitud) >= TO_DATE(:fechaInicio, 'YYYY-MM-DD'))
  AND (:fechaFin IS NULL OR TRUNC(s.fecha_solicitud) <= TO_DATE(:fechaFin, 'YYYY-MM-DD'))
  AND (:prioridad IS NULL OR s.prioridad = UPPER(:prioridad))
  AND (:montoMin IS NULL OR s.total >= TO_NUMBER(:montoMin))
  AND (:montoMax IS NULL OR s.total <= TO_NUMBER(:montoMax))
ORDER BY s.fecha_solicitud DESC
]'
    );

    -- ENDPOINT: GET /solicitudes/mis-solicitudes
    -- Devuelve solamente las solicitudes creadas por un usuario especifico.
    ORDS.DEFINE_TEMPLATE('solicitudes', 'mis-solicitudes');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => 'mis-solicitudes',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT s.id_solicitud, s.numero_solicitud, e.codigo estado, s.prioridad, s.total, s.fecha_solicitud
FROM solicitudes s
JOIN estados_solicitud e ON e.id_estado = s.id_estado
WHERE s.id_usuario_solicitante = TO_NUMBER(:id_usuario)
ORDER BY s.fecha_solicitud DESC
]'
    );

    -- ENDPOINT: GET /solicitudes/pendientes
    -- Devuelve solicitudes pendientes para usuarios con rol APROBADOR o ADMIN.
    ORDS.DEFINE_TEMPLATE('solicitudes', 'pendientes');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => 'pendientes',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT p.*
FROM vw_solicitudes_pendientes_aprobador p
WHERE pkg_sigescom.fn_usuario_tiene_rol(TO_NUMBER(:id_usuario), 'APROBADOR') = 1
   OR pkg_sigescom.fn_usuario_tiene_rol(TO_NUMBER(:id_usuario), 'ADMIN') = 1
ORDER BY p.fecha_envio
]'
    );

    -- ENDPOINT: GET /solicitudes/{id}
    -- Devuelve encabezado y detalle de una solicitud especifica.
    ORDS.DEFINE_TEMPLATE('solicitudes', ':id');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => ':id',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT
    s.id_solicitud, s.numero_solicitud, e.codigo estado, s.prioridad,
    s.justificacion, s.observaciones, s.subtotal, s.impuesto, s.total,
    sd.id_detalle, sd.tipo_item, sd.descripcion, sd.cantidad, sd.precio_estimado, sd.subtotal_linea
FROM solicitudes s
JOIN estados_solicitud e ON e.id_estado = s.id_estado
LEFT JOIN solicitud_detalle sd ON sd.id_solicitud = s.id_solicitud
WHERE s.id_solicitud = TO_NUMBER(:id)
]'
    );

    -- ENDPOINT: DELETE /solicitudes/{id}
    -- Elimina una solicitud solo si esta en BORRADOR y pertenece al usuario.
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => ':id',
        p_method      => 'DELETE',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    pkg_sigescom.sp_eliminar_solicitud_borrador(TO_NUMBER(:id), TO_NUMBER(:id_usuario));
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Solicitud borrador eliminada"}');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: PUT /solicitudes/{id}/enviar
    -- Cambia una solicitud de BORRADOR o DEVUELTA a PENDIENTE.
    ORDS.DEFINE_TEMPLATE('solicitudes', ':id/enviar');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => ':id/enviar',
        p_method      => 'PUT',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    pkg_sigescom.sp_enviar_solicitud(TO_NUMBER(:id), TO_NUMBER(:id_usuario));
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Solicitud enviada a aprobacion"}');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        :status := 400;
        sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- TEMPLATES DE DECISION:
    -- Se separan los endpoints para que el frontend pueda llamar aprobar, rechazar o devolver.
    ORDS.DEFINE_TEMPLATE('solicitudes', ':id/aprobar');
    ORDS.DEFINE_TEMPLATE('solicitudes', ':id/rechazar');
    ORDS.DEFINE_TEMPLATE('solicitudes', ':id/devolver');

    -- ENDPOINT: PUT /solicitudes/{id}/aprobar
    -- Aprueba una solicitud pendiente. Solo APROBADOR o ADMIN.
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => ':id/aprobar',
        p_method      => 'PUT',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    pkg_sigescom.sp_decidir_solicitud(TO_NUMBER(:id), TO_NUMBER(:id_usuario_accion), 'APROBAR', :observacion);
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Solicitud aprobada"}');
EXCEPTION WHEN OTHERS THEN ROLLBACK; :status := 400; sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: PUT /solicitudes/{id}/rechazar
    -- Rechaza una solicitud pendiente. Exige observacion.
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => ':id/rechazar',
        p_method      => 'PUT',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    pkg_sigescom.sp_decidir_solicitud(TO_NUMBER(:id), TO_NUMBER(:id_usuario_accion), 'RECHAZAR', :observacion);
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Solicitud rechazada"}');
EXCEPTION WHEN OTHERS THEN ROLLBACK; :status := 400; sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: PUT /solicitudes/{id}/devolver
    -- Devuelve una solicitud pendiente para correccion.
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => ':id/devolver',
        p_method      => 'PUT',
        p_source_type => ORDS.source_type_plsql,
        p_source      => q'[
BEGIN
    pkg_sigescom.sp_decidir_solicitud(TO_NUMBER(:id), TO_NUMBER(:id_usuario_accion), 'DEVOLVER', :observacion);
    COMMIT;
    :status := 200;
    sys.htp.p('{"success":true,"message":"Solicitud devuelta"}');
EXCEPTION WHEN OTHERS THEN ROLLBACK; :status := 400; sys.htp.p('{"success":false,"message":"' || REPLACE(sys.htf.escape_sc(SQLERRM), '"', '\"') || '"}');
END;
]'
    );

    -- ENDPOINT: GET /solicitudes/{id}/historial
    -- Devuelve la trazabilidad de estados de una solicitud.
    ORDS.DEFINE_TEMPLATE('solicitudes', ':id/historial');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'solicitudes',
        p_pattern     => ':id/historial',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT h.id_historial, h.estado_anterior, h.estado_nuevo, h.observacion,
       h.fecha_accion, u.nombre_completo usuario_accion
FROM historial_solicitud h
JOIN usuarios u ON u.id_usuario = h.id_usuario_accion
WHERE h.id_solicitud = TO_NUMBER(:id)
ORDER BY h.fecha_accion
]'
    );

    -- MODULO ORDS: dashboard
    -- Agrupa endpoints de metricas generales para un panel de control.
    ORDS.DEFINE_MODULE(
        p_module_name    => 'dashboard',
        p_base_path      => '/dashboard/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED'
    );

    -- ENDPOINT: GET /dashboard/resumen
    -- Devuelve indicadores generales: total, aprobadas, rechazadas, pendientes y monto total.
    ORDS.DEFINE_TEMPLATE('dashboard', 'resumen');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'dashboard',
        p_pattern     => 'resumen',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => q'[
SELECT
    COUNT(*) total_solicitudes,
    SUM(CASE WHEN e.codigo = 'APROBADA' THEN 1 ELSE 0 END) aprobadas,
    SUM(CASE WHEN e.codigo = 'RECHAZADA' THEN 1 ELSE 0 END) rechazadas,
    SUM(CASE WHEN e.codigo = 'PENDIENTE' THEN 1 ELSE 0 END) pendientes,
    NVL(SUM(s.total), 0) monto_total_solicitado
FROM solicitudes s
JOIN estados_solicitud e ON e.id_estado = s.id_estado
]'
    );

    COMMIT;
END;
/
