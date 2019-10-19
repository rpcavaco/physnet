
# Rede Física

Schema de base de dados ***physnet***

## Sequência para criação de Rede

Passos para criar e pre-processar uma rede e respectivos procedures de PG/PLSQL

### Esvaziamento da estrutura previamente carregada

Caso a estrutura de dados contenha já uma outra rede, diferente da que pretendemos carregar, ou com uma versão anterior de dados da mesma rede, devemos proceder ao seu esvaziamento com a função ***physnet.resetnet()***. Esta função esvazia as tabelas

- physnet.arc
- physnet.node

e reinicia os respectivos numeradores sequenciais.


### Carregamento de arcos com *collect_arcs()*

A função ***collect_arcs()*** carrega os arcos (tabela ***physnet.arcs***) da rede a partir de layers geográficas de eixos indicadas na tabela *physnet.sources*.

Em ***physnet.arcs*** é também indicada uma função custo para os arcos. Esta função, definida para cada caso, deve devolver dois arrays de valores de custo:
- o primeiro para custos de deslocação **directos** (na direcção do desenho da geometria)
- o outro para os custos **reversos** (na direcção oposta ao desenho da geometria)

Um exempplo de função de custos é dado mais à frente no ponto *Exemplo de função de custos*.

### Passo seguinte: inferir nós com *physnet.infer_nodes()*

Neste passo vamos preencher a tabela **physnet.node***.

Para cada ponto extremo de cada arco, é testada a proxiidade a outros pontos extemos de outros arcos. Se fôr encontrado algum outro ponto extremo dentro da tolerância (distância) indicada no parâmetro NODETOLERANCE, uma entrada nova é criada na referida tabela.



## Parâmetros da rede

Estes parâmetros são guardados na tabela ***physnet.params***.

| Parâmetro | Tipo | Descrição |
|-----------|------|-------|
|WALKVEL_MPS| numérico | Velocidade de deslocação pedonal m/s |
|NODETOLERANCE | numérico | Tolerância nós - distância máxima admissível entre dois pontos extremos de arcos para que qualquer um deles possa ser tomado como possível localização de um nó de rede |

## Exemplo de função de custos

O único exemplo duma função deste tipo, existente neste momento é ***physnet.usr_rede_viaria_cost***.

O array de custos devolvido por esta função contém valores para dois tipos de custo de deslocação, por esta ordem:
- custo pedonal
- custo rodoviário

Para determinação do custo de deslocação pedonal, tomamos como referência o valor indicado no parâmetro de rede WALKVEL_MPS (ver o ponto *Parâmetros da rede*).
