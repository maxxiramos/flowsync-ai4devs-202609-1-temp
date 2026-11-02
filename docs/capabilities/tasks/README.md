# Capability `tasks`

La lista de trabajo del equipo: una sola lista compartida con todas las tareas del espacio, donde crear una tarea cuesta escribir su título y donde se ve sin abrir nada quién lleva cada una y en qué estado está. Cada tarea puede tener además una fecha de vencimiento, que se pone y se consulta al abrirla.

> **Las reglas están en la spec, no aquí.** El comportamiento que se espera de esta capability está en [`openspec/specs/tasks/spec.md`](../../../openspec/specs/tasks/spec.md), con sus requisitos y scenarios. Este README solo dice dónde vive cada cosa en el código y cómo probarla. Si algo de aquí contradice a la spec, manda la spec ([ADR 0001](../../adr/0001-openspec-como-fuente-de-verdad.md)).

## Endpoints

Todos van bajo `/api/v1/tasks`, piden `Authorization: Bearer <token>` y responden envueltos en `{ data: ... }`. El contrato completo (parámetros, cuerpos, códigos y esquemas) lo sirve la propia API en `http://localhost:3333/api`, generado desde las anotaciones de los controladores.

| Método | Ruta | Controlador | Qué devuelve |
|---|---|---|---|
| `GET` | `/api/v1/tasks` | [`TasksController.index`](../../../backend/app/controllers/tasks_controller.ts) | La lista (`TaskTransformer`). Query opcional `status` |
| `POST` | `/api/v1/tasks` | [`TasksController.store`](../../../backend/app/controllers/tasks_controller.ts) | La tarea creada, con `201` (`TaskTransformer`). Cuerpo `{ title }` |
| `GET` | `/api/v1/tasks/:id` | [`TasksController.show`](../../../backend/app/controllers/tasks_controller.ts) | La tarea suelta con su vencimiento (`TaskDetailTransformer`). Query obligatoria `today` |
| `PATCH` | `/api/v1/tasks/:id/status` | [`TaskStatusesController.update`](../../../backend/app/controllers/task_statuses_controller.ts) | La tarea con su estado nuevo (`TaskTransformer`). Cuerpo `{ status }` |
| `PUT` | `/api/v1/tasks/:id/due-date` | [`TaskDueDatesController.update`](../../../backend/app/controllers/task_due_dates_controller.ts) | La tarea con su fecha nueva (`TaskDetailTransformer`). Cuerpo `{ dueDate, today }` |

Las rutas están declaradas en [`backend/start/routes.ts`](../../../backend/start/routes.ts).

## Reglas de negocio: dónde se implementan

La lista de requisitos y lo que exige cada uno están en la [spec](../../../openspec/specs/tasks/spec.md). Lo que sigue es el mapa de dónde vive cada grupo de reglas en el código, para saber qué tocar cuando cambie un requisito.

| Grupo de requisitos de la spec | Dónde se implementa |
|---|---|
| Creación, título obligatorio y límite de longitud | `createTaskValidator` en [`app/validators/task.ts`](../../../backend/app/validators/task.ts); responsable y estado iniciales en `TasksController.store` |
| Lista compartida, vista por defecto y orden | `TasksController.index` y `DEFAULT_LIST_STATUSES` en [`app/models/task.ts`](../../../backend/app/models/task.ts) |
| Acotar la lista por estado | `listTasksValidator` en [`app/validators/task.ts`](../../../backend/app/validators/task.ts) y `TasksController.index` |
| Tres estados fijos y cambio de estado | `TASK_STATUSES` en [`app/models/task.ts`](../../../backend/app/models/task.ts), `updateTaskStatusValidator` y `TaskStatusesController` |
| Lo que la tarea muestra de su responsable | [`TaskAssigneeTransformer`](../../../backend/app/transformers/task_assignee_transformer.ts) y el getter `initials` de [`User`](../../../backend/app/models/user.ts) |
| La lista no lleva el vencimiento | [`TaskTransformer`](../../../backend/app/transformers/task_transformer.ts), separado a propósito de [`TaskDetailTransformer`](../../../backend/app/transformers/task_detail_transformer.ts) |
| Fecha de vencimiento, cuándo está vencida y día de referencia | `Task.isOverdueOn` en [`app/models/task.ts`](../../../backend/app/models/task.ts), `taskReferenceDayValidator` y `setTaskDueDateValidator`, y `TaskDueDatesController` |
| Las tareas exigen sesión | `middleware.auth()` sobre el grupo de rutas en [`start/routes.ts`](../../../backend/start/routes.ts) |
| Pantallas, filtro en la dirección y mensajes de lista vacía | [`pages/tasks-page.tsx`](../../../frontend/src/pages/tasks-page.tsx), [`pages/task-page.tsx`](../../../frontend/src/pages/task-page.tsx), [`components/task-item.tsx`](../../../frontend/src/components/task-item.tsx) y [`components/task-filter.tsx`](../../../frontend/src/components/task-filter.tsx) |

Datos:
- **Tabla `tasks`:** la crean [`database/migrations/1786642030284_create_tasks_table.ts`](../../../backend/database/migrations/1786642030284_create_tasks_table.ts) y [`1786644500000_add_due_date_to_tasks_table.ts`](../../../backend/database/migrations/1786644500000_add_due_date_to_tasks_table.ts).
- **Llamadas desde el frontend:** pasan todas por [`frontend/src/lib/api.ts`](../../../frontend/src/lib/api.ts).
- **Esquemas del documento OpenAPI:** están en [`app/openapi/schemas.ts`](../../../backend/app/openapi/schemas.ts).

## Cómo se prueba en local

### Arrancar

Desde la raíz, con GNU Make (`Makefile` para PowerShell en Windows; `make -f Makefile.linux` en macOS, Linux o WSL):

```bash
make setup   # dependencias, .env, APP_KEY y migraciones
make start   # backend en http://localhost:3333 y frontend con Vite
```

O a mano, cada parte desde su carpeta:

```bash
cd backend && npm install && cp .env.example .env && node ace generate:key && node ace migration:run && npm run dev
cd frontend && npm install && cp .env.example .env && npm run dev
```

En el navegador, la lista está en `/tasks` y cada tarea en `/tasks/:id`; las dos piden haber iniciado sesión.

### Tests automáticos

```bash
cd backend
node ace test --files="tasks/*"   # solo los de esta capability
node ace test                     # toda la suite
```

Los tests de `tasks` están en [`backend/tests/functional/tasks/`](../../../backend/tests/functional/tasks/). Cada test corre dentro de una transacción global que se deshace al terminar, porque la suite usa el mismo fichero SQLite que el servidor de desarrollo. Hoy solo cubren parte de los scenarios de la spec: conviene contrastar con ella qué falta antes de dar algo por probado.

### A mano contra la API

Con el backend en marcha. Lo que se cree así se queda en `backend/tmp/db.sqlite3`, la base del servidor de desarrollo. En PowerShell, usa `curl.exe` en vez de `curl`.

```bash
# 1. Crear una cuenta; la respuesta trae el token en data.token
curl -s -X POST http://localhost:3333/api/v1/auth/signup \
  -H 'Content-Type: application/json' \
  -d '{"fullName":"Ada Lovelace","email":"ada@example.com","password":"secreto123","passwordConfirmation":"secreto123"}'

TOKEN=<el valor de data.token>

# 2. Crear una tarea, listar y acotar por estado
curl -s -X POST http://localhost:3333/api/v1/tasks -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"title":"Revisar el informe"}'
curl -s http://localhost:3333/api/v1/tasks -H "Authorization: Bearer $TOKEN"
curl -s "http://localhost:3333/api/v1/tasks?status=done" -H "Authorization: Bearer $TOKEN"

# 3. Cambiar el estado, poner fecha y consultar la tarea suelta
curl -s -X PATCH http://localhost:3333/api/v1/tasks/1/status -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"status":"in_progress"}'
curl -s -X PUT http://localhost:3333/api/v1/tasks/1/due-date -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"dueDate":"2026-09-30","today":"2026-10-27"}'
curl -s "http://localhost:3333/api/v1/tasks/1?today=2026-10-27" -H "Authorization: Bearer $TOKEN"
```

Para explorar los endpoints sin `curl`, está la interfaz de Scalar en `http://localhost:3333/api`.
