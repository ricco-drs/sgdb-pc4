
-- Vista 1: Prestamos activos con datos del cliente
CREATE OR REPLACE VIEW v_prestamos_activos AS
SELECT p.id_prestamo,
       cl.id_cliente,
       cl.nombres || ' ' || cl.apellidos AS cliente,
       cl.dni,
       tp.nombre                AS tipo_prestamo,
       p.monto_aprobado,
       p.cuota_mensual,
       p.saldo_pendiente,
       p.plazo_meses,
       p.fecha_desembolso,
       p.estado
  FROM t_prestamo p
  JOIN t_solicitud s     ON s.id_solicitud = p.id_solicitud
  JOIN t_cliente cl      ON cl.id_cliente = s.id_cliente
  JOIN t_tipo_prestamo tp ON tp.id_tipo_prestamo = s.id_tipo_prestamo
 WHERE p.estado = 'VIGENTE';

-- Vista 2: Cuotas pendientes con datos del cliente (para cobranza)
CREATE OR REPLACE VIEW v_cuotas_pendientes AS
SELECT c.id_cuota,
       p.id_prestamo,
       cl.id_cliente,
       cl.nombres || ' ' || cl.apellidos AS cliente,
       c.numero_cuota,
       c.fecha_vencimiento,
       c.monto_cuota,
       c.monto_pagado,
       (c.monto_cuota - c.monto_pagado)  AS saldo_cuota,
       c.estado,
       TRUNC(SYSDATE - c.fecha_vencimiento) AS dias_atraso
  FROM t_cuota c
  JOIN t_prestamo p  ON p.id_prestamo = c.id_prestamo
  JOIN t_solicitud s ON s.id_solicitud = p.id_solicitud
  JOIN t_cliente cl  ON cl.id_cliente = s.id_cliente
 WHERE c.estado <> 'PAGADA';


-- #####################################################################
-- PARTE B : VISTA GERENCIAL (ejecutar en CONN_REPORTES)
-- #####################################################################

-- Vista gerencial: resumen consolidado de la cartera
CREATE OR REPLACE VIEW v_resumen_cartera AS
SELECT p.estado,
       COUNT(*)                AS cantidad_prestamos,
       SUM(p.monto_aprobado)   AS monto_total_prestado,
       SUM(p.saldo_pendiente)  AS saldo_por_cobrar,
       ROUND(AVG(p.monto_aprobado), 2) AS ticket_promedio
  FROM c##g01_negocio.t_prestamo p
 GROUP BY p.estado;
