# Prompt para primeira sessão Codex — UNIGRAN Skills

Copie e envie ao Codex depois de instalar as skills no projeto:

---

Analise este projeto antes de iniciarmos qualquer implementação.

1. Leia o `AGENTS.md` e respeite as orientações já existentes.
2. Verifique quais skills estão instaladas em `.agents/skills/` e se há outras skills globais ou versões duplicadas.
3. Identifique a stack, principais diretórios, endpoints, banco de dados, integrações e dependências do projeto.
4. Recomende as skills mais apropriadas para a stack, mas carregue os arquivos `SKILL.md` **somente quando forem necessários**, para evitar consumo desnecessário de contexto.
5. Verifique se a configuração inicial de `setup-matt-pocock-skills` já foi realizada neste projeto. Se não, explique o que falta e pergunte antes de executar mudanças de configuração.
6. Para mudanças maiores, considere `ask-matt`, `change-impact`, testes, revisão e segurança.
7. Se Graphify estiver instalado, confira se a CLI está disponível e se existe `graphify-out/graph.json`. **Não gere nem atualize o grafo agora** sem necessidade.
8. Apresente um resumo da estrutura encontrada, configuração recomendada e possíveis riscos.

Não modifique código de produção, dados, dependências, hooks, MCPs nem faça commits nesta etapa. Aguarde minha próxima solicitação de desenvolvimento.