# Prompt para implementar os índices no Red-Driver-MySQL

Copie o texto abaixo para uma sessão aberta no repositório do driver MySQL.

---

Implemente o suporte aos novos índices declarativos do Red no Red-Driver-MySQL.
O core foi implementado no checkout local `/Users/fernando/Projects/Red`, incluindo
SQLite e PostgreSQL. Use esse checkout como fonte da API; não use apenas a versão
do Red instalada pelo Zef nem o commit antigo fixado no container do driver.
Leia o AGENTS.md aplicável e preserve alterações locais. Não faça release, push ou
altere pins de CI para commits que ainda não existam.

## Comportamento esperado

As traits já são responsabilidade do core. Não as reimplemente no driver:

```raku
model Contact {
    has Int $.id is serial;
    has Int $.account-id is indexed<account-email>;
    has Str $.email is indexed('account-email', { .lc });
    has Str $.handle is unique{ .lc };
    has Str $.code is unique;
    has Str $.tag is column{ :indexed };
    has Str $.label is column{ :indexed('label-search', { .lc }) };
    has $.email-search is index{ .email.lc };
    has $.account-email is unique-index{ .account-id, .email.lc };
}
```

`indexed` e `unique` implicam coluna; seus blocos recebem a expressão da coluna.
`index` e `unique-index` são atributos de metadados; seus blocos recebem o model.
Nomes iguais agrupam as contribuições num índice composto ordenado. Ambas as
traits de coluna aceitam vários nomes, inclusive com uma transformação:
`is indexed(<a b>, { .lc })` e `is unique(<a b>, { .lc })`.

`.^create-table` e `schema(...).create` criam os índices automaticamente. O novo
`.^create-indexes` adiciona todas as declarações a uma tabela existente, inclusive
`is unique` tradicional. Repetições devem reutilizar definições existentes; uma
definição diferente com o mesmo nome SQL gera `X::Red::Index`. Nenhum índice é
removido ou reconstruído automaticamente. Duplicatas existentes devem impedir a
criação de índices únicos e resultar em `X::Red::Driver::Mapped::Unique`.

## Interfaces que já existem no core

Leia primeiro:

- `lib/Red/AST/CreateIndex.rakumod` e `lib/Red/Index.rakumod`;
- `create-indexes` em `lib/MetamodelX/Red/Model.rakumod`;
- os hooks e tradutores de índices em `lib/Red/Driver/CommonSQL.rakumod`;
- as implementações de `indexes-for-table` em SQLite e Pg;
- `t/97-indexes.rakutest` e seu fixture `t/lib/IndexedFixture.rakumod`.

`Red::AST::CreateIndex` tem `table`, `name` (nome SQL já gerado pelo core),
`logical-name`, `unique`, `inline` e `keys`, uma lista ordenada de ASTs de DDL.
`inline` identifica as constraints únicas tradicionais. Não gere outros nomes
no driver nem transforme os valores armazenados.

As colunas nessas ASTs são `Red::AST::IndexColumn`, com `name` e `value-type`.
O CommonSQL já traduz essas referências sem qualificá-las com tabelas/aliases e
usa `self.table-name-wrapper`, portanto deve herdar os backticks do MySQL.
`index-key(Red::AST)` retorna SQL de uma chave e rejeita binds. O tradutor genérico
já envolve cada chave funcional em parênteses adicionais, gerando, por exemplo:

```sql
CREATE INDEX `contact_account_email_idx`
ON `contact` (`account_id`, (LOWER(`email`)))
```

Verifique a tradução herdada antes de adicionar overrides. Preserve as listas de
binds vazias para DDL e o escape correto de identificadores e literais. Não
habilite binds em CREATE INDEX e não interpole dados recebidos em consultas aos
catálogos.

## Implementação necessária no driver

Implemente `method indexes-for-table(Str $table --> Array)`. Retorne um Array de
Hashes, um por índice, com este contrato:

```raku
{
    name    => 'contact_account_email_idx',
    unique  => False,
    keys    => ['`account_id`', 'lower(`email`)'],
    partial => False,
    valid   => True,
}
```

`keys` contém fragmentos SQL na ordem das chaves, não nomes de atributos Raku.
Inclua PRIMARY KEY e índices únicos associados a constraints para que o core
reconheça constraints legadas, sem recriá-las com os novos nomes gerados.

Consulte `information_schema.STATISTICS`, filtrando por `TABLE_SCHEMA = DATABASE()`
e `TABLE_NAME = ?`, com o nome da tabela em bind. Ordene por `INDEX_NAME` e
`SEQ_IN_INDEX`. Use `NON_UNIQUE`, `COLUMN_NAME`, `EXPRESSION`, `SUB_PART`,
`COLLATION`, `INDEX_TYPE` e `IS_VISIBLE` para descrever a definição efetiva.
Preserve a distinção entre uma coluna, uma expressão, uma chave com prefixo e uma
chave descendente. Um índice incompatível não deve ser declarado equivalente a
um índice completo ascendente; use a definição das chaves e/ou `valid => False`
para sinalizar os casos que este recurso não suporta. `partial` representa um
predicado WHERE; não o use para esconder chaves ou expressões desconhecidas.

O helper herdado `index-catalog-rows($statement)` retorna uma Seq de Hashes e
trata tanto fim de linhas vazio quanto `IterationEnd`. Use-o para consumir os
resultados sem depender de detalhes de outro backend.

O core compara as chaves chamando
`index-key-fingerprint(Str $key --> Str)` nos fragmentos esperados e existentes.
O default faz tokenização conservadora, preserva literais, agrupamento,
modificadores e caixa de identificadores quoted, e normaliza diferenças simples
de espaços/quoting. Verifique como o MySQL descreve LOWER, SUBSTR, casts,
collations e literais com introduzidores de charset. Se necessário, sobrescreva
essa função no driver para normalizar apenas diferenças de representação que
sejam equivalentes. Não use substituições globais que alterem strings SQL ou
apaguem diferenças de definição. Índices repetidos devem continuar idempotentes
com os tipos e a collation que o driver usa por padrão.

Valide em MySQL 8.4, já usado no compose/CI do driver. Consulte a documentação
oficial para chaves funcionais; o suporte foi introduzido em MySQL 8.0.13.
Não implemente fallback silencioso para índice de coluna quando uma expressão
não for suportada. Preserve o mapeamento do erro 1062 para a exceção de unicidade
quando CREATE UNIQUE INDEX encontra dados duplicados. Caso sejam necessários
ajustes pequenos no contrato do core, explique-os e cubra-os com testes; não
remova capacidades SQLite/Pg para acomodar o MySQL.

## Validação obrigatória

Execute os testes do driver e os testes do core usando o checkout local do Red.
O repositório tem `tools/red-test-exec.raku`, que cria uma base isolada por arquivo;
configure `RED_SOURCE` com o caminho local e use `-I` para carregar ambos os
checkouts. No container, monte ou copie o core atualizado e defina RED_SOURCE para
o caminho correspondente. O Dockerfile pode carregar uma revisão antiga em
`/red`: confirme que os testes estão realmente exercitando a nova API.

Cubra pelo menos:

1. Índices simples, compostos, por expressão e únicos; nome + Callable e vários
   grupos; formas equivalentes em `is column` e atributos independentes.
2. `.^create-table`, `schema.create`, tabela já existente e chamadas repetidas a
   `.^create-indexes`, incluindo seleção de driver por `:with`.
3. Ordem das chaves; LOWER e SUBSTR com argumentos literais; SQL sem binds de DDL,
   sem aliases e com backticks corretamente escapados.
4. Reutilização de constraints únicas legadas e adição de constraints únicas
   ausentes. Uma constraint composta não satisfaz uma individual.
5. Mesmo nome com outras chaves, outra unicidade, ordem invertida, prefixo ou
   DESC: detectar conflito antes de executar qualquer índice pendente.
6. Dados duplicados impedem criar unicidade; corrigir os dados permite repetir a
   operação; manter os valores originais armazenados.
7. Catálogo real: verificar as expressões em STATISTICS, a definição por
   SHOW CREATE TABLE/SHOW INDEX e a ausência de índices duplicados.
8. Roles, herança e models pré-compilados. Nos Rakudos com a limitação de blocos
   literais em traits de roles, use uma constante Callable externa, como nos
   testes do core.
9. Regressões de inserts, updates, deletes, identificação por uniques tradicionais,
   JSON, quoting e tipos, sem mudar a semântica existente de collation/NULL.

Execute `t/97-indexes.rakutest` do core contra MySQL e depois a suíte completa com
isolamento por arquivo. Faça compile checks dos módulos alterados e registre os
comandos/resultados. Atualize documentação e Changes do driver conforme os
padrões do repositório. Entregue um resumo do diff e de qualquer limite real de
versão/tipo; informe também o commit do driver que poderá ser fixado no CI do Red
quando as mudanças forem commitadas, sem inventar um hash nem fazer push.
