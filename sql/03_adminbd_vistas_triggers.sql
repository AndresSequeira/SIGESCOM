-- SIGESCOM - Paso 03
-- Ejecutar conectado como ADMINBD.
-- En este archivo se crean vistas para consultar informacion resumida
-- y triggers para automatizar auditorias y valores calculados del sistema.

-- VISTA: vw_resumen_solicitudes_usuario
-- Resume las solicitudes agrupadas por usuario.
-- Sirve para saber cuantas solicitudes tiene cada usuario y cuanto dinero ha solicitado.
CREATE OR REPLACE VIEW vw_resumen_solicitudes_usuario AS
SELECT
    u.id_usuario,
    u.nombre_completo,
    u.correo,
    d.nombre AS departamento,
    COUNT(s.id_solicitud) AS total_solicitudes,
    SUM(CASE WHEN e.codigo = 'BORRADOR' THEN 1 ELSE 0 END) AS borradores,
    SUM(CASE WHEN e.codigo = 'PENDIENTE' THEN 1 ELSE 0 END) AS pendientes,
    SUM(CASE WHEN e.codigo = 'APROBADA' THEN 1 ELSE 0 END) AS aprobadas,
    SUM(CASE WHEN e.codigo = 'RECHAZADA' THEN 1 ELSE 0 END) AS rechazadas,
    NVL(SUM(s.total), 0) AS monto_total_solicitado
FROM usuarios u
JOIN departamentos d ON d.id_departamento = u.id_departamento
LEFT JOIN solicitudes s ON s.id_usuario_solicitante = u.id_usuario
LEFT JOIN estados_solicitud e ON e.id_estado = s.id_estado
GROUP BY u.id_usuario, u.nombre_completo, u.correo, d.nombre;

-- VISTA: vw_solicitudes_pendientes_aprobador
-- Lista las solicitudes que estan en estado PENDIENTE.
-- Esta vista alimenta la pantalla o endpoint donde los aprobadores revisan solicitudes.
CREATE OR REPLACE VIEW vw_solicitudes_pendientes_aprobador AS
SELECT
    s.id_solicitud,
    s.numero_solicitud,
    s.id_departamento,
    d.nombre AS departamento,
    s.id_usuario_solicitante,
    u.nombre_completo AS solicitante,
    s.prioridad,
    s.justificacion,
    s.subtotal,
    s.impuesto,
    s.total,
    s.requiere_aprobacion_especial,
    s.fecha_envio
FROM solicitudes s
JOIN estados_solicitud e ON e.id_estado = s.id_estado
JOIN usuarios u ON u.id_usuario = s.id_usuario_solicitante
JOIN departamentos d ON d.id_departamento = s.id_departamento
WHERE e.codigo = 'PENDIENTE';

-- TRIGGER: trg_usuarios_biu
-- Se ejecuta antes de insertar o actualizar usuarios.
-- Convierte el correo a minusculas y actualiza la fecha de modificacion automaticamente.
CREATE OR REPLACE TRIGGER trg_usuarios_biu
BEFORE INSERT OR UPDATE ON usuarios
FOR EACH ROW
BEGIN
    :NEW.correo := LOWER(:NEW.correo);
    :NEW.fecha_actualizacion := SYSDATE;
END;
/

-- TRIGGER: trg_bitacora_usuario_insert
-- Se ejecuta despues de insertar un usuario.
-- Registra automaticamente en bitacora_usuarios que se creo una nueva cuenta.
CREATE OR REPLACE TRIGGER trg_bitacora_usuario_insert
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
    INSERT INTO bitacora_usuarios (id_usuario, correo, accion, descripcion, fecha_registro)
    VALUES (:NEW.id_usuario, :NEW.correo, 'INSERT', 'Se registro un nuevo usuario en el sistema', SYSDATE);
END;
/

-- TRIGGER: trg_bitacora_usuario_password
-- Se ejecuta cuando cambia el password_hash de un usuario.
-- Permite demostrar que el sistema audita cambios de contrasena.
CREATE OR REPLACE TRIGGER trg_bitacora_usuario_password
AFTER UPDATE OF password_hash ON usuarios
FOR EACH ROW
WHEN (OLD.password_hash <> NEW.password_hash)
BEGIN
    INSERT INTO bitacora_usuarios (id_usuario, correo, accion, descripcion, fecha_registro)
    VALUES (:NEW.id_usuario, :NEW.correo, 'UPDATE_PASSWORD', 'Se modifico la contrasena del usuario', SYSDATE);
END;
/

-- TRIGGER: trg_solicitudes_bi
-- Se ejecuta antes de insertar una solicitud.
-- Si no se envio numero_solicitud, genera uno automaticamente con fecha y hora.
CREATE OR REPLACE TRIGGER trg_solicitudes_bi
BEFORE INSERT ON solicitudes
FOR EACH ROW
BEGIN
    IF :NEW.numero_solicitud IS NULL THEN
        :NEW.numero_solicitud := 'SOL-' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF3');
    END IF;
END;
/

-- TRIGGER: trg_bitacora_solicitud_insert
-- Se ejecuta despues de crear una solicitud.
-- Registra en bitacora_solicitudes que se creo una solicitud nueva en BORRADOR.
CREATE OR REPLACE TRIGGER trg_bitacora_solicitud_insert
AFTER INSERT ON solicitudes
FOR EACH ROW
BEGIN
    INSERT INTO bitacora_solicitudes (
        id_solicitud, numero_solicitud, accion, estado_nuevo, descripcion, fecha_registro
    ) VALUES (
        :NEW.id_solicitud, :NEW.numero_solicitud, 'INSERT', 'BORRADOR',
        'Se creo una nueva solicitud de compra', SYSDATE
    );
END;
/

-- TRIGGER: trg_bitacora_solicitud_estado
-- Se ejecuta cuando cambia el estado de una solicitud.
-- Guarda en bitacora_solicitudes el estado anterior, el estado nuevo y la fecha del cambio.
CREATE OR REPLACE TRIGGER trg_bitacora_solicitud_estado
AFTER UPDATE OF id_estado ON solicitudes
FOR EACH ROW
WHEN (OLD.id_estado <> NEW.id_estado)
DECLARE
    v_estado_anterior estados_solicitud.codigo%TYPE;
    v_estado_nuevo estados_solicitud.codigo%TYPE;
BEGIN
    SELECT codigo INTO v_estado_anterior FROM estados_solicitud WHERE id_estado = :OLD.id_estado;
    SELECT codigo INTO v_estado_nuevo FROM estados_solicitud WHERE id_estado = :NEW.id_estado;

    IF v_estado_nuevo IN ('APROBADA', 'RECHAZADA', 'DEVUELTA', 'PENDIENTE') THEN
        INSERT INTO bitacora_solicitudes (
            id_solicitud, numero_solicitud, accion, estado_anterior, estado_nuevo, descripcion, fecha_registro
        ) VALUES (
            :NEW.id_solicitud, :NEW.numero_solicitud, 'CAMBIO_ESTADO',
            v_estado_anterior, v_estado_nuevo, 'Cambio de estado de solicitud', SYSDATE
        );
    END IF;
END;
/
