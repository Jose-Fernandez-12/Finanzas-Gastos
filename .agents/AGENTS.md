# Reglas del Proyecto — App de Finanzas

## 1. Validación Estricta de Campos NOT NULL en SQLite
Al implementar o modificar endpoints de escritura (`POST`, `PUT`, `PATCH`) en el backend (`backend/src/routes/`):
- **Verificar siempre el esquema (`schema.sql`)** para identificar las columnas marcadas como `NOT NULL`.
- **Paridad entre POST y PUT**: Cualquier lógica de cálculo o derivación de valores por defecto que se aplique en la creación (`POST`) debe aplicarse exactamente igual en la actualización (`PUT`). Por ejemplo, si en `POST /ingresos` se calcula `mes_referencia = mes_referencia || fecha.slice(0, 7)`, en `PUT /ingresos/:id` se debe realizar el mismo cálculo antes de ejecutar el `UPDATE`.
- **Prevención de `undefined` y `null`**: Asegurar que ningún parámetro enviado a `db.run()` sea `undefined`. Si una columna permite nulos, usar explícitamente `valor || null`. Si es `NOT NULL`, garantizar un valor por defecto válido o retornar un error HTTP 400 antes de ejecutar la consulta.
