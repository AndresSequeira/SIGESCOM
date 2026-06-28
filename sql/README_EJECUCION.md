# SIGESCOM - Orden de ejecucion

Este proyecto debe iniciar como indica el Laboratorio 11.

1. En Oracle Cloud cree una `Autonomous AI Database` llamada `SIGESCOM`.
2. Use la contrasena indicada por el laboratorio: `Basesdedatos2026.`
3. Descargue/configure la Wallet y cree la conexion SQL Developer `ADMIN_SIGESCOM` con usuario `ADMIN`.
4. Ejecute `01_admin_crear_usuario.sql` conectado como `ADMIN`.
5. Cree una segunda conexion SQL Developer `ADMINBD_SIGESCOM` con usuario `ADMINBD`.
6. Ejecute conectado como `ADMINBD`, en este orden:
   - `02_adminbd_tablas_datos.sql`
   - `03_adminbd_vistas_triggers.sql`
   - `04_adminbd_paquete_logica.sql`
   - `05_adminbd_ords_endpoints.sql`
   - `06_adminbd_pruebas.sql`

El script `05_adminbd_ords_endpoints.sql` intenta crear los modulos ORDS por SQL. Si en su entorno el profesor prefiere hacerlo desde APEX, cree los modulos visualmente y copie los bloques PL/SQL de cada handler.

Endpoints principales esperados:

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/perfil`
- `POST /auth/validar-correo`
- `POST /auth/solicitar-reset`
- `POST /auth/validar-reset`
- `POST /auth/cambiar-password`
- `GET /catalogos/departamentos`
- `POST /solicitudes`
- `GET /solicitudes/mis-solicitudes`
- `GET /solicitudes/{id}`
- `DELETE /solicitudes/{id}`
- `GET /solicitudes`
- `GET /solicitudes/pendientes`
- `PUT /solicitudes/{id}/enviar`
- `PUT /solicitudes/{id}/aprobar`
- `PUT /solicitudes/{id}/rechazar`
- `PUT /solicitudes/{id}/devolver`
- `GET /solicitudes/{id}/historial`
- `GET /dashboard/resumen`
