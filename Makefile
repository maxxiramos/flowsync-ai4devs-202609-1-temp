# FlowSync — atajos de desarrollo (Windows nativo, PowerShell).
#
# Requisitos: Node.js + npm y GNU Make para Windows.
#   - winget install ezwinports.make     (o: choco install make / scoop install make)
#
# Las recetas se ejecutan con Windows PowerShell 5.1 (powershell.exe), que
# viene de serie en Windows 10/11. Para Linux, macOS o WSL usa el Makefile
# POSIX original:  make -f Makefile.linux <target>
#
# Particularidades de GNU Make en Windows con un SHELL que no es sh, que
# condicionan cómo están escritas las recetas:
#
#   - Cada línea de receta es una invocación distinta de powershell.exe, así
#     que las variables de PowerShell no sobreviven de una línea a la
#     siguiente. Lo que necesita estado va en una sola línea lógica.
#   - make no quita el `\` de las continuaciones de línea: se lo pasa tal cual
#     a PowerShell, que no sabe qué hacer con él. Por eso las continuaciones
#     se escriben `#\`: el `#` convierte la barra en un comentario de
#     PowerShell y el salto de línea, que sí llega, separa las sentencias.
#   - No se usa `.ONESHELL`: en Windows, con un shell que no es sh, make lo
#     ignora y vuelca la receta en un .bat que ejecuta cmd.exe.
#   - Los mensajes de las recetas van sin tildes ni emojis a propósito: make
#     pasa la línea de comandos a powershell.exe con la página de códigos
#     ANSI y los caracteres no ASCII llegarían corruptos a la consola.
#   - `$` es especial en make: en las recetas, `$$` es un `$` de PowerShell.

SHELL := powershell.exe
.SHELLFLAGS := -NoProfile -ExecutionPolicy Bypass -Command

BACKEND  := backend
FRONTEND := frontend

.DEFAULT_GOAL := help
.PHONY: help setup start install env migrate clean

# La ayuda se genera a partir de los comentarios `## ...` de cada target, para
# que no haya un segundo listado que mantener a mano y que pueda divergir.
help: ## Muestra esta ayuda
	@Write-Host 'FlowSync - targets disponibles:'
	@Write-Host ''
	@Select-String -Path '$(firstword $(MAKEFILE_LIST))' -Pattern '^([a-zA-Z_-]+):.*## (.*)$$' | #\
	  ForEach-Object { Write-Host ('  make {0,-8} {1}' -f $$_.Matches[0].Groups[1].Value, $$_.Matches[0].Groups[2].Value) }
	@Write-Host ''

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------

setup: install env migrate ## Deja el proyecto listo para arrancar
	@Write-Host ''
	@Write-Host '[OK] Setup completado. Arranca todo con: make start'

install:
	@if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host '[ERROR] Node.js no esta instalado.'; exit 1 }
	@if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Write-Host '[ERROR] npm no esta instalado.'; exit 1 }
	@Write-Host '[npm] Instalando dependencias del backend...'
	@Set-Location '$(BACKEND)'; npm install; exit $$LASTEXITCODE
	@Write-Host '[npm] Instalando dependencias del frontend...'
	@Set-Location '$(FRONTEND)'; npm install; exit $$LASTEXITCODE

env:
	@foreach ($$dir in '$(BACKEND)', '$(FRONTEND)') { #\
	  if (-not (Test-Path "$$dir/.env")) { #\
	    Write-Host "[env] Creando $$dir/.env desde .env.example..." #\
	    Copy-Item "$$dir/.env.example" "$$dir/.env" -ErrorAction Stop #\
	  } else { #\
	    Write-Host "[env] $$dir/.env ya existe, no se toca." #\
	  } #\
	}
	@if (Select-String -Path '$(BACKEND)/.env' -Pattern '^APP_KEY=.+' -Quiet) { #\
	  Write-Host '[key] APP_KEY ya definida, no se regenera.' #\
	} else { #\
	  Write-Host '[key] Generando APP_KEY...' #\
	  Set-Location '$(BACKEND)'; node ace generate:key; exit $$LASTEXITCODE #\
	}

migrate:
	@Write-Host '[db] Ejecutando migraciones...'
	@Set-Location '$(BACKEND)'; node ace migration:run; exit $$LASTEXITCODE

# ---------------------------------------------------------------------------
# start
# ---------------------------------------------------------------------------

# Lanza los dos servidores en paralelo, en la misma consola, y vigila ambos.
#
# Windows no tiene grupos de procesos POSIX ni `kill -INT 0`, así que el
# equivalente se hace a mano:
#
#   - cada servidor se arranca con `Start-Process -NoNewWindow`, de modo que
#     comparte la consola (salida visible y atajos de teclado de Adonis/Vite);
#   - un bucle comprueba cada segundo si alguno ha terminado: si el backend
#     crashea al arrancar, el frontend no se queda vivo para siempre y el
#     usuario se entera;
#   - el bloque `finally` se ejecuta tanto cuando uno de los dos termina como
#     cuando llega un Ctrl-C, y mata el árbol completo de procesos de ambos
#     (`taskkill /T /F`), incluidos los hijos de `npm run dev`, para no dejar
#     nodos huérfanos ocupando los puertos 3333 y 5173.
start: ## Levanta backend y frontend a la vez
	@if (-not (Test-Path '$(BACKEND)/node_modules') -or -not (Test-Path '$(FRONTEND)/node_modules')) { #\
	  Write-Host '[ERROR] Faltan dependencias. Ejecuta primero: make setup'; exit 1 #\
	}
	@if (-not (Test-Path '$(BACKEND)/.env')) { #\
	  Write-Host '[ERROR] Falta $(BACKEND)/.env. Ejecuta primero: make setup'; exit 1 #\
	}
	@Write-Host '[start] Arrancando backend (http://localhost:3333) y frontend (http://localhost:5173)...'
	@Write-Host '        Ctrl-C para parar los dos. Si uno se cae, el otro se cierra tambien.'
	@Write-Host ''
	@$$procs = @{} #\
	try { #\
	  $$procs['backend']  = Start-Process -FilePath 'npm.cmd' -ArgumentList 'run', 'dev' -WorkingDirectory '$(BACKEND)'  -NoNewWindow -PassThru #\
	  $$procs['frontend'] = Start-Process -FilePath 'npm.cmd' -ArgumentList 'run', 'dev' -WorkingDirectory '$(FRONTEND)' -NoNewWindow -PassThru #\
	  while ($$true) { #\
	    $$stopped = @($$procs.Keys | Where-Object { $$procs[$$_].HasExited }) | Select-Object -First 1 #\
	    if ($$stopped) { #\
	      $$other = if ($$stopped -eq 'backend') { 'frontend' } else { 'backend' } #\
	      Write-Host '' #\
	      Write-Host "[!] El $$stopped se ha parado. Cerrando el $$other." #\
	      break #\
	    } #\
	    Start-Sleep -Seconds 1 #\
	  } #\
	} finally { #\
	  foreach ($$p in $$procs.Values) { #\
	    if ($$p -and -not $$p.HasExited) { taskkill /T /F /PID $$p.Id 2>&1 | Out-Null } #\
	  } #\
	}

# ---------------------------------------------------------------------------
# clean
# ---------------------------------------------------------------------------

clean: ## Borra node_modules y la base de datos SQLite
	@Write-Host '[clean] Limpiando...'
	@Remove-Item -Recurse -Force -ErrorAction SilentlyContinue '$(BACKEND)/node_modules', '$(FRONTEND)/node_modules'; exit 0
	@Remove-Item -Force -ErrorAction SilentlyContinue '$(BACKEND)/tmp/db.sqlite3', '$(BACKEND)/tmp/db.sqlite3-wal', '$(BACKEND)/tmp/db.sqlite3-shm'; exit 0
	@Write-Host '[OK] Listo. Vuelve a ejecutar: make setup'
