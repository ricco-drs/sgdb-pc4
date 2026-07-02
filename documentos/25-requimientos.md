# Requerimientos del Sistema — PrestaFácil

> Sistema de Gestión de Préstamos Personales para una Institución Financiera
> 25 requerimientos organizados en 5 paquetes PL/SQL, distribuidos en 3 esquemas Oracle

---

## Mapa general

| Paquete | Esquema | Bloque | Requerimientos | Quién opera |
|---|---|---|---|---|
| `PKG_VALOR` | `G01_NEGOCIO` | 1 | VAL01–VAL05 | Analista, Cajero |
| `PKG_SEGURIDAD` | `G01_SEGURIDAD` | 2 | SEG01–SEG05 | Administrador |
| `PKG_ADMINISTRACION` | `G01_NEGOCIO` | 3 | ADM01–ADM05 | Administrador |
| `PKG_CONSULTAS` | `G01_NEGOCIO` | 4 | CON01–CON05 | Analista, Cajero, Supervisor |
| `PKG_REPORTES` | `G01_REPORTES` | 5 | REP01–REP05 | Gerente, Supervisor (solo lectura) |

---

## Bloque 1 — PKG_VALOR (VAL01–VAL05)

*El corazón del negocio: el ciclo de vida del préstamo.*

| Código | Requerimiento | Qué hace y qué valida |
|---|---|---|
| **VAL01** | Registrar solicitud de préstamo | Procedimiento que crea una solicitud vinculando cliente, monto, plazo y tipo de préstamo. Valida: monto dentro de rangos permitidos, plazo válido, cliente existente y no en lista negra. Estado inicial: `PENDIENTE`. |
| **VAL02** | Evaluar capacidad de pago y calificar | Función que calcula la capacidad de pago (40% del ingreso) y asigna calificación A/B/C/D según el ratio cuota/ingreso. Devuelve la calificación y guarda el resultado en la solicitud. |
| **VAL03** | Aprobar o rechazar solicitud | Procedimiento que cambia el estado a `APROBADO` o `RECHAZADO`. Regla clave: calificación D se rechaza automáticamente; solo un analista puede aprobar B o C. Registra quién decidió y cuándo. |
| **VAL04** | Generar cronograma (método francés) | Procedimiento estrella: genera automáticamente todas las cuotas con amortización francesa (capital + interés + cuota fija + fecha de vencimiento). Solo se ejecuta si el préstamo está aprobado. |
| **VAL05** | Registrar pago de cuota | Procedimiento que registra un pago, actualiza el saldo pendiente y marca la cuota como `PAGADA`. Valida: que la cuota exista, que no esté ya pagada, y que el monto coincida. |

---

## Bloque 2 — PKG_SEGURIDAD (SEG01–SEG05)

*Control de acceso, auditoría y protección de datos.*

| Código | Requerimiento | Qué hace y qué valida |
|---|---|---|
| **SEG01** | Autenticar usuario | Función que valida usuario y contraseña (comparando hash, nunca texto plano). Devuelve si el acceso es válido y el rol del usuario. |
| **SEG02** | Verificar permisos por rol *actualizado* | Función que comprueba si el rol del usuario tiene permitido ejecutar cierta operación (ej.: un cajero NO puede aprobar préstamos). Lanza excepción si no tiene permiso. **Actualización:** se suma al Gerente en la matriz de permisos — puede ejecutar reportes, pero se le niega cualquier operación de negocio (registrar, aprobar, pagar). Permite demostrar en la sustentación que el Gerente es rechazado al intentar aprobar un préstamo. |
| **SEG03** | Registrar auditoría | Procedimiento que graba en la bitácora toda acción significativa: usuario, acción, tabla afectada, fecha/hora. Es el "ojo que todo lo ve". |
| **SEG04** | Bloquear usuario por intentos fallidos | Procedimiento que cuenta intentos fallidos de login y bloquea la cuenta tras 3 intentos. El administrador puede desbloquear. |
| **SEG05** | Encriptar y consultar datos sensibles | Usa `DBMS_CRYPTO` para encriptar datos sensibles del cliente (ej.: ingresos, DNI) y una función que solo permite verlos a roles autorizados. Aquí se cubre el requisito de encriptación del caso. |

---

## Bloque 3 — PKG_ADMINISTRACION (ADM01–ADM05)

*Datos maestros, catálogos y parámetros configurables.*

| Código | Requerimiento | Qué hace y qué valida |
|---|---|---|
| **ADM01** | Mantenimiento de clientes | Procedimiento para registrar/actualizar clientes. Valida DNI (8 dígitos, único), mayoría de edad, e ingreso mensual positivo. |
| **ADM02** | Mantenimiento de tipos de préstamo y tasas | CRUD de tipos de préstamo con su tasa de interés configurable, monto mínimo/máximo y plazo permitido. Requisito previo indispensable para que VAL04 pueda calcular el cronograma. |
| **ADM03** | Mantenimiento de usuarios y roles | Procedimiento para crear usuarios del sistema y asignarles rol (analista, cajero, supervisor, gerente, administrador). |
| **ADM04** | Gestión de parámetros del sistema | Administra parámetros globales: % de capacidad de pago, días para morosidad, ratios de calificación. Cambiar un parámetro cambia el comportamiento del sistema sin tocar el código. |
| **ADM05** | Gestión de lista negra de clientes | Procedimiento para agregar/quitar clientes de la lista negra (por morosidad grave o fraude). Es consultado por VAL01 para rechazar solicitudes de entrada. |

---

## Bloque 4 — PKG_CONSULTAS (CON01–CON05)

*Información del día a día para el trabajo operativo.*

| Código | Requerimiento | Qué hace y qué valida |
|---|---|---|
| **CON01** | Consultar cronograma de un préstamo | Función/cursor que devuelve todas las cuotas de un préstamo con su detalle (capital, interés, estado, vencimiento). |
| **CON02** | Consultar saldo y estado de préstamo | Devuelve el saldo pendiente actual, cuántas cuotas van pagadas y el estado general del préstamo. |
| **CON03** | Consultar historial de pagos de un cliente | Lista todos los pagos realizados por un cliente, ordenados por fecha. |
| **CON04** | Buscar clientes/solicitudes por criterios | Búsqueda flexible por nombre, DNI o estado de solicitud. Útil para el analista en el día a día. |
| **CON05** | Consultar cuotas vencidas/morosas | Devuelve las cuotas con más de 5 días de atraso (globales o por cliente). Base para la gestión de cobranza. |

---

## Bloque 5 — PKG_REPORTES (REP01–REP05)

*Información consolidada para la gerencia.*

| Código | Requerimiento | Qué hace y qué valida |
|---|---|---|
| **REP01** | Cartera total de préstamos | Reporte consolidado del monto total prestado, agrupado por estado y por período. La foto general del negocio. |
| **REP02** | Índice de morosidad por período | Calcula el % de morosidad (monto moroso / cartera total) por mes. Indicador clave de salud financiera. |
| **REP03** | Ranking de clientes | Ranking de clientes por monto prestado o por mejor comportamiento de pago. Usa funciones analíticas (`RANK`/`ROW_NUMBER`). *Mejora opcional: mostrar el ranking por código de cliente en vez de DNI, para no exponer datos personales sensibles incluso en la reportería.* |
| **REP04** | Recaudación por período | Total recaudado por mes/período, comparando lo esperado vs. lo efectivamente cobrado. |
| **REP05** | Análisis por tipo/calificación | Distribución de préstamos por tipo y por calificación crediticia (cuántos A, B, C, D). Análisis por categoría. |

---
