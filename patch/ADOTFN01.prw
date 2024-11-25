//Bibliotecas
#Include "Totvs.ch"
#Include "FWMVCDEF.ch"

/*/{Protheus.doc} ADOTFN01
Importador Contas a Pagar
@author Thalys Augusto
@since 08/11/2024
@version 1.0
@type function
/*/
User Function ADOTFN01()
	Local aArea := FWGetArea()
	Local cDirIni := GetTempPath()
	Local cTipArq := 'Arquivos com separações (*.csv) | Arquivos texto (*.txt) | Todas extensões (*.*)'
	Local cTitulo := 'Seleção de Arquivos para Processamento'
	Local lSalvar := .F.
	Local cArqSel := ''

	//Se não estiver sendo executado via job
	If ! IsBlind()

		//Chama a função para buscar arquivos
		cArqSel := tFileDialog(;
			cTipArq,;  // Filtragem de tipos de arquivos que serão selecionados
			cTitulo,;  // Título da Janela para seleção dos arquivos
			,;         // Compatibilidade
			cDirIni,;  // Diretório inicial da busca de arquivos
			lSalvar,;  // Se for .T., será uma Save Dialog, senão será Open Dialog
			;          // Se não passar parâmetro, irá pegar apenas 1 arquivo; Se for informado GETF_MULTISELECT será possível pegar mais de 1 arquivo; Se for informado GETF_RETDIRECTORY será possível selecionar o diretório
			)

		//Se tiver o arquivo selecionado e ele existir
		If ! Empty(cArqSel) .And. File(cArqSel)
			Processa({|| fImporta(cArqSel) }, 'Importando...')
		EndIf
	EndIf

	FWRestArea(aArea)
Return

/*/{Protheus.doc} fImporta
Função que processa o arquivo e realiza a importação para o sistema
@author Thalys Augusto
@since 08/11/2024
@version 1.0
@type function
/*/
Static Function fImporta(cArqSel)
	Local cDirTmp          := GetTempPath()
	Local cArqLog          := 'importacao_' + dToS(Date()) + '_' + StrTran(Time(), ':' , '-' ) + '.log'
	Local nTotLinhas       := 0
	Local cLinAtu          := ''
	Local nLinhaAtu        := 0
	Local cJson            := ""
	Local cGetParms        := ""
	Local cHeaderGet       := ""
	Local nTimeOut         := 200
	Local aHeadStr         :={"Content-Type: application/json"}
	Local oObjJson         := Nil
	Local aLinha           := {}
	Local oArquivo
	Local cLog             := ''
	Local lIgnor01         := FWAlertYesNo( 'Deseja ignorar a linha 1 do arquivo?' , 'Ignorar?' )
	Local cPastaErro       := '\x_logs\'
	Local cNomeErro        := ''
	Local cTextoErro       := ''
	Local cFornec          := ''
	Local cForLoja         := '01'
	Local aLogErro         := {}
	Local nLinhaErro       := 0
	Local lIncOk           := .F.
	//Variáveis do ExecAuto
	Private cAlias         := GetNextAlias()
	Private cAliasSA2      := GetNextAlias()
	Private aDados         := {}
	Private lMSHelpAuto    := .T.
	Private lAutoErrNoFile := .T.
	Private lMsErroAuto    := .F.
	//Variáveis da Importação
	Private cAliasImp      := 'SA2'
	Private cSeparador     := ';'
	//Variáveis da Importação em MVC
	Private aRotina        := FWLoadMenuDef( 'MATA020' )
	Private oModel         := Nil
	Private cIDAlias       := 'SA2MASTER' //Revise aqui o nome do AddFields da rotina

	//Abre as tabelas que serão usadas
	DbSelectArea(cAliasImp)
	(cAliasImp)->(DbSetOrder(1))
	(cAliasImp)->(DbGoTop())

	//Definindo o arquivo a ser lido
	oArquivo := FWFileReader():New(cArqSel)

	//Se o arquivo pode ser aberto
	If (oArquivo:Open())

		//Se não for fim do arquivo
		If ! (oArquivo:EoF())

			//Definindo o tamanho da régua
			aLinhas := oArquivo:GetAllLines()
			nTotLinhas := Len(aLinhas)
			ProcRegua(nTotLinhas)

			//Método GoTop não funciona (dependendo da versão da LIB), deve fechar e abrir novamente o arquivo
			oArquivo:Close()
			oArquivo := FWFileReader():New(cArqSel)
			oArquivo:Open()

			//Caso você queira, usar controle de transação, descomente a linha abaixo (e a do End Transaction), mas tem algumas rotinas que podem ser impactadas via ExecAuto

			//Enquanto tiver linhas
			While (oArquivo:HasLine())

				//Incrementa na tela a mensagem
				nLinhaAtu++
				IncProc('Analisando linha ' + cValToChar(nLinhaAtu) + ' de ' + cValToChar(nTotLinhas) + '...')

				//Pegando a linha atual e transformando em array
				cLinAtu := oArquivo:GetLine()
				aLinha  := Separa(cLinAtu, cSeparador)

				//Se estiver configurado para pular a linha 1, e for a linha 1
				If lIgnor01 .And. nLinhaAtu == 1
					Loop

					//Se houver posições no array
				ElseIf Len(aLinha) > 0

					//Transformando de caractere para numérico (exemplo '1.234,56' para 1234.56)
					aLinha[3] := StrTran(aLinha[3], '.', '')
					aLinha[3] := StrTran(aLinha[3], ',', '.')
					aLinha[3] := Val(aLinha[3])

					//Transformando os campos caractere, adicionando espaços a direita conforme tamanho do campo no dicionário
					cCGC     := AvKey(aLinha[1], 'A2_CGC' )
					cNome    := AvKey(aLinha[2], 'A2_NOME' )
					nValor   := aLinha[3]
					cCep     := AvKey(aLinha[4], 'A2_CEP' )
					cTipo    := AvKey(aLinha[5], 'A2_TIPO' )
					cTipPIX  := AvKey(aLinha[6], 'F72_TPCHV' )
					cChavPix := AvKey(aLinha[7], 'F72_CHVPIX' )
					cDataEmi := AvKey(aLinha[8], 'E2_EMISSAO' )

					//Utiliza HTTPGET para retornar os dados da Receita Federal
					//cJson := HttpGet('https://viacep.com.br/ws/'+ cCep + '/json/', cGetParms, nTimeOut, aHeadStr, @cHeaderGet)
					//cJson := DecodeUTF8(cJson)
					//cJson := NoAcento(cJson)

					// Verifica se o JSON contém erro antes de tentar deserializar
					//If "erro" $ cJson .And. FWJsonDeserialize(cJson, @oObjJson)
					//	// Tratamento quando a API retorna erro
					//	If oObjJson:erro == "true"
					//		// Define valores padrão para as variáveis
					//		cEnder  := ""
					//		cBairro := ""
					//		cMuni   := ""
					//		cEstado := ""
					//		cCodMun := ""
					//		// Log do erro (opcional)
					//		//cLog += '- CEP ' + cCep + ' não encontrado na API ViaCEP.' + CRLF
					//	Else
					//		// Caso não haja erro, preenche as variáveis com os dados retornados
					//		cEnder  := oObjJson:logradouro
					//		cBairro := oObjJson:Bairro
					//		cMuni   := oObjJson:localidade
					//		cEstado := oObjJson:uf
					//		cCodMun := Substr(oObjJson:ibge,3)
					//	EndIf
					//Else
					//	// Caso o JSON não contenha erro e seja válido
					//	If FWJsonDeserialize(cJson, @oObjJson)
					//		cEnder  := oObjJson:logradouro
					//		cBairro := oObjJson:Bairro
					//		cMuni   := oObjJson:localidade
					//		cEstado := oObjJson:uf
					//		cCodMun := Substr(oObjJson:ibge,3)
					//	Else
					//		// Se a deserialização falhar, defina valores padrão e log de erro
					//		cEnder  := ""
					//		cBairro := ""
					//		cMuni   := ""
					//		cEstado := ""
					//		cCodMun := ""
					//		//cLog += '- Erro ao processar JSON da API ViaCEP para o CEP ' + cCep + '.' + CRLF
					//	EndIf
					//EndIf


					If Select(cAlias) <> 0
						(cAlias)->(DbCloseArea())
					EndIf
					//Pegando o último código do fornecedor conforme a query
					BeginSql Alias cAlias
						%noparser%

						SELECT
							max(A2_COD) A2_COD
						FROM
							%table:SA2% SA2 WITH (NOLOCK)
						WHERE
							A2_COD NOT IN ('MUNIC', 'UNIAO', 'ISS', 'INSS')
					EndSql

					(cAlias)->(dbGoTop())

					cFornec := AvKey((cAlias)->A2_COD, 'A2_COD')
					cFornec := Soma1(cFornec)

					If Select(cAliasSA2) <> 0
						(cAliasSA2)->(DbCloseArea())
					EndIf
					//Verificando se o fornecedor existe
					BeginSql Alias cAliasSA2
						%noparser%

						SELECT
							A2_COD,
							A2_LOJA
						FROM
							%table:SA2% SA2 WITH (NOLOCK)
						WHERE
							A2_CGC = %exp:cCGC%
							AND SA2.D_E_L_E_T_ <> '*'
					EndSql

					(cAliasSA2)->(dbGoTop())

					If (cAliasSA2)->(Eof())

						RecLock("SA2", .T.)
						SA2->A2_FILIAL  := xFilial("SA2")
						SA2->A2_COD     := cFornec
						SA2->A2_LOJA    := cForLoja
						SA2->A2_CGC     := cCGC
						SA2->A2_NOME    := Substr(cNome,1,60)
						SA2->A2_NREDUZ  := Substr(cNome,1,14)
						SA2->A2_END     := 'NENHUM'
						SA2->A2_EST     := 'SP'
						//SA2->A2_EST     := cEstado
						SA2->A2_COD_MUN := '00000'
						//SA2->A2_COD_MUN := cCodMun
						SA2->A2_MUN     := 'NA'
						//SA2->A2_MUN     := cMuni
						SA2->A2_NATUREZ := "PAGFOR"
						SA2->A2_PAIS    := "105"
						SA2->A2_CODPAIS := "01058"
						SA2->A2_TPESSOA := "OS"
						SA2->A2_TIPO    := cTipo
						SA2->(MsUnlock())
						lIncOk := .T.

					Else
						cFornec := (cAliasSA2)->A2_COD
						cForLoja := (cAliasSA2)->A2_LOJA
						lIncOk := .T.
					EndIf

					If lIncOk
						U_F885MVC(cFornec,cForLoja, cTipPIX, cChavPix, cDataEmi, nValor, cNome)
					EndIf

				EndIf

			EndDo

			//Se tiver log, mostra ele
			If ! Empty(cLog)
				MemoWrite(cDirTmp + cArqLog, cLog)
				ShellExecute('OPEN', cArqLog, '', cDirTmp, 1)
			EndIf

		Else
			FWAlertError('Arquivo não tem conteúdo!', 'Atenção')
		EndIf

		//Fecha o arquivo
		oArquivo:Close()
	Else
		FWAlertError('Arquivo não pode ser aberto!', 'Atenção')
	EndIf

	//SA2->(DbCloseArea())

Return


/*/{Protheus.doc} F885MVC

	inclusão de chave PIX para fornecedor via execauto (MVC)

	@author      Thalys Augusto
	@example Exemplos
	@param   [Nome_do_Parametro],Tipo_do_Parametro,Descricao_do_Parametro
	@return  Especifica_o_retorno
	@table   Tabelas
	@since   08-11-2024
/*/
User Function F885MVC(cFornec As Character, cForLoja As Character, cTipoCHV As Character, cCodChvPIX As Character, cData as Character, nValor, cNome)

	//Local oModel      := Nil
	Local lOk := .F.
	Local aAreaF72    := GetArea()
	Local cAliasF72 := GetNextAlias()()

	If Select(cAliasF72) <> 0
		(cAliasF72)->(DbCloseArea())
	EndIf

	BeginSql alias cAliasF72
		%noparser%

		SELECT
			F72_COD
		FROM
			%table:F72% F72 WITH (NOLOCK)
		WHERE
			F72_COD = %exp:cFornec%
			AND F72_LOJA = %exp:cForLoja%
			AND F72.D_E_L_E_T_ <> '*'
	EndSql

	If (cAliasF72)->(EOF())

		RecLock('F72', .T.)

		F72_FILIAL := xFilial("F72")
		F72_COD := cFornec
		F72_LOJA := cForLoja
		F72_TPCHV := cTipoCHV
		F72_CHVPIX := cCodChvPIX
		F72_ACTIVE := '1'
		F72->(MsUnlock())

		lOk := .T.

	Else

		lOk := .T.
	EndIf
	(cAliasF72)->(DbCloseArea())

	if lOk
		U_FIN050(cFornec, cForLoja, cData, nValor, cNome)
	Endif

	SA2->(DbCloseArea())
	F72->(DbCloseArea())
	RestArea(aAreaF72)

Return Nil

/*/{Protheus.doc} FIN050

	Inclui o titulo no contas a pagar

	@author      Thalys Augusto
	@example Exemplos
	@param   [Nome_do_Parametro],Tipo_do_Parametro,Descricao_do_Parametro
	@return  Especifica_o_retorno
	@table   Tabelas
	@since   08-11-2024
/*/
User Function FIN050(cFornec, cForLoja, cData, nValor, cNome)

	Local aArray := {}
	Local cFunName := ""
	Local cParcela := ""
	Local cPrefSE2 := "PIX"
	Local cAliasSE2 := GetNextAlias()
	PRIVATE lMsErroAuto := .F.

	cParcela := AvKey(cParcela, 'E2_PARCELA' )
	cPrefSE2 := AvKey(cPrefSE2, 'E2_PREFIXO' )

	If Select(cAliasSE2) <> 0
		(cAliasSE2)->(DbCloseArea())
	EndIf

	BeginSql Alias cAliasSE2
		%noparser%

		Select
			E2_NUM
		from
			%table:SE2% SE2 WITH (NOLOCK)
		Where
			E2_NUM = %exp:cData%
			AND E2_TIPO = 'NF'
			AND E2_NATUREZ = 'PAGFOR'
			AND E2_FORNECE = %exp:cFornec%
			AND E2_LOJA = %exp:cForLoja%
			AND E2_PREFIXO = 'PIX'
			AND E2_EMISSAO = %exp:cData%
			and SE2.D_E_L_E_T_ <> '*'
	EndSql

	cNumero := Alltrim((cAliasSE2)->E2_NUM)

	If cNumero == ""

		DbSelectArea("SE2")
		SE2->(DbSetOrder(1))//E2_FILIAL + E2_PREFIXO + E2_NUM + E2_PARCELA + E2_TIPO + E2_FORNECE + E2_LOJA

		RecLock('SE2',.T.)
		SE2->E2_FILIAL  := xFilial("SE2")
		SE2->E2_PREFIXO := "PIX"
		SE2->E2_NUM     := cData
		SE2->E2_TIPO    := "NF"
		SE2->E2_NATUREZ := "PAGFOR"
		SE2->E2_FORNECE := cFornec
		SE2->E2_LOJA    := cForLoja
		SE2->E2_NOMFOR := Substr(cNome,1,60)
		SE2->E2_EMISSAO := Stod(cData)
		SE2->E2_VENCTO  := Stod(cData)
		SE2->E2_VENCREA := Stod(cData)
		SE2->E2_HIST    := "Pagamento VIA PIX"
		SE2->E2_MOEDA   := 1
		SE2->E2_VALOR   := nValor
		SE2->E2_SALDO   := nValor
		SE2->E2_VLCRUZ   := nValor
		SE2->E2_ORIGEM := "ADOTFN01"
		SE2->(MsUnlock())

		Conout("incluido titulo")

	EndIf

	SE2->(DbCloseArea())

Return Nil
