# FlowSync — atajos de desarrollo para Windows nativo (PowerShell).
#
# Requisitos: Node.js + npm y GNU Make para Windows.
#   - winget install ezwinports.make   (o choco install make / scoop install make)
#
# Las recetas se ejecutan con Windows PowerShell (powershell.exe), así que
# funcionan desde PowerShell o cmd sin WSL. En macOS, Linux o WSL usa
# Makefile.linux:   make -f Makefile.linux <target>
#
# Notas de implementación:
#   - Cada línea de receta es una invocación independiente de PowerShell: no
#     se comparten variables entre líneas y no se usan continuaciones con `\`
#     (PowerShell no las entiende), así que cada bloque va en una sola línea.
#   - `$$` es un `$` literal para PowerShell; `$(VAR)` lo expande make.
#   - Los mensajes que se imprimen van sin tildes ni emojis: make pasa la línea
#     a PowerShell en la página de códigos ANSI y los caracteres UTF-8 llegan
#     destrozados a la consola.

SHELL       := powershell.exe
.SHELLFLAGS := -NoProfile -ExecutionPolicy Bypass -Command

BACKEND  := backend
FRONTEND := frontend

.DEFAULT_GOAL := help
.PHONY: help setup start install env migrate clean

# La ayuda se genera a partir de los comentarios `## ...` de cada target, para
# que no haya un segundo listado que mantener a mano y que pueda divergir.
help: ## Muestra esta ayuda
	@Write-Host "FlowSync - targets disponibles:"
	@Write-Host ""
	@Select-String -Path "$(firstword $(MAKEFILE_LIST))" -Pattern '^([a-zA-Z_-]+):.*## (.*)$$' | ForEach-Object { '  make {0,-8} {1}' -f $$_.Matches[0].Groups[1].Value, $$_.Matches[0].Groups[2].Value }
	@Write-Host ""

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------

setup: install env migrate ## Deja el proyecto listo para arrancar
	@Write-Host ""
	@Write-Host "[OK] Setup completado. Arranca todo con: make start"

install:
	@if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host "[X] Node.js no esta instalado."; exit 1 }
	@if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Write-Host "[X] npm no esta instalado."; exit 1 }
	@Write-Host "[..] Instalando dependencias del backend..."
	@Set-Location "$(BACKEND)"; npm install; exit $$LASTEXITCODE
	@Write-Host "[..] Instalando dependencias del frontend..."
	@Set-Location "$(FRONTEND)"; npm install; exit $$LASTEXITCODE

env:
	@if (-not (Test-Path "$(BACKEND)/.env")) { Write-Host "[..] Creando $(BACKEND)/.env desde .env.example..."; Copy-Item "$(BACKEND)/.env.example" "$(BACKEND)/.env" } else { Write-Host "[--] $(BACKEND)/.env ya existe, no se toca." }
	@if (-not (Test-Path "$(FRONTEND)/.env")) { Write-Host "[..] Creando $(FRONTEND)/.env desde .env.example..."; Copy-Item "$(FRONTEND)/.env.example" "$(FRONTEND)/.env" } else { Write-Host "[--] $(FRONTEND)/.env ya existe, no se toca." }
	@if (Select-String -Path "$(BACKEND)/.env" -Pattern '^APP_KEY=.+' -Quiet) { Write-Host "[--] APP_KEY ya definida, no se regenera." } else { Write-Host "[..] Generando APP_KEY..."; Set-Location "$(BACKEND)"; node ace generate:key; exit $$LASTEXITCODE }

migrate:
	@Write-Host "[..] Ejecutando migraciones..."
	@Set-Location "$(BACKEND)"; node ace migration:run; exit $$LASTEXITCODE

# ---------------------------------------------------------------------------
# start
# ---------------------------------------------------------------------------

# Lanza los dos servidores en paralelo, compartiendo la consola actual
# (`-NoNewWindow`), y vigila ambos procesos:
#
#   - Ctrl-C: Windows manda CTRL_C_EVENT a todos los procesos enganchados a la
#     consola, así que los dos servidores lo reciben igual que con un Ctrl-C
#     real. Además, el `finally` mata lo que quede vivo.
#   - Si uno de los dos termina por su cuenta (p. ej. el backend crashea al
#     arrancar), el bucle lo detecta y el `finally` cierra el otro, para que no
#     se quede un servidor huérfano ocupando el puerto.
#
# Se mata el árbol completo con `taskkill /T /F` porque `npm run dev` lanza
# `cmd` → `node` como hijos, y `Stop-Process` en PowerShell 5.1 solo mata el
# proceso raíz y dejaría los `node` colgados.
start: ## Levanta backend y frontend a la vez
	@if (-not (Test-Path "$(BACKEND)/node_modules") -or -not (Test-Path "$(FRONTEND)/node_modules")) { Write-Host "[X] Faltan dependencias. Ejecuta primero: make setup"; exit 1 }
	@if (-not (Test-Path "$(BACKEND)/.env")) { Write-Host "[X] Falta $(BACKEND)/.env. Ejecuta primero: make setup"; exit 1 }
	@Write-Host "[>>] Arrancando backend (http://localhost:3333) y frontend (http://localhost:5173)..."
	@Write-Host "     Ctrl-C para parar los dos. Si uno se cae, el otro se cierra tambien."
	@Write-Host ""
	@$$be = Start-Process -FilePath npm.cmd -ArgumentList 'run','dev' -WorkingDirectory "$(BACKEND)" -NoNewWindow -PassThru; $$fe = Start-Process -FilePath npm.cmd -ArgumentList 'run','dev' -WorkingDirectory "$(FRONTEND)" -NoNewWindow -PassThru; try { while (-not $$be.HasExited -and -not $$fe.HasExited) { Start-Sleep -Milliseconds 500 }; Write-Host ""; if ($$be.HasExited) { Write-Host "[!] El backend se ha parado. Cerrando el frontend." } else { Write-Host "[!] El frontend se ha parado. Cerrando el backend." } } finally { foreach ($$p in @($$be, $$fe)) { if (-not $$p.HasExited) { taskkill /PID $$p.Id /T /F 2>&1 | Out-Null } } }

# ---------------------------------------------------------------------------
# clean
# ---------------------------------------------------------------------------

clean: ## Borra node_modules y la base de datos SQLite
	@Write-Host "[..] Limpiando..."
	@Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$(BACKEND)/node_modules", "$(FRONTEND)/node_modules"; exit 0
	@Remove-Item -Force -ErrorAction SilentlyContinue "$(BACKEND)/tmp/db.sqlite3", "$(BACKEND)/tmp/db.sqlite3-wal", "$(BACKEND)/tmp/db.sqlite3-shm"; exit 0
	@Write-Host "[OK] Listo. Vuelve a ejecutar: make setup"
