# SIGESCOM Frontend

Frontend en Vite + React + Tailwind para consumir los endpoints ORDS de SIGESCOM.

## URL local

Cuando el servidor esta iniciado:

```text
http://127.0.0.1:5173
```

## API configurada

La URL base esta en:

```text
src/api/client.js
```

Valor actual:

```text
https://g6444ba724080c1-sigescom.adb.mx-queretaro-1.oraclecloudapps.com/ords/adminbd
```

## Pantallas incluidas

- Acceso: login, registro, validar correo y logout.
- Reset: solicitar codigo, validar codigo y cambiar password.
- Solicitudes: crear solicitud con items, consultar, ver detalle, enviar y eliminar borrador.
- Aprobacion: ver pendientes, aprobar, rechazar, devolver e historial.
- Dashboard: metricas generales y listado de solicitudes.

## Comandos normales si tienes Node.js instalado

```bash
npm install
npm run dev
```

Si usas pnpm:

```bash
pnpm install
pnpm dev
```

