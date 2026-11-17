-- =============================================================================
-- EduCloud · Esquema relacional en Amazon RDS for MySQL 8.4
-- Autora: María Cecilia Alegre
--
-- Por qué relacional: los datos de EduCloud están conectados entre sí
-- (un estudiante se inscribe en muchos cursos, cada inscripción tiene pagos,
-- cada curso tiene lecciones) y los pagos necesitan transacciones ACID.
-- Las claves foráneas (FOREIGN KEY) impiden, por ejemplo, registrar un pago
-- de una inscripción que no existe.
--
-- Los archivos pesados (videos, PDFs) NO se guardan acá: viven en el bucket
-- S3 educloud-contenido-usuarios-2026-use1 (Pre-entrega 4). La base solo
-- guarda la clave del objeto en S3.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS educloud CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE educloud;

-- Perfiles de usuario: estructura fija, el email no se puede repetir.
CREATE TABLE estudiantes (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(120) NOT NULL,
  email       VARCHAR(255) NOT NULL UNIQUE,
  pais        CHAR(2)      NOT NULL DEFAULT 'AR',
  fecha_alta  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE instructores (
  id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre  VARCHAR(120) NOT NULL,
  email   VARCHAR(255) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Catálogo de cursos: cada curso pertenece a un instructor.
CREATE TABLE cursos (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  titulo         VARCHAR(200)  NOT NULL,
  instructor_id  BIGINT UNSIGNED NOT NULL,
  precio_usd     DECIMAL(10,2) NOT NULL CHECK (precio_usd >= 0),  -- DECIMAL: sin errores de redondeo en montos
  publicado      BOOLEAN       NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_curso_instructor FOREIGN KEY (instructor_id) REFERENCES instructores(id)
) ENGINE=InnoDB;

CREATE TABLE lecciones (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  curso_id      BIGINT UNSIGNED NOT NULL,
  orden         SMALLINT UNSIGNED NOT NULL,
  titulo        VARCHAR(200) NOT NULL,
  video_s3_key  VARCHAR(500) NULL,           -- ej.: cursos/aws-101/leccion-01.mp4 (el video está en S3)
  CONSTRAINT fk_leccion_curso FOREIGN KEY (curso_id) REFERENCES cursos(id) ON DELETE CASCADE,
  UNIQUE KEY uq_orden (curso_id, orden)
) ENGINE=InnoDB;

-- Relación muchos a muchos: un estudiante tiene muchos cursos y un curso muchos estudiantes.
CREATE TABLE inscripciones (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  estudiante_id  BIGINT UNSIGNED NOT NULL,
  curso_id       BIGINT UNSIGNED NOT NULL,
  estado         ENUM('pendiente_pago','activa','cancelada') NOT NULL DEFAULT 'pendiente_pago',
  fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_insc_estudiante FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
  CONSTRAINT fk_insc_curso      FOREIGN KEY (curso_id)      REFERENCES cursos(id),
  UNIQUE KEY uq_estudiante_curso (estudiante_id, curso_id)   -- nadie se inscribe dos veces al mismo curso
) ENGINE=InnoDB;

-- Transacciones: necesitan consistencia fuerte y no se pueden perder.
CREATE TABLE pagos (
  id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  inscripcion_id   BIGINT UNSIGNED NOT NULL,
  monto_usd        DECIMAL(10,2) NOT NULL CHECK (monto_usd > 0),
  estado           ENUM('aprobado','rechazado','reintegrado') NOT NULL,
  referencia_pasarela VARCHAR(100) NOT NULL UNIQUE,         -- evita registrar dos veces el mismo cobro
  fecha            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pago_inscripcion FOREIGN KEY (inscripcion_id) REFERENCES inscripciones(id),
  KEY idx_pagos_fecha (fecha)                                -- acelera el reporte diario
) ENGINE=InnoDB;

CREATE TABLE progreso (
  estudiante_id  BIGINT UNSIGNED NOT NULL,
  leccion_id     BIGINT UNSIGNED NOT NULL,
  completada_en  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (estudiante_id, leccion_id),
  CONSTRAINT fk_prog_estudiante FOREIGN KEY (estudiante_id) REFERENCES estudiantes(id),
  CONSTRAINT fk_prog_leccion    FOREIGN KEY (leccion_id)    REFERENCES lecciones(id) ON DELETE CASCADE
) ENGINE=InnoDB;
