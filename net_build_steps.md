
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

- **srcid**: identificador da layer fonte
- **srcarcid**: identificador deste arco na fonte
- **arcid**: identificador global do arco
- **dircosts**: array de custos de deslocação na direcção de desenho do arco
- **invcosts**: array de custos de deslocação na direcção contrária ao desenho do arco
- **arcgeom**: geometria do arco
- **fromnode**: geometria do nó inicial
- **tonode**: geometria do nó final
- **usable**: flag para remover este arco das restantes operações de construção da rede

Em ***physnet.arcs*** é indicada uma função custo para os arcos. Esta função, definida para cada caso, deve devolver dois arrays de valores de custo:
- o primeiro para custos de deslocação **directos** (na direcção do desenho da geometria)
- o outro para os custos **reversos** (na direcção oposta ao desenho da geometria)

Um exemplo de função de custos é dado mais à frente no ponto *Exemplo de função de custos*.

### Passo seguinte: inferir nós com *physnet.infer_nodes()*

Neste passo vamos preencher a tabela **physnet.node***.

Ao exceutar *physnet.infer_nodes()*, para cada ponto extremo de cada arco, é testada a proximidade a outros pontos extemos de outros arcos. Se fôr encontrado algum outro ponto extremo dentro da tolerância (distância) indicada no parâmetro NODETOLERANCE, uma entrada nova é criada na referida tabela.

Como já referido, os arcos são direccionais, a sua direcção acompanha o sentido do desenho gráfico do arco.

De acordo com este sentido, os arcos poderão dirigir-se para um nó ou partir de um nó. Por isso, a tabela dos nós tem três campos de tipo array de identificadores de arco (*arcid*):

- **nodeid**: número de série identificador do nó;
- **incoming_arcs**: para os arcos que se dirigem ao nó;
- **outgoing_arcs**: para os arcos que partem do nó;
- **all_arcs**: todos os arcos que tocam o nó.

### Terceira etapa: validar os nós inferidos, com *physnet.validate_nodes()*

Após inferir os nós, deverá ser verificado se cada arco liga apenas dois nós. Um arco poderá ligar um nó consigo próprio se constituir um *cul-de-sac*.

Esta função lista os erros encontrados, a **lista vazia** indica uma rede **sem erros**.

### Sequência das operações

1. resetnet() (se necessário)
1. collect_arcs() (imediato)
1. infer_nodes()  (49 segundos)
1. validate_nodes()


    select physnet.resetnet();
    select * from physnet.collect_arcs();
    .........
    select physnet.infer_nodes();
    select physnet.validate_nodes();


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

### Construção da adjacência de nós de rede com *build_adjacency()*
