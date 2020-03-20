
# Rede Física

Todas as operações descritas e respectivos dados deverão ser guardados num schema de base de dados próprio. A título de exemplo o nome de schema usado neste documento será ***physnet***

## Sequência para criação de Rede

Passos para criar e pre-processar uma rede e respectivos procedures de PG/PLSQL

### Esvaziamento da estrutura previamente carregada

Caso a estrutura de dados contenha já uma outra rede, diferente da que pretendemos carregar, ou com uma versão anterior de dados da mesma rede, devemos proceder ao seu esvaziamento com a função ***resetnet()***. Esta função esvazia as tabelas

- arc
- node

e reinicia os respectivos numeradores sequenciais.


### Carregamento de arcos com *collect_arcs()*

A função ***collect_arcs()*** carrega os arcos (tabela ***arc***) da rede a partir de layers geográficas de eixos indicadas na tabela *sources*.

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

Em ***arc*** é indicada uma função custo para os arcos. Esta função, definida para cada caso, deve devolver dois arrays de valores de custo:
- o primeiro para custos de deslocação **directos** (na direcção do desenho da geometria)
- o outro para os custos **reversos** (na direcção oposta ao desenho da geometria)

Um exemplo de função de custos é dado mais à frente no ponto *Exemplo de função de custos*.

Esta função retorna uma estatística dos arcos usáveis e não-usáveis. Um arco será usável se o seu comprimento for maior ou igual ao valor de NODETOLERANCE, parâmetro de rede a indicar na tabela **params** (ver ponto *Parâmetros da rede* mais à frente).

### Passo seguinte: inferir nós com *infer_nodes()*

Neste passo vamos preencher a tabela **node***.

Ao exceutar *infer_nodes()*, para cada ponto extremo de cada arco, é testada a proximidade a outros pontos extemos de outros arcos. Se for encontrado algum outro ponto extremo dentro da tolerância (distância) indicada no parâmetro NODETOLERANCE, uma entrada nova é criada na referida tabela.

Como já referido, os arcos são direccionais, a sua direcção acompanha o sentido do desenho gráfico do arco.

De acordo com este sentido, os arcos poderão dirigir-se para um nó ou partir de um nó. Por isso, a tabela dos nós tem três campos de tipo array de identificadores de arco (*arcid*):

- **nodeid**: número de série identificador do nó;
- **incoming_arcs**: para os arcos que se dirigem ao nó;
- **outgoing_arcs**: para os arcos que partem do nó;
- **all_arcs**: todos os arcos que tocam o nó.

### Terceira etapa: validar os nós inferidos, com *validate_nodes()*

Após inferir os nós, deverá ser verificado se cada arco liga apenas com um ou dois nós. Um arco poderá ligar um nó consigo próprio (auto-relação) se se tratar do arco final de um *cul-de-sac* ou beco-sem-saída.

Esta função lista os erros encontrados, a **lista vazia** indica uma rede **sem erros**.

### Construção da adjacência de nós de rede com *build_adjacency()*

Apesar da topologia de arcos, reunida na tabela **arcs**, ser constituída por arcos **orientados** (permitindo registar e manter a orientação gráfica, factor importante na modelação de redes seguida por software como, por exemplo, *Visum*), a topologia de nós poderá ser bidirecional permitindo que o algoritmo de caminho mais curto usado possa decidir não seguir por um certo arco numa determinada direcção com base apenas nos custos de deslocação retornados pela função custo em uso.

A bidirecionalidade da adjacência a criar é controlada pelo parâmetro booleano *p_dontduplicate* de *build_adjacency()*: se for verdadeiro, a adjacência replicará integralmente o sentido de desenho dos arcos colectados nos dados de partida; se for falso, por cada arco colectado serão definidas adjacências no sentido de desenho do arco e no seu inverso.

As relações de nós consigo próprios (auto-relação em becos-sem-saída ou cul-de-sac) são permitidos.

Assim cada par de nós diferentes, ou iguais no caso da auto-relação, terá obrigatoriamente que ter duas entradas na tabela de adjacência de nós **node_adjacency**.


Esta condição do parágrafo anterior pode ser validada consultando o resultado de *build_adjacency()*: essa condição das duas entradas por arco é verdadeira se *out_min_nodeforarc_count* for igual a *out_min_nodeforarc_count* e ambos iguais ao número dois (resultado de *build_adjacency()* na imagem abaixo).

![build_adjacency](out_build_adjacency.png "Resultado de build_adjacency()")

### Sequência das operações

!!!!!!!!!!

campo node_adjacency passou de arc para v_arcid

Validar número de velcidades nos parÂmetros (SPEEDS) com as devolvidas pelas funcções usadas na construção da tabela respectiva

node arc replacement deve ter foreign key para o código de arco

necessário controle: arcco unidireccional não pode ter duas adjacências (constraint ?)

Marcar estado
Consoante o estado, criar lista de tarefas a executar para ter a rede pronta a responde

Schemas de staging e produção

Substituição de uma fonte arcos / layer

Exportação dos arcos de uma fonte

Áreas sujas - substituição parcial de alguns arcos



!!!!!!!!!!!

Construção inicial de arcos e nós de rede:

1. resetnet() (se necessário)
1. collect_arcs() (5 segundos)
1. infer_nodes()  (52 segundos)
1. validate_nodes() (de imediato a 21 sec -- deve depender se a indexação de alguns campos já terminou)

Se a validação de nós não retornar nenhum caso a corrigir, segue-se a construção da adjacência:

5. build_adjacency() (22 segundos)
6. remove_pseudo_nodes()


    -- configurar search_path para o schema usado ('physnet' neste exemplo)
    SELECT set_config('search_path', '$user", physnet_staging, public', false);

    select resetnet();
    select * from collect_arcs(null);
    -- retorna estatística dos arcos usáveis e não-usáveis
    select infer_nodes();
	-- reindex node_allarc_ix
    select * from validate_nodes();
    -- (deverá retornar zero registos)
	-- reindex node_ougarc_ix e node_incarc_ix
    select * from build_adjacency()

    select * from remove_pseudo_nodes(null)


    .....

    Os passos anteriores deverão ocorrer numa única transacção em modo SERIALIZADO,
    evitando o acesso simulataneo por várias connections?

## Parâmetros da rede

Estes parâmetros são guardados na tabela ***params***.

| Parâmetro | Tipo | Descrição |
|-----------|------|-------|
|SPEEDS| numérico | Número de velocidades a calcular para arco |
|WALKVEL_MPS| numérico | Velocidade de deslocação pedonal m/s |
|NODETOLERANCE | numérico | Tolerância nós - distância máxima admissível entre dois pontos extremos de arcos para que qualquer um deles possa ser tomado como possível localização de um nó de rede |

## Funções adicionais

### *stats*()

Gera uma tabela de estatísticas da rede.

## Exemplo de função de custos

O único exemplo duma função deste tipo, existente neste momento é ***usr_rede_viaria_cost***.

O array de custos devolvido por esta função contém valores para dois tipos de custo de deslocação, por esta ordem:
- custo pedonal
- custo rodoviário

Para determinação do custo de deslocação pedonal, tomamos como referência o valor indicado no parâmetro de rede WALKVEL_MPS (ver o ponto *Parâmetros da rede*).


## Testes

Qualquer alteração a código deve-se correr as funções de teste ......
