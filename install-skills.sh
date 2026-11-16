#!/usr/bin/env bash
# UNIGRAN Skills - instalador 100% com fontes publicas (macOS/Linux)
# Uso dentro do projeto: bash "$HOME/Documents/UNIGRAN-Skills-Completo/install-skills.sh" "$PWD"
# O instalador NAO usa repositorios privados nem requer gh auth login.
set -euo pipefail

PROJECT_DIR="$(pwd)"
FORCE=0
SKIP_MATT=0
SKIP_ECC=0
SKIP_GRAPHIFY=0
NO_AGENT_INSTRUCTIONS=0

usage() {
  cat <<'HELP'
Instala 58 skills da web no projeto, preservando as existentes.

Uso: bash install-skills.sh [diretorio-do-projeto] [opcoes]

Opcoes:
  --force                  Atualiza skills existentes com backup
  --no-matt                Nao instala as 27 skills Matt Pocock
  --no-ecc                 Nao instala as 30 skills ECC
  --no-graphify            Nao instala a skill Graphify
  --no-agent-instructions  Nao cria/atualiza o bloco UNIGRAN em AGENTS.md
  -h, --help               Exibe a ajuda

Fontes: mattpocock/skills (main), affaan-m/ECC (main),
        Graphify-Labs/graphify (v8), todos publicos.
Prerequisitos: curl, unzip e acesso HTTPS a github.com.
HELP
}

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --no-matt) SKIP_MATT=1 ;;
    --no-ecc) SKIP_ECC=1 ;;
    --no-graphify) SKIP_GRAPHIFY=1 ;;
    --no-agent-instructions) NO_AGENT_INSTRUCTIONS=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'Opcao desconhecida: %s\n' "$arg" >&2; exit 2 ;;
    *) PROJECT_DIR="$arg" ;;
  esac
done

for cmd in curl unzip; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'Erro: comando %s nao encontrado.\n' "$cmd" >&2; exit 1; }
done

mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MATT_SKILLS=(
  ask-matt code-review codebase-design diagnosing-bugs domain-modeling
  grill-me grill-with-docs grilling handoff implement-spec implement
  improve-codebase-architecture pr prototype research retro
  setup-matt-pocock-skills tdd teach to-questionnaire to-spec
  to-tickets triage wait-what wayfinder wizard writing-for-agents
)
ECC_SKILLS=(
  coding-standards frontend-patterns backend-patterns typescript-patterns
  api-design change-impact search-first hexagonal-architecture
  design-system frontend-design-direction react-patterns react-performance
  frontend-a11y browser-qa dashboard-builder postgres-patterns
  database-migrations redis-patterns docker-patterns deployment-patterns
  mcp-server-patterns api-connector-builder security-review tdd-workflow
  e2e-testing verification-loop production-audit context-budget
  strategic-compact cost-aware-llm-pipeline
)

# Evita baixar um arquivo grande se todas as skills desse grupo ja existem.
needs_group() {
  local name
  if (( FORCE )); then return 0; fi
  for name in "$@"; do
    [[ -e "$PROJECT_DIR/.agents/skills/$name" ]] || return 0
  done
  return 1
}

needs_graphify() {
  if (( FORCE )); then return 0; fi
  [[ ! -e "$PROJECT_DIR/.agents/skills/graphify" && ! -e "$PROJECT_DIR/.codex/skills/graphify" ]]
}

fetch_archive() {
  local label="$1" url="$2" target="$3" archive contents root
  archive="$TMP_DIR/$label.zip"
  contents="$TMP_DIR/$label-unpacked"
  printf 'Baixando %s diretamente da fonte publica...\n' "$label" >&2
  curl --fail --location --silent --show-error --retry 2 --connect-timeout 20 --output "$archive" "$url" \
    || { printf 'Falha ao baixar %s. Verifique sua conexao com a internet.\n' "$label" >&2; return 1; }
  mkdir -p "$contents"
  unzip -q "$archive" -d "$contents" || { printf 'Arquivo ZIP invalido: %s\n' "$label" >&2; return 1; }
  root=""
  for root in "$contents"/*; do
    if [[ -d "$root" ]]; then break; fi
  done
  [[ -d "$root" ]] || { printf 'Estrutura do arquivo %s inesperada.\n' "$label" >&2; return 1; }
  printf -v "$target" '%s' "$root"
}

MATT_ROOT=""
ECC_ROOT=""
GRAPHIFY_ROOT=""

if (( ! SKIP_MATT )) && needs_group "${MATT_SKILLS[@]}"; then
  fetch_archive 'Matt-Pocock' 'https://codeload.github.com/mattpocock/skills/zip/refs/heads/main' MATT_ROOT
  for name in "${MATT_SKILLS[@]}"; do
    if [[ -d "$MATT_ROOT/skills/engineering/$name" ]]; then
      src="$MATT_ROOT/skills/engineering/$name"
    else
      src="$MATT_ROOT/skills/productivity/$name"
    fi
    [[ -f "$src/SKILL.md" ]] || { echo "Skill publica ausente: $name ($src)" >&2; exit 1; }
  done
fi
if (( ! SKIP_ECC )) && needs_group "${ECC_SKILLS[@]}"; then
  fetch_archive 'ECC' 'https://codeload.github.com/affaan-m/ECC/zip/refs/heads/main' ECC_ROOT
  for name in "${ECC_SKILLS[@]}"; do
    [[ -f "$ECC_ROOT/skills/$name/SKILL.md" ]] || { echo "Skill ECC ausente: $name" >&2; exit 1; }
  done
fi
if (( ! SKIP_GRAPHIFY )) && needs_graphify; then
  fetch_archive 'Graphify' 'https://codeload.github.com/Graphify-Labs/graphify/zip/refs/heads/v8' GRAPHIFY_ROOT
  [[ -f "$GRAPHIFY_ROOT/graphify/skill-codex.md" ]] || { echo 'Skill Graphify ausente no projeto publico.' >&2; exit 1; }
  [[ -f "$GRAPHIFY_ROOT/graphify/skills/codex/references/query.md" ]] || { echo 'Referencias Graphify ausentes.' >&2; exit 1; }
fi

INSTALLED=0
PRESERVED=0
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$PROJECT_DIR/.unigran-skills-backup/$STAMP"

install_skill() {
  local src="$1" dst="$2" name="$3" rel
  [[ -f "$src/SKILL.md" ]] || { echo "Origem incompleta para $name" >&2; return 1; }
  if [[ -e "$dst" ]]; then
    if (( ! FORCE )); then
      printf '[OK] Preservada: %s\n' "$name"
      PRESERVED=$((PRESERVED+1))
      return 0
    fi
    rel="${dst#"$PROJECT_DIR"/}"
    mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
    cp -R "$dst" "$BACKUP_DIR/$rel"
    rm -rf "$dst"
    printf '[BACKUP] %s\n' "$BACKUP_DIR/$rel"
  fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  INSTALLED=$((INSTALLED+1))
  printf '[INSTALADA] %s\n' "$name"
}

if (( ! SKIP_MATT )); then
  for name in "${MATT_SKILLS[@]}"; do
    dst="$PROJECT_DIR/.agents/skills/$name"
    if [[ -z "$MATT_ROOT" ]]; then
      printf '[OK] Preservada: %s\n' "$name"
      PRESERVED=$((PRESERVED+1))
      continue
    fi
    if [[ -d "$MATT_ROOT/skills/engineering/$name" ]]; then
      src="$MATT_ROOT/skills/engineering/$name"
    else
      src="$MATT_ROOT/skills/productivity/$name"
    fi
    install_skill "$src" "$dst" "Matt/$name"
  done
fi
if (( ! SKIP_ECC )); then
  for name in "${ECC_SKILLS[@]}"; do
    if [[ -z "$ECC_ROOT" ]]; then
      printf '[OK] Preservada: %s\n' "$name"
      PRESERVED=$((PRESERVED+1))
      continue
    fi
    install_skill "$ECC_ROOT/skills/$name" "$PROJECT_DIR/.agents/skills/$name" "ECC/$name"
  done
fi
if (( ! SKIP_GRAPHIFY )); then
  if [[ -z "$GRAPHIFY_ROOT" ]]; then
    echo '[OK] Graphify existente preservada.'
    PRESERVED=$((PRESERVED+1))
  else
    mkdir -p "$TMP_DIR/graphify-prepared/references"
    cp "$GRAPHIFY_ROOT/graphify/skill-codex.md" "$TMP_DIR/graphify-prepared/SKILL.md"
    cp -R "$GRAPHIFY_ROOT/graphify/skills/codex/references/." "$TMP_DIR/graphify-prepared/references/"
    if [[ -e "$PROJECT_DIR/.codex/skills/graphify" && ! -e "$PROJECT_DIR/.agents/skills/graphify" ]]; then
      # Atualiza no caminho legado, sem criar uma segunda copia.
      install_skill "$TMP_DIR/graphify-prepared" "$PROJECT_DIR/.codex/skills/graphify" 'Graphify (Codex legado)'
    else
      install_skill "$TMP_DIR/graphify-prepared" "$PROJECT_DIR/.agents/skills/graphify" 'Graphify'
    fi
  fi
fi

if (( ! NO_AGENT_INSTRUCTIONS )); then
  AGENTS_FILE="$PROJECT_DIR/AGENTS.md"
  BLOCK_FILE="$TMP_DIR/agents-block.txt"
  cat > "$BLOCK_FILE" <<'AGENT_TEXT'
<!-- UNIGRAN-SKILLS:BEGIN -->
## Skills UNIGRAN (instaladas de fontes publicas)

- Skills do projeto: `.agents/skills/`. Instalei-as de `mattpocock/skills`, `affaan-m/ECC` e `Graphify-Labs/graphify`; consulte apenas as relevantes para a tarefa.
- Primeiro uso do projeto: verifique a necessidade de invocar `setup-matt-pocock-skills` para configurar issues, triagem e documentacao; essa skill pede decisoes do usuario.
- Para planejar uma mudanca, `ask-matt` pode ajudar a escolher o fluxo; use `tdd`, `code-review` e `verification-loop` onde fizer sentido.
- Antes de alterar componentes sensiveis, considere `change-impact`, `security-review` e, para banco, `postgres-patterns`.
- Graphify: skill disponivel em `.agents/skills/graphify/` (ou `.codex/skills/graphify/` nos projetos legados). Sua CLI e seu grafo NAO sao instalados ou gerados automaticamente pelo bootstrap.
- Se `graphify-out/graph.json` existir e a CLI estiver disponivel, use consultas pontuais ao grafo para perguntas de arquitetura e atualize apos alteracoes relevantes.
- Nao instale hooks, MCPs ou dependencias adicionais, nao altere codigo nem realize commits por causa deste bloco. Respeite o escopo da tarefa do usuario.
<!-- UNIGRAN-SKILLS:END -->
AGENT_TEXT
  if [[ -f "$AGENTS_FILE" ]] && grep -q '<!-- UNIGRAN-SKILLS:BEGIN -->' "$AGENTS_FILE" && grep -q '<!-- UNIGRAN-SKILLS:END -->' "$AGENTS_FILE"; then
    awk '
      /<!-- UNIGRAN-SKILLS:BEGIN -->/ { deleting=1; next }
      /<!-- UNIGRAN-SKILLS:END -->/ { deleting=0; next }
      !deleting { print }
    ' "$AGENTS_FILE" > "$TMP_DIR/agents-preserved.txt"
    { cat "$TMP_DIR/agents-preserved.txt"; printf '\n'; cat "$BLOCK_FILE"; } > "$AGENTS_FILE"
    echo '[AGENTS.md] Bloco UNIGRAN atualizado; outras instrucoes preservadas.'
  else
    [[ ! -s "$AGENTS_FILE" ]] || printf '\n' >> "$AGENTS_FILE"
    cat "$BLOCK_FILE" >> "$AGENTS_FILE"
    echo '[AGENTS.md] Bloco UNIGRAN adicionado.'
  fi
fi

printf '\nConcluido: %s instaladas / atualizadas; %s ja existentes preservadas.\n' "$INSTALLED" "$PRESERVED"
printf 'Projeto: %s\n' "$PROJECT_DIR"
echo 'Abra uma nova sessao do Codex e leia o README do kit para o primeiro prompt.'
echo 'Graphify CLI (opcional): uv tool install graphifyy'