
# Rede Física

Schema de base de dados ***physnet***

## Sequência para criação de Rede

Passos para criar e pre-processar uma rede e respectivos procedures de PG/PLSQL

### Esvaziamento da estrutura previamente carregada

Caso a estrutura de dados contenha já uma outra rede, diferente da que pretendemos carregar, ou com uma versão anterior de dados da mesma rede, devemos proceder ao esvaziamento 




### Carregamento de arcos com *collect_arcs()*

A função *collect_arcs()* carrega os arcos (tabela *physnet.arcs*) da rede a partir de layers geográficas de eixos indicadas na tabela *physnet.sources*.

Em *physnet.arcs* é também indicada uma função custo para os arcos. Esta função, definida para cada caso, deve devolver dois arrays de valores de custo:
- o primeiro para custos de deslocação **directos** (na direcção do desenho da geometria)
- o outro para os custos **reversos** (na direcção oposta ao desenho da geometria)

O único exemplo duma função deste tipo, neste momento é *physnet.usr_rede_viaria_cost*.

O array de custos devolvido por esta função contém valores para dois tipos de custo de deslocação, por esta ordem:
- custo pedonal
- custo rodoviário

2.
