# v2.1.0 — Bugfix & Melhorias

Oi! Arrumei alguns problemas no script anterior. Essa versao avisa quando tem algo perigoso acontecendo.

## O que foi consertado

**Problema**: quando DISM ou SFC falhavam, o script escrevia `[OK]` mesmo assim. Enganava.

**Solucao**: agora verifica o exit code e mostra `[ERRO]` ou `[AVISO]` quando necessario.

## Novidades

- ✅ **Rotacao de logs** — Mantém apenas os ultimos 10 arquivos de log. Antes acumulava.
- ✅ **Deteccao de notebook** — Se e laptop, avisa que Alto Desempenho drena bateria. Pode cancelar.
- ✅ **Aviso de RDP** — Se conectado remotamente, avisa que `ipconfig /release` vai desconectar voce.
- ✅ **Logs detalhados** — Registra nao so sucesso, mas tambem erros e avisos com contexto.

## Como usar (igual antes)

1. Coloque os dois arquivos na mesma pasta
2. Execute `INICIAR-MANUTENCAO.bat` como admin
3. Escolha o numero do modulo desejado
4. Logs em `C:\Users\{usuario}\Manutencao\`

## Modulos

| ID | Modulo |
|----|--------|
| 1 | Limpeza de temporarios |
| 2 | Reparo do sistema (DISM + SFC + CHKDSK) |
| 3 | Otimizacao de rede |
| 4 | Seguranca (Defender) |
| 5 | Desempenho |
| 6 | Tudo + reinicia automaticamente |
| 7 | Tudo + pergunta antes de reiniciar |

## Conhecidos & TODO

**Nao fiz ainda:**
- [ ] Firefox cache na limpeza
- [ ] Parametro `-Silent` para automacao
- [ ] Mais navegadores (Opera, Brave)
- [ ] Relatorio visual dos logs

**Avisos:**
- Use por conta e risco
- Sempre tenha backup antes
- Se estiver em RDP, nao use o modulo 3

---

Obrigado por usar! Se encontrar bug ou tiver ideias, abre uma issue :)
