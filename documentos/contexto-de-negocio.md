# Sistema de Gestión de Préstamos Personales para una Institución Financiera

> Proyecto del curso **SW609 – Sistemas de Gestión de Base de Datos**
> Universidad Nacional de Ingeniería | Docente: Dr. Eric Gustavo Coronel Castillo

---

## Contexto de Negocio: "PrestaFácil"

**PrestaFácil** es una fintech peruana especializada en préstamos personales rápidos para trabajadores y emprendedores, bajo el lema *"Tu crédito en 24 horas, sin vueltas"*. A diferencia de un banco tradicional, su ventaja competitiva son las decisiones ágiles y transparentes — algo que solo es posible si su información está perfectamente ordenada y protegida.

### El problema

La empresa creció más rápido que su infraestructura. Pasaron de una hoja de cálculo a gestionar cientos de préstamos al mes, con:

- Cuotas calculadas a mano.
- Pagos anotados en cuadernos.
- Sin certeza de cuánto dinero está prestado ni quién está atrasado.
- Cualquier empleado con acceso al Excel puede ver datos personales y financieros de todos los clientes — un riesgo grave bajo normativas financieras.

### La solución

Una base de datos robusta en **Oracle 19c** que sea el corazón del negocio: que calcule, controle, audite y reporte todo automáticamente, garantizando además que **cada persona vea solo lo que le corresponde**.

---

## Actores del sistema

| Rol | Qué hace | Nivel de acceso |
|---|---|---|
|  Analista de crédito | Registra solicitudes, evalúa clientes y aprueba/rechaza préstamos | Opera datos de negocio |
|  Cajero | Registra los pagos de las cuotas de los clientes | Opera datos de negocio (limitado) |
|  Supervisor | Consulta el estado operativo, cuotas morosas y cartera | Lectura operativa |
|  Gerente | Analiza reportes consolidados para tomar decisiones estratégicas | Solo reportes — nunca datos crudos |
|  Administrador | Gestiona usuarios, tasas, parámetros y seguridad del sistema | Administración y seguridad |

---

## Seguridad: cada quien ve lo suyo

El diseño de PrestaFácil se basa en separar físicamente tres tipos de información con sensibilidades muy distintas:

1. **Información operativa** (clientes, préstamos, cuotas, pagos) → la manejan analistas y cajeros en su día a día.
2. **Información de seguridad** (usuarios, roles, contraseñas, auditoría) → solo la toca el administrador; es el "cuarto blindado" del sistema.
3. **Información gerencial** (reportes consolidados, indicadores, rankings) → la consume el Gerente, que necesita ver números y tendencias, pero **jamás** los datos personales crudos de un cliente (DNI, ingresos exactos).

El caso del Gerente ilustra el principio de **mínimo privilegio** de forma tangible: aunque quisiera, no puede modificar un préstamo ni husmear un DNI, porque simplemente no tiene acceso al esquema donde vive esa información.

---

## Ciclo de vida de un préstamo

1. **Solicitud ** — El analista registra al cliente (datos personales, ingresos mensuales) y crea una solicitud por un monto y plazo deseados.
2. **Evaluación ** — El sistema calcula automáticamente la capacidad de pago con una fórmula fija (40% del ingreso) y asigna una calificación crediticia (A, B, C o D).
3. **Decisión ** — Según la calificación, el analista aprueba, rechaza o deja pendiente la solicitud. *(Regla: calificación D se rechaza automáticamente)*.
4. **Cronograma ** — Si se aprueba, el sistema genera automáticamente el cronograma de cuotas con el **método francés de amortización** (capital + interés + fecha de vencimiento por cada cuota).
5. **Pagos ** — El cajero registra los pagos. El sistema actualiza el saldo y marca la cuota como pagada.
6. **Morosidad ** — Si una cuota pasa 5 días de vencida sin pagar, el sistema la marca como morosa y genera una alerta interna.
7. **Auditoría ** — Toda acción importante (aprobar, rechazar, pagar, editar) queda registrada con usuario + fecha/hora en una bitácora.
8. **Decisiones gerenciales ** — El Gerente consulta reportes consolidados (cartera total, índice de morosidad, rankings, recaudación) para dirigir el rumbo del negocio, sin tocar jamás un dato operativo.

---

## Reglas de negocio clave

| Regla | Definición |
|---|---|
| Capacidad de pago | 40% del ingreso mensual del cliente |
| Calificación crediticia | Según ratio cuota/ingreso: A (≤30%), B (≤40%), C (≤50%), D (>50%) |
| Rechazo automático | Toda solicitud con calificación D se rechaza |
| Tasa de interés | Fija por tipo de préstamo (parámetro configurable) |
| Alerta de morosidad | Cuota con más de 5 días de atraso |
| Método de amortización | Francés (cuota fija mensual) |
| Segregación de acceso | El Gerente accede solo a reportes; nunca a datos personales operativos |

---

## Arquitectura: organización en 3 esquemas

| Esquema | Contenido | Quién accede | Modo |
|---|---|---|---|
| `G01_NEGOCIO` | Clientes, solicitudes, préstamos, cuotas, pagos, catálogos + paquetes de valor, administración y consultas | Analista, Cajero, Supervisor | Lectura/escritura según rol |
| `G01_SEGURIDAD` | Usuarios, roles, auditoría, intentos de login + paquete de seguridad | Administrador | Restringido |
| `G01_REPORTES` | Paquete de reportes y vistas consolidadas | Gerente, Supervisor | Solo lectura |

**Justificación:** cada tipo de información vive en su propio esquema porque cada rol tiene una necesidad de acceso distinta, y separarlos físicamente hace imposible que alguien vea o toque lo que no le corresponde — seguridad real, no decorativa.

---

## Stack tecnológico

- **Motor de base de datos:** Oracle Database 19c Enterprise Edition
- **Lenguaje procedural:** PL/SQL (funciones, procedimientos, triggers, paquetes)
- **Cliente de administración:** SQL Developer

---

## Autores

Ricco Didier Rashuaman Sapallanay
Christopher Henrry Albino Soto
Luis Angel Vargas Ponce 
Curso: SW609 – Sistemas de Gestión de Base de Datos
