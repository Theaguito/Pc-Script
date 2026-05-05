# pc-maintenance-script

Script PowerShell de manutenção e inventário para Windows com menu interativo.

---

## Por que criei isso?

Trabalhando no suporte de TI da empresa, percebi que toda vez que ia fazer manutenção em um equipamento, o processo era diferente — dependia do que eu lembrava no momento, do tempo disponível, e nem sempre tudo era feito do jeito certo.

Além disso, não tinha uma forma fácil de saber o estado dos computadores da empresa: modelo, quantidade de memória, tipo de disco, uso de armazenamento. Tudo era feito na mão, abindo propriedades do sistema ou rodando comandos separados.

Resolvi juntar os dois problemas em um script só: ao abrir, já mostra as informações completas do hardware. E no menu, cada tarefa de manutenção pode ser executada individualmente ou tudo de uma vez.

Ainda estou aprendendo PowerShell, então qualquer feedback ou sugestão é bem-vindo.

---

## O que ele faz

Ao iniciar, o script exibe automaticamente as especificações do equipamento:

```
  --------------------------------------------------------------
   INFORMACOES DO EQUIPAMENTO
  --------------------------------------------------------------
  Sistema Op. : Windows 11 Pro
  Processador : Intel Core i5-10400 @ 2.90GHz
  Memoria RAM : 16.0 GB total | 9.2 GB livre
  Placa Video : NVIDIA GeForce GTX 1650
  Placa-mae   : ASUSTeK PRIME B460M-A
  Disco 0     : WD Blue SN570 | 500 GB | SSD
  Volume C:   : 465.6GB total | 210.3GB livre | Uso: 55%
  --------------------------------------------------------------
```

Depois exibe o menu:

```
  [1]  Limpeza de Temporarios e Cache
  [2]  Reparo do Sistema (DISM + SFC + CHKDSK)
  [3]  Otimizacao de Rede (DNS, Winsock, TCP/IP)
  [4]  Atualizacoes de Windows e Drivers
  [5]  Seguranca (Defender + Firewall)
  [6]  Otimizacao de Desempenho (Disco, Servicos, Energia)

  [7]  EXECUTAR TUDO + REINICIAR AUTOMATICAMENTE
  [8]  EXECUTAR TUDO + PERGUNTAR ANTES DE REINICIAR

  [0]  Sair
```

Cada módulo pode ser rodado separadamente. Útil quando você precisa fazer só uma coisa específica sem esperar o processo completo.

---

## O que cada opção faz

**[1] Limpeza**
Remove arquivos temporários do sistema e do usuário, cache dos browsers (Chrome, Edge, Firefox), logs do Windows, cache do Windows Update, minidumps e esvazia a lixeira. Roda o Cleanmgr com todas as opções ativas no final.

**[2] Reparo do sistema**
Executa DISM `/RestoreHealth` para reparar a imagem do Windows, depois SFC `/scannow` para verificar arquivos corrompidos, e agenda o CHKDSK para rodar no próximo boot.

**[3] Rede**
Libera e renova o IP, limpa o cache DNS, reseta Winsock e TCP/IP, limpa a tabela ARP. Resolve a maioria dos problemas de conectividade que não têm relação com o hardware.

**[4] Atualizações**
Instala atualizações do Windows e drivers via módulo PSWindowsUpdate. Gera um relatório `.txt` com todos os drivers instalados na área de trabalho.

**[5] Segurança**
Verifica se o Defender está ativo, atualiza as definições de vírus, roda uma varredura rápida e confere o status do Firewall nos três perfis (Domain, Private, Public).

**[6] Desempenho**
Ativa o plano de energia Alto Desempenho, configura a memória virtual como automática, verifica se os serviços críticos estão rodando e otimiza os discos (TRIM para SSD, Defrag para HDD).

**[7] Executar tudo — reinício automático**
Roda todos os módulos em sequência e reinicia com contagem regressiva de 5 segundos. Sem interação.

**[8] Executar tudo — com confirmação**
Igual ao [7], mas pergunta se quer reiniciar antes de fazer isso.

---

## Arquivos gerados

Toda execução gera dois arquivos na área de trabalho:

- `Manutencao_Log_YYYY-MM-DD_HH-mm.txt` — registro completo com horário de cada ação
- `Relatorio_Drivers_YYYYMMDD.txt` — lista de todos os drivers instalados no momento

---

## Como usar

1. Baixe os dois arquivos e coloque-os na **mesma pasta**:
   - `Manutencao-PC.ps1`
   - `INICIAR-MANUTENCAO.bat`

2. Clique com o botão direito em `INICIAR-MANUTENCAO.bat`

3. Selecione **Executar como administrador**

> O `.bat` já pede elevação automaticamente se você esquecer de rodar como admin.

---

## Requisitos

- Windows 10 ou Windows 11
- PowerShell 5.1 ou superior (já vem instalado no Windows)
- Conexão com internet (para as opções de atualização)
- Privilégio de administrador

---

## Estrutura do repositório

```
pc-maintenance-script/
├── Manutencao-PC.ps1         # Script principal com menu e todos os módulos
└── INICIAR-MANUTENCAO.bat    # Lançador com elevação automática de privilégio
```

---

## Contribuindo

Se quiser sugerir algo, corrigir um bug ou adicionar uma funcionalidade, fique à vontade para abrir uma issue ou um pull request. Ainda estou evoluindo com PowerShell, então qualquer melhoria é bem-vinda.

---

## Licença

MIT — pode usar, modificar e distribuir à vontade.
