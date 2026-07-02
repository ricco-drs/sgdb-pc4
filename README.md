# PrestaFácil — Capa de Aplicación (Frontend + API)

Frontend web (React) que consume los **5 packages PL/SQL** de la base de datos
Oracle 19c a través de una **API REST** intermedia. El backend NO reimplementa
lógica de negocio: solo **llama a los procedimientos y funciones** existentes.

```
┌──────────────┐   HTTP/JSON   ┌───────────────┐   node-oracledb   ┌──────────────┐
│  FRONTEND    │ ────────────► │   BACKEND      │ ───────────────► │   ORACLE 19c │
│  React :5173 │ ◄──────────── │ Express :3001  │ ◄─────────────── │  3 esquemas  │
└──────────────┘               └───────────────┘                   └──────────────┘
     UI por rol                  25 endpoints                    C##G01_APP (EXECUTE)
```

El usuario de la aplicación (`C##G01_APP`) **solo tiene privilegio EXECUTE** sobre
los packages — nunca SELECT/INSERT directo a las tablas. Eso mantiene el principio
de mínimo privilegio incluso desde la app.

---

## Requisito previo (una sola vez)

Ejecutar en **CONN_SEGURIDAD** el script de apoyo que permite al login devolver
el `id_usuario` junto con el rol:

```
scripts/13_api_support.sql
```

Crea el procedimiento `sp_login_api` y le da EXECUTE a `C##G01_APP`. Es aditivo:
no modifica ninguno de los 5 packages.

---

## Cómo arrancar

### 1. Backend (API)
```bash
cd backend
npm install          # solo la primera vez
npm start            # -> http://localhost:3001
```
Verifica: abre http://localhost:3001/api/health → debe responder `{"ok":true,...}`.

Configuración en `backend/.env` (credenciales de Oracle). El connect string por
defecto es `localhost:1521/orcl`.

### 2. Frontend (React)
En **otra** terminal:
```bash
cd frontend
npm install          # solo la primera vez
npm run dev          # -> http://localhost:5173
```
Abre http://localhost:5173 e ingresa con un usuario de prueba.

> Vite reenvía automáticamente las llamadas `/api/...` al backend `:3001`
> (configurado en `frontend/vite.config.js`), así que no hay problemas de CORS.

---

## Usuarios de prueba

| Usuario | Contraseña | Rol | Qué ve en la app |
|---|---|---|---|
| admin | admin123 | ADMINISTRADOR | Administración, Seguridad, Consultas |
| ana   | ana123   | ANALISTA | Clientes, Solicitudes, Consultas |
| caja  | caja123  | CAJERO | Pagos, Consultas |
| super | super123 | SUPERVISOR | Consultas, Reportes |
| geren | geren123 | GERENTE | Solo Reportes |

El menú lateral se filtra por rol → **demuestra la segregación de acceso** exigida
por el caso (el Gerente jamás ve operaciones de negocio).

---

## Mapa de los 25 requerimientos → endpoints

| Bloque | Requerimientos | Ruta base | Package PL/SQL |
|---|---|---|---|
| Valor | VAL01–VAL05 | `POST /api/valor/*` | `PKG_VALOR` |
| Seguridad | SEG01 (login) + SEG02–SEG05 | `/api/auth/login`, `/api/seguridad/*` | `PKG_SEGURIDAD` |
| Administración | ADM01–ADM05 | `/api/admin/*` | `PKG_ADMINISTRACION` |
| Consultas | CON01–CON05 | `GET /api/consultas/*` | `PKG_CONSULTAS` |
| Reportes | REP01–REP05 | `GET /api/reportes/*` | `PKG_REPORTES` |

---

## Estructura

```
backend/
  src/
    db.js                 pool de conexiones + helpers (run, fetchCursor)
    server.js             monta los routers y el health check
    routes/
      auth.js             SEG01 (login)
      valor.js            VAL01–VAL05
      seguridad.js        SEG02–SEG05
      administracion.js   ADM01–ADM05
      consultas.js        CON01–CON05
      reportes.js         REP01–REP05
frontend/
  src/
    api.js                cliente de la API (todas las llamadas)
    App.jsx               login + navegación por rol
    Login.jsx             pantalla de acceso (SEG01)
    ui.jsx                componentes reutilizables (tabla, tarjeta, campos)
    panels/
      negocio.jsx         Clientes, Solicitudes, Pagos, Consultas
      gestion.jsx         Reportes, Administración, Seguridad
```
