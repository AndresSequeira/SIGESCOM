# Analisis de requerimientos - SIGESCOM

## Punto de partida obligatorio

El Laboratorio 11 define el arranque correcto del proyecto:

- Crear en Oracle Cloud una `Autonomous AI Database` llamada `SIGESCOM`.
- Conectarse primero como `ADMIN` usando Wallet desde SQL Developer.
- Crear el schema `ADMINBD`.
- Trabajar el resto del proyecto desde `ADMINBD`.
- Usar APEX/ORDS para exponer endpoints REST.
- Implementar la logica principal en PL/SQL, no como CRUD simple.

## Modulos funcionales del proyecto final

### Autenticacion y usuarios

Debe soportar:

- Registro de usuario.
- Login.
- Logout o invalidacion logica de sesion/token.
- Consulta de perfil.
- Recuperacion y cambio de contrasena.
- Validacion de correo unico.
- Bitacora al registrar usuarios o modificar contrasenas.

Tablas principales:

- `usuarios`
- `roles`
- `usuario_rol`
- `departamentos`
- `reset_password`
- `bitacora_usuarios`

### Solicitudes de compra

Debe soportar:

- Crear solicitudes con encabezado y detalle.
- Iniciar solicitudes en estado `BORRADOR`.
- Enviar a aprobacion solo si existe al menos un item.
- Consultar solicitudes propias.
- Consultar detalle de una solicitud.
- Filtrar solicitudes por estado, departamento, fechas, prioridad y monto.
- Calcular subtotal, impuesto y total.
- Marcar aprobacion especial si supera el monto configurado.

Tablas principales:

- `solicitudes`
- `solicitud_detalle`
- `estados_solicitud`
- `parametros_sistema`
- `bitacora_solicitudes`

### Aprobacion e historial

Debe soportar:

- Aprobar, rechazar o devolver solicitudes.
- Permitir decisiones solo a usuarios con rol `APROBADOR` o `ADMIN`.
- Impedir aprobacion de solicitudes en `BORRADOR`.
- Exigir observacion del aprobador.
- Registrar historial con usuario, fecha, estado anterior, estado nuevo y observacion.
- Registrar bitacora cuando una solicitud cambia de estado.

Tablas principales:

- `historial_solicitud`
- `bitacora_solicitudes`

## Objetos obligatorios cubiertos por los scripts

- Funcion para validar credenciales: `pkg_sigescom.fn_validar_login` y wrapper `fn_validar_login`.
- Funcion para registrar usuarios: `pkg_sigescom.fn_registrar_usuario`.
- Procedimiento de registro segun Laboratorio 11: `sp_registrar_usuario`.
- Funcion para generar codigo de recuperacion: `pkg_sigescom.fn_generar_codigo_reset`.
- Funcion para cambiar contrasena: `pkg_sigescom.fn_cambiar_password`.
- Procedimiento para crear solicitud con detalle: `pkg_sigescom.sp_crear_solicitud`.
- Funciones de calculo: `fn_calcular_subtotal`, `fn_calcular_impuesto`, `fn_requiere_aprobacion_especial`.
- Vista resumen por usuario: `vw_resumen_solicitudes_usuario`.
- Vista de pendientes: `vw_solicitudes_pendientes_aprobador`.
- Procedimiento de decision: `pkg_sigescom.sp_decidir_solicitud`.
- Triggers de bitacora de usuarios y solicitudes.
- Modulos ORDS para `auth`, `catalogos`, `solicitudes` y `dashboard`.

## Orden recomendado de desarrollo

1. Crear base y usuario `ADMINBD`.
2. Crear tablas y datos catalogo.
3. Crear vistas y triggers.
4. Crear paquete PL/SQL.
5. Probar por SQL Developer sin APEX.
6. Crear ORDS/APEX.
7. Probar endpoints con Postman.
8. Preparar la demostracion con casos: registro, login, crear solicitud, enviar, aprobar, historial y dashboard.

