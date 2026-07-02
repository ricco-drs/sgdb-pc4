-- PARTE A : PERMISOS (ejecutar en CONN_SEGURIDAD / C##G01_SEGURIDAD)


-- Permite crear FK hacia t_usuario desde los otros esquemas
GRANT REFERENCES ON t_usuario TO c##g01_negocio;
GRANT REFERENCES ON t_usuario TO c##g01_reportes;

-- Permite leer t_usuario (subconsultas de datos y validaciones)
GRANT SELECT ON t_usuario TO c##g01_negocio;
GRANT SELECT ON t_usuario TO c##g01_reportes;

-- Permite leer t_rol (ADM03 valida roles al crear usuarios)
GRANT SELECT ON t_rol TO c##g01_negocio;

-- Permite a NEGOCIO y REPORTES insertar en la auditoria centralizada
GRANT INSERT ON t_auditoria TO c##g01_negocio;
GRANT INSERT ON t_auditoria TO c##g01_reportes;


-- PARTE B : FK CRUZADAS DE NEGOCIO (ejecutar en CONN_NEGOCIO)

ALTER TABLE t_cliente
  ADD CONSTRAINT fk_cliente_usuario
  FOREIGN KEY (id_usuario_registro)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);

ALTER TABLE t_solicitud
  ADD CONSTRAINT fk_solicitud_analista
  FOREIGN KEY (id_analista)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);

ALTER TABLE t_solicitud
  ADD CONSTRAINT fk_solicitud_analista_dec
  FOREIGN KEY (id_analista_decision)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);

ALTER TABLE t_prestamo
  ADD CONSTRAINT fk_prestamo_aprobador
  FOREIGN KEY (id_analista_aprobador)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);

ALTER TABLE t_pago
  ADD CONSTRAINT fk_pago_cajero
  FOREIGN KEY (id_cajero)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);

ALTER TABLE t_parametro
  ADD CONSTRAINT fk_parametro_usuario
  FOREIGN KEY (id_usuario_modificacion)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);

ALTER TABLE t_lista_negra
  ADD CONSTRAINT fk_lista_negra_usuario
  FOREIGN KEY (id_usuario_registro)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);


-- PARTE C : FK CRUZADA DE REPORTES (ejecutar en CONN_REPORTES)

ALTER TABLE t_log_reporte
  ADD CONSTRAINT fk_logrep_usuario
  FOREIGN KEY (id_usuario_ejecutor)
  REFERENCES c##g01_seguridad.t_usuario (id_usuario);
