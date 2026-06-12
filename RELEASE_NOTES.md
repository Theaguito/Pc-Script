# v2.2.0 — Melhorias de usabilidade e organizacao

Ola! Essa versao traz algumas melhorias que surgiram do uso real do script no dia a dia.

## O que mudou

**Opcao [8] — Executar tudo e desligar**
Adicionei a opcao [8] no menu que executa todos os modulos e desliga o computador ao final. Util para deixar rodando a manutencao e ir embora sem precisar esperar. O desligamento tem 10 segundos de espera com aviso na tela, dando tempo de cancelar com CTRL+C caso precise.

**Logs salvos na pasta do script**
Os logs agora sao salvos na mesma pasta onde o script esta localizado, usando $PSScriptRoot. Antes ficavam em uma pasta fixa no perfil do usuario, o que dificultava encontrar depois.

**Gitignore adicionado**
Adicionado .gitignore no repositorio para evitar que arquivos de log subam por acidente para o GitHub.

## Modulos disponiveis

| ID | Modulo |
|----|--------|
| 1  | Limpeza de temporarios |
| 2  | Reparo do sistema (DISM + SFC + CHKDSK) |
| 3  | Otimizacao de rede |
| 4  | Seguranca (Defender) |
| 5  | Desempenho |
| 6  | Tudo + reinicia automaticamente |
| 7  | Tudo + pergunta antes de reiniciar |
| 8  | Tudo + desliga o computador |

## Como usar

Nada mudou na forma de usar. Coloque os dois arquivos na mesma pasta e execute INICIAR-MANUTENCAO.bat como administrador.

Logs ficam na mesma pasta do script com o nome: Manutencao_Log_YYYY-MM-DD_HH-mm.txt

## Ainda na lista

- [ ] Firefox cache na limpeza de browsers
- [ ] Parametro -Silent para automacao via agendador
- [ ] Mais navegadores (Opera, Brave)

---

Obrigado por usar! Se encontrar bug ou tiver ideias, abre uma issue :)
