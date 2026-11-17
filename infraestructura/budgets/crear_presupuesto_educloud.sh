#!/usr/bin/env bash
# =============================================================================
# EduCloud: presupuesto mensual de USD 209,89 con alertas escalonadas (AWS Budgets)
# Monto = costo mensual de la estimación final en AWS Pricing Calculator
# Autora: María Cecilia Alegre
#
# PERMISOS IAM NECESARIOS para quien ejecute este script:
#   - budgets:ModifyBudget  -> crea y modifica presupuestos y sus notificaciones
#                              (en IAM no existe una acción "budgets:CreateBudget";
#                               la API CreateBudget se autoriza con ModifyBudget)
#   - budgets:TagResource   -> obligatorio porque el presupuesto se crea con tags
#   - budgets:ViewBudget    -> para el paso de verificación del final
#
# REGIÓN: AWS Budgets es un servicio global, pero su API vive en us-east-1.
#         Por eso se fija --region us-east-1 aunque los recursos estén en otra región.
#
# USO:
#   ACCOUNT_ID=123456789012 EMAIL=estudiante@ejemplo.com ./crear_presupuesto.sh
#   DRY_RUN=1 ./crear_presupuesto.sh      # solo muestra y valida el JSON, no crea nada
# =============================================================================
set -euo pipefail

ACCOUNT_ID="${ACCOUNT_ID:-123456789012}"          # ID de la cuenta (12 dígitos)
EMAIL="${EMAIL:-estudiante@ejemplo.com}"          # destinatario de las alertas
REGION="us-east-1"                                # endpoint de la API de Budgets
BUDGET_NAME="${BUDGET_NAME:-EduCloud-Presupuesto-Mensual-Produccion}"  # usar otro nombre para pruebas

# --- Presupuesto -------------------------------------------------------------
# BudgetType COST    -> mide dinero (USAGE mediría unidades, como GB u horas)
# TimeUnit MONTHLY   -> el contador vuelve a cero el día 1 de cada mes
# CostTypes:
#   UseAmortized true  -> los pagos por adelantado (RI / Savings Plans) se reparten
#                         entre los meses que cubren, para que un pago All Upfront
#                         no dispare las alertas el mes en que se paga
#   UseBlended false   -> usa la tarifa real de cada cuenta, no el promedio de la organización
#   IncludeCredit false -> los créditos (plan gratuito, promociones) NO restan del gasto
#                         medido: así la alerta avisa del consumo real aunque lo cubran créditos
#                         (los demás tipos de costo quedan en su valor por defecto: incluidos)
BUDGET_JSON=$(cat <<JSON
{
  "BudgetName": "${BUDGET_NAME}",
  "BudgetLimit": { "Amount": "${MONTO:-209.89}", "Unit": "USD" },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostTypes": {
    "UseAmortized": true,
    "UseBlended": false,
    "IncludeCredit": false
  }
}
JSON
)

# --- Notificaciones (alertas escalonadas) ------------------------------------
# Alerta 1 · ACTUAL     >  50 % -> aviso temprano: se gastaron más de USD 104,94
# Alerta 2 · ACTUAL     >  80 % -> margen para reaccionar: más de USD 167,91 gastados
# Alerta 3 · FORECASTED > 100 % -> a este ritmo el mes cerrará por encima de USD 209,89
#                                 (requiere unas 5 semanas de historial para calcularse)
# Los suscriptores EMAIL no necesitan un tópico SNS.
NOTIFICATIONS_JSON=$(cat <<JSON
[
  {
    "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN",
                      "Threshold": 50, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "${EMAIL}" } ]
  },
  {
    "Notification": { "NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN",
                      "Threshold": 80, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "${EMAIL}" } ]
  },
  {
    "Notification": { "NotificationType": "FORECASTED", "ComparisonOperator": "GREATER_THAN",
                      "Threshold": 100, "ThresholdType": "PERCENTAGE" },
    "Subscribers": [ { "SubscriptionType": "EMAIL", "Address": "${EMAIL}" } ]
  }
]
JSON
)

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "== budget ==";        echo "$BUDGET_JSON"        | python3 -m json.tool
  echo "== notificaciones =="; echo "$NOTIFICATIONS_JSON" | python3 -m json.tool
  exit 0
fi

# --- Creación ------------------------------------------------------------------
# Tags de organización: permiten encontrar y filtrar el presupuesto por proyecto.
aws budgets create-budget \
  --region "$REGION" \
  --account-id "$ACCOUNT_ID" \
  --budget "$BUDGET_JSON" \
  --notifications-with-subscribers "$NOTIFICATIONS_JSON" \
  --resource-tags Key=Proyecto,Value=EduCloud Key=Entorno,Value=Produccion Key=Responsable,Value=MariaCeciliaAlegre

# --- Verificación --------------------------------------------------------------
echo "Presupuesto creado. Configuración guardada en AWS:"
aws budgets describe-budget --region "$REGION" --account-id "$ACCOUNT_ID" \
  --budget-name "$BUDGET_NAME" \
  --query 'Budget.{Nombre:BudgetName,Limite:BudgetLimit,Periodo:TimeUnit,TiposDeCosto:CostTypes}'
echo "Alertas configuradas:"
aws budgets describe-notifications-for-budget --region "$REGION" --account-id "$ACCOUNT_ID" \
  --budget-name "$BUDGET_NAME" \
  --query 'Notifications[].{Tipo:NotificationType,Umbral:Threshold}' --output table
