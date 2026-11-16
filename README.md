# UNIGRAN Skills — Instalacao online em um comando

Instalador padrao para iniciar projetos da UNIGRAN usando Codex e skills de agentes.

**Instala 58 skills**: 27 de [mattpocock/skills](https://github.com/mattpocock/skills), 30 de [affaan-m/ECC](https://github.com/affaan-m/ECC) e 1 [Graphify](https://github.com/Graphify-Labs/graphify). Copia apenas as skills selecionadas, nao instala hooks nem MCPs, e nao executa a CLI do Graphify.

> **Este README presume que o repositorio foi publicado como `marketingead/unigran-skills-bootstrap`, PUBLICO, com branch `main`.** Ajuste a URL se escolher outro nome ou organizacao. Antes da publicacao, esses links ainda nao funcionarao.

## Windows — PowerShell (um comando)

Abra o terminal na **raiz do projeto que deseja configurar** e cole **a linha inteira**:

```powershell
$u='https://raw.githubusercontent.com/marketingead/unigran-skills-bootstrap/main/install-skills.ps1'; $f=Join-Path $env:TEMP ('unigran-skills-'+[guid]::NewGuid().ToString('N')+'.ps1'); try { Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $f -ErrorAction Stop; powershell -NoProfile -ExecutionPolicy Bypass -File $f -ProjectPath (Get-Location).Path } finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
```

**Requer:** PowerShell 5.1 ou superior, acesso HTTPS a GitHub e espaço temporário para baixar arquivos ZIP. **Nao requer GitHub CLI (`gh`) nem login.**

## macOS / Linux — Terminal (um comando)

Abra o terminal na **raiz do projeto** e cole **a linha inteira**:

```bash
(tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT; curl -fsSL 'https://raw.githubusercontent.com/marketingead/unigran-skills-bootstrap/main/install-skills.sh' -o "$tmp" && bash "$tmp" "$PWD")
```

**Requer:** `bash`, `curl`, `unzip` e acesso HTTPS. Sem GitHub CLI/login.

## Reinstalar ou atualizar um projeto ja configurado

- **Nova instalacao:** instala skills ausentes e preserva existentes. Nao duplica.
- **Reinstalar:** executa o mesmo comando; mantem as skills ja existentes.
- **Atualizar:** adicione `-Force` ao final do comando Windows (dentro do trecho que executa `powershell -File ...`) ou `--force` apos `"$PWD"` no comando Mac. O instalador faz backup antes de substituir pastas existentes.
- **Backup:** `.unigran-skills-backup/AAAAmmdd-HHMMSS/` dentro do projeto (nao faca commit de backups se contiverem informacoes locais).

### Windows — atualizacao com backup

```powershell
$u='https://raw.githubusercontent.com/marketingead/unigran-skills-bootstrap/main/install-skills.ps1'; $f=Join-Path $env:TEMP ('unigran-skills-'+[guid]::NewGuid().ToString('N')+'.ps1'); try { Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $f -ErrorAction Stop; powershell -NoProfile -ExecutionPolicy Bypass -File $f -ProjectPath (Get-Location).Path -Force } finally { Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue }
```

### Mac — atualizacao com backup

```bash
(tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT; curl -fsSL 'https://raw.githubusercontent.com/marketingead/unigran-skills-bootstrap/main/install-skills.sh' -o "$tmp" && bash "$tmp" "$PWD" --force)
```

## Conferir a instalacao

**Windows:**

```powershell
(Get-ChildItem '.agents\skills' -Directory -ErrorAction SilentlyContinue).Count
Test-Path '.codex\skills\graphify\SKILL.md'  # Graphify legado; pode estar em .agents\skills\graphify
Test-Path '.agents\skills\graphify\SKILL.md'
```

**Mac:**

```bash
find .agents/skills -mindepth 1 -maxdepth 1 -type d | wc -l
[ -f .agents/skills/graphify/SKILL.md ] || [ -f .codex/skills/graphify/SKILL.md ]
```

O total de skills e **58**, normalmente dentro de `.agents/skills`; em projetos legados, Graphify pode estar apenas em `.codex/skills/` (nesse caso, 57 + 1). O instalador insere um bloco delimitado em `AGENTS.md` e preserva outras instrucoes.

## O que pedir ao Codex depois de instalar

Inicie uma nova sessao no Codex e envie:

> Leia o `AGENTS.md`, identifique as 58 skills em `.agents/skills/` e `.codex/skills/`, analise as tecnologias deste projeto e recomende quais skills usar. Verifique se `setup-matt-pocock-skills` precisa de configuracao. Nao execute todas as skills; carregue somente as relevantes. Nao altere o codigo nesta etapa.

O prompt detalhado esta em [`PROMPT-INICIAL-CODEX.md`](PROMPT-INICIAL-CODEX.md).

A skill Graphify **nao instala automaticamente a CLI `graphify`**. Para isso, siga as [instrucoes oficiais](https://github.com/Graphify-Labs/graphify) (por exemplo, `uv tool install graphifyy`).

## Como funciona

1. O comando baixa **apenas o script do instalador** deste repositorio GitHub para um arquivo temporario.
2. O script baixa ZIPs publicos de `mattpocock/skills`, `affaan-m/ECC` e `Graphify-Labs/graphify`.
3. Copia as skills selecionadas para o projeto. Arquivos anteriores ficam preservados, a menos que atualizados com `Force`.
4. Adiciona ou atualiza apenas o bloco `UNIGRAN-SKILLS` no arquivo `AGENTS.md`.
5. Remove os arquivos temporarios.

### Seguranca e versoes

- Esse fluxo executa um script remoto. **Revise o conteudo do instalador e confira a URL oficial antes de executa-lo**, especialmente em ambiente corporativo.
- A branch `main` do instalador e as branches `main`/`v8` das fontes mudam com o tempo. Para instalacoes 100% reproduziveis, use um **tag ou SHA revisado** do bootstrap e fixe tambem os commits dos tres projetos de origem.
- Este pacote nao depende de repositorios privados, autenticacao GitHub, tokens ou chave de API.
- A instalacao apenas copia skills: **nao executa** automaticamente scripts de terceiros contidos nelas.

## Manutencao

Para mudar o conjunto padrao de skills, edite as listas `mattSkills` / `eccSkills` em `install-skills.ps1` e `MATT_SKILLS` / `ECC_SKILLS` em `install-skills.sh` de forma sincronizada. Teste antes de publicar.

Os arquivos [`CATALOGO-58-SKILLS.md`](CATALOGO-58-SKILLS.md) e [`FONTES-PUBLICAS.json`](FONTES-PUBLICAS.json) documentam a selecao e as fontes.