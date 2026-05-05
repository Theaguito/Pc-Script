# Manutencao-PC

Um script simples de manutencao do Windows feito em PowerShell.

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?logo=windows)](https://www.microsoft.com/pt-br/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg?logo=powershell)](https://docs.microsoft.com/pt-br/powershell/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Como usar

1. Baixe os dois arquivos:
   - `INICIAR-MANUTENCAO.bat`
   - `Manutencao-PC.ps1`

2. Coloque na mesma pasta

3. Clique em `INICIAR-MANUTENCAO.bat` com botao direito > Executar como administrador

4. Escolha o que quer fazer no menu

Os logs ficam em `C:\Users\{seu_usuario}\Manutencao\`

## O que ele faz

**[1] Limpeza de Temporarios**
- Esvazia pastas temporarias do Windows
- Limpa cache de Chrome e Edge
- Esvazia a Lixeira

**[2] Reparo do Sistema**
- Executa DISM /RestoreHealth
- Executa SFC /scannow
- Agenda CHKDSK para proximo boot

**[3] Otimizacao de Rede**
- Renova IP (ipconfig /release e /renew)
- Limpa cache DNS
- Reseta Winsock

**[4] Seguranca**
- Verifica se Defender esta ativo
- Atualiza definicoes de seguranca

**[5] Desempenho**
- Ativa plano de Alto Desempenho
- Verifica servicos criticos do Windows

**[6] Tudo junto**
- Executa todos os modulos acima
- Reinicia o PC automaticamente ao final

**[7] Tudo junto sem reiniciar**
- Executa todos os modulos acima
- Pergunta se quer reiniciar ao final

## O que mudou na v2.1

- [x] Captura melhor de erros (exit codes do DISM e SFC)
- [x] Aviso se estiver em RDP (remoto) antes de alterar rede
- [x] Deteccao de notebook para nao forcar Alto Desempenho blindamente
- [x] Rotacao de logs (mantém apenas os ultimos 10 arquivos)
- [x] Logs mais detalhados com timestamps

## Avisos

- Use por sua conta e risco
- O script faz alteracoes no sistema
- Sempre tenha backup importante antes de rodar
- Se estiver em RDP, nao execute o modulo de rede (pode desconectar voce)

## Feedback

Se encontrar bugs ou tiver ideias, abra uma issue ou pull request!

## Licenca

MIT

---

Feito com PowerShell :)
