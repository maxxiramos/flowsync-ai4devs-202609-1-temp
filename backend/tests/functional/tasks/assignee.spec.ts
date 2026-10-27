import Task from '#models/task'
import User from '#models/user'
import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'

/**
 * Lo que la tarea enseña de su responsable. Cubre los tres scenarios del
 * requisito «Lo que cada tarea muestra de su responsable» de
 * `openspec/specs/tasks/spec.md`: el responsable se identifica por nombre e
 * iniciales, no filtra el email ni ningún dato de acceso, y sin nombre sigue
 * llegando con sus iniciales.
 *
 * Cada scenario se comprueba en las dos formas de obtener una tarea —suelta y
 * dentro de la lista—, porque las sirven transformers distintos y que una
 * cumpla no dice nada de la otra.
 */
test.group('Tasks | responsable', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  // La consulta suelta exige el día de quien mira; aquí da igual cuál sea.
  const today = '2026-10-27'

  async function sesion(client: any, email = 'mira@example.com') {
    await User.create({ fullName: 'Quien Mira', email, password: 'secreto123' })

    const response = await client.post('/api/v1/auth/login').json({ email, password: 'secreto123' })

    return response.body().data.token as string
  }

  async function asignadaA(fullName: string | null, email: string) {
    const responsable = await User.create({ fullName, email, password: 'secreto123' })
    return Task.create({
      title: 'Revisar el informe',
      status: 'pending',
      assigneeId: responsable.id,
    })
  }

  async function suelta(client: any, token: string, task: Task) {
    const response = await client
      .get(`/api/v1/tasks/${task.id}`)
      .qs({ today })
      .header('Authorization', `Bearer ${token}`)

    response.assertStatus(200)
    return response.body().data
  }

  async function enLaLista(client: any, token: string, task: Task) {
    const response = await client.get('/api/v1/tasks').header('Authorization', `Bearer ${token}`)

    response.assertStatus(200)
    return response.body().data.find((t: { id: number }) => t.id === task.id)
  }

  test('el responsable se identifica por su nombre y sus iniciales', async ({ client, assert }) => {
    const token = await sesion(client)
    const task = await asignadaA('Ada Lovelace', 'ada@example.com')

    for (const tarea of [await suelta(client, token, task), await enLaLista(client, token, task)]) {
      assert.equal(tarea.assignee.fullName, 'Ada Lovelace')
      assert.equal(tarea.assignee.initials, 'AL')
    }
  })

  test('la tarea no filtra el email ni ningún dato de acceso del responsable', async ({
    client,
    assert,
  }) => {
    const token = await sesion(client)
    const task = await asignadaA('Ada Lovelace', 'ada@example.com')

    const casos: Array<[string, any]> = [
      ['suelta', await suelta(client, token, task)],
      ['en la lista', await enLaLista(client, token, task)],
    ]

    for (const [donde, tarea] of casos) {
      const serialized = JSON.stringify(tarea.assignee)
      assert.notProperty(tarea.assignee, 'email', `la tarea ${donde} trae el email`)
      assert.notInclude(serialized, 'ada@example.com', `la tarea ${donde} trae el email`)
      assert.notInclude(serialized, 'password', `la tarea ${donde} trae la contraseña`)
      assert.notInclude(serialized, 'secreto123', `la tarea ${donde} trae la contraseña`)
    }
  })

  test('un responsable sin nombre llega con el nombre nulo y sus iniciales', async ({
    client,
    assert,
  }) => {
    const token = await sesion(client)
    const task = await asignadaA(null, 'ada@example.com')

    for (const tarea of [await suelta(client, token, task), await enLaLista(client, token, task)]) {
      assert.isNull(tarea.assignee.fullName)
      assert.equal(tarea.assignee.initials, 'AE')
    }
  })
})
