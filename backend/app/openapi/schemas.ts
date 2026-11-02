import { TASK_STATUSES } from '#models/task'
import { ApiProperty, ApiPropertyOptional } from '@foadonis/openapi/decorators'

/**
 * Esquemas OpenAPI de lo que la API de tareas devuelve. Cada clase se publica
 * en `components.schemas` con su nombre y las respuestas la referencian, así
 * que el documento describe cada forma una sola vez.
 *
 * Describen lo que sale hoy de los transformers y del manejador de errores, no
 * lo que debería salir: si un transformer cambia, esto se cambia con él.
 */

/** `TaskAssigneeTransformer`: lo justo para identificar al responsable. */
export class TaskAssignee {
  @ApiProperty({ type: 'integer' })
  declare id: number

  @ApiProperty({ type: 'string', nullable: true })
  declare fullName: string | null

  @ApiProperty({ type: 'string', description: 'Sale del nombre, o del email si no hay nombre' })
  declare initials: string
}

/** `TaskTransformer`: la tarea tal como la da la lista. Sin vencimiento. */
export class Task {
  @ApiProperty({ type: 'integer' })
  declare id: number

  @ApiProperty({ type: 'string', maxLength: 200 })
  declare title: string

  @ApiProperty({ enum: [...TASK_STATUSES] })
  declare status: string

  @ApiProperty({ type: 'string', format: 'date-time' })
  declare createdAt: string

  @ApiProperty({ type: 'string', format: 'date-time', nullable: true })
  declare updatedAt: string | null

  @ApiProperty({ type: TaskAssignee })
  declare assignee: TaskAssignee
}

/** `TaskDetailTransformer`: la tarea suelta, con su vencimiento resuelto. */
export class TaskDetail extends Task {
  @ApiProperty({ type: 'string', format: 'date', nullable: true })
  declare dueDate: string | null

  @ApiProperty({ type: 'boolean', description: 'Resuelto contra el día `today` de la petición' })
  declare isOverdue: boolean
}

/** El envoltorio `{ data }` que añade `serialize()` a toda respuesta. */
export class TaskResponse {
  @ApiProperty({ type: Task })
  declare data: Task
}

export class TaskListResponse {
  @ApiProperty({ type: [Task] })
  declare data: Task[]
}

export class TaskDetailResponse {
  @ApiProperty({ type: TaskDetail })
  declare data: TaskDetail
}

/** Un error de VineJS: siempre señala el campo y la regla que no se cumplió. */
export class ValidationError {
  @ApiProperty({ type: 'string' })
  declare field: string

  @ApiProperty({ type: 'string' })
  declare rule: string

  @ApiProperty({ type: 'string' })
  declare message: string

  @ApiPropertyOptional({ type: 'object' })
  declare meta?: Record<string, unknown>
}

export class ValidationErrorResponse {
  @ApiProperty({ type: [ValidationError] })
  declare errors: ValidationError[]
}

export class ErrorMessage {
  @ApiProperty({ type: 'string' })
  declare message: string
}

/** Lo que responde el middleware `auth` cuando falta el token o no vale. */
export class UnauthorizedResponse {
  @ApiProperty({ type: [ErrorMessage] })
  declare errors: ErrorMessage[]
}

/**
 * Lo que responde `findOrFail` cuando la tarea no existe. Fuera de producción
 * el cuerpo trae además la traza; solo `message` está en los dos casos.
 */
export class NotFoundResponse {
  @ApiProperty({ type: 'string' })
  declare message: string
}
