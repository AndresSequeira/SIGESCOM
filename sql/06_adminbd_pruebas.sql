-- SIGESCOM - Paso 06
-- Ejecutar conectado como ADMINBD para probar sin Postman.
-- Este archivo sirve para validar la logica principal directamente desde SQL Developer.
-- Si estas pruebas funcionan, luego puedes probar los mismos flujos desde Postman usando ORDS.

-- Activa la salida de DBMS_OUTPUT para ver mensajes como "Usuario creado".
SET SERVEROUTPUT ON;

-- PRUEBA 1:
-- Registra un usuario nuevo usando el procedimiento del paquete.
-- Tambien debe disparar el trigger que inserta en bitacora_usuarios.
DECLARE
    v_id_usuario NUMBER;
BEGIN
    pkg_sigescom.sp_registrar_usuario(
        p_nombre_completo => 'Ana Solano',
        p_correo          => 'ana@empresa.com',
        p_password_hash   => 'HASH_SIMULADO_999',
        p_id_departamento => 1,
        p_telefono        => '8888-5555',
        p_puesto          => 'Analista de Compras',
        p_id_usuario      => v_id_usuario
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Usuario creado: ' || v_id_usuario);
END;
/

-- PRUEBA 2:
-- Valida login de un usuario existente.
-- Si retorna un numero mayor que 0, las credenciales son correctas.
SELECT pkg_sigescom.fn_validar_login('laura@empresa.com', 'HASH_SIMULADO_123') AS login_laura
FROM dual;

-- PRUEBA 3:
-- Crea una solicitud completa con dos items enviados como JSON.
-- El procedimiento debe calcular subtotal, impuesto, total y aprobacion especial.
DECLARE
    v_id_solicitud NUMBER;
BEGIN
    pkg_sigescom.sp_crear_solicitud(
        p_id_usuario_solicitante => 1,
        p_prioridad              => 'ALTA',
        p_justificacion          => 'Compra de licencias y equipo para el departamento',
        p_observaciones          => 'Solicitud de prueba del proyecto',
        p_items_json             => '[
            {"tipo_item":"PRODUCTO","descripcion":"Laptop empresarial","cantidad":1,"precio_estimado":450000,"proveedor_sugerido":"Proveedor A"},
            {"tipo_item":"SERVICIO","descripcion":"Instalacion y configuracion","cantidad":1,"precio_estimado":95000,"proveedor_sugerido":"Proveedor B"}
        ]',
        p_id_solicitud           => v_id_solicitud
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Solicitud creada: ' || v_id_solicitud);
END;
/

-- PRUEBA 4:
-- Envia la ultima solicitud creada a aprobacion.
-- Solo debe funcionar si la solicitud tiene al menos un item.
DECLARE
    v_id_solicitud NUMBER;
BEGIN
    SELECT MAX(id_solicitud) INTO v_id_solicitud FROM solicitudes;
    pkg_sigescom.sp_enviar_solicitud(v_id_solicitud, 1);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Solicitud enviada: ' || v_id_solicitud);
END;
/

-- PRUEBA 5:
-- Aprueba la ultima solicitud creada.
-- Usa el usuario 3 porque en los datos iniciales Maria tiene rol APROBADOR.
DECLARE
    v_id_solicitud NUMBER;
BEGIN
    SELECT MAX(id_solicitud) INTO v_id_solicitud FROM solicitudes;
    pkg_sigescom.sp_decidir_solicitud(
        p_id_solicitud      => v_id_solicitud,
        p_id_usuario_accion => 3,
        p_decision          => 'APROBAR',
        p_observacion       => 'Aprobada por cumplir con la justificacion y presupuesto'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Solicitud aprobada: ' || v_id_solicitud);
END;
/

-- CONSULTAS DE VERIFICACION:
-- Estas consultas muestran que las vistas, bitacoras e historial fueron alimentados correctamente.
SELECT * FROM vw_resumen_solicitudes_usuario;
SELECT * FROM vw_solicitudes_pendientes_aprobador;
SELECT * FROM bitacora_usuarios ORDER BY id_bitacora;
SELECT * FROM bitacora_solicitudes ORDER BY id_bitacora;
SELECT * FROM historial_solicitud ORDER BY id_historial;
