# 🧠 Análise de Similaridade de Produtos com Carga Incremental em SQL

## 📖 Sobre o Projeto

Este projeto apresenta uma solução robusta e eficiente, desenvolvida 100% em SQL (T-SQL), para calcular a associação e a similaridade entre produtos (cross-sell).

O principal desafio em análises de afinidade é o alto custo computacional para processar grandes volumes de dados históricos. A abordagem tradicional de reprocessar toda a base de vendas diariamente é lenta, cara e não escalável. Esta solução resolve o problema utilizando uma estratégia de **carga incremental**, processando apenas os dados novos a cada execução e consolidando-os com o histórico já existente.

O resultado é um processo rápido, econômico e confiável, ideal para alimentar sistemas de recomendação e dashboards de Business Intelligence.

---

## ✨ Principais Funcionalidades

- **Processamento Incremental**: Calcula a associação apenas sobre os dados de vendas mais recentes, evitando o reprocessamento completo.
- **Histórico Consolidado**: Armazena os resultados em uma tabela histórica (`SIMILARIDADE_PRODUTOS_HISTORY`), enriquecendo a análise a cada dia.
- **Segurança com Tabela Staging**: Utiliza uma tabela temporária (`#SIMILARIDADE_PRODUTOS_STAGING`) como área de segurança para garantir que os dados históricos não sejam perdidos em caso de falha.
- **Logs de Execução**: Registra o sucesso ou a falha de cada execução em uma tabela de logs (`LOGS_SIMILARIDADE_PRODUTOS`), garantindo total rastreabilidade e facilitando a depuração.
- **Validações Automáticas**: O script verifica se há novas vendas a processar e se a rotina já não foi executada no dia, prevenindo execuções desnecessárias ou duplicadas.
- **Saída Pronta para Consumo**: Gera uma tabela final (`SIMILARIDADE_PRODUTOS`) limpa, com os produtos mais recomendados um para o outro, pronta para ser usada em outras aplicações.

---

## 🏛️ Arquitetura e Funcionamento

O fluxo de execução foi projetado para ser seguro e resiliente:

1. **Verificação Inicial**: O script primeiro checa se há novos registros de venda (`SELLOUT`) para o dia a ser processado e se a rotina já não rodou na data atual. Se uma das condições não for atendida, a execução é abortada e um log é gerado.
2. **Backup (Staging)**: Os dados da tabela `SIMILARIDADE_PRODUTOS_HISTORY` são copiados para uma tabela temporária (`#SIMILARIDADE_PRODUTOS_STAGING`). Uma verificação garante que a cópia foi bem-sucedida.
3. **Cálculo Incremental**: O script calcula as associações de produtos (pares de produtos vendidos juntos e total de vendas) apenas para o período de vendas definido (ex: D-2).
4. **Consolidação**: Os novos resultados calculados são somados aos dados que estão na tabela de staging.
5. **Atualização Atômica**: As tabelas `SIMILARIDADE_PRODUTOS_HISTORY` e `SIMILARIDADE_PRODUTOS` (tabela final) são truncadas e recarregadas com os dados consolidados e atualizados.
6. **Log de Sucesso**: Ao final do processo, um registro de sucesso é inserido na tabela de logs com a data e hora da execução.

---

## 🗂️ Esquema do Banco de Dados

O projeto utiliza as seguintes tabelas:

- **PRODUTOS**: Tabela de dimensão com o cadastro dos produtos.
- **SELLOUT**: Tabela fato com os registros de venda (ID da venda, produto e data).
- **SIMILARIDADE_PRODUTOS_HISTORY**: Tabela principal que armazena os dados consolidados e históricos das associações. É a "memória" do nosso cálculo.
- **SIMILARIDADE_PRODUTOS**: Tabela final, limpa e resumida, que apresenta os top 3 produtos mais associados para cada produto principal. Pronta para ser consumida por um dashboard ou API.
- **LOGS_SIMILARIDADE_PRODUTOS**: Tabela de logs que armazena o histórico de execução da rotina.

---

## 🚀 Como Começar

### 1. Clone o Repositório

```bash
git clone https://github.com/seu-usuario/seu-repositorio.git
```

2. Execute o Script de Setup
O arquivo SQL contém um bloco de código inicial comentado com a instrução:

sql
Copiar
Editar
-- Rode este bloco caso seja a primeira vez que está executando o código --
Execute este bloco em seu ambiente SQL Server. Ele irá:

Criar todas as tabelas necessárias (PRODUTOS, SELLOUT, SIMILARIDADE_PRODUTOS, etc.).

Inserir dados fictícios para permitir um teste funcional imediato.

⚙️ Uso
O script principal (-- Query de rotina) foi projetado para ser automatizado.

Agendamento: A forma ideal de utilização é agendar a execução deste script para rodar periodicamente (ex: uma vez por dia, de madrugada) através de um scheduler de banco de dados, como o SQL Server Agent.

Configuração de Datas: As variáveis no início do script controlam o período de execução:

sql
Copiar
Editar
@Data -- Define qual a data dos registros de SELLOUT a serem processados. Por padrão: DateAdd(Day, -2, GetDate())
@Hoje -- Usada para verificar se a rotina já executou no dia atual
Ao ser executado, o script realizará todo o processo de forma autônoma e, ao final, a tabela SIMILARIDADE_PRODUTOS estará atualizada com as recomendações mais recentes.

✅ Resultado Esperado
Uma base atualizada diariamente com os produtos mais frequentemente comprados juntos, pronta para alimentar:

Dashboards em Power BI, Tableau ou Looker.

Regras de recomendação em e-commerce.

Estratégias de pricing e promoções combinadas.


