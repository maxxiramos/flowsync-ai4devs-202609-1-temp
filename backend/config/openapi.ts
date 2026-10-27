import { defineConfig } from '@foadonis/openapi'

export default defineConfig({
  ui: 'scalar',
  document: {
    info: {
      title: 'FlowSync API',
      version: 'v1',
    },
    components: {
      // `@ApiBearerAuth()` en los controladores referencia este esquema por su nombre.
      securitySchemes: {
        bearer: {
          type: 'http',
          scheme: 'bearer',
          description: 'Access token opaco de /auth/login',
        },
      },
    },
  },
})
