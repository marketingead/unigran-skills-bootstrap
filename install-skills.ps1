# UNIGRAN Skills - instalador 100% com fontes publicas (Windows PowerShell 5.1+)
# Uso dentro do projeto:
# powershell -NoProfile -ExecutionPolicy Bypass -File "C:\...\UNIGRAN-Skills-Completo\install-skills.ps1" -ProjectPath (Get-Location).Path
# Nao utiliza GitHub CLI, autenticacao ou repositorios privados.
[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Force,
    [switch]$SkipMatt,
    [switch]$SkipECC,
    [switch]$SkipGraphify,
    [switch]$NoAgentInstructions
)

$ErrorActionPreference = 'Stop'

$mattSkills = @(
    'ask-matt', 'code-review', 'codebase-design', 'diagnosing-bugs', 'domain-modeling',
    'grill-me', 'grill-with-docs', 'grilling', 'handoff', 'implement-spec', 'implement',
    'improve-codebase-architecture', 'pr', 'prototype', 'research', 'retro',
    'setup-matt-pocock-skills', 'tdd', 'teach', 'to-questionnaire', 'to-spec',
    'to-tickets', 'triage', 'wait-what', 'wayfinder', 'wizard', 'writing-for-agents'
)
$eccSkills = @(
    'coding-standards', 'frontend-patterns', 'backend-patterns', 'typescript-patterns',
    'api-design', 'change-impact', 'search-first', 'hexagonal-architecture',
    'design-system', 'frontend-design-direction', 'react-patterns', 'react-performance',
    'frontend-a11y', 'browser-qa', 'dashboard-builder', 'postgres-patterns',
    'database-migrations', 'redis-patterns', 'docker-patterns', 'deployment-patterns',
    'mcp-server-patterns', 'api-connector-builder', 'security-review', 'tdd-workflow',
    'e2e-testing', 'verification-loop', 'production-audit', 'context-budget',
    'strategic-compact', 'cost-aware-llm-pipeline'
)

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
}
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("unigran-skills-web-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null

# GitHub usa TLS 1.2 para os downloads ZIP (necessario em algumas maquinas com Windows PowerShell 5.1).
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Test-NeedsGroup {
    param([string[]]$Names)
    if ($Force) { return $true }
    foreach ($name in $Names) {
        if (-not (Test-Path -LiteralPath (Join-Path $project ".agents/skills/$name"))) {
            return $true
        }
    }
    return $false
}

function Receive-PublicArchive {
    param([string]$Label, [string]$Url)
    $archive = Join-Path $temp ($Label + '.zip')
    $extract = Join-Path $temp ($Label + '-unpacked')
    Write-Host "Baixando $Label da fonte publica oficial..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $archive -UseBasicParsing -ErrorAction Stop
    } catch {
        throw "Falha ao baixar $Label diretamente da web. Verifique internet e firewall. Detalhe: $($_.Exception.Message)"
    }
    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
    $root = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
    if (-not $root) { throw "Arquivo publico $Label inesperado (sem pasta raiz)." }
    return $root.FullName
}

$installed = 0
$preserved = 0
$backupDir = Join-Path $project ('.unigran-skills-backup/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Install-SkillFolder {
    param([string]$From, [string]$To, [string]$Name)
    if (-not (Test-Path -LiteralPath (Join-Path $From 'SKILL.md'))) {
        throw "Origem sem SKILL.md: $Name ($From)"
    }
    if (Test-Path -LiteralPath $To) {
        if (-not $Force) {
            Write-Host "[OK] Preservada: $Name"
            $script:preserved += 1
            return
        }
        $rel = $To.Substring($project.Length).TrimStart([char]'\', [char]'/')
        $backup = Join-Path $backupDir $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
        Copy-Item -LiteralPath $To -Destination $backup -Recurse -Force
        Remove-Item -LiteralPath $To -Recurse -Force
        Write-Host "[BACKUP] $backup"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $To) -Force | Out-Null
    Copy-Item -LiteralPath $From -Destination $To -Recurse
    $script:installed += 1
    Write-Host "[INSTALADA] $Name"
}

try {
    $mattRoot = $null
    $eccRoot = $null
    $graphifyRoot = $null

    if (-not $SkipMatt -and (Test-NeedsGroup -Names $mattSkills)) {
        $mattRoot = Receive-PublicArchive -Label 'Matt-Pocock' -Url 'https://codeload.github.com/mattpocock/skills/zip/refs/heads/main'
        foreach ($name in $mattSkills) {
            $src = Join-Path $mattRoot "skills/engineering/$name"
            if (-not (Test-Path -LiteralPath $src)) { $src = Join-Path $mattRoot "skills/productivity/$name" }
            if (-not (Test-Path -LiteralPath (Join-Path $src 'SKILL.md'))) { throw "Skill Matt ausente: $name" }
        }
    }
    if (-not $SkipECC -and (Test-NeedsGroup -Names $eccSkills)) {
        $eccRoot = Receive-PublicArchive -Label 'ECC' -Url 'https://codeload.github.com/affaan-m/ECC/zip/refs/heads/main'
        foreach ($name in $eccSkills) {
            if (-not (Test-Path -LiteralPath (Join-Path $eccRoot "skills/$name/SKILL.md"))) {
                throw "Skill ECC ausente: $name"
            }
        }
    }

    $graphCurrent = Join-Path $project '.agents/skills/graphify'
    $graphLegacy = Join-Path $project '.codex/skills/graphify'
    $needGraphify = $Force -or (-not (Test-Path -LiteralPath $graphCurrent) -and -not (Test-Path -LiteralPath $graphLegacy))
    if (-not $SkipGraphify -and $needGraphify) {
        $graphifyRoot = Receive-PublicArchive -Label 'Graphify' -Url 'https://codeload.github.com/Graphify-Labs/graphify/zip/refs/heads/v8'
        if (-not (Test-Path -LiteralPath (Join-Path $graphifyRoot 'graphify/skill-codex.md'))) {
            throw 'Skill Graphify (Codex) ausente no repositório publico.'
        }
        if (-not (Test-Path -LiteralPath (Join-Path $graphifyRoot 'graphify/skills/codex/references/query.md'))) {
            throw 'Referencias Graphify ausentes.'
        }
    }

    # Instala apenas apos validar todas as fontes remotas.
    if (-not $SkipMatt) {
        foreach ($name in $mattSkills) {
            if (-not $mattRoot) {
                Write-Host "[OK] Preservada: Matt/$name"
                $preserved += 1
                continue
            }
            $src = Join-Path $mattRoot "skills/engineering/$name"
            if (-not (Test-Path -LiteralPath $src)) { $src = Join-Path $mattRoot "skills/productivity/$name" }
            Install-SkillFolder -From $src -To (Join-Path $project ".agents/skills/$name") -Name "Matt/$name"
        }
    }
    if (-not $SkipECC) {
        foreach ($name in $eccSkills) {
            if (-not $eccRoot) {
                Write-Host "[OK] Preservada: ECC/$name"
                $preserved += 1
                continue
            }
            Install-SkillFolder -From (Join-Path $eccRoot "skills/$name") -To (Join-Path $project ".agents/skills/$name") -Name "ECC/$name"
        }
    }
    if (-not $SkipGraphify) {
        if (-not $graphifyRoot) {
            Write-Host '[OK] Graphify existente preservada.'
            $preserved += 1
        } else {
            $graphStage = Join-Path $temp 'graphify-prepared'
            New-Item -ItemType Directory -Path $graphStage -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $graphifyRoot 'graphify/skill-codex.md') -Destination (Join-Path $graphStage 'SKILL.md')
            Copy-Item -LiteralPath (Join-Path $graphifyRoot 'graphify/skills/codex/references') -Destination (Join-Path $graphStage 'references') -Recurse
            if ((Test-Path -LiteralPath $graphLegacy) -and (-not (Test-Path -LiteralPath $graphCurrent))) {
                Install-SkillFolder -From $graphStage -To $graphLegacy -Name 'Graphify (Codex legado)'
            } else {
                Install-SkillFolder -From $graphStage -To $graphCurrent -Name 'Graphify'
            }
        }
    }

    if (-not $NoAgentInstructions) {
        $agentPath = Join-Path $project 'AGENTS.md'
        $startMark = '<!-- UNIGRAN-SKILLS:BEGIN -->'
        $endMark = '<!-- UNIGRAN-SKILLS:END -->'
        $block = @'
<!-- UNIGRAN-SKILLS:BEGIN -->
## Skills UNIGRAN (instaladas de fontes publicas)

- Skills do projeto: `.agents/skills/`. Instaladas de `mattpocock/skills`, `affaan-m/ECC` e `Graphify-Labs/graphify`; consulte apenas as relevantes para a tarefa.
- Primeiro uso do projeto: verifique a necessidade de invocar `setup-matt-pocock-skills` para configurar issues, triagem e documentacao; essa skill pede decisoes do usuario.
- Para planejar uma mudanca, `ask-matt` ajuda a escolher o fluxo; use `tdd`, `code-review` e `verification-loop` quando fizer sentido.
- Antes de alterar componentes sensiveis, considere `change-impact`, `security-review` e, para banco, `postgres-patterns`.
- Graphify: skill disponivel em `.agents/skills/graphify/` (ou `.codex/skills/graphify/` nos projetos legados). Sua CLI e seu grafo NAO sao instalados ou gerados automaticamente pelo bootstrap.
- Se `graphify-out/graph.json` existir e a CLI estiver disponivel, consulte o grafo para perguntas de arquitetura e atualize depois de alteracoes relevantes.
- Nao instale hooks, MCPs ou dependencias adicionais, nao altere codigo nem realize commits por causa deste bloco. Respeite o escopo da tarefa do usuario.
<!-- UNIGRAN-SKILLS:END -->
'@
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        if (Test-Path -LiteralPath $agentPath) {
            $current = [IO.File]::ReadAllText($agentPath)
            $begin = $current.IndexOf($startMark)
            $end = if ($begin -ge 0) { $current.IndexOf($endMark, $begin) } else { -1 }
            if ($begin -ge 0 -and $end -ge 0) {
                $updated = $current.Substring(0, $begin) + $block + $current.Substring($end + $endMark.Length)
                Write-Host '[AGENTS.md] Bloco UNIGRAN atualizado; outras instrucoes preservadas.'
            } else {
                $updated = $current.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
                Write-Host '[AGENTS.md] Bloco UNIGRAN adicionado.'
            }
        } else {
            $updated = $block + "`r`n"
            Write-Host '[AGENTS.md] Arquivo criado.'
        }
        [IO.File]::WriteAllText($agentPath, $updated, $utf8)
    }

    Write-Host "`nConcluido: $installed instaladas/atualizadas; $preserved existentes preservadas."
    Write-Host "Projeto: $project"
    Write-Host 'Abra uma nova sessao do Codex; veja o README do kit para o prompt inicial.'
    Write-Host 'Graphify CLI (opcional): uv tool install graphifyy'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}