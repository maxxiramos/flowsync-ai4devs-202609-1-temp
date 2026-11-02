# Arquitectura de FlowSync

Diagrama de contenedores (estilo C4) de FlowSync tal como está hoy en el código. La persona usa una SPA de React (`frontend/`) que guarda el token de acceso en el `localStorage` del navegador y habla con la API de AdonisJS (`backend/`) por HTTP con JSON, pasando siempre por `src/lib/api.ts`. La API agrupa sus rutas bajo `/api/v1` (las de cuenta y tareas, protegidas con el middleware `auth` del guard de access tokens), responde a través de transformers envueltos en `{ data }` y persiste con Lucid en un único fichero SQLite. Dentro de cada contenedor solo se nombran las piezas que existen en el repo: las pantallas y rutas de React, y los controladores, modelos y transformers del backend.

```mermaid
C4Container
  title FlowSync — diagrama de contenedores

  Person(member, "Miembro del equipo", "Apunta tareas, ve la lista compartida y cambia su estado y su fecha de vencimiento")

  System_Boundary(flowsync, "FlowSync") {
    Container(spa, "SPA web", "React 19, Vite 8, react-router, Tailwind v4, shadcn/ui", "Pantallas /login, /register, /tasks, /tasks/:id y /profile, con los guards ProtectedRoute y PublicOnlyRoute. src/lib/api.ts es el único cliente de la API")
    ContainerDb(storage, "localStorage del navegador", "Web Storage", "Token de acceso bajo la clave flowsync.token, que AuthProvider rehidrata contra GET /account/profile")
    Container(api, "API REST", "AdonisJS 7, VineJS 4, Auth 10 (access tokens)", "Controladores NewAccount, AccessTokens, Profile, Tasks, TaskStatuses y TaskDueDates. Modelos User y Task. Transformers User, Task, TaskDetail y TaskAssignee, con las respuestas envueltas en { data }. Puerto 3333")
    ContainerDb(db, "Base de datos", "SQLite (better-sqlite3) vía Lucid 22", "tmp/db.sqlite3 con las tablas users, auth_access_tokens y tasks (assignee_id → users.id, due_date)")
  }

  Rel(member, spa, "Usa", "Navegador")
  Rel(spa, storage, "Guarda y lee el token")
  Rel(spa, api, "/api/v1/auth, /api/v1/account, /api/v1/tasks", "fetch, JSON, Authorization: Bearer")
  Rel(api, db, "Lee y escribe", "Lucid ORM")
```
