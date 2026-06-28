# SIGESCOM

Sistema empresarial para gestion de solicitudes internas y aprobacion de compras.

SIGESCOM permite registrar usuarios, iniciar sesion, crear solicitudes de compra con productos o servicios, enviar solicitudes a aprobacion, aprobar/rechazar/devolver solicitudes, consultar historial y visualizar indicadores generales.

## Contenido del proyecto

- `sql/`: scripts para crear la base de datos en Oracle Autonomous Database, tablas, datos iniciales, vistas, triggers, paquete PL/SQL, endpoints ORDS y pruebas.
- `frontend/`: aplicacion Vite + React + Tailwind + Axios para consumir los endpoints REST publicados en Oracle APEX/ORDS.

## Tecnologias

- Oracle Autonomous Database
- Oracle APEX / ORDS
- PL/SQL
- React
- Vite
- Tailwind CSS
- Axios

## Modulos principales

- Autenticacion y recuperacion de contrasena.
- Administracion de usuarios pendientes.
- Solicitudes de compra.
- Aprobacion de solicitudes.
- Historial y bitacoras.
- Dashboard de metricas.

## Ejecucion del frontend

```bash
cd frontend
npm install
npm run dev
```

URL local:

```text
http://127.0.0.1:5173
```

## API ORDS

La URL base de los endpoints esta configurada en:

```text
frontend/src/api/client.js
```

## Base de datos

El orden recomendado de ejecucion esta documentado en:

```text
sql/README_EJECUCION.md
```

