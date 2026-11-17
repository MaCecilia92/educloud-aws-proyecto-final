# Políticas IAM de la capa de cómputo

| Archivo | Se adjunta a | Qué permite |
|---|---|---|
| `politica-iam-ec2-web.json` | Rol IAM de las instancias EC2 (perfil de instancia) | Leer **solo** el secreto `educloud/rds/app` y publicar en el tema SNS `nuevo-registro` (Pre-entrega 3). |
| `politica-iam-lambda-reportes.json` | Rol de ejecución de la Lambda `reporte-diario` | Leer **solo** el secreto `educloud/rds/reportes` y enviar el resumen con SES desde una dirección fija. Además lleva la política administrada `AWSLambdaVPCAccessExecutionRole` (crear sus interfaces de red en la VPC y escribir logs). |

- El `*` al final del ARN del secreto es necesario: Secrets Manager agrega 6 caracteres al azar al nombre (`educloud/rds/app-AbC123`).
- Reemplazar `<ID_DE_CUENTA>` por el ID de la cuenta de AWS. No se publica en el repositorio.
- IAM decide **quién puede leer la contraseña**; el Security Group decide **quién puede llegar a la base por la red**. Hacen falta las dos cosas para conectarse.
