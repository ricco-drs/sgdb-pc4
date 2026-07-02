-- ---------------------------------------------------------------------
-- TABLA: T_LOG_REPORTE (bitacora de ejecucion de reportes)
-- FK a t_usuario (seguridad) -> se agrega en script 05
-- ---------------------------------------------------------------------
CREATE TABLE t_log_reporte (
  id_log_reporte       NUMBER          NOT NULL,
  codigo_reporte       VARCHAR2(10)    NOT NULL,
  id_usuario_ejecutor  NUMBER          NOT NULL,
  parametros           VARCHAR2(200),
  fecha_ejecucion      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  filas_retornadas     NUMBER,
  CONSTRAINT pk_log_reporte PRIMARY KEY (id_log_reporte),
  CONSTRAINT ck_log_codigo CHECK (codigo_reporte IN ('REP01','REP02','REP03','REP04','REP05'))
);
