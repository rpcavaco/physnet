
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

Os arcos são direccionais, a sua direcção acompanha o sentido do desenho gráfico do arco.

Cada arco representa uma linha geométrica, com dois ou mais vértices que ligará dois nós de rede. Os arcos são invariavelmente copiados de um tema geográfico de linhas, preferencialmente uma tabela PostGIS com geometria de tipo POLYLINE. O tipo MULTIPOLYLINE não deve ser usado porque permite uma linha dividida em componentes não necessariamente contíguos e sequenciais, dificultando a mais que certa necessidade de interpolar localizações sobre arcos com atribuição de custos.

Neste momento não é filtrado o tipo de geometria.

Cada registo de arco contém:

- srcid: identificador da fonte >>>> WORK 20191019_2015 <<<<

Em ***physnet.arcs*** é indicada uma função custo para os arcos. Esta função, definida para cada caso, deve devolver dois arrays de valores de custo:
- o primeiro para custos de deslocação **directos** (na direcção do desenho da geometria)
- o outro para os custos **reversos** (na direcção oposta ao desenho da geometria)

Um exempplo de função de custos é dado mais à frente no ponto *Exemplo de função de custos*.

### Passo seguinte: inferir nós com *physnet.infer_nodes()*

Neste passo vamos preencher a tabela **physnet.node***.

Para cada ponto extremo de cada arco, é testada a proximidade a outros pontos extemos de outros arcos. Se fôr encontrado algum outro ponto extremo dentro da tolerância (distância) indicada no parâmetro NODETOLosANCE, uma entrada nova é criada na referida tabela.

Como já referido, os arcos são direccionais, a sua direcção acompanha o sentido do desenho gráfico do arco.

De acordo com este sentido, os arcos poderão dirigir-se para um nó ou partir de um nó. Por isso, a tabela dos nós tem três campos de tipo array de identificadores de arco (*arcid*):

- **incoming_arcs**: para os arcos que se dirigem ao nó;
- **outgoing_arcs**: para os arcos que partem do nó;
- **all_arcs**: todos os arcos que tocam o nó.





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
