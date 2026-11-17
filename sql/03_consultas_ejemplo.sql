-- =============================================================================
-- Consultas que justifican elegir RDS: JOINs y transacciones ACID
-- =============================================================================
USE educloud;

-- Datos de prueba
INSERT INTO instructores (nombre, email) VALUES ('Laura Gómez', 'laura@educloud.example');
INSERT INTO cursos (titulo, instructor_id, precio_usd, publicado) VALUES
  ('AWS Cloud Practitioner', 1, 49.90, TRUE), ('Python desde cero', 1, 29.90, TRUE);
INSERT INTO lecciones (curso_id, orden, titulo, video_s3_key) VALUES
  (1, 1, '¿Qué es la nube?', 'cursos/aws-101/leccion-01.mp4'),
  (1, 2, 'Modelo de responsabilidad compartida', 'cursos/aws-101/leccion-02.mp4'),
  (2, 1, 'Variables y tipos de datos', 'cursos/python-101/leccion-01.mp4');
INSERT INTO estudiantes (nombre, email) VALUES
  ('Ana López', 'ana@example.com'), ('Juan Pérez', 'juan@example.com');

-- 1) TRANSACCIÓN ACID: inscribir y cobrar es "todo o nada".
--    Si el INSERT del pago falla, el ROLLBACK deshace también la inscripción:
--    nunca queda un estudiante inscripto sin pago, ni un pago sin inscripción.
START TRANSACTION;
  INSERT INTO inscripciones (estudiante_id, curso_id) VALUES (1, 1);
  SET @insc := LAST_INSERT_ID();
  INSERT INTO pagos (inscripcion_id, monto_usd, estado, referencia_pasarela)
    VALUES (@insc, 49.90, 'aprobado', 'PAY-0001');
  UPDATE inscripciones SET estado = 'activa' WHERE id = @insc;
COMMIT;

START TRANSACTION;
  INSERT INTO inscripciones (estudiante_id, curso_id) VALUES (2, 1);
  SET @insc := LAST_INSERT_ID();
  INSERT INTO pagos (inscripcion_id, monto_usd, estado, referencia_pasarela)
    VALUES (@insc, 49.90, 'aprobado', 'PAY-0002');
  UPDATE inscripciones SET estado = 'activa' WHERE id = @insc;
COMMIT;

START TRANSACTION;
  INSERT INTO inscripciones (estudiante_id, curso_id) VALUES (1, 2);
  SET @insc := LAST_INSERT_ID();
  INSERT INTO pagos (inscripcion_id, monto_usd, estado, referencia_pasarela)
    VALUES (@insc, 29.90, 'aprobado', 'PAY-0003');
  UPDATE inscripciones SET estado = 'activa' WHERE id = @insc;
COMMIT;

INSERT INTO progreso (estudiante_id, leccion_id) VALUES (1, 1), (1, 2), (2, 1);

-- 2) REPORTE FINANCIERO con JOIN de 4 tablas: ingresos por curso e instructor.
--    En DynamoDB no hay JOINs: habría que leer varias tablas y cruzarlas en el código.
SELECT c.titulo                AS curso,
       i.nombre                AS instructor,
       COUNT(p.id)             AS ventas,
       SUM(p.monto_usd)        AS ingresos_usd
FROM pagos p
JOIN inscripciones ins ON ins.id = p.inscripcion_id
JOIN cursos c          ON c.id   = ins.curso_id
JOIN instructores i    ON i.id   = c.instructor_id
WHERE p.estado = 'aprobado'
GROUP BY c.id, c.titulo, i.nombre
ORDER BY ingresos_usd DESC;

-- 3) PROGRESO de cada estudiante en cada curso (% de lecciones completadas).
SELECT e.nombre AS estudiante, c.titulo AS curso,
       COALESCE(ROUND(100 * COUNT(pr.leccion_id) / NULLIF(COUNT(l.id), 0), 0), 0) AS avance_pct
FROM inscripciones ins
JOIN estudiantes e ON e.id = ins.estudiante_id
JOIN cursos c      ON c.id = ins.curso_id
LEFT JOIN lecciones l ON l.curso_id = c.id
LEFT JOIN progreso pr ON pr.leccion_id = l.id AND pr.estudiante_id = e.id
WHERE ins.estado = 'activa'
GROUP BY e.id, e.nombre, c.id, c.titulo
ORDER BY e.nombre, c.titulo;

-- 4) INTEGRIDAD: esta inscripción duplicada se RECHAZA (UNIQUE estudiante + curso).
-- INSERT INTO inscripciones (estudiante_id, curso_id) VALUES (1, 1);
--   -> ERROR 1062: Duplicate entry '1-1' for key 'uq_estudiante_curso'
