-- Query de rotina
IF OBJECT_ID('LOGS_SIMILARIDADE_PRODUTOS', 'U') IS NULL
	BEGIN
		CREATE TABLE LOGS_SIMILARIDADE_PRODUTOS (
			LOGS VARCHAR(MAX),
			ATUALIZACAO DATETIME
		);
	END

IF OBJECT_ID('SIMILARIDADE_PRODUTOS', 'U') IS NULL
	BEGIN
		CREATE TABLE SIMILARIDADE_PRODUTOS (
			PRODUTO_A   INT,
			DESCRICAO_A VarChar(100),
			PRODUTO_B   INT,
			DESCRICAO_B VarChar(100),
			QTD_JUNTOS  Decimal(14,2),
			TOTAL       Decimal(14,2),
			CONFIANCA   Decimal(5,4)
		);
	END

IF OBJECT_ID('SIMILARIDADE_PRODUTOS_HISTORY', 'U') IS NULL
	BEGIN
		CREATE TABLE SIMILARIDADE_PRODUTOS_HISTORY (
			PRODUTO_A  VarChar(100),    
			PRODUTO_B  VarChar(100),    
			QTD_JUNTOS Decimal(14,2),
			TOTAL      Decimal(14,2),
			VERSION	   DateTime
		);
	END

IF OBJECT_ID('SELLOUT', 'U') IS NULL
	BEGIN
		CREATE TABLE SELLOUT (
			VENDA     BigInt,	
			PRODUTO   Int,
			MOVIMENTO Date
		);
	END

IF OBJECT_ID('PRODUTOS', 'U') IS NULL
	BEGIN
		CREATE TABLE PRODUTOS (
			PRODUTO		   Int,	
			DESCRICAO	   VarChar(100),	
			STATUS_PRODUTO Int
		);
	END

Declare @Data	     AS Date
Declare @Hoje	     AS Date
Declare @Version	 AS DateTime
Declare @Verificacao AS Int
Declare @Conferencia AS Int
Declare @DataFimLog  AS Date

Set @Data = Cast(DateAdd(Day, - 2, GetDate()) AS Date);
Set @Hoje = Cast(DateAdd(Day, - 0, GetDate()) AS Date);
Set @Version = GetDate();
Set @DataFimLog = DateAdd(Day, - 3, GetDate());

With Verifica_SellOut AS (
    Select 
		Case 
			When Sum(1) > 0
			Then 1
			Else 0
		End AS value
    From 
        SELLOUT
    Where 
        MOVIMENTO = @Data
) 
, Verifica_Associacao AS (
    Select 
		Case 
			When Cast(Max(VERSION) AS Date) != @Hoje
			Then 1
			Else 0
		End AS value 
    From 
        SIMILARIDADE_PRODUTOS_HISTORY
)
Select
	@Verificacao =
		Case
			When A.value + B.value = 2
			Then 1
			Else 0
		End 
From 
	Verifica_Associacao AS A 
Cross Join 
	Verifica_SellOut    AS B;

If @Verificacao != 0

	Begin 
		IF OBJECT_ID('#SIMILARIDADE_PRODUTOS', 'U') IS NULL
			Begin Create Table #SIMILARIDADE_PRODUTOS_STAGING (
					PRODUTO_A  Int,
					PRODUTO_B  Int,
					QTD_JUNTOS Decimal(14,2),
					TOTAL	   Decimal(14,2)
				);
			END

		Insert Into #SIMILARIDADE_PRODUTOS_STAGING (
			PRODUTO_A,
			PRODUTO_B,
			QTD_JUNTOS,
			TOTAL
		)
		Select 
			PRODUTO_A  AS PRODUTO_A,	
			PRODUTO_B  AS PRODUTO_B,	
			QTD_JUNTOS AS QTD_JUNTOS,
			TOTAL      AS TOTAL
		From 
			SIMILARIDADE_PRODUTOS_HISTORY;

		Select
			@Conferencia = 
				Case
					When
						Cast((Select Sum(1) From SIMILARIDADE_PRODUTOS_HISTORY)  AS Int) =
						Cast((Select Sum(1) From #SIMILARIDADE_PRODUTOS_STAGING) AS Int)
					Then 1
					Else 0
				End

		If @Conferencia != 0
			
			Begin 
				Truncate Table SIMILARIDADE_PRODUTOS_HISTORY;
			End
		Else
			Begin
				Insert Into LOGS_SIMILARIDADE_PRODUTOS (
						LOGS,
						ATUALIZACAO
					)
				Select
					'O baldeio da Staging para History falhou!' AS LOGS,
					@Version								    AS ATUALIZACAO
			End

		Select 
			@Conferencia =
				Case 
					When
						Cast((Select Sum(1) From SIMILARIDADE_PRODUTOS_HISTORY) AS Int) > 0
					Then 1
					Else 0 
				End

		If @Conferencia != 0

			Begin 
				With BASE AS (
					Select 
						A.VENDA                 AS VENDA, 
						A.PRODUTO               AS PRODUTO
					From 
						SELLOUT  AS A
					Inner Join 
						PRODUTOS AS B On A.PRODUTO = B.PRODUTO
					Where 
						MOVIMENTO = @Data
						And B.STATUS_PRODUTO In (1) -- Produtos ativos
				)
				, COMBOS AS (
					Select Distinct
						A.VENDA   AS VENDA,
						A.PRODUTO AS PRODUTO_A,
						B.PRODUTO AS PRODUTO_B
					From 
						BASE A
					Join 
						BASE B On A.VENDA = B.VENDA 
					Where 
						A.PRODUTO <> B.PRODUTO
				)
				, FREQ_COMBOS AS (
					Select 
						PRODUTO_A             AS PRODUTO_A,
						PRODUTO_B             AS PRODUTO_B,
						Count(Distinct VENDA) AS QTD_JUNTOS
					From 
						COMBOS
					Group By 
						PRODUTO_A, PRODUTO_B
				)
				, TOTAL_A AS (
					Select 
						PRODUTO               AS PRODUTO_A,
						Count(Distinct VENDA) AS TOTAL
					From 
						BASE
					Group By 
						PRODUTO
				) 
				, RECOMENDACOES AS (
					Select 
						F.PRODUTO_A  AS PRODUTO_A,
						F.PRODUTO_B  AS PRODUTO_B,
						F.QTD_JUNTOS AS QTD_JUNTOS,
						T.TOTAL      AS TOTAL
					From 
						FREQ_COMBOS F
					Join 
						TOTAL_A T On F.PRODUTO_A = T.PRODUTO_A
				) 
				, CONSILIDACAO_DADOS_NOVOS AS (
					Select
						A.PRODUTO_A                 AS PRODUTO_A_ANTIGO,	
						A.PRODUTO_B                 AS PRODUTO_B_ANTIGO,	
						A.QTD_JUNTOS + B.QTD_JUNTOS AS QTD_JUNTOS_SOMADO,
						A.TOTAL + B.TOTAL           AS TOTAL_SOMADOS
					From 
						#SIMILARIDADE_PRODUTOS_STAGING AS A
					Left Join 
						RECOMENDACOES AS B On A.PRODUTO_A = B.PRODUTO_A And A.PRODUTO_B = B.PRODUTO_B
				)
				Insert Into SIMILARIDADE_PRODUTOS_HISTORY (
					PRODUTO_A,	
					PRODUTO_B,	
					QTD_JUNTOS,
					TOTAL,
					VERSION
				)
				Select
					PRODUTO_A_ANTIGO  AS PRODUTO_A,	
					PRODUTO_B_ANTIGO  AS PRODUTO_B,	
					QTD_JUNTOS_SOMADO AS QTD_JUNTOS,
					TOTAL_SOMADOS     AS TOTAL,
					@Version		  AS VERSION
				From 
					CONSILIDACAO_DADOS_NOVOS;

				Truncate Table SIMILARIDADE_PRODUTOS;

				With RECOMENDACOES AS(
					Select 
						PRODUTO_A                                                                         AS PRODUTO_A,	
						PRODUTO_B                                                                         AS PRODUTO_B,	
						QTD_JUNTOS                                                                        AS QTD_JUNTOS,
						TOTAL                                                                             AS TOTAL,
						ROUND(QTD_JUNTOS * 1.0 / TOTAL, 4)                                                AS CONFIANCA,
						ROW_NUMBER() OVER (PARTITION BY PRODUTO_A ORDER BY QTD_JUNTOS * 1.0 / TOTAL DESC) AS POSICAO
					From 
						SIMILARIDADE_PRODUTOS_HISTORY
				)
				, INFO_PRODUTOS AS (
					Select 
						PRODUTO   AS PRODUTO,
						DESCRICAO AS DESCRICAO
					From 
						PRODUTOS
					Where 
						PRODUTO In (Select PRODUTO_A From SIMILARIDADE_PRODUTOS_HISTORY)
				)
				Insert Into SIMILARIDADE_PRODUTOS (
					PRODUTO_A,
					DESCRICAO_A,
					PRODUTO_B,
					DESCRICAO_B,
					QTD_JUNTOS,
					TOTAL,
					CONFIANCA
				)
				Select 
					PRODUTO_A   AS PRODUTO_A,
					B.DESCRICAO AS DESCRICAO_A,
					PRODUTO_B   AS PRODUTO_B,
					C.DESCRICAO AS DESCRICAO_B,
					QTD_JUNTOS  AS QTD_JUNTOS,
					TOTAL       AS TOTAL,
					CONFIANCA   AS CONFIANCA
				From 
					RECOMENDACOES AS A 
				Left Join 
					INFO_PRODUTOS AS B On A.PRODUTO_A = B.PRODUTO
				Left Join 
					INFO_PRODUTOS AS C On A.PRODUTO_B = C.PRODUTO
				Where 
					POSICAO <= 3;

				Delete From LOGS_SIMILARIDADE_PRODUTOS Where Cast(ATUALIZACAO AS Date) <= @DataFimLog;

				Insert Into LOGS_SIMILARIDADE_PRODUTOS (
							LOGS,
							ATUALIZACAO
				)
				Select
					'Rotina de similaridade de produtos executada com sucesso!' AS LOGS,
					@Version													AS ATUALIZACAO;
			End

			Else
				Begin
					Insert Into LOGS_SIMILARIDADE_PRODUTOS (
						LOGS,
						ATUALIZACAO
					)
				Select
					'O Truncate na History falhou!' AS LOGS,
					@Version						AS ATUALIZACAO;
				End
			End
							
Else
	Begin
		Insert Into LOGS_SIMILARIDADE_PRODUTOS (
				LOGS,
				ATUALIZACAO
			)
		Select
			'A tabela de vendas não atualizou ou esta rotina ja foi executada hoje!' AS LOGS,
			@Version																 AS ATUALIZACAO;
End	